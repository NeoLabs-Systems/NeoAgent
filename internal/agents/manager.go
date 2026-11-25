package agents

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/google/uuid"
)

// ErrNotFound is the "Agent not found." of every profile change.
var ErrNotFound = errors.New("Agent not found.")

// Manager reads and changes a user's agents.
type Manager struct{ DB *dbx.DB }

// input is a request body or a run's request, read the loose way Node did.
type input map[string]any

func (in input) get(keys ...string) any {
	for _, k := range keys {
		if v, ok := in[k]; ok && v != nil {
			return v
		}
	}
	return nil
}

func truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case string:
		return x != ""
	case float64:
		return x != 0
	case json.Number:
		f, _ := x.Float64()
		return f != 0
	}
	return true
}

// jsString is String(v) for the values a JSON body holds.
func jsString(v any) string {
	switch x := v.(type) {
	case nil:
		return ""
	case string:
		return x
	case json.Number:
		return x.String()
	case bool:
		return strconv.FormatBool(x)
	case []any:
		parts := make([]string, len(x))
		for i, item := range x {
			if item != nil {
				parts[i] = jsString(item)
			}
		}
		return strings.Join(parts, ",")
	case map[string]any:
		return "[object Object]"
	}
	return fmt.Sprint(v)
}

// or is String(a || b || ...).
func or(values ...any) string {
	for _, v := range values {
		if truthy(v) {
			return jsString(v)
		}
	}
	return ""
}

func boolFromInput(v any, fallback bool) bool {
	switch x := v.(type) {
	case nil:
		return fallback
	case bool:
		return x
	case json.Number:
		if x.String() == "1" {
			return true
		}
		if x.String() == "0" {
			return false
		}
	case string:
		if x == "1" {
			return true
		}
		if x == "0" {
			return false
		}
	}
	switch strings.ToLower(strings.TrimSpace(jsString(v))) {
	case "true", "yes", "on":
		return true
	case "false", "no", "off":
		return false
	}
	return fallback
}

// parseDelegateTargets reads a list of agent ids, or its JSON text.
func parseDelegateTargets(v any) []string {
	out := []string{}
	if !truthy(v) {
		return out
	}
	list, ok := v.([]any)
	if !ok {
		var parsed any
		dec := json.NewDecoder(strings.NewReader(jsString(v)))
		dec.UseNumber()
		if dec.Decode(&parsed) != nil {
			return out
		}
		if list, ok = parsed.([]any); !ok {
			return out
		}
	}
	for _, id := range list {
		if s := strings.TrimSpace(or(id)); s != "" {
			out = append(out, s)
		}
	}
	return out
}

var policyCategories = map[string]bool{
	"credential_use": true, "network_write": true, "user_contact": true, "skill_mutation": true, "agent_creation": true, "external": true,
}

// restriction is one category and level, in the order the source listed them.
type restriction struct{ category, level string }

func levelRank(level string) int {
	switch level {
	case "require_approval":
		return 1
	case "deny":
		return 2
	}
	return 0
}

// normalizeRestrictions keeps known categories with a known level, in order.
func normalizeRestrictions(v any) []restriction {
	text := ""
	switch x := v.(type) {
	case nil:
		return nil
	case string:
		text = x
		if text == "" {
			text = "{}"
		}
	default:
		raw, _ := json.Marshal(x)
		text = string(raw)
	}
	dec := json.NewDecoder(strings.NewReader(text))
	if tok, err := dec.Token(); err != nil || tok != json.Delim('{') {
		return nil
	}
	var out []restriction
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil
		}
		key, _ := tok.(string)
		var value any
		if dec.Decode(&value) != nil {
			return nil
		}
		level, _ := value.(string)
		if policyCategories[key] && levelRank(level) > 0 {
			out = setRestriction(out, key, level)
		}
	}
	return out
}

func setRestriction(list []restriction, category, level string) []restriction {
	for i := range list {
		if list[i].category == category {
			list[i].level = level
			return list
		}
	}
	return append(list, restriction{category, level})
}

// mergeRestrictions is the strictest level per category across sources.
func mergeRestrictions(sources ...any) []restriction {
	var merged []restriction
	for _, source := range sources {
		for _, r := range normalizeRestrictions(source) {
			current := ""
			for _, m := range merged {
				if m.category == r.category {
					current = m.level
				}
			}
			if levelRank(r.level) > levelRank(current) {
				merged = setRestriction(merged, r.category, r.level)
			}
		}
	}
	return merged
}

func restrictionsJSON(list []restriction) string {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, r := range list {
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

func restrictionsObject(list []restriction) json.RawMessage {
	return json.RawMessage(restrictionsJSON(list))
}

// row is an agents row.
type row struct {
	id, slug, displayName                                string
	description, responsibilities, instructions, status  sql.NullString
	isDefault, canDelegate, canBeDelegatedTo             sql.NullInt64
	delegateTargets, toolRestrictions, createdBy, reason sql.NullString
	createdAt, updatedAt                                 sql.NullString
}

const rowColumns = `id, slug, display_name, description, responsibilities, instructions, status, is_default, can_delegate, can_be_delegated_to,
  delegate_targets_json, tool_restrictions_json, created_by_agent_id, creation_reason, created_at, updated_at`

func scan(sc interface{ Scan(...any) error }) (*row, error) {
	var r row
	err := sc.Scan(&r.id, &r.slug, &r.displayName, &r.description, &r.responsibilities, &r.instructions, &r.status,
		&r.isDefault, &r.canDelegate, &r.canBeDelegatedTo, &r.delegateTargets, &r.toolRestrictions, &r.createdBy, &r.reason, &r.createdAt, &r.updatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &r, err
}

func (m *Manager) get(ctx context.Context, userID int64, id string) (*row, error) {
	if userID == 0 || id == "" {
		return nil, nil
	}
	return scan(m.DB.W.QueryRowContext(ctx, `SELECT `+rowColumns+` FROM agents WHERE user_id = ? AND id = ?`, userID, id))
}

func (m *Manager) bySlug(ctx context.Context, userID int64, slug string) (*row, error) {
	slug = normalizeSlug(slug)
	if userID == 0 || slug == "" {
		return nil, nil
	}
	return scan(m.DB.W.QueryRowContext(ctx, `SELECT `+rowColumns+` FROM agents WHERE user_id = ? AND slug = ?`, userID, slug))
}

func nullable(s sql.NullString) any {
	if !s.Valid || s.String == "" {
		return nil
	}
	return s.String
}

func nullString(s sql.NullString) any {
	if !s.Valid {
		return nil
	}
	return s.String
}

// serialize is serializeAgent.
func serialize(r *row) map[string]any {
	status := r.status.String
	if status == "" {
		status = "active"
	}
	return map[string]any{
		"id":               r.id,
		"slug":             r.slug,
		"displayName":      r.displayName,
		"description":      r.description.String,
		"responsibilities": r.responsibilities.String,
		"instructions":     r.instructions.String,
		"status":           status,
		"isDefault":        r.isDefault.Int64 == 1,
		"canDelegate":      r.canDelegate.Int64 == 1,
		"canBeDelegatedTo": !(r.canBeDelegatedTo.Valid && r.canBeDelegatedTo.Int64 == 0),
		"delegateTargets":  parseDelegateTargets(r.delegateTargets.String),
		"toolRestrictions": restrictionsObject(normalizeRestrictions(r.toolRestrictions.String)),
		"createdByAgentId": nullable(r.createdBy),
		"creationReason":   r.reason.String,
		"createdAt":        nullString(r.createdAt),
		"updatedAt":        nullString(r.updatedAt),
	}
}

// head is s.slice(0, n) in UTF-16 units, after trimming.
func trimHead(s string, n int) string { return head(strings.TrimSpace(s), n) }

// Create is createAgent: a new agent from a request body.
func (m *Manager) Create(ctx context.Context, userID int64, in input) (map[string]any, error) {
	slug := normalizeSlug(or(in["slug"], in["displayName"], in["name"]))
	if slug == "" {
		return nil, errors.New("Agent slug or display name is required.")
	}
	existing, err := m.bySlug(ctx, userID, slug)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, fmt.Errorf("An agent with the identifier %q already exists.", slug)
	}
	displayName := trimHead(or(in["displayName"], in["name"], slug), 120)
	isMain := slug == mainSlug
	status := "active"
	if in["status"] == "paused" {
		status = "paused"
	}
	var reason any
	if r := trimHead(or(in["creationReason"]), 1000); r != "" {
		reason = r
	}
	var createdBy any
	if truthy(in["createdByAgentId"]) {
		createdBy = in["createdByAgentId"]
	}
	targets, _ := json.Marshal(parseDelegateTargets(in.get("delegateTargets", "delegate_targets", "delegate_targets_json")))
	id := uuid.NewString()
	if _, err := m.DB.W.ExecContext(ctx, `INSERT INTO agents (
      id, user_id, slug, display_name, description, responsibilities, instructions,
      status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json,
      tool_restrictions_json, created_by_agent_id, creation_reason
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, userID, slug, displayName,
		strings.TrimSpace(or(in["description"])), strings.TrimSpace(or(in["responsibilities"])), strings.TrimSpace(or(in["instructions"])),
		status, boolInt(isMain),
		boolInt(boolFromInput(in.get("canDelegate", "can_delegate"), isMain)),
		boolInt(boolFromInput(in.get("canBeDelegatedTo", "can_be_delegated_to"), !isMain)),
		string(targets), restrictionsJSON(normalizeRestrictions(in["toolRestrictions"])), createdBy, reason); err != nil {
		return nil, err
	}
	if isMain {
		if err := m.makeDefault(ctx, userID, id, false); err != nil {
			return nil, err
		}
	}
	r, err := m.get(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	return serialize(r), nil
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func (m *Manager) makeDefault(ctx context.Context, userID int64, id string, touch bool) error {
	query := `UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ?`
	if touch {
		query = `UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END, updated_at = datetime('now') WHERE user_id = ?`
	}
	_, err := m.DB.W.ExecContext(ctx, query, id, userID)
	return err
}

// Update is updateAgent: a field left out keeps its value.
func (m *Manager) Update(ctx context.Context, userID int64, id string, in input) (map[string]any, error) {
	existing, err := m.get(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		return nil, ErrNotFound
	}
	slug := existing.slug
	if existing.slug != mainSlug && in["slug"] != nil {
		slug = normalizeSlug(jsString(in["slug"]))
	}
	if slug == "" {
		return nil, errors.New("Agent slug is required.")
	}
	displayName := existing.displayName
	if in["displayName"] != nil {
		displayName = trimHead(or(in["displayName"]), 120)
	}
	if displayName == "" {
		return nil, errors.New("Agent display name is required.")
	}
	status := existing.status.String
	if s, ok := in["status"].(string); ok && (s == "active" || s == "paused" || s == "archived") {
		status = s
	}
	if status == "archived" && (existing.slug == mainSlug || existing.isDefault.Int64 != 0) {
		return nil, errors.New("The default main agent cannot be archived.")
	}
	canDelegate := boolFromInput(in.get("canDelegate", "can_delegate"), existing.canDelegate.Int64 == 1)
	canBe := boolFromInput(in.get("canBeDelegatedTo", "can_be_delegated_to"), !(existing.canBeDelegatedTo.Valid && existing.canBeDelegatedTo.Int64 == 0))
	targetSource := in.get("delegateTargets", "delegate_targets", "delegate_targets_json")
	var targets []string
	if targetSource != nil {
		targets = parseDelegateTargets(targetSource)
	} else {
		targets = parseDelegateTargets(existing.delegateTargets.String)
	}
	restrictions := normalizeRestrictions(existing.toolRestrictions.String)
	if in["toolRestrictions"] != nil {
		restrictions = normalizeRestrictions(in["toolRestrictions"])
	}
	if slug != existing.slug {
		taken, err := m.bySlug(ctx, userID, slug)
		if err != nil {
			return nil, err
		}
		if taken != nil {
			return nil, fmt.Errorf("An agent with the identifier %q already exists.", slug)
		}
	}
	keep := func(key string, current sql.NullString) any {
		if in[key] == nil {
			return nullString(current)
		}
		return strings.TrimSpace(or(in[key]))
	}
	targetsJSON, _ := json.Marshal(targets)
	if _, err := m.DB.W.ExecContext(ctx, `UPDATE agents
     SET slug = ?, display_name = ?, description = ?, responsibilities = ?, instructions = ?,
         status = ?, can_delegate = ?, can_be_delegated_to = ?, delegate_targets_json = ?,
         tool_restrictions_json = ?, updated_at = datetime('now')
     WHERE user_id = ? AND id = ?`,
		slug, displayName, keep("description", existing.description), keep("responsibilities", existing.responsibilities), keep("instructions", existing.instructions),
		status, boolInt(canDelegate), boolInt(canBe), string(targetsJSON), restrictionsJSON(restrictions), userID, id); err != nil {
		return nil, err
	}
	if in["isDefault"] == true || in["is_default"] == true {
		if _, err := m.SetDefault(ctx, userID, id); err != nil {
			return nil, err
		}
	}
	r, err := m.get(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	return serialize(r), nil
}

// SetDefault makes an agent the user's default.
func (m *Manager) SetDefault(ctx context.Context, userID int64, id string) (map[string]any, error) {
	existing, err := m.get(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		return nil, ErrNotFound
	}
	if err := m.makeDefault(ctx, userID, id, true); err != nil {
		return nil, err
	}
	r, err := m.get(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	return serialize(r), nil
}

// Archive archives an agent other than the default main agent.
func (m *Manager) Archive(ctx context.Context, userID int64, id string) error {
	existing, err := m.get(ctx, userID, id)
	if err != nil {
		return err
	}
	if existing == nil {
		return ErrNotFound
	}
	if existing.slug == mainSlug || existing.isDefault.Int64 != 0 {
		return errors.New("The default main agent cannot be archived.")
	}
	_, err = m.DB.W.ExecContext(ctx, `UPDATE agents SET status = 'archived', updated_at = datetime('now') WHERE user_id = ? AND id = ?`, userID, id)
	return err
}

// List lists the user's agents, default first, and the default agent's id.
func (m *Manager) List(ctx context.Context, userID int64, includeArchived bool) ([]map[string]any, string, error) {
	resolver := agentscope.Resolver{DB: m.DB}
	defaultID, err := resolver.Resolve(ctx, userID, "")
	if err != nil {
		return nil, "", err
	}
	query := `SELECT ` + rowColumns + ` FROM agents WHERE user_id = ?`
	if !includeArchived {
		query += ` AND status != 'archived'`
	}
	query += ` ORDER BY is_default DESC, updated_at DESC, display_name ASC`
	rows, err := m.DB.W.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		r, err := scan(rows)
		if err != nil {
			return nil, "", err
		}
		out = append(out, serialize(r))
	}
	return out, defaultID, rows.Err()
}
