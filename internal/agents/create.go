// Package agents is the agents manager (agents/manager.js and
// agents/creation.js): the agent profiles the app edits, and the agents runs
// create. Whether a run's new agent is worth having is the model's decision;
// this only checks the rules that can be counted. Whether creating agents is
// allowed at all is the account's agent_creation tool policy, enforced before
// the tool runs.
package agents

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

const (
	maxAgentsPerAccount = 12
	mainSlug            = "main"
)

// Creator creates agents in the agents table.
type Creator struct {
	DB *dbx.DB
}

// Run is the run asking for an agent.
type Run struct {
	UserID         int64
	AgentID, RunID string
	// AlreadyCreated: this run already created one.
	AlreadyCreated bool
}

// Agent is the created agent.
type Agent struct {
	ID, Slug, DisplayName string
}

// Refusal is a rule the request broke; the tool reports it as {error}.
type Refusal struct{ Msg string }

func (e *Refusal) Error() string { return e.Msg }

var slugJunk = regexp.MustCompile(`[^a-z0-9_-]+`)

func normalizeSlug(value string) string {
	slug := strings.Trim(slugJunk.ReplaceAllString(strings.ToLower(strings.TrimSpace(value)), "-"), "-")
	if len(slug) > 48 {
		slug = slug[:48]
	}
	return slug
}

// head is s.slice(0, n) in UTF-16 units.
func head(s string, n int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= n {
		return s
	}
	return string(utf16.Decode(units[:n]))
}

func text(args map[string]any, key string) string {
	s, ok := args[key].(string)
	if !ok {
		if args[key] == nil || args[key] == false || args[key] == 0.0 {
			return ""
		}
		s = fmt.Sprint(args[key])
	}
	return strings.TrimSpace(s)
}

func strings_(v any) []string {
	list, _ := v.([]any)
	out := make([]string, 0, len(list))
	for _, item := range list {
		out = append(out, fmt.Sprint(item))
	}
	return out
}

// restrictionsFromArgs: ask_first categories need approval, not_allowed
// ones are denied.
func restrictionsFromArgs(args map[string]any) string {
	var requested []restriction
	for _, c := range strings_(args["ask_first"]) {
		requested = setRestriction(requested, c, "require_approval")
	}
	for _, c := range strings_(args["not_allowed"]) {
		requested = setRestriction(requested, c, "deny")
	}
	var b strings.Builder
	b.WriteByte('{')
	for i, r := range requested {
		if i > 0 {
			b.WriteByte(',')
		}
		k, _ := json.Marshal(r.category)
		v, _ := json.Marshal(r.level)
		b.Write(k)
		b.WriteByte(':')
		b.Write(v)
	}
	b.WriteByte('}')
	return b.String()
}

// CreateForRun creates the agent a run asked for. The new agent is never less
// restricted than its creator or than the agents whose task the creator works.
func (c *Creator) CreateForRun(ctx context.Context, run Run, args map[string]any) (Agent, error) {
	name, responsibility, reason := text(args, "name"), text(args, "responsibility"), text(args, "reason")
	if name == "" || responsibility == "" || reason == "" {
		return Agent{}, &Refusal{"name, responsibility and reason are required."}
	}
	if run.AlreadyCreated {
		return Agent{}, &Refusal{"A run may create one agent. Use the one you created."}
	}
	if run.RunID != "" {
		var id string
		err := c.DB.R.QueryRowContext(ctx, `SELECT id FROM agent_delegations WHERE child_run_id = ?`, run.RunID).Scan(&id)
		if err == nil {
			return Agent{}, &Refusal{"Agents working on a task for another agent cannot create agents. Report the need in your result instead."}
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return Agent{}, err
		}
	}
	var count int
	if err := c.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM agents WHERE user_id = ? AND status != 'archived'`, run.UserID).Scan(&count); err != nil {
		return Agent{}, err
	}
	if count >= maxAgentsPerAccount {
		return Agent{}, &Refusal{fmt.Sprintf("This account already has %d agents, the most it may have. Hand the work to one of them, or ask the user to archive one.", count)}
	}
	creatorID, err := agentscope.Resolver{DB: c.DB}.Resolve(ctx, run.UserID, run.AgentID)
	if err != nil {
		return Agent{}, err
	}
	m := &Manager{DB: c.DB}
	creator, err := m.get(ctx, run.UserID, creatorID)
	if err != nil {
		return Agent{}, err
	}
	var creatorRestrictions, createdBy any
	if creator != nil {
		creatorRestrictions, createdBy = creator.toolRestrictions.String, creator.id
	}
	agent, err := m.Create(ctx, run.UserID, input{
		"displayName":      name,
		"description":      text(args, "description"),
		"responsibilities": responsibility,
		"instructions":     text(args, "instructions"),
		"toolRestrictions": restrictionsObject(mergeRestrictions(creatorRestrictions, restrictionsFromArgs(args))),
		"createdByAgentId": createdBy,
		"creationReason":   reason,
		"canDelegate":      false,
		"canBeDelegatedTo": true,
	})
	if err != nil {
		return Agent{}, err
	}
	return Agent{ID: agent["id"].(string), Slug: agent["slug"].(string), DisplayName: agent["displayName"].(string)}, nil
}
