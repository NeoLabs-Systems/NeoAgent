// Package skilllearning turns proven work into reusable skills: completed runs
// that taught or repeated a procedure, and computer workflows the owner
// demonstrated in Teach Mode. A learned skill is managed by this package until
// the owner edits it, and is retired again when its real use keeps failing.
package skilllearning

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/skills"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

const (
	reviewActivityThreshold  = 3
	detailedRequestChars     = 600
	repeatObservations       = 2
	minimumToolSteps         = 3
	retirementMinInvocations = 5
	retirementMaxSuccessRate = 0.25
)

// Inference asks a model for a JSON object (purpose "fast" or "general").
type Inference func(ctx context.Context, userID int64, agentID, purpose, system, prompt string, maxTokens int) (map[string]any, error)

// Emitter sends realtime events to a user's clients.
type Emitter interface {
	EmitToUser(userID int64, event string, payload any)
}

// Service learns skills.
type Service struct {
	DB      *dbx.DB
	Skills  *skills.Runner
	Infer   Inference
	Emitter Emitter
	// AutoLearning reports whether the agent's auto_skill_learning setting is on.
	AutoLearning func(ctx context.Context, userID int64, agentID string) bool
	Log          *slog.Logger

	mu       sync.Mutex
	queues   map[int64]chan struct{}
	wg       sync.WaitGroup
	stopping bool
}

func (s *Service) log() *slog.Logger {
	if s.Log != nil {
		return s.Log
	}
	return slog.Default()
}

func (s *Service) emit(userID int64, event string, payload map[string]any) {
	if s.Emitter != nil {
		s.Emitter.EmitToUser(userID, event, payload)
	}
}

func text(v any, max int) string {
	var str string
	switch t := v.(type) {
	case string:
		str = t
	case nil:
	default:
		str = fmt.Sprint(t)
	}
	str = strings.TrimSpace(str)
	if r := []rune(str); len(r) > max {
		str = string(r[:max])
	}
	return str
}

var (
	nonNameChars = regexp.MustCompile(`(?i)[^a-z0-9-]`)
	dashRun      = regexp.MustCompile(`-+`)
	lineSplit    = regexp.MustCompile(`\r?\n+`)
	numbered     = regexp.MustCompile(`(?:^|\s)\d+[.)]\s+`)
	bullet       = regexp.MustCompile(`^(?:\d+[.)]|[-*])\s+`)
	unsafeReason = regexp.MustCompile(`password|credential|secret|private data|clipboard contents`)
)

// NormalizeName is a skill name: lower-case letters, digits and dashes.
func NormalizeName(v any) string {
	name := nonNameChars.ReplaceAllString(strings.TrimSpace(text(v, 1<<20)), "-")
	name = strings.Trim(dashRun.ReplaceAllString(name, "-"), "-")
	return strings.ToLower(name)
}

func clip(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n])
	}
	return s
}

func splitInstructions(v string) []string {
	trimmed := strings.TrimSpace(v)
	if trimmed == "" {
		return nil
	}
	var lines []string
	for _, l := range lineSplit.Split(trimmed, -1) {
		if l = strings.TrimSpace(l); l != "" {
			lines = append(lines, l)
		}
	}
	source := lines
	if len(lines) <= 1 {
		source = nil
		for _, part := range numbered.Split(trimmed, -1) {
			if part = strings.TrimSpace(part); part != "" {
				source = append(source, part)
			}
		}
	}
	var out []string
	for _, item := range source {
		if item = strings.TrimSpace(bullet.ReplaceAllString(item, "")); item != "" {
			out = append(out, item)
		}
	}
	return out
}

func normalizeList(v any, maxItems, maxLength int) []string {
	var source []any
	switch t := v.(type) {
	case []any:
		source = t
	case string:
		for _, s := range splitInstructions(t) {
			source = append(source, s)
		}
	case map[string]any:
		for _, item := range t {
			source = append(source, item)
		}
	}
	out := []string{}
	for _, item := range source {
		var value any = item
		if m, ok := item.(map[string]any); ok {
			value = firstOf(m["instruction"], m["description"], m["text"])
		}
		if s := text(value, maxLength); s != "" {
			out = append(out, s)
			if len(out) >= maxItems {
				break
			}
		}
	}
	return out
}

func firstOf(values ...any) any {
	for _, v := range values {
		if s, ok := v.(string); ok && s != "" {
			return v
		}
		if v != nil {
			if _, isString := v.(string); !isString {
				return v
			}
		}
	}
	return nil
}

func approval(v map[string]any) *bool {
	t, f := true, false
	switch raw := v["approved"].(type) {
	case string:
		switch strings.ToLower(strings.TrimSpace(raw)) {
		case "true", "yes":
			return &t
		case "false", "no":
			return &f
		}
	case bool:
		if raw {
			return &t
		}
		return &f
	case float64:
		if raw == 1 {
			return &t
		}
		if raw == 0 {
			return &f
		}
	}
	return nil
}

// Review is the decision on a completed run.
type Review struct {
	Decision, WorkflowKey, Title, Summary, ExistingSkillName, Reason string
	Confidence                                                       float64
}

func normalizeReview(v map[string]any) Review {
	decision, _ := v["decision"].(string)
	switch decision {
	case "ignore", "observe", "create", "update":
	default:
		decision = "ignore"
	}
	confidence, _ := v["confidence"].(float64)
	return Review{
		Decision: decision, WorkflowKey: clip(NormalizeName(firstOf(v["workflowKey"], v["workflow_key"])), 80),
		Title: text(v["title"], 160), Summary: text(v["summary"], 1000),
		ExistingSkillName: NormalizeName(firstOf(v["existingSkillName"], v["existing_skill_name"])),
		Confidence:        math.Max(0, math.Min(confidence, 1)), Reason: text(v["reason"], 500),
	}
}

// Proposal is a synthesized skill.
type Proposal struct {
	Name, Description, Trigger, Category, WorkflowKey, ExistingSkillName string
	RequiredInputs, Steps, Pitfalls, Verification                        []string
	Approved                                                             bool
	RejectionReason                                                      string
}

func (p Proposal) complete() bool {
	return p.Name != "" && p.Description != "" && p.Trigger != "" && len(p.Steps) > 0 && len(p.Verification) > 0
}

func (p Proposal) usable() bool { return p.Approved && p.complete() }

func (p Proposal) failure() string {
	if p.RejectionReason != "" {
		return p.RejectionReason
	}
	if !p.complete() {
		var missing []string
		for _, f := range []struct {
			ok   bool
			name string
		}{{p.Name != "", "name"}, {p.Description != "", "description"}, {p.Trigger != "", "trigger"}, {len(p.Steps) > 0, "steps"}, {len(p.Verification) > 0, "verification"}} {
			if !f.ok {
				missing = append(missing, f.name)
			}
		}
		if len(missing) > 0 {
			return fmt.Sprintf("Skill synthesis was incomplete (missing %s).", strings.Join(missing, ", "))
		}
	}
	if !p.Approved {
		return "The demonstration did not prove a reusable procedure."
	}
	return "The demonstration did not produce a reusable skill."
}

func normalizeProposal(v map[string]any) (Proposal, bool) {
	skill, ok := v["skill"].(map[string]any)
	if !ok {
		skill = v
	}
	category := clip(NormalizeName(firstOf(skill["category"], "learned")), 64)
	if category == "" {
		category = "learned"
	}
	p := Proposal{
		Name: clip(NormalizeName(skill["name"]), 64), Description: text(skill["description"], 300), Trigger: text(skill["trigger"], 500),
		Category: category, WorkflowKey: clip(NormalizeName(firstOf(skill["workflowKey"], skill["workflow_key"], skill["name"])), 80),
		ExistingSkillName: NormalizeName(firstOf(skill["existingSkillName"], skill["existing_skill_name"])),
		RequiredInputs:    normalizeList(firstOf(skill["requiredInputs"], skill["required_inputs"]), 20, 400),
		Steps:             normalizeList(skill["steps"], 30, 1000), Pitfalls: normalizeList(skill["pitfalls"], 20, 700),
		Verification: normalizeList(firstOf(skill["verification"], skill["successCriteria"], skill["success_criteria"]), 20, 700),
	}
	a := approval(v)
	if a == nil {
		a = approval(skill)
	}
	p.Approved = (a != nil && *a) || (a == nil && p.complete())
	explicitNo := a != nil && !*a
	if explicitNo {
		p.RejectionReason = text(firstOf(v["reason"], skill["reason"], v["message"]), 500)
	}
	return p, explicitNo
}

func (p Proposal) safetyRejection() bool {
	return !p.Approved && unsafeReason.MatchString(strings.ToLower(p.RejectionReason))
}

func demonstrationDefaults(p Proposal, goal string) Proposal {
	title := text(goal, 160)
	if title == "" {
		title = "taught computer workflow"
	}
	if p.Name == "" {
		p.Name = clip(NormalizeName(title), 64)
		if p.Name == "" {
			p.Name = "taught-computer-workflow"
		}
	}
	if p.Description == "" {
		p.Description = text("Taught computer workflow: "+title, 300)
	}
	if p.Trigger == "" {
		p.Trigger = text("Use when repeating the taught computer workflow: "+title, 500)
	}
	if p.Category == "" {
		p.Category = "computer"
	}
	if p.WorkflowKey == "" {
		p.WorkflowKey = p.Name
	}
	if len(p.Steps) == 0 {
		p.Steps = []string{"Inspect the current computer, window, and UI state before acting.", "Repeat the taught workflow: " + title + ".",
			"Adapt to the current semantic UI state instead of replaying coordinates or timing."}
	}
	if len(p.Verification) == 0 {
		p.Verification = []string{"Confirm the taught outcome is visible in the current computer state."}
	}
	p.Approved, p.RejectionReason = true, ""
	return p
}

func instructions(p Proposal, computer bool) string {
	lines := []string{"# " + p.Name, "", "## Purpose", p.Description, "", "## When To Use", p.Trigger}
	if len(p.RequiredInputs) > 0 {
		lines = append(lines, "", "## Required Inputs")
		for _, i := range p.RequiredInputs {
			lines = append(lines, "- "+i)
		}
	}
	lines = append(lines, "", "## Procedure")
	if computer {
		lines = append(lines, "Inspect the current computer state before acting. Use semantic UI labels, accessibility or DOM state, visible content, and tool results; never replay recorded coordinates or timing.")
	}
	for i, step := range p.Steps {
		lines = append(lines, fmt.Sprintf("%d. %s", i+1, step))
	}
	if len(p.Pitfalls) > 0 {
		lines = append(lines, "", "## Pitfalls And Recovery")
		for _, i := range p.Pitfalls {
			lines = append(lines, "- "+i)
		}
	}
	lines = append(lines, "", "## Verification")
	for _, i := range p.Verification {
		lines = append(lines, "- "+i)
	}
	if computer {
		lines = append(lines, "", "## Execution Contract", "- Execute through the normal NeoAgent loop and preserve approval and security rules.",
			"- Re-plan when the current application state differs from the demonstration.", "- Verify observed state before reporting success.")
	}
	return strings.Join(lines, "\n")
}

func compactDialogue(messages []llm.Message, max int) []map[string]any {
	var out []map[string]any
	for _, m := range messages {
		if m.Role != "user" && m.Role != "assistant" {
			continue
		}
		content, _ := m.Content.(string)
		if c := text(content, 1800); c != "" {
			out = append(out, map[string]any{"role": m.Role, "content": c})
		}
	}
	if len(out) > max {
		out = out[len(out)-max:]
	}
	if out == nil {
		out = []map[string]any{}
	}
	return out
}

// ── Repository ──────────────────────────────────────────────────────────────

func (s *Service) recordActivity(ctx context.Context, userID int64, agentID string, increment int) int {
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return 0
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `INSERT INTO skill_learning_state (user_id, agent_scope, activity_score) VALUES (?, ?, ?)
		ON CONFLICT(user_id, agent_scope) DO UPDATE SET activity_score = activity_score + excluded.activity_score, updated_at = datetime('now')`,
		userID, agentID, max(1, increment)); err != nil {
		return 0
	}
	var score int
	_ = tx.QueryRowContext(ctx, `SELECT activity_score FROM skill_learning_state WHERE user_id = ? AND agent_scope = ?`, userID, agentID).Scan(&score)
	if score >= reviewActivityThreshold {
		_, _ = tx.ExecContext(ctx, `UPDATE skill_learning_state SET activity_score = 0, updated_at = datetime('now') WHERE user_id = ? AND agent_scope = ?`, userID, agentID)
	}
	_ = tx.Commit()
	return score
}

type candidate struct {
	WorkflowKey      string `json:"workflowKey"`
	Title            string `json:"title"`
	Summary          string `json:"summary"`
	ObservationCount int    `json:"observationCount"`
	LatestRunID      string `json:"latestRunId,omitempty"`
	Evidence         []any  `json:"evidence,omitempty"`
	Status           string `json:"status,omitempty"`
}

func (s *Service) listCandidates(ctx context.Context, userID int64) []candidate {
	rows, err := s.DB.R.QueryContext(ctx, `SELECT workflow_key, title, summary, observation_count, latest_run_id FROM skill_learning_candidates
		WHERE user_id = ? AND status = 'observing' ORDER BY updated_at DESC LIMIT 20`, userID)
	out := []candidate{}
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var c candidate
		var title, summary, run sql.NullString
		if rows.Scan(&c.WorkflowKey, &title, &summary, &c.ObservationCount, &run) == nil {
			c.Title, c.Summary, c.LatestRunID = title.String, summary.String, run.String
			out = append(out, c)
		}
	}
	return out
}

func (s *Service) observeCandidate(ctx context.Context, userID int64, key, title, summary, runID string) candidate {
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return candidate{}
	}
	defer tx.Rollback()
	var id, evidenceJSON, status sql.NullString
	var count int
	found := tx.QueryRowContext(ctx, `SELECT id, observation_count, evidence_json, status FROM skill_learning_candidates WHERE user_id = ? AND workflow_key = ?`, userID, key).
		Scan(&id, &count, &evidenceJSON, &status) == nil
	var evidence []map[string]any
	_ = json.Unmarshal([]byte(evidenceJSON.String), &evidence)
	already := false
	var next []map[string]any
	for _, item := range evidence {
		if item["runId"] == runID {
			already = true
			continue
		}
		next = append(next, item)
	}
	next = append(next, map[string]any{"runId": runID, "summary": summary})
	if len(next) > 8 {
		next = next[len(next)-8:]
	}
	encoded, _ := json.Marshal(next)
	if found {
		if !already {
			count++
		}
		_, _ = tx.ExecContext(ctx, `UPDATE skill_learning_candidates SET title = ?, summary = ?, observation_count = ?, latest_run_id = ?, evidence_json = ?, updated_at = datetime('now') WHERE id = ?`,
			title, summary, count, runID, string(encoded), id.String)
	} else {
		count = 1
		status.String = "observing"
		_, _ = tx.ExecContext(ctx, `INSERT INTO skill_learning_candidates (id, user_id, workflow_key, title, summary, latest_run_id, evidence_json) VALUES (?, ?, ?, ?, ?, ?, ?)`,
			uuid.NewString(), userID, key, title, summary, runID, string(encoded))
		_ = tx.QueryRowContext(ctx, `SELECT observation_count, status FROM skill_learning_candidates WHERE user_id = ? AND workflow_key = ?`, userID, key).Scan(&count, &status)
	}
	_ = tx.Commit()
	ev := make([]any, len(next))
	for i, item := range next {
		ev[i] = item
	}
	return candidate{WorkflowKey: key, Title: title, Summary: summary, ObservationCount: count, Evidence: ev, Status: status.String}
}

type outcome struct{ invocations, successes, failures int }

func (s *Service) skillOutcomes(ctx context.Context, userID int64) map[string]outcome {
	out := map[string]outcome{}
	rows, err := s.DB.R.QueryContext(ctx, `SELECT skill_name, SUM(invocation_count), SUM(success_count), SUM(failure_count) FROM skill_metrics WHERE user_id = ? GROUP BY skill_name`, userID)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var name string
		var o outcome
		if rows.Scan(&name, &o.invocations, &o.successes, &o.failures) == nil {
			out[name] = o
		}
	}
	return out
}

// ── Writer ──────────────────────────────────────────────────────────────────

func learning(sk skills.Skill) workspace.Obj {
	l, _ := sk.Metadata.Value("learning").(workspace.Obj)
	return l
}

func managed(sk skills.Skill, ok bool) bool {
	return ok && sk.OwnerType == "user" && sk.Metadata.Value("auto_created") == true && learning(sk).Value("managed") == true
}

func (s *Service) catalog(ctx context.Context, userID int64) []map[string]any {
	outcomes := s.skillOutcomes(ctx, userID)
	all := s.Skills.GetAll(userID)
	if len(all) > 80 {
		all = all[:80]
	}
	out := []map[string]any{}
	for _, sk := range all {
		source := sk.Metadata.Value("source")
		if source == nil || source == "" {
			source = sk.OwnerType
		}
		key, _ := learning(sk).Value("workflowKey").(string)
		entry := map[string]any{"name": sk.Name, "description": sk.Description, "source": source, "learningManaged": managed(sk, true), "workflowKey": key}
		if o := outcomes[sk.Name]; o.invocations > 0 {
			entry["invocations"], entry["failures"] = o.invocations, o.failures
		}
		out = append(out, entry)
	}
	return out
}

func (s *Service) retireFailing(ctx context.Context, userID int64) {
	for name, o := range s.skillOutcomes(ctx, userID) {
		if o.invocations < retirementMinInvocations {
			continue
		}
		rate := float64(o.successes) / float64(o.invocations)
		if rate > retirementMaxSuccessRate {
			continue
		}
		sk, ok := s.Skills.GetSkill(name, userID)
		if !managed(sk, ok) || sk.Metadata.Value("enabled") == false {
			continue
		}
		reason := fmt.Sprintf("Disabled after %d of %d invocations succeeded.", o.successes, o.invocations)
		l := learning(sk).With("retiredAt", time.Now().UTC().Format("2006-01-02T15:04:05.000Z")).With("retiredReason", reason).With("successRate", math.Round(rate*100)/100)
		meta := sk.Metadata.With("enabled", false).With("learning", l)
		if saved, err := s.Skills.Update(ctx, userID, sk.Name, skills.Edit{Metadata: &meta, SkipVersion: true}); err != nil || !saved.Success {
			continue
		}
		s.log().Info("Retired learned skill", "name", sk.Name, "reason", reason)
		s.emit(userID, "skill:retired", map[string]any{"name": sk.Name, "reason": reason})
	}
}

func (s *Service) findManaged(userID int64, key string) (skills.Skill, bool) {
	if key == "" {
		return skills.Skill{}, false
	}
	for _, sk := range s.Skills.GetAll(userID) {
		if managed(sk, true) && learning(sk).Value("workflowKey") == key {
			return sk, true
		}
	}
	return skills.Skill{}, false
}

// Result is how persisting a learned skill went.
type Result struct {
	Success     bool   `json:"success"`
	Ignored     bool   `json:"ignored,omitempty"`
	Name        string `json:"name,omitempty"`
	Action      string `json:"action,omitempty"`
	Description string `json:"description,omitempty"`
	Error       string `json:"error,omitempty"`
}

func (s *Service) persist(ctx context.Context, userID int64, runID string, p Proposal, review Review, existing *skills.Skill, observations int, sourceKind string) Result {
	if !p.usable() {
		return Result{Ignored: true, Error: p.failure()}
	}
	var target *skills.Skill
	if existing != nil {
		target = existing
	} else if sk, ok := s.findManaged(userID, orText(p.WorkflowKey, review.WorkflowKey)); ok {
		target = &sk
	} else if sk, ok := s.Skills.GetSkill(orText(p.ExistingSkillName, p.Name), userID); ok {
		target = &sk
	}
	if target != nil && !managed(*target, true) {
		target = nil
	}
	prior := workspace.Obj{}
	meta := workspace.Obj{}
	if target != nil {
		prior, meta = learning(*target), target.Metadata
	}
	var runs []any
	if list, ok := prior.Value("sourceRunIds").([]any); ok {
		runs = append(runs, list...)
	}
	if runID != "" {
		runs = append(runs, runID)
	}
	seen := map[any]bool{}
	var unique []any
	for _, r := range runs {
		if !seen[r] {
			seen[r] = true
			unique = append(unique, r)
		}
	}
	if len(unique) > 8 {
		unique = unique[len(unique)-8:]
	}
	priorCount, _ := prior.Value("observationCount").(float64)
	computer := sourceKind == "computer-demonstration"
	category := p.Category
	if computer {
		category = "computer"
	}
	meta = meta.With("category", category).With("trigger", p.Trigger).With("source", "learned").With("enabled", true).With("draft", false).With("auto_created", true)
	if computer {
		meta = meta.With("required_capabilities", []any{"computer"})
	}
	meta = meta.With("learning", workspace.Obj{}.With("managed", true).With("origin", sourceKind).With("workflowKey", orText(p.WorkflowKey, review.WorkflowKey)).
		With("observationCount", math.Max(priorCount+1, float64(max(observations, 1)))).With("confidence", review.Confidence).
		With("sourceRunIds", unique).With("updatedAt", time.Now().UTC().Format("2006-01-02T15:04:05.000Z")))
	body := instructions(p, computer)
	var saved skills.Saved
	var err error
	action := "created"
	if target != nil {
		action = "updated"
		saved, err = s.Skills.Update(ctx, userID, target.Name, skills.Edit{Description: &p.Description, Instructions: &body, Metadata: &meta})
	} else {
		name := p.Name
		if _, taken := s.Skills.GetSkill(name, userID); taken {
			for suffix := 2; ; suffix++ {
				if _, taken := s.Skills.GetSkill(fmt.Sprintf("%s-%d", p.Name, suffix), userID); !taken {
					name = fmt.Sprintf("%s-%d", p.Name, suffix)
					break
				}
			}
		}
		saved, err = s.Skills.Create(ctx, userID, name, p.Description, body, meta)
	}
	if err != nil {
		return Result{Error: err.Error()}
	}
	if !saved.Success {
		return Result{Error: "The skill could not be saved."}
	}
	if saved.VersionID != nil {
		notes := review.Reason
		if notes == "" {
			notes = "Learned from " + sourceKind + "."
		}
		_, _ = s.DB.W.ExecContext(ctx, `INSERT INTO agent_skill_evaluations (id, skill_version_id, run_id, score, outcome, notes) VALUES (?, ?, ?, ?, ?, ?)`,
			uuid.NewString(), *saved.VersionID, nullString(runID), review.Confidence, action, notes)
	}
	s.emit(userID, "skill:learned", map[string]any{"action": action, "name": saved.Name, "description": p.Description, "origin": sourceKind})
	return Result{Success: true, Name: saved.Name, Action: action, Description: p.Description}
}

func nullString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func orText(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

// ── Service ─────────────────────────────────────────────────────────────────

const reviewSystem = "You review completed agent work for durable procedural learning. Return JSON only with decision, workflowKey, title, summary, existingSkillName, confidence, and reason. decision must be ignore, observe, create, or update. Skills are reusable procedures, not facts, conversation summaries, outputs, or one-off task narratives. Create when a proven reusable procedure was taught in detail or is clearly represented by repeated evidence. Observe when a reusable pattern is plausible but needs another occurrence. Use a stable class-level workflowKey. Update only an existing skill whose catalog entry says learningManaged=true and only when this run produced a concrete correction or improvement. A catalog entry may carry invocations and failures counted from real use. Treat a high failure share as evidence that the skill is wrong, and prefer update when this run shows what it should do instead. Ignore unresolved failures, transient environment problems, and work with no reusable method. Do not preserve secrets, credentials, literal private data, brittle coordinates, or session-specific identifiers."

func jsonPrompt(v any, limit int) string {
	encoded, _ := json.Marshal(v)
	return clipUTF16(string(encoded), limit)
}

func clipUTF16(s string, n int) string {
	units := 0
	for i, r := range s {
		size := 1
		if r > 0xFFFF {
			size = 2
		}
		if units+size > n {
			return s[:i]
		}
		units += size
	}
	return s
}

func (s *Service) synthesize(ctx context.Context, userID int64, agentID, sourceKind string, experience map[string]any, review map[string]any, existing *skills.Skill) (Proposal, bool, error) {
	contract := "Reject with approved=false if the evidence does not prove a safe reusable procedure."
	if sourceKind == "computer-demonstration" {
		contract = "The user explicitly taught this computer workflow. Approve a reusable skill from the demonstration. Use semantic UI state and never coordinates, recorded timing, brittle selectors, clipboard contents, or macro replay. Reject with approved=false only when the demonstration exposes secrets or has no observable method."
	}
	system := strings.Join([]string{"You synthesize and validate a reusable NeoAgent skill from proven experience.",
		"Return JSON only as {approved, skill}. skill contains name, description, trigger, category, workflowKey, existingSkillName, requiredInputs, steps, pitfalls, and verification.",
		"Use a class-level name and make the description and trigger precise enough for future semantic selection.",
		"Generalize the successful method; omit transcript narration, final-answer content, temporary failures, and task-specific identifiers.",
		"Every step must be actionable and adaptive. Include observed pitfalls only when the evidence includes a working recovery.",
		"Verification must describe observable proof, not an assumption of success.", contract}, " ")
	var existingSkill any
	if existing != nil {
		existingSkill = map[string]any{"name": existing.Name, "description": existing.Description, "instructions": existing.Instructions, "metadata": existing.Metadata}
	}
	prompt := jsonPrompt(map[string]any{"sourceKind": sourceKind, "review": review, "experience": experience, "existingSkill": existingSkill,
		"installedSkills": s.catalog(ctx, userID)}, 48000)
	parsed, err := s.Infer(ctx, userID, agentID, "general", system, prompt, 2200)
	if err != nil {
		return Proposal{}, false, err
	}
	if parsed == nil {
		parsed = map[string]any{"approved": false, "skill": map[string]any{}}
	}
	p, rejected := normalizeProposal(parsed)
	return p, rejected, nil
}

// LearnFromComputerDemonstration saves a workflow the owner demonstrated as a skill.
func (s *Service) LearnFromComputerDemonstration(ctx context.Context, userID int64, agentID, goal string, evidence any) (Result, error) {
	goal = text(goal, 2000)
	if userID == 0 || goal == "" {
		return Result{}, fmt.Errorf("Computer learning requires a user and demonstrated goal.")
	}
	p, _, err := s.synthesize(ctx, userID, agentID, "computer-demonstration", map[string]any{"goal": goal, "demonstration": evidence},
		map[string]any{"workflowKey": "", "title": goal, "summary": "A user-demonstrated computer workflow.", "confidence": 1}, nil)
	if err != nil {
		return Result{}, err
	}
	if p.safetyRejection() {
		s.log().Warn("Computer demonstration was rejected as unsafe", "reason", p.RejectionReason)
		reason := p.RejectionReason
		if reason == "" {
			reason = "The demonstration could not be saved as a skill."
		}
		return Result{Ignored: true, Error: reason}, nil
	}
	if !p.usable() {
		s.log().Warn("Computer demonstration synthesis needed taught-goal defaults", "reason", p.failure())
		p = demonstrationDefaults(p, goal)
	}
	result := s.persist(ctx, userID, "", p, Review{WorkflowKey: p.WorkflowKey, Confidence: 1}, nil, 1, "computer-demonstration")
	if !result.Success {
		s.log().Warn("Computer demonstration did not produce a skill", "error", result.Error)
	}
	return result, nil
}

// CompletedRun is a run that ended with an answer.
type CompletedRun struct {
	UserID                     int64
	AgentID, RunID             string
	TriggerType, TriggerSource string
	Task, FinalContent         string
	TaskID                     int64
	Iterations                 int
	Messages                   []llm.Message
}

// EnqueueCompletedRun reviews a completed run in the background, one at a time
// per user.
func (s *Service) EnqueueCompletedRun(run CompletedRun) {
	s.mu.Lock()
	if s.stopping {
		s.mu.Unlock()
		return
	}
	if s.queues == nil {
		s.queues = map[int64]chan struct{}{}
	}
	previous := s.queues[run.UserID]
	done := make(chan struct{})
	s.queues[run.UserID] = done
	s.wg.Add(1)
	s.mu.Unlock()
	go func() {
		defer s.wg.Done()
		defer func() {
			close(done)
			s.mu.Lock()
			if s.queues[run.UserID] == done {
				delete(s.queues, run.UserID)
			}
			s.mu.Unlock()
		}()
		if previous != nil {
			<-previous
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		if err := s.observe(ctx, run); err != nil {
			s.log().Warn("Post-run skill review failed", "error", err)
		}
	}()
}

func (s *Service) observe(ctx context.Context, run CompletedRun) error {
	agentID := text(run.AgentID, 128)
	runID := text(run.RunID, 128)
	task := text(run.Task, 6000)
	final := text(run.FinalContent, 4000)
	if run.UserID == 0 || runID == "" || task == "" || final == "" {
		return nil
	}
	triggerType := orText(text(run.TriggerType, 64), "user")
	triggerSource := text(run.TriggerSource, 64)
	if triggerType != "user" && run.TaskID == 0 && triggerSource != "schedule" && triggerSource != "tasks" {
		return nil
	}
	if s.AutoLearning != nil && !s.AutoLearning(ctx, run.UserID, agentID) {
		return nil
	}
	s.retireFailing(ctx, run.UserID)
	rows, err := s.DB.R.QueryContext(ctx, `SELECT step_index, tool_name, status, description, error FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`, runID)
	if err != nil {
		return err
	}
	var steps []map[string]any
	completed := 0
	for rows.Next() {
		var index sql.NullInt64
		var tool, status, desc, errText sql.NullString
		if rows.Scan(&index, &tool, &status, &desc, &errText) != nil || tool.String == "" {
			continue
		}
		if status.String == "completed" {
			completed++
		}
		steps = append(steps, map[string]any{"index": index.Int64, "tool": tool.String, "status": status.String, "description": text(desc.String, 300), "error": text(errText.String, 240)})
	}
	rows.Close()
	if steps == nil {
		steps = []map[string]any{}
	}
	dialogue := compactDialogue(run.Messages, 10)
	explained := 0
	for _, m := range dialogue {
		if m["role"] == "user" {
			explained += len([]rune(m["content"].(string)))
		}
	}
	detailed := max(len([]rune(task)), explained) >= detailedRequestChars
	if !detailed && completed < minimumToolSteps {
		return nil
	}
	activity := s.recordActivity(ctx, run.UserID, agentID, max(completed, 1))
	if !detailed && activity < reviewActivityThreshold {
		return nil
	}
	experience := map[string]any{"triggerSource": triggerSource, "triggerType": triggerType, "userRequest": task, "recentDialogue": dialogue,
		"finalResponse": final, "toolSteps": steps, "modelIterations": max(0, run.Iterations)}
	parsed, err := s.Infer(ctx, run.UserID, agentID, "fast", reviewSystem,
		jsonPrompt(map[string]any{"installedSkills": s.catalog(ctx, run.UserID), "candidates": s.listCandidates(ctx, run.UserID), "experience": experience}, 36000), 900)
	if err != nil {
		return err
	}
	review := normalizeReview(parsed)
	reviewMap := map[string]any{"decision": review.Decision, "workflowKey": review.WorkflowKey, "title": review.Title, "summary": review.Summary,
		"existingSkillName": review.ExistingSkillName, "confidence": review.Confidence, "reason": review.Reason}
	switch review.Decision {
	case "ignore":
		return nil
	case "update":
		existing, ok := s.Skills.GetSkill(review.ExistingSkillName, run.UserID)
		if !managed(existing, ok) {
			return nil
		}
		p, _, err := s.synthesize(ctx, run.UserID, agentID, "agent-run", experience, reviewMap, &existing)
		if err != nil {
			return err
		}
		s.persist(ctx, run.UserID, runID, p, review, &existing, 1, "agent-run")
		return nil
	}
	if review.WorkflowKey == "" || review.Title == "" || review.Summary == "" {
		return nil
	}
	c := s.observeCandidate(ctx, run.UserID, review.WorkflowKey, review.Title, review.Summary, runID)
	if c.Status == "promoted" || (review.Decision != "create" && c.ObservationCount < repeatObservations) {
		return nil
	}
	var existing *skills.Skill
	if sk, ok := s.findManaged(run.UserID, review.WorkflowKey); ok {
		existing = &sk
	}
	experience["repeatedEvidence"] = c.Evidence
	p, _, err := s.synthesize(ctx, run.UserID, agentID, "agent-run", experience, reviewMap, existing)
	if err != nil {
		return err
	}
	result := s.persist(ctx, run.UserID, runID, p, review, existing, c.ObservationCount, "agent-run")
	if result.Success {
		_, _ = s.DB.W.ExecContext(ctx, `UPDATE skill_learning_candidates SET status = 'promoted', skill_name = ?, updated_at = datetime('now') WHERE user_id = ? AND workflow_key = ?`,
			result.Name, run.UserID, review.WorkflowKey)
	}
	return nil
}

// Shutdown waits for reviews in flight.
func (s *Service) Shutdown() {
	s.mu.Lock()
	s.stopping = true
	s.mu.Unlock()
	s.wg.Wait()
}
