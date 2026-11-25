package models

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// Stored in place of a model id: every model of the provider, or only its paid
// ones.
const (
	providerHealthSentinel = "*"
	paidModelsSentinel     = "$paid"
	maxTransientCooldown   = 15 * time.Minute
)

// HealthStore persists model failures (the ai_model_health table) so a cooldown
// survives a restart. Persistence is best effort: a failure to write is logged
// and the in-memory state still applies.
type HealthStore struct {
	DB  *dbx.DB
	Log *slog.Logger
}

// HealthEntry is one stored failure.
type HealthEntry struct {
	UserID           int64
	AgentID          string
	ProviderID       string
	ModelSelectionID string
	Scope            string // "model" or "provider"
	FailureClass     string
	Status           int
	ExpiresAtMs      int64
}

func (s *HealthStore) warn(msg string, err error) {
	if s.Log != nil {
		s.Log.Warn(msg, "error", err)
	}
}

func (s *HealthStore) hasUser(ctx context.Context, userID int64) bool {
	var one int
	return s.DB.R.QueryRowContext(ctx, `SELECT 1 FROM users WHERE id = ?`, userID).Scan(&one) == nil
}

// Save records a failure; repeated failures count up and keep the later cooldown.
func (s *HealthStore) Save(ctx context.Context, e HealthEntry) {
	if !s.hasUser(ctx, e.UserID) {
		return
	}
	var status any
	if e.Status != 0 {
		status = e.Status
	}
	_, err := s.DB.W.ExecContext(ctx,
		`INSERT INTO ai_model_health (
		   user_id, agent_id, provider_id, model_selection_id, failure_scope,
		   failure_class, failure_count, last_status, cooldown_until_ms
		 ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
		 ON CONFLICT(user_id, agent_id, provider_id, model_selection_id) DO UPDATE SET
		   failure_scope = excluded.failure_scope,
		   failure_class = excluded.failure_class,
		   failure_count = ai_model_health.failure_count + 1,
		   last_status = excluded.last_status,
		   cooldown_until_ms = MAX(ai_model_health.cooldown_until_ms, excluded.cooldown_until_ms),
		   updated_at = datetime('now')`,
		e.UserID, e.AgentID, e.ProviderID, e.ModelSelectionID, e.Scope, e.FailureClass, status, e.ExpiresAtMs)
	if err != nil {
		s.warn("Could not persist model health state.", err)
	}
}

// Clear removes the failures stored for a model and for its provider.
func (s *HealthStore) Clear(ctx context.Context, userID int64, agentID, providerID string, selectionIDs [2]string) bool {
	if !s.hasUser(ctx, userID) {
		return false
	}
	result, err := s.DB.W.ExecContext(ctx,
		`DELETE FROM ai_model_health
		 WHERE user_id = ? AND agent_id = ? AND provider_id = ? AND model_selection_id IN (?, ?)`,
		userID, agentID, providerID, selectionIDs[0], selectionIDs[1])
	if err != nil {
		s.warn("Could not clear model health state.", err)
		return false
	}
	n, _ := result.RowsAffected()
	return n > 0
}

// ActiveRow is a stored failure that is still cooling down.
type ActiveRow struct {
	ProviderID       string
	ModelSelectionID string
	FailureScope     string
	FailureClass     string
	LastStatus       sql.NullInt64
	CooldownUntilMs  int64
}

// ListActive returns the failures still cooling down and deletes the expired ones.
func (s *HealthStore) ListActive(ctx context.Context, userID int64, agentID string, nowMs int64) []ActiveRow {
	if !s.hasUser(ctx, userID) {
		return nil
	}
	if _, err := s.DB.W.ExecContext(ctx, `DELETE FROM ai_model_health WHERE user_id = ? AND agent_id = ? AND cooldown_until_ms <= ?`, userID, agentID, nowMs); err != nil {
		s.warn("Could not read model health state.", err)
		return nil
	}
	rows, err := s.DB.R.QueryContext(ctx,
		`SELECT provider_id, model_selection_id, failure_scope, failure_class, last_status, cooldown_until_ms
		 FROM ai_model_health WHERE user_id = ? AND agent_id = ? AND cooldown_until_ms > ?`, userID, agentID, nowMs)
	if err != nil {
		s.warn("Could not read model health state.", err)
		return nil
	}
	defer rows.Close()
	var out []ActiveRow
	for rows.Next() {
		var r ActiveRow
		if err := rows.Scan(&r.ProviderID, &r.ModelSelectionID, &r.FailureScope, &r.FailureClass, &r.LastStatus, &r.CooldownUntilMs); err != nil {
			s.warn("Could not read model health state.", err)
			return out
		}
		out = append(out, r)
	}
	return out
}

// Cooldowns are how long each kind of failure keeps a model or provider out of
// routing.
type Cooldowns struct {
	ModelUnavailable time.Duration
	ProviderAuth     time.Duration
	ProviderBilling  time.Duration
	Recovery         time.Duration
}

// DefaultCooldowns are the cooldowns when nothing is configured.
func DefaultCooldowns() Cooldowns {
	return Cooldowns{
		ModelUnavailable: 7 * 24 * time.Hour,
		ProviderAuth:     time.Hour,
		ProviderBilling:  15 * time.Minute,
		Recovery:         time.Minute,
	}
}

// CooldownsFromEnv applies the NEOAGENT_*_COOLDOWN_MS overrides; each is kept
// between one second and its maximum.
func CooldownsFromEnv(getenv func(string) string) Cooldowns {
	c := DefaultCooldowns()
	read := func(name string, fallback, maximum time.Duration) time.Duration {
		var ms float64
		if _, err := fmt.Sscan(strings.TrimSpace(getenv(name)), &ms); err != nil {
			return fallback
		}
		return max(time.Second, min(time.Duration(ms*float64(time.Millisecond)), maximum))
	}
	c.ModelUnavailable = read("NEOAGENT_MODEL_NOT_FOUND_COOLDOWN_MS", c.ModelUnavailable, 30*24*time.Hour)
	c.ProviderAuth = read("NEOAGENT_PROVIDER_AUTH_COOLDOWN_MS", c.ProviderAuth, 24*time.Hour)
	c.ProviderBilling = read("NEOAGENT_PROVIDER_BILLING_COOLDOWN_MS", c.ProviderBilling, 24*time.Hour)
	c.Recovery = read("NEOAGENT_MODEL_RECOVERY_COOLDOWN_MS", c.Recovery, maxTransientCooldown)
	return c
}

var (
	modelUnavailableCodes = map[string]bool{
		"MODEL_NOT_FOUND": true, "MODEL_NOT_AVAILABLE": true,
		// GitHub Copilot answers HTTP 400 for models outside the account's plan.
		"MODEL_NOT_SUPPORTED": true, "MODEL_UNSUPPORTED": true, "UNSUPPORTED_MODEL": true,
	}
	modelRecoveryCodes = map[string]bool{"MODEL_EMPTY_RESPONSE": true, "MODEL_CALL_TIMEOUT": true}
)

// Disposition says what a failure means for routing.
type Disposition struct {
	Scope        string // "model", "provider" or "paid"
	FailureClass string
	Cooldown     time.Duration
	Status       int
}

// ProviderTraits answers what the failure rules need to know about a provider.
type ProviderTraits interface {
	// IsAggregator: an aggregator resells many vendors' models under one account.
	// Its rate limits come from the upstream serving one model, and running out of
	// credit stops only the models that cost money.
	IsAggregator(providerID string) bool
}

// Failures remembers which models and providers are cooling down after errors,
// in memory and in the store.
type Failures struct {
	Store     *HealthStore
	Providers ProviderTraits
	Cooldowns Cooldowns
	Now       func() time.Time
	Log       *slog.Logger

	mu       sync.Mutex
	failures map[string]HealthEntry
}

func (f *Failures) now() time.Time {
	if f.Now != nil {
		return f.Now()
	}
	return time.Now()
}

func scopedAgentID(agentID string) string {
	if agentID == "" {
		return "main"
	}
	return agentID
}

func providerFromSelectionID(id string) string {
	id = strings.TrimSpace(id)
	if i := strings.Index(id, SelectionSeparator); i > 0 {
		return strings.ToLower(id[:i])
	}
	return ""
}

func cacheKey(userID int64, agentID, providerID, selectionID string) string {
	return fmt.Sprintf("%d:%s:%s:%s", userID, scopedAgentID(agentID), strings.ToLower(strings.TrimSpace(providerID)), strings.TrimSpace(selectionID))
}

func (f *Failures) transientCooldown(err *llm.Error) time.Duration {
	configured := f.Cooldowns.Recovery
	if err == nil || err.RetryAfter <= 0 {
		return configured
	}
	return max(configured, min(err.RetryAfter, maxTransientCooldown))
}

// Disposition classifies a failure: which part of routing it stops, why, and
// for how long. nil means the failure says nothing about the model's health (an
// abort, or an error of the request itself).
func (f *Failures) Disposition(err error, providerID string) *Disposition {
	if err == nil || llm.IsAbort(err) || errors.Is(err, context.Canceled) {
		return nil
	}
	providerErr := llm.AsError(err)
	status, code := 0, ""
	if providerErr != nil {
		status, code = providerErr.Status, strings.ToUpper(strings.TrimSpace(providerErr.Code))
	}
	aggregator := f.Providers != nil && f.Providers.IsAggregator(providerID)
	switch {
	case status == 404 || modelUnavailableCodes[code]:
		return &Disposition{Scope: "model", FailureClass: "model_unavailable", Cooldown: f.Cooldowns.ModelUnavailable, Status: status}
	case status == 401 || status == 403:
		return &Disposition{Scope: "provider", FailureClass: "provider_auth", Cooldown: f.Cooldowns.ProviderAuth, Status: status}
	case status == 402:
		scope := "provider"
		if aggregator {
			scope = "paid"
		}
		return &Disposition{Scope: scope, FailureClass: "provider_billing", Cooldown: f.Cooldowns.ProviderBilling, Status: status}
	case status == 429 && aggregator:
		return &Disposition{Scope: "model", FailureClass: "model_rate_limit", Cooldown: f.transientCooldown(providerErr), Status: status}
	case status == 429 || llm.IsTransient(err):
		class := "provider_transient"
		if status == 429 {
			class = "provider_rate_limit"
		}
		return &Disposition{Scope: "provider", FailureClass: class, Cooldown: f.transientCooldown(providerErr), Status: status}
	case modelRecoveryCodes[code]:
		return &Disposition{Scope: "model", FailureClass: "model_transient", Cooldown: f.transientCooldown(providerErr), Status: status}
	}
	return nil
}

// IsPermanentModelFailure: the model itself is not offered to this account.
func (f *Failures) IsPermanentModelFailure(err error) bool {
	d := f.Disposition(err, "")
	return d != nil && d.FailureClass == "model_unavailable"
}

// IsRecoverableModelFailure: a failure that passes, so another model can carry
// the run meanwhile.
func (f *Failures) IsRecoverableModelFailure(err error) bool {
	d := f.Disposition(err, "")
	return d != nil && d.FailureClass != "model_unavailable"
}

// ShouldSwitchModel: the failure is a reason to move to another model.
func (f *Failures) ShouldSwitchModel(err error) bool { return f.Disposition(err, "") != nil }

// RecordFailure puts the model (or its provider, or its paid models) into
// cooldown when the failure calls for it, and reports whether it did.
func (f *Failures) RecordFailure(ctx context.Context, userID int64, agentID, selectionID string, err error) bool {
	selected := strings.TrimSpace(selectionID)
	providerID := providerFromSelectionID(selected)
	d := f.Disposition(err, providerID)
	if selected == "" || d == nil {
		return false
	}
	healthModelID := selected
	switch d.Scope {
	case "provider":
		healthModelID = providerHealthSentinel
	case "paid":
		healthModelID = paidModelsSentinel
	}
	scope := "provider"
	if d.Scope == "model" {
		scope = "model"
	}
	entry := HealthEntry{
		UserID: userID, AgentID: scopedAgentID(agentID), ProviderID: providerID, ModelSelectionID: healthModelID,
		Scope: scope, FailureClass: d.FailureClass, Status: d.Status, ExpiresAtMs: f.now().Add(d.Cooldown).UnixMilli(),
	}
	f.mu.Lock()
	if f.failures == nil {
		f.failures = map[string]HealthEntry{}
	}
	f.failures[cacheKey(userID, agentID, providerID, healthModelID)] = entry
	f.mu.Unlock()
	if f.Store != nil {
		f.Store.Save(ctx, entry)
	}
	if f.Log != nil {
		message := err.Error()
		if len(message) > 200 {
			message = message[:200]
		}
		f.Log.Warn("model cooling down", "target", describeHealthEntry(entry.Scope, providerID, healthModelID), "class", d.FailureClass,
			"status", d.Status, "until", time.UnixMilli(entry.ExpiresAtMs).UTC().Format(time.RFC3339), "user", userID, "agent", entry.AgentID, "error", message)
	}
	return true
}

// RecordSuccess lifts the cooldowns of a model and its provider.
func (f *Failures) RecordSuccess(ctx context.Context, userID int64, agentID, selectionID string) bool {
	selected := strings.TrimSpace(selectionID)
	if selected == "" {
		return false
	}
	providerID := providerFromSelectionID(selected)
	removed := false
	f.mu.Lock()
	for _, id := range []string{selected, providerHealthSentinel} {
		key := cacheKey(userID, agentID, providerID, id)
		if _, ok := f.failures[key]; ok {
			delete(f.failures, key)
			removed = true
		}
	}
	f.mu.Unlock()
	if f.Store != nil && f.Store.Clear(ctx, userID, scopedAgentID(agentID), providerID, [2]string{selected, providerHealthSentinel}) {
		removed = true
	}
	return removed
}

// HealthSnapshot is what is cooling down for one account and agent.
type HealthSnapshot struct {
	ModelIDs        map[string]bool
	ProviderIDs     map[string]bool
	PaidProviderIDs map[string]bool
}

// Snapshot collects the active cooldowns.
func (f *Failures) Snapshot(ctx context.Context, userID int64, agentID string) HealthSnapshot {
	now := f.now()
	agent := scopedAgentID(agentID)
	snap := HealthSnapshot{ModelIDs: map[string]bool{}, ProviderIDs: map[string]bool{}, PaidProviderIDs: map[string]bool{}}
	add := func(scope, providerID, healthModelID string) {
		switch {
		case scope != "provider":
			snap.ModelIDs[healthModelID] = true
		case healthModelID == paidModelsSentinel:
			snap.PaidProviderIDs[providerID] = true
		default:
			snap.ProviderIDs[providerID] = true
		}
	}
	f.mu.Lock()
	for key, entry := range f.failures {
		if entry.ExpiresAtMs <= now.UnixMilli() {
			delete(f.failures, key)
			continue
		}
		if entry.UserID == userID && entry.AgentID == agent {
			add(entry.Scope, entry.ProviderID, entry.ModelSelectionID)
		}
	}
	f.mu.Unlock()
	if f.Store != nil {
		for _, row := range f.Store.ListActive(ctx, userID, agent, now.UnixMilli()) {
			add(row.FailureScope, row.ProviderID, row.ModelSelectionID)
		}
	}
	return snap
}

// IsBlocked reports whether the snapshot keeps this catalog model out of
// routing. A model with no known price counts as paid.
func (h HealthSnapshot) IsBlocked(m Model) bool {
	return h.ModelIDs[m.ID] || h.ProviderIDs[m.Provider] || (h.PaidProviderIDs[m.Provider] && m.PriceTier != "free")
}

func describeHealthEntry(scope, providerID, healthModelID string) string {
	if scope != "provider" {
		return healthModelID
	}
	if healthModelID == paidModelsSentinel {
		return "paid models of provider " + providerID
	}
	return "provider " + providerID
}

// DescribeCooldowns lists, for diagnostics, the active cooldowns that keep a
// model out of routing.
func (f *Failures) DescribeCooldowns(ctx context.Context, userID int64, agentID, selectionID string) []string {
	selected := strings.TrimSpace(selectionID)
	providerID := providerFromSelectionID(selected)
	if f.Store == nil {
		return nil
	}
	var out []string
	for _, row := range f.Store.ListActive(ctx, userID, scopedAgentID(agentID), f.now().UnixMilli()) {
		if row.ProviderID != providerID || !(row.FailureScope == "provider" || row.ModelSelectionID == selected) {
			continue
		}
		status := "n/a"
		if row.LastStatus.Valid {
			status = fmt.Sprint(row.LastStatus.Int64)
		}
		out = append(out, fmt.Sprintf("%s %s HTTP %s until %s", describeHealthEntry(row.FailureScope, providerID, row.ModelSelectionID), row.FailureClass, status,
			time.UnixMilli(row.CooldownUntilMs).UTC().Format("2006-01-02T15:04:05.000Z")))
	}
	return out
}

// IsCoolingDown reports whether a model (or its provider) is cooling down.
func (f *Failures) IsCoolingDown(ctx context.Context, userID int64, agentID, selectionID string) bool {
	selected := strings.TrimSpace(selectionID)
	if selected == "" {
		return false
	}
	snap := f.Snapshot(ctx, userID, agentID)
	return snap.ModelIDs[selected] || snap.ProviderIDs[providerFromSelectionID(selected)]
}

// Reset forgets the in-memory cooldowns.
func (f *Failures) Reset() {
	f.mu.Lock()
	defer f.mu.Unlock()
	clear(f.failures)
}
