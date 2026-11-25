package behavior

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// StructuredRequest asks the agent's model for a JSON object.
type StructuredRequest struct {
	UserID                  int64
	AgentID, ModelID        string
	Purpose, System, Prompt string
	MaxTokens               int
}

// StructuredAnswer is the model's JSON object.
type StructuredAnswer struct {
	Parsed                  map[string]any
	Model, ModelSelectionID string
	Usage                   int
}

// DecisionRequest is a SystemOne question set.
type DecisionRequest struct {
	UserID           int64
	AgentID, Phase   string
	State, Questions map[string]any
}

// Inference is the central AI engine as the pipeline uses it.
type Inference interface {
	InferStructured(ctx context.Context, req StructuredRequest) (StructuredAnswer, error)
	// Decide returns nil answers when SystemOne is off or unavailable.
	Decide(ctx context.Context, req DecisionRequest) (map[string]any, error)
	SystemOneReady(ctx context.Context, userID int64, agentID string) (bool, error)
}

// Recalled is one memory the social-memory module may show.
type Recalled struct {
	ID, Category, Summary, Content string
}

// Memory recalls channel-scoped memories.
type Memory interface {
	RecallChannel(ctx context.Context, userID int64, agentID, query string, limit int, scopeID string) ([]Recalled, error)
}

// Emitter reaches the owner's app.
type Emitter interface {
	EmitToUser(userID int64, event string, payload any)
}

// Pipeline is the behavior pipeline for chats: the turn-taking gate, social
// context for the prompt, and natural-bubble delivery.
type Pipeline struct {
	DB        *dbx.DB
	Store     *Store
	Inference Inference
	Memory    Memory
	Emitter   Emitter
	Sender    Sender
	Log       *slog.Logger
	Now       func() time.Time

	states *States
	log    decisionLog

	once       sync.Once
	ctx        context.Context
	cancel     context.CancelFunc
	wg         sync.WaitGroup
	mu         sync.Mutex
	background map[string]bool
}

func (p *Pipeline) init() {
	p.once.Do(func() {
		if p.Now == nil {
			p.Now = time.Now
		}
		if p.Log == nil {
			p.Log = slog.Default()
		}
		if p.Store == nil {
			p.Store = NewStore(p.DB)
		}
		p.states = NewStates()
		p.states.Now = p.Now
		p.ctx, p.cancel = context.WithCancel(context.Background())
		p.background = map[string]bool{}
	})
}

// States exposes the thread states (tests and diagnostics).
func (p *Pipeline) States() *States { p.init(); return p.states }

// Config resolves the configuration for a message's chat.
func (p *Pipeline) Config(ctx context.Context, userID int64, agentID string, m *messaging.Message) *Effective {
	p.init()
	return p.Store.Resolve(ctx, userID, agentID, m.Platform, m.ChatID, m.IsGroup)
}

// BatchWindow is how long a group message waits for more to merge into it.
func (p *Pipeline) BatchWindow(ctx context.Context, userID int64, agentID string, m *messaging.Message) time.Duration {
	if !m.IsGroup {
		return 0
	}
	return time.Duration(p.Config(ctx, userID, agentID, m).BatchWindowMs) * time.Millisecond
}

// NoteInbound snapshots the chat's turn epoch on the message without claiming
// a speak turn, so silent room traffic cannot invalidate a reply in flight.
func (p *Pipeline) NoteInbound(userID int64, agentID string, m *messaging.Message) int64 {
	p.init()
	m.BehaviorTurnEpoch = p.states.Get(userID, agentID, m.Platform, m.ChatID).TurnEpoch
	return m.BehaviorTurnEpoch
}

func (p *Pipeline) claimSpeakTurn(userID int64, agentID string, m *messaging.Message) int64 {
	m.BehaviorTurnEpoch = p.states.BumpTurnEpoch(userID, agentID, m.Platform, m.ChatID).TurnEpoch
	return m.BehaviorTurnEpoch
}

// Result is the gate's answer for one inbound message.
type Result struct {
	Engage       bool
	Decision     Decision
	Config       *Effective
	PromptBlocks []string
}

type runCtx struct {
	userID    int64
	agentID   string
	msg       *messaging.Message
	cfg       *Effective
	turnEpoch int64
	systemOne bool
}

// HandleInbound runs the gate on a message and, for groups, logs the decision.
func (p *Pipeline) HandleInbound(ctx context.Context, userID int64, agentID string, m *messaging.Message) (Result, error) {
	result, err := p.decideInbound(ctx, userID, agentID, m)
	if err != nil {
		return result, err
	}
	if m.IsGroup {
		p.log.record(userID, agentID, m, result.Decision, p.Now())
	}
	return result, nil
}

func (p *Pipeline) decideInbound(ctx context.Context, userID int64, agentID string, m *messaging.Message) (Result, error) {
	p.init()
	cfg := p.Config(ctx, userID, agentID, m)
	turnEpoch := m.BehaviorTurnEpoch
	if turnEpoch == 0 {
		turnEpoch = p.NoteInbound(userID, agentID, m)
	}
	skipped := func(engage bool, d Decision) Result {
		d.LatencyMs = 0
		return Result{Engage: engage, Decision: d, Config: cfg, PromptBlocks: []string{}}
	}
	if m.IsGroup && !m.AccessPolicyAllowUntagged && !m.WasMentioned && !m.RepliedToAgent {
		d := ruleDecision("stay_silent", "untagged_disabled_for_shared_space", 1)
		d.TurnEpoch = turnEpoch
		return skipped(false, d), nil
	}
	if !cfg.Enabled {
		d := ruleDecision("speak", "behavior_disabled", 1)
		d.TurnEpoch = p.claimSpeakTurn(userID, agentID, m)
		return skipped(true, d), nil
	}
	rc := &runCtx{userID: userID, agentID: agentID, msg: m, cfg: cfg, turnEpoch: turnEpoch}
	p.observe(rc)
	// With SystemOne on, no model runs for a group message until SystemOne says speak.
	if m.IsGroup && p.Inference != nil {
		ready, err := p.Inference.SystemOneReady(ctx, userID, agentID)
		if err != nil && ctx.Err() != nil {
			return Result{}, ctx.Err()
		}
		rc.systemOne = ready
	}
	if m.IsGroup && !rc.systemOne {
		p.scheduleBackground(*rc)
	}
	var decision Decision
	if cfg.ModuleEnabled("turn_taking") {
		d, err := p.shouldEngage(ctx, rc)
		if err != nil {
			return Result{}, err
		}
		decision = d
	} else {
		decision = ruleDecision("speak", "turn_taking_disabled", 1)
		decision.TurnEpoch = turnEpoch
	}
	p.emitDecision(userID, agentID, m, decision)
	if !decision.Speaks() {
		return Result{Engage: false, Decision: decision, Config: cfg, PromptBlocks: []string{}}, nil
	}
	// The speak turn is claimed only once the gate engages.
	decision.TurnEpoch = p.claimSpeakTurn(userID, agentID, m)
	rc.turnEpoch = decision.TurnEpoch
	if rc.systemOne {
		p.scheduleBackground(*rc)
	}
	blocks, err := p.composeContext(ctx, rc)
	if err != nil {
		return Result{}, err
	}
	return Result{Engage: true, Decision: decision, Config: cfg, PromptBlocks: blocks}, nil
}

func (p *Pipeline) emitDecision(userID int64, agentID string, m *messaging.Message, d Decision) {
	if p.Emitter == nil || userID <= 0 {
		return
	}
	tokenPath := d.TokenPath
	if tokenPath == "" {
		tokenPath = "gate_only"
	}
	p.Emitter.EmitToUser(userID, "behavior:decision", dyn.Ordered{
		{Key: "platform", Value: m.Platform}, {Key: "chatId", Value: m.ChatID}, {Key: "agentId", Value: optional(agentID)},
		{Key: "isGroup", Value: m.IsGroup}, {Key: "decision", Value: d.Decision}, {Key: "confidence", Value: d.Confidence},
		{Key: "needScore", Value: d.NeedScore}, {Key: "reasonCodes", Value: nonNil(d.ReasonCodes)}, {Key: "urgency", Value: d.Urgency},
		{Key: "tokenPath", Value: tokenPath}, {Key: "turnEpoch", Value: d.TurnEpoch}, {Key: "model", Value: d.Model},
		{Key: "at", Value: isoTime(p.Now())},
	})
}

func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

// --- Modules: observe -------------------------------------------------------

// observe runs social_memory (which only names the scope) and social_signals.
func (p *Pipeline) observe(rc *runCtx) {
	if !rc.cfg.ModuleEnabled("social_signals") {
		return
	}
	eventType := rc.msg.EventType
	if eventType == "" {
		eventType = "inbound_message"
	}
	p.recordSignal(rc, eventType, map[string]any{
		"hasMedia":       rc.msg.LocalMediaPath != "" || rc.msg.MediaType != "",
		"wasMentioned":   rc.msg.WasMentioned,
		"repliedToAgent": rc.msg.RepliedToAgent,
	})
}

func (p *Pipeline) recordSignal(rc *runCtx, signalType string, details map[string]any) {
	at := isoTime(p.Now())
	p.states.Update(rc.userID, rc.agentID, rc.msg.Platform, rc.msg.ChatID, func(t *ThreadState) {
		signals := t.RecentSignals
		if len(signals) > 19 {
			signals = signals[len(signals)-19:]
		}
		t.RecentSignals = append(append([]Signal{}, signals...), Signal{Type: signalType, At: at, Sender: optional(rc.msg.Sender), Details: details})
	})
}

// --- Modules: turn taking ---------------------------------------------------

// gateQuestions are SystemOne's version of the model judge's question.
var gateQuestions = map[string]any{
	"speak": map[string]any{
		"type":         "noul",
		"instructions": "The agent named in `agent.names` should post a reply to `latest_message` now.",
		"criteria": map[string]any{
			"true":  "Someone asks the agent something, asks the group a question the agent can answer with what `agent.can` do, follows up on the agent's last message, or says something harmful that should be corrected.",
			"false": "Side chatter, greetings, feelings, or talk meant for another person in the chat, where nobody needs the agent.",
		},
	},
	"for_someone_else": map[string]any{
		"type":         "noul",
		"instructions": "`latest_message` is meant for a specific other person in the chat, not for the agent or the whole group.",
	},
	"urgency": map[string]any{
		"type":         "score",
		"instructions": "How time-sensitive is a reply to `latest_message`?",
		"criteria":     []any{"Not time-sensitive", "Should be answered soon", "Needed right now"},
	},
}

// Without a description of what the agent can do, SystemOne treats open
// questions to the room as not the agent's business.
const agentCapabilities = "answer questions, look things up on the web, and do tasks with its tools and connected apps"

// SystemOne scores are calibrated probabilities, so the room threshold tuned
// on self-reported model scores sits a little lower for them.
const systemOneThresholdOffset = 0.08

const judgeSystemPrompt = `You are NeoAgent's group turn-taking gate.
Decide whether the agent should speak now or stay silent in a multi-party chat.
Hold back on side chatter and talk that is clearly only between other people.
Speak when the agent is named or addressed, someone asks the agent a question, the room is waiting after the agent just spoke, the agent can usefully answer an open need, or a harmful misunderstanding should be corrected.
Judge the meaning and flow of the provided room context. Do not use phrase matching or keyword rules.
Return JSON only with keys:
decision ("speak" or "stay_silent"),
needScore (0-1 number measuring how worthwhile an agent contribution is now),
confidence (0-1 number),
reasonCodes (array of short snake_case strings),
urgency ("low"|"medium"|"high").`

var parseFallback = decisionFallback{Decision: "stay_silent", NeedScore: 0, Confidence: 0.55, ReasonCodes: []string{"parse_fallback"}, Urgency: "low"}

func gateState(packet Packet) map[string]any {
	names := packet.Room.AgentNames
	if len(names) == 0 {
		names = []string{"the assistant"}
	}
	sender := "participant"
	if packet.Sender.Name != nil {
		sender = *packet.Sender.Name
	} else if packet.Sender.Username != nil {
		sender = *packet.Sender.Username
	}
	latest := map[string]any{"sender": sender, "content": packet.Event.Content, "has_media": packet.Event.HasMedia}
	if packet.Event.ReplyTo != nil {
		latest["reply_to"] = map[string]any{"sender": packet.Event.ReplyTo.Sender, "content": packet.Event.ReplyTo.Content}
	}
	recent := make([]any, len(packet.Room.RecentMessages))
	for i, line := range packet.Room.RecentMessages {
		recent[i] = map[string]any{"sender": line.Sender, "content": line.Content}
	}
	var since any
	if packet.Room.SecondsSinceAgentSpoke != nil {
		since = *packet.Room.SecondsSinceAgentSpoke
	}
	var chatName any
	if packet.Chat.GroupName != nil {
		chatName = *packet.Chat.GroupName
	}
	return map[string]any{
		"agent":                     map[string]any{"names": names, "can": agentCapabilities},
		"chat":                      map[string]any{"platform": packet.Chat.Platform, "name": chatName},
		"latest_message":            latest,
		"recent_messages":           recent,
		"seconds_since_agent_spoke": since,
	}
}

func answer(answers map[string]any, key, field string) float64 {
	n, _ := dyn.Float(dyn.Get(answers, key, field))
	return n
}

// decisionFromAnswers: the need score is the chance a reply is wanted now and
// meant for the agent, so messages aimed at someone else stay quiet.
func decisionFromAnswers(answers map[string]any) Decision {
	speak := answer(answers, "speak", "noul")
	forSomeoneElse := answer(answers, "for_someone_else", "noul")
	codes := []string{"system_one_gate", "hold_back"}
	decision := "stay_silent"
	if speak >= 0.5 {
		codes[1], decision = "agent_can_help", "speak"
	}
	if forSomeoneElse >= 0.5 {
		codes = append(codes, "meant_for_someone_else")
	}
	urgency := urgencyLevels[int(math.Floor(math.Max(0, math.Min(2, answer(answers, "urgency", "score")))+0.5))]
	d := normalizeDecision(rawDecision{Decision: decision, NeedScore: speak * (1 - forSomeoneElse), Confidence: math.Max(speak, 1-speak), ReasonCodes: codes, Urgency: urgency},
		decisionFallback{TokenPath: "system_one_gate", Model: "system_one"})
	d.SystemOneScores = &SystemOneScores{Speak: speak, ForSomeoneElse: forSomeoneElse}
	return d
}

func (p *Pipeline) askSystemOne(ctx context.Context, rc *runCtx, packet Packet) (*Decision, error) {
	if p.Inference == nil {
		return nil, nil
	}
	answers, err := p.Inference.Decide(ctx, DecisionRequest{UserID: rc.userID, AgentID: rc.agentID, Phase: "system_one_turn_taking", State: gateState(packet), Questions: gateQuestions})
	if err != nil || answers == nil {
		return nil, err
	}
	d := decisionFromAnswers(answers)
	return &d, nil
}

func (p *Pipeline) askModel(ctx context.Context, rc *runCtx, packet Packet) (Decision, error) {
	if p.Inference == nil {
		return Decision{}, errors.New("behavior inference requires the central AI engine")
	}
	prompt, _ := json.Marshal(packet)
	modelID := ""
	if rc.cfg.DecisionModelID != nil {
		modelID = *rc.cfg.DecisionModelID
	}
	result, err := p.Inference.InferStructured(ctx, StructuredRequest{UserID: rc.userID, AgentID: rc.agentID, ModelID: modelID, Purpose: rc.cfg.DecisionModelPurpose,
		System: judgeSystemPrompt, Prompt: string(prompt), MaxTokens: 220})
	if err != nil {
		return Decision{}, err
	}
	model := firstText(result.ModelSelectionID, result.Model)
	parsed := result.Parsed
	fb := parseFallback
	fb.TokenPath, fb.Model = "gate_only", model
	usage := float64(result.Usage)
	d := normalizeDecision(rawDecision{Decision: parsed["decision"], NeedScore: parsed["needScore"], Confidence: parsed["confidence"], ReasonCodes: parsed["reasonCodes"],
		Urgency: parsed["urgency"], Model: dyn.Str(parsed["model"]), Usage: &usage}, fb)
	if model != "" {
		d.Model = &model
	} else {
		d.Model = nil
	}
	d.Usage = &usage
	return d, nil
}

// judgeRoom: SystemOne judges whenever it answers. When SystemOne is on, an
// outage holds back rather than handing the decision to the chat model.
func (p *Pipeline) judgeRoom(ctx context.Context, rc *runCtx, packet Packet) (Decision, error) {
	d, err := p.askSystemOne(ctx, rc, packet)
	if err != nil {
		return Decision{}, err
	}
	if d != nil {
		return *d, nil
	}
	if rc.systemOne {
		return holdBackDecision("system_one_unavailable"), nil
	}
	judged, err := p.askModel(ctx, rc, packet)
	if err != nil {
		if ctx.Err() != nil {
			return Decision{}, ctx.Err()
		}
		return holdBackDecision("model_unavailable"), nil
	}
	return judged, nil
}

// applyNeedThreshold: a judged "speak" still has to clear the room threshold.
func applyNeedThreshold(d Decision, cfg *Effective, secondsSinceSpoke *int64) Decision {
	threshold := cfg.MinimumNeedScore
	if secondsSinceSpoke != nil && *secondsSinceSpoke < 120 {
		threshold = math.Min(threshold, 0.45)
	}
	if d.TokenPath == "system_one_gate" {
		threshold -= systemOneThresholdOffset
	}
	if d.Decision != "speak" || d.NeedScore >= threshold {
		d.NeedThreshold = &threshold
		return d
	}
	model := ""
	if d.Model != nil {
		model = *d.Model
	}
	tokenPath := d.TokenPath
	if tokenPath == "" {
		tokenPath = "gate_only"
	}
	codes := append(append([]string{}, d.ReasonCodes...), "below_need_threshold")
	held := normalizeDecision(rawDecision{Decision: "stay_silent", NeedScore: d.NeedScore, Confidence: d.Confidence, ReasonCodes: codes, Urgency: d.Urgency,
		Model: model, Usage: d.Usage}, decisionFallback{TokenPath: tokenPath, Model: model})
	held.SystemOneScores = d.SystemOneScores
	held.NeedThreshold = &threshold
	return held
}

func (p *Pipeline) shouldEngage(ctx context.Context, rc *runCtx) (Decision, error) {
	started := p.Now()
	finish := func(d Decision) (Decision, error) {
		d.LatencyMs = p.Now().Sub(started).Milliseconds()
		d.TurnEpoch = rc.turnEpoch
		return d, nil
	}
	m := rc.msg
	if d := bypassDecision(m, rc.cfg); d != nil {
		return finish(*d)
	}
	addressing := resolveAddressing(ctx, p.DB, rc.userID, rc.agentID, m)
	if d := addressDecision(m, rc.cfg, addressing); d != nil {
		return finish(*d)
	}
	state := p.states.Get(rc.userID, rc.agentID, m.Platform, m.ChatID)
	room := loadRecentRoomMessages(ctx, p.DB, rc.userID, rc.agentID, m.Platform, m.ChatID, rc.cfg.DecisionContextMessageLimit)
	packet := buildDecisionPacket(m, rc.cfg, state, room, addressing, p.Now())
	judged, err := p.judgeRoom(ctx, rc, packet)
	if err != nil {
		return Decision{}, err
	}
	d := applyNeedThreshold(judged, rc.cfg, packet.Room.SecondsSinceAgentSpoke)
	now := isoTime(p.Now())
	p.states.Update(rc.userID, rc.agentID, m.Platform, m.ChatID, func(t *ThreadState) {
		decision := d.Decision
		t.LastDecision, t.LastDecisionAt = &decision, &now
		if d.Decision == "stay_silent" {
			t.RecentSilenceCount = state.RecentSilenceCount + 1
		} else {
			t.RecentSilenceCount = 0
		}
	})
	return finish(d)
}

// --- Modules: prompt context ------------------------------------------------

type contribution struct {
	key      string
	priority float64
	content  string
}

// composeContext gathers the modules' prompt blocks, highest priority first.
func (p *Pipeline) composeContext(ctx context.Context, rc *runCtx) ([]string, error) {
	var parts []contribution
	if rc.cfg.ModuleEnabled("social_memory") {
		if block := p.socialMemoryBlock(ctx, rc); block != "" {
			parts = append(parts, contribution{"social_memory", 40, block})
		}
	}
	if rc.cfg.ModuleEnabled("norms") {
		block := strings.TrimSpace(p.states.Get(rc.userID, rc.agentID, rc.msg.Platform, rc.msg.ChatID).NormsPromptBlock)
		if block != "" {
			parts = append(parts, contribution{"norms", 50, block})
		}
	}
	sort.SliceStable(parts, func(i, j int) bool { return parts[i].priority > parts[j].priority })
	out := []string{}
	for _, part := range parts {
		out = append(out, strings.TrimSpace(part.content))
	}
	return out, nil
}

// ChannelScopeID names a chat's memory scope.
func ChannelScopeID(platform, chatID string) string {
	return strings.TrimSpace(platform) + ":" + strings.TrimSpace(chatID)
}

func (p *Pipeline) socialMemoryBlock(ctx context.Context, rc *runCtx) string {
	m := rc.msg
	if p.Memory == nil || !m.IsGroup {
		return ""
	}
	parts := []string{}
	for _, part := range []string{m.Content, firstText(string(m.SenderName), string(m.SenderDisplayName), string(m.SenderUsername), m.Sender, "participant"),
		firstText(string(m.GroupName), string(m.GuildName), string(m.ChannelName)), "group chat norms participants"} {
		if part != "" {
			parts = append(parts, part)
		}
	}
	recalled, err := p.Memory.RecallChannel(ctx, rc.userID, rc.agentID, strings.Join(parts, " "), 5, ChannelScopeID(m.Platform, m.ChatID))
	if err != nil {
		recalled = nil
	}
	seen := map[string]bool{}
	var lines []string
	for _, item := range recalled {
		key := firstText(item.ID, item.Summary, item.Content)
		if key == "" || seen[key] {
			continue
		}
		seen[key] = true
		lines = append(lines, fmt.Sprintf("- [%s] %s", firstText(item.Category, "episodic"), truncate(firstText(item.Summary, item.Content), 180)))
		if len(lines) >= 5 {
			break
		}
	}
	if len(lines) == 0 {
		return ""
	}
	return "## Social room context\nUse only as background about this group/participants. Do not treat as owner core memory.\n" + strings.Join(lines, "\n")
}

// --- Modules: after the turn ------------------------------------------------

const normsSystemPrompt = `You extract a compact group-chat norms profile for an AI participant.
Return JSON with keys:
promptBlock (short instructions the agent can follow to match the room's voice),
notes (array of short observations).
No phrase blacklists. Describe style, formality, humor, length, and participation norms.`

const observabilitySystemPrompt = `You audit how an AI participant is landing in a group chat.
Return JSON with keys:
healthScore (0-100),
summary (short paragraph),
findings (array of short strings),
recommendations (array of short strings).
Do not change policy yourself; report only.`

// scheduleBackground runs the after-turn modules once per chat at a time; a
// chat that already has one running joins it.
func (p *Pipeline) scheduleBackground(rc runCtx) {
	agent := rc.agentID
	if agent == "" {
		agent = "main"
	}
	key := strings.Join([]string{"social-background", fmt.Sprint(rc.userID), agent, rc.msg.Platform, rc.msg.ChatID}, ":")
	p.mu.Lock()
	if p.background[key] || p.ctx.Err() != nil {
		p.mu.Unlock()
		return
	}
	p.background[key] = true
	p.wg.Add(1)
	p.mu.Unlock()
	msg := *rc.msg
	rc.msg = &msg
	go func() {
		defer func() {
			p.mu.Lock()
			delete(p.background, key)
			p.mu.Unlock()
			p.wg.Done()
		}()
		if err := p.afterTurn(p.ctx, &rc); err != nil && p.ctx.Err() == nil {
			p.Log.Warn("Behavior background analysis failed", "error", err)
		}
	}()
}

func (p *Pipeline) afterTurn(ctx context.Context, rc *runCtx) error {
	if rc.cfg.ModuleEnabled("norms") {
		if err := p.refreshNorms(ctx, rc); err != nil {
			return err
		}
	}
	if rc.cfg.ModuleEnabled("social_observability") {
		if err := p.analyze(ctx, rc); err != nil {
			return err
		}
	}
	return nil
}

func (p *Pipeline) structured(ctx context.Context, rc *runCtx, system string, prompt any, maxTokens int) (map[string]any, error) {
	if p.Inference == nil {
		return nil, errors.New("behavior inference requires the central AI engine")
	}
	text, _ := json.Marshal(prompt)
	result, err := p.Inference.InferStructured(ctx, StructuredRequest{UserID: rc.userID, AgentID: rc.agentID, Purpose: "fast", System: system, Prompt: string(text), MaxTokens: maxTokens})
	if err != nil {
		return nil, err
	}
	return result.Parsed, nil
}

func (p *Pipeline) refreshNorms(ctx context.Context, rc *runCtx) error {
	m := rc.msg
	if !m.IsGroup {
		return nil
	}
	state := p.states.Get(rc.userID, rc.agentID, m.Platform, m.ChatID)
	count := state.MessageCountSinceNorms + 1
	setCount := func(n int) {
		p.states.Update(rc.userID, rc.agentID, m.Platform, m.ChatID, func(t *ThreadState) { t.MessageCountSinceNorms = n })
	}
	gap := rc.cfg.NormsRefreshMessageGap
	if gap == 0 {
		gap = 18
	}
	if count < gap {
		setCount(count)
		return nil
	}
	room := loadRecentRoomMessages(ctx, p.DB, rc.userID, rc.agentID, m.Platform, m.ChatID, 24)
	if len(room) < 4 {
		setCount(count)
		return nil
	}
	recent := make([]dyn.Ordered, len(room))
	for i, item := range room {
		recent[i] = dyn.Ordered{{Key: "sender", Value: item.Sender}, {Key: "content", Value: item.Content}}
	}
	parsed, err := p.structured(ctx, rc, normsSystemPrompt, dyn.Ordered{{Key: "platform", Value: m.Platform}, {Key: "chatId", Value: m.ChatID}, {Key: "recentMessages", Value: recent}}, 280)
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		setCount(count)
		return nil
	}
	block := truncate(jsTruthyString(parsed["promptBlock"]), 900)
	if block == "" {
		setCount(0)
		return nil
	}
	now := isoTime(p.Now())
	p.states.Update(rc.userID, rc.agentID, m.Platform, m.ChatID, func(t *ThreadState) {
		t.NormsPromptBlock = "## Group norms\n" + block
		t.NormsUpdatedAt = &now
		t.MessageCountSinceNorms = 0
	})
	return nil
}

func listOf(v any, limit int) []any {
	list, _ := v.([]any)
	if len(list) > limit {
		list = list[:limit]
	}
	if list == nil {
		return []any{}
	}
	return list
}

func (p *Pipeline) analyze(ctx context.Context, rc *runCtx) error {
	m := rc.msg
	if !m.IsGroup {
		return nil
	}
	state := p.states.Get(rc.userID, rc.agentID, m.Platform, m.ChatID)
	count := state.MessageCountSinceObservability + 1
	if state.LastObservabilitySummary == nil && count < 24 {
		p.states.Update(rc.userID, rc.agentID, m.Platform, m.ChatID, func(t *ThreadState) { t.MessageCountSinceObservability = count })
		return nil
	}
	interval := time.Duration(rc.cfg.ObservabilityIntervalMinutes) * time.Minute
	if interval == 0 {
		interval = 360 * time.Minute
	}
	if state.LastObservabilityAt != nil {
		if at, err := time.Parse(time.RFC3339Nano, *state.LastObservabilityAt); err == nil && p.Now().Sub(at) < interval {
			return nil
		}
	}
	room := loadRecentRoomMessages(ctx, p.DB, rc.userID, rc.agentID, m.Platform, m.ChatID, 30)
	if len(room) < 6 {
		return nil
	}
	parsed, err := p.structured(ctx, rc, observabilitySystemPrompt, dyn.Ordered{{Key: "platform", Value: m.Platform}, {Key: "chatId", Value: m.ChatID},
		{Key: "recentSilenceCount", Value: state.RecentSilenceCount}, {Key: "recentMessages", Value: room}}, 320)
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return nil
	}
	health, _ := jsNumber(parsed["healthScore"], parsed["healthScore"] != nil)
	if math.IsNaN(health) {
		health = 0
	}
	summary := &ObservabilitySummary{HealthScore: health, Summary: strings.TrimSpace(jsTruthyString(parsed["summary"])), Findings: listOf(parsed["findings"], 8),
		Recommendations: listOf(parsed["recommendations"], 8), At: isoTime(p.Now())}
	p.states.Update(rc.userID, rc.agentID, m.Platform, m.ChatID, func(t *ThreadState) {
		t.LastObservabilityAt = &summary.At
		t.LastObservabilitySummary = summary
		t.MessageCountSinceObservability = 0
	})
	return nil
}

// --- Delivery ---------------------------------------------------------------

// DeliverRequest is a reply the agent wrote for a chat.
type DeliverRequest struct {
	UserID                    int64
	AgentID                   string
	Message                   *messaging.Message
	Config                    *Effective
	Content, MediaPath, RunID string
	TurnEpoch                 int64
}

// DeliverResult is what became of a reply.
type DeliverResult struct {
	Delivered  bool
	Suppressed bool
	Delivery   *Delivered
	Content    string
	Reason     string
}

// DeliverReply delivers the reply exactly as written. The only checks are
// about the room: a group reply is dropped when newer traffic made the turn
// stale, and [NO RESPONSE] sends nothing.
func (p *Pipeline) DeliverReply(ctx context.Context, r DeliverRequest) (DeliverResult, error) {
	p.init()
	m := r.Message
	text := strings.TrimSpace(r.Content)
	expected := r.TurnEpoch
	if expected == 0 {
		expected = m.BehaviorTurnEpoch
	}
	current := func(int) bool {
		return !m.IsGroup || p.states.IsTurnCurrent(r.UserID, r.AgentID, m.Platform, m.ChatID, expected)
	}
	if !current(0) {
		return DeliverResult{Suppressed: true, Content: text, Reason: "stale_turn"}, nil
	}
	if text == "" || strings.ToUpper(text) == "[NO RESPONSE]" {
		return DeliverResult{Suppressed: true, Content: text, Reason: "no_response"}, nil
	}
	if p.Sender == nil {
		return DeliverResult{}, errors.New("behavior delivery has no messaging sender")
	}
	cfg := r.Config
	if cfg == nil {
		cfg = p.Config(ctx, r.UserID, r.AgentID, m)
	}
	deliveryCfg := *cfg
	if !cfg.ModuleEnabled("delivery") {
		deliveryCfg.DeliveryStyle = "single"
	}
	delivery, err := deliverSocialReply(ctx, p.Sender, deliverRequest{userID: r.UserID, agentID: r.AgentID, platform: m.Platform, chatID: m.ChatID, content: text,
		runID: r.RunID, mediaPath: r.MediaPath, cfg: &deliveryCfg, turnEpoch: expected, beforeBubble: current})
	if err != nil {
		return DeliverResult{}, err
	}
	delivered := delivery.Success && !delivery.Suppressed
	if delivered || delivery.DeliveredBubbles > 0 {
		p.states.MarkSpoke(r.UserID, r.AgentID, m.Platform, m.ChatID)
	}
	out := DeliverResult{Delivered: delivered, Suppressed: delivery.Suppressed, Delivery: &delivery, Content: text}
	if !delivered {
		out.Reason = firstText(delivery.Reason, delivery.Error)
	}
	return out, nil
}

// --- Diagnostics ------------------------------------------------------------

// Diagnostics is the pipeline's view of a chat.
func (p *Pipeline) Diagnostics(userID int64, agentID, platform, chatID string) any {
	p.init()
	ctx := context.Background()
	cfg := p.Store.Resolve(ctx, userID, agentID, platform, chatID, true)
	modules := dyn.Ordered{}
	for _, id := range ModuleIDs {
		if _, ok := cfg.Modules[id]; ok {
			modules = append(modules, dyn.KV{Key: id, Value: cfg.ModuleEnabled(id)})
		}
	}
	return dyn.Ordered{{Key: "config", Value: cfg}, {Key: "state", Value: p.states.Get(userID, agentID, platform, chatID)}, {Key: "modules", Value: modules}}
}

// ListDecisions is the recent decision log of a platform.
func (p *Pipeline) ListDecisions(userID int64, agentID, platform string) any {
	p.init()
	return p.log.list(userID, agentID, platform)
}

// Shutdown stops background analysis and waits for it.
func (p *Pipeline) Shutdown(ctx context.Context) {
	p.init()
	p.cancel()
	done := make(chan struct{})
	go func() { p.wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-ctx.Done():
	}
}
