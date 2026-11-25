package voice

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// RuntimeSettings are an agent's voice settings. Transcription (voice notes,
// dictation) and the live voice model are separate concerns that share one
// per-agent settings scope.
type RuntimeSettings struct {
	STTProvider  string
	STTModel     string
	LiveProvider string
	// LiveModel is empty for the provider's default, taken from its model list
	// when a call opens.
	LiveModel string
	LiveVoice string
	InputMode string
}

// SettingsReader reads voice settings from the same tables the settings API
// writes.
type SettingsReader struct {
	DB       *dbx.DB
	Agents   Agents
	Defaults Defaults
}

// Read returns the voice settings of an agent. agentID may be a candidate; it
// is resolved to one of the account's agents first.
func (r SettingsReader) Read(ctx context.Context, userID int64, agentID string) (RuntimeSettings, error) {
	scoped, err := r.Agents.Resolve(ctx, userID, agentID)
	if err != nil {
		return RuntimeSettings{}, err
	}
	main, err := r.Agents.IsMain(ctx, userID, scoped)
	if err != nil {
		return RuntimeSettings{}, err
	}
	var failure error
	read := func(key string) string {
		value, err := r.scoped(ctx, userID, scoped, main, key)
		if err != nil && failure == nil {
			failure = err
		}
		return jsString(value)
	}
	sttProvider := NormalizeSTTProvider(read("voice_stt_provider"))
	sttModel := ResolveSTTModel(sttProvider, read("voice_stt_model"))
	liveProvider := r.Defaults.NormalizeProvider(read("voice_live_provider"))
	settings := RuntimeSettings{
		STTProvider:  sttProvider,
		STTModel:     sttModel,
		LiveProvider: liveProvider,
		LiveModel:    r.Defaults.ConfiguredModel(liveProvider, read("voice_live_model")),
		LiveVoice:    r.Defaults.ResolveVoice(liveProvider, read("voice_live_voice")),
		InputMode:    NormalizeInputMode(read("voice_input_mode")),
	}
	return settings, failure
}

// scoped is readScopedSetting: the agent's own row, then, for the main agent
// only, the account-wide one.
func (r SettingsReader) scoped(ctx context.Context, userID int64, agentID string, main bool, key string) (any, error) {
	var raw sql.NullString
	err := r.DB.R.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`,
		userID, agentID, key).Scan(&raw)
	switch {
	case err == nil:
		return parseSettingValue(raw), nil
	case !errors.Is(err, sql.ErrNoRows):
		return nil, err
	case !main:
		return "", nil
	}
	err = r.DB.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, key).Scan(&raw)
	switch {
	case err == nil:
		return parseSettingValue(raw), nil
	case errors.Is(err, sql.ErrNoRows):
		return "", nil
	}
	return nil, err
}

// parseSettingValue: a stored value is JSON; one that is not is the plain text.
func parseSettingValue(raw sql.NullString) any {
	if !raw.Valid {
		return ""
	}
	var v any
	if err := json.Unmarshal([]byte(raw.String), &v); err != nil {
		return raw.String
	}
	return v
}

// jsString is String(value || ”): a falsy value is empty and numbers print
// the way JavaScript prints them.
func jsString(value any) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		if v {
			return "true"
		}
		return ""
	case float64:
		if v == 0 {
			return ""
		}
		return strconv.FormatFloat(v, 'f', -1, 64)
	case []any:
		parts := make([]string, len(v))
		for i, item := range v {
			if item != nil {
				parts[i] = jsString(item)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}
