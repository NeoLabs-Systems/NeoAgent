// Package settings serves NeoAgent's /api/settings routes and keeps the
// user_settings and agent_settings tables behind them. It reads and writes the
// same rows and JSON shapes as the Node server's routes/settings.js and
// services/settings/store.js.
package settings

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log/slog"
	"reflect"
	"sort"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/timezone"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// Hooks are the other domains that react to a settings change. Each is
// optional and stays unset until its domain is ported.
type Hooks struct {
	// PromptChanged drops the cached system prompt after the persona notes or
	// the time zone changed.
	PromptChanged func(userID int64, agentID string)
	// RescheduleTasks re-plans recurring tasks after a time zone change.
	RescheduleTasks func(userID int64) error
	// VoiceCapabilities is the voice section of GET /api/settings. Nil answers
	// null, as a server without a voice runtime did.
	VoiceCapabilities func(ctx context.Context, userID int64, agentID string) (any, error)
}

// Store reads and writes settings rows.
type Store struct {
	DB     *dbx.DB
	Agents agentscope.Resolver
	Box    *secretbox.Box
	// RuntimeBackend is where computers run (qemu, docker or host); see
	// RuntimeBackendFor.
	RuntimeBackend string
	Hooks          Hooks
	Log            *slog.Logger
}

// RuntimeBackendFor maps the TERMINAL_ENV value to the runtime_backend setting.
func RuntimeBackendFor(terminalEnv string) string {
	switch strings.ToLower(strings.TrimSpace(terminalEnv)) {
	case "docker", "container", "containers":
		return "docker"
	case "host", "local", "server":
		return "host"
	}
	return "qemu"
}

// runtimeSettings are fixed by the deployment, not chosen per account.
func (s *Store) runtimeSettings() map[string]string {
	return map[string]string{
		"runtime_profile":  "cloud-computer",
		"runtime_backend":  s.RuntimeBackend,
		"computer_backend": "cloud",
		"android_backend":  "host",
		"mcp_backend":      "host-remote",
	}
}

// ValidationError is a patch the settings refuse.
type ValidationError struct{ Message string }

func (e *ValidationError) Error() string { return e.Message }

var nullJSON = json.RawMessage("null")

type row struct {
	Key   string
	Value sql.NullString
}

func (s *Store) rows(ctx context.Context, query string, args ...any) ([]row, error) {
	res, err := s.DB.R.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer res.Close()
	var out []row
	for res.Next() {
		var r row
		if err := res.Scan(&r.Key, &r.Value); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, res.Err()
}

// parseStored is parseStoredValue: a stored value is JSON when it parses and
// plain text otherwise.
func (s *Store) parseStored(key string, value sql.NullString) json.RawMessage {
	switch {
	case !value.Valid:
		return nullJSON
	case json.Valid([]byte(value.String)):
		return json.RawMessage(value.String)
	}
	if t := strings.TrimSpace(value.String); strings.HasPrefix(t, "{") || strings.HasPrefix(t, "[") {
		s.Log.Warn("settings value is not valid JSON, treating as text", "key", key)
	}
	return jsonText(value.String)
}

// storedValue is what clients are shown: the parsed value, except that cookie
// secrets only say whether they are set.
func (s *Store) storedValue(key string, value sql.NullString) json.RawMessage {
	parsed := s.parseStored(key, value)
	if isProtectedSecret(key) {
		return jsonText(map[string]any{"configured": truthy(decode(parsed)), "redacted": true})
	}
	return parsed
}

// ReadValue is GET /api/settings/{key}: the stored value, null when unset.
func (s *Store) ReadValue(ctx context.Context, userID int64, agentID, key string) (json.RawMessage, error) {
	if retiredKeys[key] || hiddenKeys[key] {
		return nullJSON, nil
	}
	userQuery := `SELECT key, value FROM user_settings WHERE user_id = ? AND key = ?`
	var found []row
	var err error
	if isAgentScoped(key) {
		found, err = s.rows(ctx, `SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`, userID, agentID, key)
		if err == nil && len(found) == 0 {
			var main bool
			if main, err = s.Agents.IsMain(ctx, userID, agentID); err == nil && main {
				found, err = s.rows(ctx, userQuery, userID, key)
			}
		}
	} else {
		found, err = s.rows(ctx, userQuery, userID, key)
	}
	if err != nil || len(found) == 0 {
		return nullJSON, err
	}
	return s.storedValue(key, found[0].Value), nil
}

// All is GET /api/settings: the defaults overlaid with this account's and this
// agent's rows.
func (s *Store) All(ctx context.Context, userID int64, agentID string) (map[string]json.RawMessage, error) {
	if err := s.ensureDefaults(ctx, userID, agentID); err != nil {
		return nil, err
	}
	main, err := s.Agents.IsMain(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	userRows, err := s.rows(ctx, `SELECT key, value FROM user_settings WHERE user_id = ?`, userID)
	if err != nil {
		return nil, err
	}
	agentRows, err := s.rows(ctx, `SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ?`, userID, agentID)
	if err != nil {
		return nil, err
	}

	settings := make(map[string]json.RawMessage, len(aiDefaults)+len(userRows)+len(agentRows)+8)
	for _, d := range aiDefaults {
		settings[d.Key] = json.RawMessage(d.JSON)
	}
	visible := func(key string) bool { return !retiredKeys[key] && !hiddenKeys[key] }
	for _, r := range userRows {
		if visible(r.Key) && (main || !isAgentScoped(r.Key)) {
			settings[r.Key] = s.storedValue(r.Key, r.Value)
		}
	}
	for _, r := range agentRows {
		if visible(r.Key) {
			settings[r.Key] = s.storedValue(r.Key, r.Value)
		}
	}
	settings["agentId"] = jsonText(agentID)
	settings["ai_provider_configs"] = jsonText(normalizeProviderConfigs(decode(settings["ai_provider_configs"])))

	settings["voice_capabilities"] = nullJSON
	if s.Hooks.VoiceCapabilities != nil {
		capabilities, err := s.Hooks.VoiceCapabilities(ctx, userID, agentID)
		if err != nil {
			return nil, err
		}
		if truthy(capabilities) {
			settings["voice_capabilities"] = jsonText(capabilities)
		}
	}
	for key, value := range s.runtimeSettings() {
		settings[key] = jsonText(value)
	}
	return settings, nil
}

// ensureDefaults gives an agent every AI setting it lacks: the account's older
// shared value for the main agent, the default otherwise.
func (s *Store) ensureDefaults(ctx context.Context, userID int64, agentID string) error {
	present, err := s.rows(ctx, `SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key IN (`+
		strings.TrimSuffix(strings.Repeat("?,", len(aiDefaults)), ",")+`)`, append([]any{userID, agentID}, aiKeys()...)...)
	if err != nil {
		return err
	}
	seen := map[string]bool{}
	for _, r := range present {
		seen[r.Key] = true
	}
	main, err := s.Agents.IsMain(ctx, userID, agentID)
	if err != nil {
		return err
	}
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, d := range aiDefaults {
		if seen[d.Key] {
			continue
		}
		value := d.JSON
		if main {
			var legacy sql.NullString
			err := tx.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, d.Key).Scan(&legacy)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return err
			}
			if legacy.Valid {
				value = legacy.String
			}
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)
			ON CONFLICT(user_id, agent_id, key) DO NOTHING`, userID, agentID, d.Key, value); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func aiKeys() []any {
	keys := make([]any, len(aiDefaults))
	for i, d := range aiDefaults {
		keys[i] = d.Key
	}
	return keys
}

// Patch is a settings update: top-level JSON members. A member with no bytes
// stands for a value that was not sent.
type Patch map[string]json.RawMessage

// normalize drops the keys nobody may write here and validates the rest. A
// value that cannot be accepted rejects the whole patch.
func (s *Store) normalize(patch Patch) (Patch, error) {
	out := make(Patch, len(patch))
	for key, value := range patch {
		if !retiredKeys[key] && !serverManagedKeys[key] && !isProtectedSecret(key) {
			out[key] = value
		}
	}

	if raw, ok := out["timezone"]; ok {
		name, known := timezone.Normalize(jsTrim(orEmpty(decode(raw))))
		if !known {
			return nil, &ValidationError{"Unknown time zone."}
		}
		out["timezone"] = jsonText(name)
	}
	if raw, ok := out["web_sharing_enabled"]; ok {
		if _, isBool := decode(raw).(bool); !isBool {
			return nil, &ValidationError{"web_sharing_enabled must be true or false."}
		}
	}
	if raw, ok := out["ui_language"]; ok {
		code := strings.ToLower(jsTrim(jsString(decode(raw))))
		if !uiLanguages[code] {
			return nil, &ValidationError{"Unknown language."}
		}
		out["ui_language"] = jsonText(code)
	}
	if raw, ok := out["system_one_model"]; ok {
		if selection, isString := decode(raw).(string); !isString || normalizeSystemOneModel(selection) != selection {
			return nil, &ValidationError{"Unknown SystemOne model selection."}
		}
	}
	if raw, ok := out["platform_whitelist_whatsapp"]; ok {
		whitelist := decode(raw)
		if text, isString := whitelist.(string); isString {
			if err := json.Unmarshal([]byte(text), &whitelist); err != nil {
				whitelist = []any{}
			}
		}
		out["platform_whitelist_whatsapp"] = jsonText(string(jsonText(normalizeWhatsAppWhitelist(whitelist))))
	}
	for _, key := range runtimeKeys {
		if _, ok := out[key]; ok {
			for runtimeKey, value := range s.runtimeSettings() {
				out[runtimeKey] = jsonText(value)
			}
			break
		}
	}
	return out, nil
}

var uiLanguages = setOf(
	"en", "de", "bg", "hr", "cs", "da", "nl", "et", "fi", "fr", "el", "hu", "ga", "it", "lv", "lt", "mt",
	"pl", "pt", "ro", "sk", "sl", "es", "sv",
)

// serialize is how a value is stored: text as it is, anything else as JSON.
func serialize(raw json.RawMessage) (string, bool) {
	if len(raw) == 0 {
		return "", false
	}
	if v, ok := decode(raw).(string); ok {
		return v, true
	}
	var compact bytes.Buffer
	if err := json.Compact(&compact, raw); err != nil {
		return "", false
	}
	return compact.String(), true
}

// Update validates and saves a patch for one account and agent. The settings
// API goes through here; a refused value comes back as *ValidationError.
func (s *Store) Update(ctx context.Context, userID int64, agentID string, patch Patch, source string) error {
	if err := s.ensureDefaults(ctx, userID, agentID); err != nil {
		return err
	}
	settings, err := s.normalize(patch)
	if err != nil {
		return err
	}
	keys := make([]string, 0, len(settings))
	serialized := make(map[string]string, len(settings))
	for key, raw := range settings {
		text, ok := serialize(raw)
		if !ok {
			return &ValidationError{"A value is required for " + key + "."}
		}
		keys = append(keys, key)
		serialized[key] = text
	}
	sort.Strings(keys)

	if err := s.logModelChanges(ctx, userID, agentID, settings, source); err != nil {
		return err
	}
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, key := range keys {
		switch {
		case isAgentScoped(key):
			_, err = tx.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)
				ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`, userID, agentID, key, serialized[key])
		case key != "agentId" && key != "agent_id":
			_, err = tx.ExecContext(ctx, `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
				ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`, userID, key, serialized[key])
		}
		if err != nil {
			return err
		}
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	s.sideEffects(userID, agentID, keys)
	return nil
}

// logModelChanges records who switched the default models, since a changed
// model changes cost and behavior.
func (s *Store) logModelChanges(ctx context.Context, userID int64, agentID string, settings Patch, source string) error {
	previous, err := s.rows(ctx, `SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ?
		AND key IN ('default_chat_model', 'default_subagent_model')`, userID, agentID)
	if err != nil {
		return err
	}
	for _, key := range []string{"default_chat_model", "default_subagent_model"} {
		raw, changing := settings[key]
		if !changing {
			continue
		}
		var before any
		for _, r := range previous {
			if r.Key == key {
				before = decode(s.parseStored(key, r.Value))
			}
		}
		if after := decode(raw); !reflect.DeepEqual(before, after) {
			s.Log.Info("default model changed", "user", userID, "agent", agentID, "key", key,
				"from", before, "to", after, "source", source)
		}
	}
	return nil
}

// sideEffects: the prompt clock and recurring task schedules both follow the
// persona notes and the user's time zone.
func (s *Store) sideEffects(userID int64, agentID string, changed []string) {
	has := func(key string) bool {
		for _, k := range changed {
			if k == key {
				return true
			}
		}
		return false
	}
	if (has("assistant_behavior_notes") || has("timezone")) && s.Hooks.PromptChanged != nil {
		s.Hooks.PromptChanged(userID, agentID)
	}
	if has("timezone") && s.Hooks.RescheduleTasks != nil {
		go func() {
			if err := s.Hooks.RescheduleTasks(userID); err != nil {
				s.Log.Error("rescheduling tasks after time zone change failed", "error", err)
			}
		}()
	}
}

// Delete is DELETE /api/settings/{key}.
func (s *Store) Delete(ctx context.Context, userID int64, agentID, key string) error {
	deleteAgent := func() error {
		_, err := s.DB.W.ExecContext(ctx, `DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`, userID, agentID, key)
		return err
	}
	deleteUser := func() error {
		_, err := s.DB.W.ExecContext(ctx, `DELETE FROM user_settings WHERE user_id = ? AND key = ?`, userID, key)
		return err
	}
	switch {
	case retiredKeys[key]:
		if err := deleteAgent(); err != nil {
			return err
		}
		return deleteUser()
	case isAgentScoped(key):
		if err := deleteAgent(); err != nil {
			return err
		}
	default:
		if err := deleteUser(); err != nil {
			return err
		}
	}
	s.sideEffects(userID, agentID, []string{key})
	return nil
}
