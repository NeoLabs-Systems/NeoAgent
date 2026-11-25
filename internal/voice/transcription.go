package voice

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// credentialSource says where a provider's key comes from. A key set in the
// app's AI provider settings wins over the server environment, the same
// precedence the chat models use.
type credentialSource struct {
	aiProvider string
	env        []string
	label      string
}

var credentialSources = map[string]credentialSource{
	"openai":    {aiProvider: "openai", env: []string{"OPENAI_API_KEY"}, label: "OpenAI"},
	"gemini":    {aiProvider: "google", env: []string{"GOOGLE_AI_KEY", "GEMINI_API_KEY"}, label: "Google Gemini"},
	"deepgram":  {env: []string{"DEEPGRAM_API_KEY"}, label: "Deepgram"},
	"neorouter": {label: "NeoRouter"},
}

// maxClipBytes bounds a recorded clip read from disk, as the providers' own
// limits do for what they accept.
const maxClipBytes = 40 << 20

// Transcriber turns recorded audio into text with the account's configured
// speech-to-text provider: voice notes, dictation, the transcribe_audio tool.
// Live calls never pass through here; the live model hears the caller directly.
type Transcriber struct {
	AI       AIDirectory
	Settings SettingsReader
	client   *http.Client
}

// NewTranscriber builds a transcriber. client carries every provider request,
// so it should refuse internal addresses (a provider base URL is user input).
func NewTranscriber(ai AIDirectory, settings SettingsReader, client *http.Client) *Transcriber {
	return &Transcriber{AI: ai, Settings: settings, client: client}
}

func (t *Transcriber) requireKey(label string, names []string, override string) (string, error) {
	if key := strings.TrimSpace(override); key != "" {
		return key, nil
	}
	if key := strings.TrimSpace(t.AI.ResolveAPIKey(names)); key != "" {
		return key, nil
	}
	return "", fmt.Errorf("%s is selected but %s is not configured.", label, names[0])
}

func (t *Transcriber) credentials(userID int64, agentID, provider string) Credentials {
	if provider == "neorouter" {
		router, _ := t.AI.NeoRouterFor(userID, agentID, "transcription")
		return Credentials{APIKey: router.APIKey, BaseURL: router.APIBase}
	}
	source := credentialSources[provider]
	var runtime Credentials
	if source.aiProvider != "" {
		runtime = t.AI.ProviderCredentials(userID, source.aiProvider, agentID)
	}
	key := strings.TrimSpace(runtime.APIKey)
	if key == "" {
		key = strings.TrimSpace(t.AI.ResolveAPIKey(source.env))
	}
	return Credentials{APIKey: key, BaseURL: strings.TrimSpace(runtime.BaseURL)}
}

// ErrNoSTTKey means no speech-to-text provider has an API key.
var ErrNoSTTKey = errors.New("No speech-to-text provider has an API key. Add an OpenAI, Google Gemini or Deepgram key, or choose a provider under Settings → Voice.")

func (t *Transcriber) resolveTarget(userID int64, agentID string, settings RuntimeSettings) (sttTarget, error) {
	// On automatic, a NeoRouter that handles transcription picks the model; it
	// speaks OpenAI's transcription API.
	if settings.STTProvider == AutoSTTProvider {
		if router, ok := t.AI.NeoRouterFor(userID, agentID, "transcription"); ok {
			return sttTarget{Provider: "openai", Model: "auto", APIKey: router.APIKey, BaseURL: router.APIBase}, nil
		}
	}
	if settings.STTProvider != AutoSTTProvider {
		c := t.credentials(userID, agentID, settings.STTProvider)
		return sttTarget{Provider: settings.STTProvider, Model: settings.STTModel, APIKey: c.APIKey, BaseURL: c.BaseURL}, nil
	}
	for _, provider := range STTProviders {
		if c := t.credentials(userID, agentID, provider); c.APIKey != "" {
			return sttTarget{Provider: provider, APIKey: c.APIKey, BaseURL: c.BaseURL}, nil
		}
	}
	return sttTarget{}, ErrNoSTTKey
}

// STTProviderInfo is one provider as Settings → Voice lists it.
type STTProviderInfo struct {
	ID           string           `json:"id"`
	Label        string           `json:"label"`
	DefaultModel string           `json:"defaultModel"`
	Available    bool             `json:"available"`
	Models       *[]STTModelEntry `json:"models,omitempty"`
}

// STTModelEntry is a model a NeoRouter offers for transcription.
type STTModelEntry struct {
	ID    string `json:"id"`
	Label string `json:"label"`
}

// STTCapabilities is what Settings → Voice offers for transcription: each
// provider and whether it has a key, whether automatic goes through a
// NeoRouter, and that router's models.
type STTCapabilities struct {
	NeoRouter bool              `json:"neorouter"`
	Providers []STTProviderInfo `json:"providers"`
}

// Describe lists the transcription providers for an agent.
func (t *Transcriber) Describe(ctx context.Context, userID int64, agentID string) STTCapabilities {
	router, hasRouter := t.AI.NeoRouterFor(userID, agentID, "transcription")
	models := []STTModelEntry{}
	if hasRouter {
		listed, err := t.AI.NeoRouterModels(ctx, router, "transcription")
		if err == nil {
			for _, m := range listed {
				if m.ID == "auto" || !strings.HasPrefix(m.ID, "auto") {
					label := m.Name
					if label == "" {
						label = m.ID
					}
					models = append(models, STTModelEntry{ID: m.ID, Label: label})
				}
			}
		}
	}
	out := STTCapabilities{NeoRouter: hasRouter}
	for _, id := range STTProviders {
		info := STTProviderInfo{
			ID: id, Label: credentialSources[id].label, DefaultModel: DefaultSTTModels[id],
			Available: t.credentials(userID, agentID, id).APIKey != "",
		}
		if id == "neorouter" {
			info.Models = &models
		}
		out.Providers = append(out.Providers, info)
	}
	return out
}

// Clip is a recorded clip to transcribe.
type Clip struct {
	Audio    []byte
	FileName string
	MimeType string
}

// TranscribeClip transcribes audio with the account's configured provider.
func (t *Transcriber) TranscribeClip(ctx context.Context, userID int64, agentID string, clip Clip, timeout time.Duration) (string, error) {
	settings, err := t.Settings.Read(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	resolved, err := t.Settings.Agents.Resolve(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	target, err := t.resolveTarget(userID, resolved, settings)
	if err != nil {
		return "", err
	}
	text, err := t.transcribe(ctx, target, sttRequest{Audio: clip.Audio, FileName: clip.FileName, MimeType: clip.MimeType}, timeout)
	return strings.TrimSpace(text), err
}

// TranscribeFile transcribes a recorded file (a voice note kept on disk).
func (t *Transcriber) TranscribeFile(ctx context.Context, userID int64, agentID, path, mimeType string, timeout time.Duration) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	audio, err := io.ReadAll(io.LimitReader(f, maxClipBytes+1))
	if err != nil {
		return "", err
	}
	if len(audio) > maxClipBytes {
		return "", errors.New("Audio file is too large to transcribe.")
	}
	return t.TranscribeClip(ctx, userID, agentID, Clip{Audio: audio, FileName: filepath.Base(path), MimeType: mimeType}, timeout)
}
