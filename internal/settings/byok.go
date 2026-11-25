package settings

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/url"
	"os"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
)

// Bring-your-own-key credentials live in agent_settings: the keys encrypted
// under ai_provider_api_keys, the non-secret side (address, label) in
// ai_provider_configs. Callers pass the signed-in account's id, never one from
// the request.

func (s *Store) upsertAgentSetting(ctx context.Context, userID int64, agentID, key, value string) error {
	_, err := s.DB.W.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)
		ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`, userID, agentID, key, value)
	return err
}

func (s *Store) agentSettingValue(ctx context.Context, userID int64, agentID, key string) (sql.NullString, error) {
	var value sql.NullString
	err := s.DB.W.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`,
		userID, agentID, key).Scan(&value)
	if errors.Is(err, sql.ErrNoRows) {
		return sql.NullString{}, nil
	}
	return value, err
}

// providerConfigs reads an agent's provider configs; the main agent falls back
// to the account's older shared value.
func (s *Store) providerConfigs(ctx context.Context, userID int64, agentID string) (providerConfigs, error) {
	value, err := s.agentSettingValue(ctx, userID, agentID, "ai_provider_configs")
	if err != nil {
		return nil, err
	}
	if !value.Valid {
		main, err := s.Agents.IsMain(ctx, userID, agentID)
		if err != nil {
			return nil, err
		}
		if main {
			err = s.DB.W.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = 'ai_provider_configs'`, userID).Scan(&value)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return nil, err
			}
		}
	}
	return normalizeProviderConfigs(decode(s.parseStored("ai_provider_configs", value))), nil
}

// SetProviderSecret stores a user's own API key for a provider, encrypted, or
// removes it when apiKey is empty.
func (s *Store) SetProviderSecret(ctx context.Context, userID int64, agentID, providerID, apiKey string) error {
	stored, err := s.agentSettingValue(ctx, userID, agentID, "ai_provider_api_keys")
	if err != nil {
		return err
	}
	secrets := s.openSecrets(stored)
	if key := jsTrim(apiKey); key != "" {
		secrets[providerID] = key
	} else {
		delete(secrets, providerID)
	}
	sealed, err := s.Box.Seal(string(jsonText(secrets)))
	if err != nil {
		return err
	}
	return s.upsertAgentSetting(ctx, userID, agentID, "ai_provider_api_keys", sealed)
}

// openSecrets decrypts the stored key set; anything unreadable counts as empty.
func (s *Store) openSecrets(stored sql.NullString) map[string]any {
	secrets := map[string]any{}
	if !stored.Valid || stored.String == "" {
		return secrets
	}
	plain, err := s.Box.Open(stored.String)
	if err != nil {
		return secrets
	}
	var parsed map[string]any
	if json.Unmarshal([]byte(plain), &parsed) != nil || parsed == nil {
		return secrets
	}
	return parsed
}

// SetProviderConfig updates the non-secret side of a provider's credential: a
// nil field is left alone. An empty address falls back to the provider's own.
func (s *Store) SetProviderConfig(ctx context.Context, userID int64, agentID string, def providerDef, baseURL, label *string) error {
	configs, err := s.providerConfigs(ctx, userID, agentID)
	if err != nil {
		return err
	}
	entry := &configs[providerIndex(def.ID)]
	if baseURL != nil {
		entry.BaseURL = def.resolveBaseURL(jsTrim(*baseURL))
	}
	if label != nil {
		entry.Label = truncateUTF16(jsTrim(*label), maxProviderLabel)
	}
	return s.upsertAgentSetting(ctx, userID, agentID, "ai_provider_configs", string(jsonText(configs)))
}

// SetProviderConfigByID updates the non-secret config of a provider by id.
func (s *Store) SetProviderConfigByID(ctx context.Context, userID int64, agentID, providerID string, baseURL, label *string) error {
	def, ok := providerByID(providerID)
	if !ok {
		return nil
	}
	return s.SetProviderConfig(ctx, userID, agentID, def, baseURL, label)
}

// ProviderStatus describes a provider's stored configuration and credential state.
type ProviderStatus struct {
	ID              string
	Authentication  string
	SupportsAPIKey  bool
	SupportsBaseURL bool
	RequiresBaseURL bool
	DefaultBaseURL  string
	Enabled         bool
	BaseURL         string
	Label           string
	APIKey          string
	IsBYOK          bool
}

func (s *Store) readSecrets(ctx context.Context, userID int64, agentID string) map[string]any {
	stored, err := s.agentSettingValue(ctx, userID, agentID, "ai_provider_api_keys")
	if err != nil {
		return map[string]any{}
	}
	return s.openSecrets(stored)
}

// ProviderCredential returns the unsealed API key, base URL, label, and enabled flag for one provider.
func (s *Store) ProviderCredential(ctx context.Context, userID int64, agentID, providerID string) (apiKey, baseURL, label string, enabled bool, err error) {
	configs, err := s.providerConfigs(ctx, userID, agentID)
	if err != nil {
		return "", "", "", false, err
	}
	idx := providerIndex(providerID)
	if idx < 0 || idx >= len(configs) {
		return "", "", "", false, nil
	}
	secrets := s.readSecrets(ctx, userID, agentID)
	if k, ok := secrets[providerID].(string); ok {
		apiKey = k
	}
	return apiKey, configs[idx].BaseURL, configs[idx].Label, configs[idx].Enabled, nil
}

// ProviderStatuses returns all known providers with their stored configs and BYOK presence.
func (s *Store) ProviderStatuses(ctx context.Context, userID int64, agentID string) ([]ProviderStatus, error) {
	configs, err := s.providerConfigs(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	secrets := s.readSecrets(ctx, userID, agentID)
	out := make([]ProviderStatus, len(providers))
	for i, p := range providers {
		cfg := configs[i]
		key, _ := secrets[p.ID].(string)
		key = strings.TrimSpace(key)
		baseURL := strings.TrimSpace(cfg.BaseURL)
		if unsafeUserBaseURL(baseURL, p) {
			baseURL = ""
		}
		// A user's own key makes a provider theirs; a provider without an API
		// key concept (Ollama) is theirs through its own address. A stored URL
		// belongs to that user's key: the server's key never goes there.
		isByok := key != ""
		if !p.SupportsAPIKey {
			isByok = p.SupportsBaseURL && baseURL != ""
		}
		out[i] = ProviderStatus{
			ID:              p.ID,
			Authentication:  p.Authentication,
			SupportsAPIKey:  p.SupportsAPIKey,
			SupportsBaseURL: p.SupportsBaseURL,
			RequiresBaseURL: p.RequiresBaseURL,
			DefaultBaseURL:  p.DefaultBaseURL,
			Enabled:         cfg.Enabled,
			BaseURL:         baseURL,
			Label:           cfg.Label,
			APIKey:          key,
			IsBYOK:          isByok,
		}
	}
	return out, nil
}

func providerIndex(id string) int {
	for i, p := range providers {
		if p.ID == id {
			return i
		}
	}
	return -1
}

// unsafeUserBaseURL reports a stored base URL that points into a private
// network, unless it is the provider's default or the operator's own address
// (users sign in to the server's NeoRouter on the home network).
func unsafeUserBaseURL(raw string, p providerDef) bool {
	if raw == "" || raw == p.DefaultBaseURL {
		return false
	}
	if def, ok := llm.ProviderDefinitionFor(p.ID); ok && def.BaseURLEnvKey != "" {
		if operator := strings.TrimSpace(os.Getenv(def.BaseURLEnvKey)); operator != "" && raw == operator {
			return false
		}
	}
	u, err := url.Parse(raw)
	if err != nil || u.Hostname() == "" {
		return true
	}
	return cloudsec.IsPrivateHost(u.Hostname())
}
