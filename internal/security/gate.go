package security

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

const (
	approvalTimeout     = 30 * time.Second
	chatApprovalTimeout = 5 * time.Minute
	sessionGrantTTL     = 12 * time.Hour
)

// Emitter pushes events to a user's clients.
type Emitter interface {
	EmitToUser(userID int64, event string, payload any)
}

// Peer is one connected client.
type Peer interface {
	Emit(event string, args ...any) error
}

// ChatOffer is an approval put up in the chat a run came from.
type ChatOffer struct {
	ApprovalID, AgentID, Category, ToolName string
	UserID                                  int64
	Trust                                   *agent.Trust
	Args                                    map[string]any
	ArgOrder                                []string
	Reason, ReasonKey                       string
	ReasonParams                            map[string]string
	Timeout                                 time.Duration
}

// ChatDelivery offers approvals in chats.
type ChatDelivery interface {
	CanOffer(userID int64, agentID string, trust *agent.Trust) bool
	Offer(o ChatOffer)
	Withdraw(approvalID string, timedOut bool)
}

type pendingApproval struct {
	result    chan string
	timer     *time.Timer
	userID    int64
	runID     string
	toolName  string
	args      map[string]any
	category  string
	escalated bool
	payload   map[string]any
}

// Gate is the approval gate: it asks the owner before a call runs and waits for
// the decision, which may come from the app or the chat the run came from.
type Gate struct {
	DB        *dbx.DB
	Emitter   Emitter
	Policies  *Policies
	Describer Describer
	Log       *slog.Logger

	mu      sync.Mutex
	pending map[string]*pendingApproval
	grants  map[string]bool
	chat    ChatDelivery
}

// NewGate creates the gate and loads the session grants still in force.
func NewGate(db *dbx.DB, emitter Emitter, policies *Policies, log *slog.Logger) *Gate {
	if log == nil {
		log = slog.Default()
	}
	g := &Gate{DB: db, Emitter: emitter, Policies: policies, Describer: Describer{DB: db}, Log: log, pending: map[string]*pendingApproval{}, grants: map[string]bool{}}
	ctx := context.Background()
	if _, err := db.W.ExecContext(ctx, `DELETE FROM approval_session_grants WHERE expires_at <= datetime('now')`); err != nil {
		log.Warn("Failed to load session grants", "error", err)
		return g
	}
	rows, err := db.R.QueryContext(ctx, `SELECT user_id, run_id, tool_name FROM approval_session_grants WHERE expires_at > datetime('now')`)
	if err != nil {
		return g
	}
	defer rows.Close()
	for rows.Next() {
		var userID int64
		var runID, tool string
		if rows.Scan(&userID, &runID, &tool) == nil {
			g.grants[grantKey(userID, runID, tool)] = true
		}
	}
	return g
}

// SetChatDelivery installs the chat approvals.
func (g *Gate) SetChatDelivery(c ChatDelivery) {
	g.mu.Lock()
	g.chat = c
	g.mu.Unlock()
}

func grantKey(userID int64, runID, tool string) string {
	return fmt.Sprintf("%d:%s:%s", userID, runID, tool)
}

func (g *Gate) emit(userID int64, event string, payload any) {
	if g.Emitter != nil {
		g.Emitter.EmitToUser(userID, event, payload)
	}
}

// IsPending says whether an approval still waits.
func (g *Gate) IsPending(id string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	_, ok := g.pending[id]
	return ok
}

// HasSessionGrant says whether the owner allowed a tool for the rest of a run.
func (g *Gate) HasSessionGrant(userID int64, runID, tool string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.grants[grantKey(userID, runID, tool)]
}

func (g *Gate) setStatus(id, status, scope string) {
	var scopeValue any
	if scope != "" {
		scopeValue = scope
	}
	_, _ = g.DB.W.Exec(`UPDATE pending_approvals SET status = ?, scope = COALESCE(?, scope),
		decided_at = CASE WHEN ? = 'pending' THEN decided_at ELSE COALESCE(decided_at, datetime('now')) END, updated_at = datetime('now') WHERE id = ?`,
		status, scopeValue, status, id)
}

func (g *Gate) logDecision(userID int64, runID, tool string, args map[string]any, decision, scope string) {
	encoded, _ := json.Marshal(args)
	if _, err := g.DB.W.Exec(`INSERT INTO tool_approval_log (id, user_id, run_id, tool_name, tool_args_json, decision, scope) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		uuid.NewString(), userID, runID, tool, string(encoded), decision, scope); err != nil {
		g.Log.Warn("Failed to log approval decision", "error", err)
	}
}

// ApprovalRequest is a call that needs the owner.
type ApprovalRequest struct {
	UserID            int64
	RunID, AgentID    string
	ToolName          string
	Args              map[string]any
	ArgOrder          []string
	Reason, ReasonKey string
	ReasonParams      map[string]string
	Trust             *agent.Trust
}

// Request emits tool:approval_required and waits for a decision: "approved",
// "denied", "timeout" or "expired".
func (g *Gate) Request(ctx context.Context, req ApprovalRequest) string {
	id := uuid.NewString()
	g.mu.Lock()
	chat := g.chat
	g.mu.Unlock()
	inChat := chat != nil && chat.CanOffer(req.UserID, req.AgentID, req.Trust)
	timeout := approvalTimeout
	if inChat {
		timeout = chatApprovalTimeout
	}
	expires := time.Now().Add(timeout).UTC().Format("2006-01-02T15:04:05.000Z")
	category := g.Policies.Catalog.CategoryFor(req.ToolName, req.Args)
	if category == "" {
		category = "unknown"
	}
	args := req.Args
	if args == nil {
		args = map[string]any{}
	}
	encoded, _ := json.Marshal(args)
	var runID any
	if req.RunID != "" {
		runID = req.RunID
	}
	copy := g.Describer.Describe(ctx, req.UserID, req.AgentID, req.ToolName, args, req.ArgOrder, category, req.Reason, req.ReasonKey, req.ReasonParams)
	reason := any(nil)
	if copy.Reason != "" {
		reason = copy.Reason
	} else if req.Reason != "" {
		reason = req.Reason
	}
	nullable := func(s string) any {
		if s == "" {
			return nil
		}
		return s
	}
	payload := map[string]any{"approvalId": id, "runId": runID, "toolName": req.ToolName, "toolArgs": args, "category": category, "expiresAt": expires,
		"reason": reason, "title": nullable(copy.Title), "action": nullable(copy.Action), "detail": nullable(copy.Detail)}
	entry := &pendingApproval{result: make(chan string, 1), userID: req.UserID, runID: req.RunID, toolName: req.ToolName, args: args, category: category,
		escalated: req.Reason != "", payload: payload}
	entry.timer = time.AfterFunc(timeout, func() {
		g.mu.Lock()
		_, still := g.pending[id]
		delete(g.pending, id)
		g.mu.Unlock()
		if !still {
			return
		}
		g.setStatus(id, "timeout", "once")
		if chat != nil {
			chat.Withdraw(id, true)
		}
		g.emit(req.UserID, "tool:approval_resolved", map[string]any{"approvalId": id, "decision": "timeout"})
		g.logDecision(req.UserID, req.RunID, req.ToolName, args, "timeout", "once")
		entry.result <- "timeout"
	})
	// The waiter exists before the row and the event do, so a decision that
	// arrives at once is never lost.
	g.mu.Lock()
	g.pending[id] = entry
	g.mu.Unlock()
	_, _ = g.DB.W.Exec(`INSERT INTO pending_approvals (id, user_id, run_id, tool_name, tool_args_json, category, status, expires_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, datetime('now'))`, id, req.UserID, runID, req.ToolName, string(encoded), category, expires)
	g.emit(req.UserID, "tool:approval_required", payload)
	if inChat {
		go chat.Offer(ChatOffer{ApprovalID: id, UserID: req.UserID, AgentID: req.AgentID, Trust: req.Trust, Category: category, ToolName: req.ToolName,
			Args: args, ArgOrder: req.ArgOrder, Reason: req.Reason, ReasonKey: req.ReasonKey, ReasonParams: req.ReasonParams, Timeout: timeout})
	}
	select {
	case decision := <-entry.result:
		return decision
	case <-ctx.Done():
		// The run was paused or stopped while it waited; the approval expires.
		g.expire(id, "Approval expired because the run was interrupted.")
		return "expired"
	}
}

func (g *Gate) expire(id, reason string) {
	g.mu.Lock()
	entry, ok := g.pending[id]
	delete(g.pending, id)
	chat := g.chat
	g.mu.Unlock()
	if !ok {
		return
	}
	entry.timer.Stop()
	g.setStatus(id, "expired", "once")
	if chat != nil {
		chat.Withdraw(id, false)
	}
	g.emit(entry.userID, "tool:approval_resolved", map[string]any{"approvalId": id, "decision": "expired", "reason": reason})
	g.logDecision(entry.userID, entry.runID, entry.toolName, entry.args, "timeout", "once")
	entry.result <- "expired"
}

// Shutdown expires every waiting approval.
func (g *Gate) Shutdown() {
	g.mu.Lock()
	ids := make([]string, 0, len(g.pending))
	for id := range g.pending {
		ids = append(ids, id)
	}
	g.mu.Unlock()
	for _, id := range ids {
		g.expire(id, "Approval expired because the server restarted.")
	}
}

// OfferPending re-sends the approvals still waiting on a user to a client that
// just connected.
func (g *Gate) OfferPending(peer Peer, userID int64) {
	now := time.Now()
	g.mu.Lock()
	var payloads []map[string]any
	for _, entry := range g.pending {
		if entry.userID != userID {
			continue
		}
		if t, err := time.Parse("2006-01-02T15:04:05.000Z", entry.payload["expiresAt"].(string)); err == nil && !t.After(now) {
			continue
		}
		payloads = append(payloads, entry.payload)
	}
	g.mu.Unlock()
	for _, p := range payloads {
		_ = peer.Emit("tool:approval_required", p)
	}
}

// Decided is the call a decision answered.
type Decided struct {
	RunID, ToolName string
	Args            map[string]any
}

func (g *Gate) settle(id string, entry *pendingApproval, decision, scope string) {
	entry.timer.Stop()
	g.setStatus(id, decision, scope)
	g.mu.Lock()
	chat := g.chat
	g.mu.Unlock()
	if chat != nil {
		chat.Withdraw(id, false)
	}
	logScope := scope
	if scope == "always" {
		logScope = "session"
	}
	g.logDecision(entry.userID, entry.runID, entry.toolName, entry.args, decision, logScope)
	g.emit(entry.userID, "tool:approval_resolved", map[string]any{"approvalId": id, "decision": decision})
	entry.result <- decision
}

// Resolve applies the owner's decision; nil when nothing was pending.
func (g *Gate) Resolve(id string, userID int64, decision, scope string) *Decided {
	g.mu.Lock()
	entry, ok := g.pending[id]
	if !ok || entry.userID != userID {
		g.mu.Unlock()
		return nil
	}
	delete(g.pending, id)
	if decision != "approved" {
		decision = "denied"
	}
	if scope != "session" && scope != "always" {
		scope = "once"
	}
	wide := decision == "approved" && scope != "once"
	if wide {
		g.grants[grantKey(userID, entry.runID, entry.toolName)] = true
	}
	g.mu.Unlock()
	if wide {
		_, _ = g.DB.W.Exec(`INSERT INTO approval_session_grants (user_id, run_id, tool_name, expires_at, updated_at) VALUES (?, ?, ?, ?, datetime('now'))
			ON CONFLICT(user_id, run_id, tool_name) DO UPDATE SET expires_at = excluded.expires_at, updated_at = excluded.updated_at`,
			userID, entry.runID, entry.toolName, time.Now().Add(sessionGrantTTL).UTC().Format("2006-01-02T15:04:05.000Z"))
	}
	g.settle(id, entry, decision, scope)
	// A wider grant also answers the parallel calls still waiting that it covers.
	if wide {
		g.mu.Lock()
		var covered []string
		for otherID, other := range g.pending {
			if other.userID != userID {
				continue
			}
			sameTool := other.runID == entry.runID && other.toolName == entry.toolName
			sameCategory := scope == "always" && !other.escalated && other.category == entry.category
			if sameTool || sameCategory {
				covered = append(covered, otherID)
			}
		}
		entries := map[string]*pendingApproval{}
		for _, otherID := range covered {
			entries[otherID] = g.pending[otherID]
			delete(g.pending, otherID)
		}
		g.mu.Unlock()
		for otherID, other := range entries {
			g.settle(otherID, other, "approved", scope)
		}
	}
	return &Decided{RunID: entry.runID, ToolName: entry.toolName, Args: entry.args}
}

// Decide is a decision from the owner, wherever it was made; "always" also
// saves the category policy.
func (g *Gate) Decide(ctx context.Context, id string, userID int64, decision, scope string) *Decided {
	decided := g.Resolve(id, userID, decision, scope)
	if decided != nil && decision == "approved" && scope == "always" {
		if category := g.Policies.Catalog.CategoryFor(decided.ToolName, decided.Args); category != "" {
			if err := g.Policies.SetPolicy(ctx, userID, category, "allow"); err != nil {
				g.Log.Warn("Failed to save always-allow policy", "error", err)
			}
		}
	}
	return decided
}

// StoredStatus is the stored status of an approval ("" when none).
func (g *Gate) StoredStatus(ctx context.Context, id string, userID int64) string {
	var status string
	_ = g.DB.R.QueryRowContext(ctx, `SELECT status FROM pending_approvals WHERE id = ? AND user_id = ?`, id, userID).Scan(&status)
	return status
}

// ── The policy gate of one run ──────────────────────────────────────────────

// Guard builds the run gates: delegation, agent restriction, category policy
// and approval, in that order. A check that cannot decide blocks.
type Guard struct {
	DB        *dbx.DB
	Policies  *Policies
	Approvals *Gate
	Registry  *tools.Registry
	// HostTerminal reports that commands run on the server itself, where nothing
	// else stands between content a run read and the machine.
	HostTerminal func() bool
	// WorkspaceBusy says a sub-agent of the run is changing the workspace.
	WorkspaceBusy func(runID string) bool
	Log           *slog.Logger
}

// Gate is the ai.Gate of a run.
func (g *Guard) Gate(r *agent.Run) ai.Gate {
	if g.Log == nil {
		g.Log = slog.Default()
	}
	return &runGate{g: g, r: r}
}

type runGate struct {
	g *Guard
	r *agent.Run
}

func (rg *runGate) WorkspaceBusy(s *ai.Session) bool {
	return rg.g.WorkspaceBusy != nil && rg.g.WorkspaceBusy(rg.r.ID)
}

func argOrder(call ai.Call) []string {
	raw := call.Raw.Function.Arguments
	dec := json.NewDecoder(strings.NewReader(raw))
	var out []string
	if t, err := dec.Token(); err != nil || t != json.Delim('{') {
		return nil
	}
	depth := 0
	expectKey := true
	for dec.More() || depth > 0 {
		t, err := dec.Token()
		if err != nil {
			break
		}
		switch v := t.(type) {
		case json.Delim:
			if v == '{' || v == '[' {
				depth++
			} else {
				depth--
			}
			if depth == 0 {
				expectKey = true
			}
		case string:
			if depth == 0 && expectKey {
				out = append(out, v)
				expectKey = false
				continue
			}
			if depth == 0 {
				expectKey = true
			}
		default:
			if depth == 0 {
				expectKey = true
			}
		}
	}
	return out
}

func (rg *runGate) publish(s *ai.Session, payload map[string]any) {
	if s != nil && s.Env.Journal != nil {
		s.Env.Journal.Publish("permission_decision", payload)
	}
}

// BeforeToolCall runs the security checks of a call.
func (rg *runGate) BeforeToolCall(ctx context.Context, s *ai.Session, call ai.Call, meta tools.Meta) (block bool, reason string) {
	g, r := rg.g, rg.r
	name, args := call.Name, call.Arguments
	if args == nil {
		args = map[string]any{}
	}
	trust := r.Trust()
	category := g.Policies.Catalog.CategoryFor(name, args)
	decision, by, approved := "allow", "", false
	defer func() {
		if category != "" || block {
			if block {
				decision = "deny"
			}
			who := by
			if who == "" {
				if approved {
					who = "owner_approval"
				} else {
					who = "policy"
				}
			}
			var cat any
			if category != "" {
				cat = category
			}
			rg.publish(s, map[string]any{"tool": name, "category": cat, "decision": decision, "by": who, "tainted": trust.Tainted()})
		}
	}()
	safe := g.Policies.Catalog.Safe(name)
	userID := r.UserID
	// Delegation: categories a manager took away; the user's own mode cannot lift it.
	if !safe && category != "" && !Permitted(ctx, g.DB, userID, category) {
		by = "delegation"
		g.Log.Info("Blocked tool by delegation", "tool", name, "user", userID, "category", category)
		return true, fmt.Sprintf(`The tool "%s" is turned off for this account by the person who manages it. The user cannot change this in their own settings; only their manager can.`, name)
	}
	restriction := ""
	if !safe {
		restriction = agent.RestrictionForRun(ctx, g.DB, userID, r.AgentID, r.ID, category)
	}
	if restriction == "deny" {
		by = "agent_restriction"
		return true, fmt.Sprintf(`This agent may not use "%s". The user set that in the agent's settings, so do not try to get around it; say what you would have done instead.`, name)
	}
	mode := g.Policies.Mode(ctx, userID)
	if !safe && mode != "allow_all" && g.Policies.Policy(ctx, userID, name, args) == "deny" {
		by = "policy"
		return true, fmt.Sprintf(`The tool "%s" is disabled by your security policy. To use it, go to Settings → Tool Permissions and set the category to "Allow" or "Ask me".`, name)
	}
	review := ReviewCall(g.Registry, name, args, category, trust)
	noBoundary := g.HostTerminal != nil && g.HostTerminal()
	var escalation *Review
	if review != nil && (review.Kind == "audience" || mode != "allow_all" || noBoundary) {
		escalation = review
	}
	agentAsks := !safe && restriction == "require_approval"
	if escalation == nil && !agentAsks {
		if safe || mode == "allow_all" {
			return false, ""
		}
		policy := g.Policies.Policy(ctx, userID, name, args)
		askAnyway := mode == "always_ask" && category != ""
		if policy != "require_approval" && !askAnyway {
			return false, ""
		}
	}
	if g.Approvals.HasSessionGrant(userID, r.ID, name) {
		return false, ""
	}
	req := ApprovalRequest{UserID: userID, RunID: r.ID, AgentID: r.AgentID, ToolName: name, Args: args, ArgOrder: argOrder(call), Trust: trust}
	if escalation != nil {
		req.Reason, req.ReasonKey, req.ReasonParams = escalation.Reason, escalation.ReasonKey, escalation.ReasonParams
	}
	g.Log.Info("Requesting approval", "tool", name, "run", r.ID)
	switch result := g.Approvals.Request(ctx, req); result {
	case "approved":
		approved = true
		return false, ""
	case "expired":
		by = "approval_expired"
		return true, fmt.Sprintf(`Approval for "%s" expired because the server restarted or the run was interrupted. Do not retry unless the user explicitly asks you to try again.`, name)
	case "timeout":
		by = "approval_timeout"
		return true, fmt.Sprintf(`Approval for "%s" timed out — the user did not respond in time. Do not retry unless the user explicitly asks you to try again.`, name)
	default:
		by = "user_denied"
		return true, fmt.Sprintf(`The user denied the use of "%s". Do not retry this tool call in this run.`, name)
	}
}
