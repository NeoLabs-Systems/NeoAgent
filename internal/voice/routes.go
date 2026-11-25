package voice

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/audiox"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	// bodyLimit is the JSON body limit of the whole API (Express: 10mb).
	bodyLimit = 10 << 20
	// maxTranscribeBytes is the audio a dictation request may carry.
	maxTranscribeBytes = 25 * 1024 * 1024
	transcribeTimeout  = 30 * time.Second
)

// RoutesConfig wires the /api/voice-assistant routes.
type RoutesConfig struct {
	Manager *Manager
	Log     *slog.Logger
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
	// AgentCandidate is the agent a request names in its query or headers
	// (agentscope.Candidate); nil means none.
	AgentCandidate func(*http.Request) string
	// Sanitize hides paths in errors shown to the client (publicerr.Sanitize).
	Sanitize func(string) string
}

// API serves the /api/voice-assistant routes.
type API struct {
	cfg RoutesConfig
}

// NewAPI builds the routes.
func NewAPI(cfg RoutesConfig) *API {
	if cfg.UserID == nil {
		cfg.UserID = sessionUserID
	}
	if cfg.AgentCandidate == nil {
		cfg.AgentCandidate = func(*http.Request) string { return "" }
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	return &API{cfg: cfg}
}

func sessionUserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

// Routes registers the voice assistant routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/voice-assistant/capabilities", a.capabilities)
	mux.HandleFunc("POST /api/voice-assistant/transcribe", a.transcribe)
}

func (a *API) capabilities(w http.ResponseWriter, r *http.Request) {
	userID, ok := a.cfg.UserID(r)
	if !ok {
		httpx.Error(w, 401, "Unauthorized")
		return
	}
	agentID, err := a.cfg.Manager.cfg.Agents.Resolve(r.Context(), userID, a.cfg.AgentCandidate(r))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, a.cfg.Manager.GetCapabilities(r.Context(), userID, agentID))
}

func (a *API) transcribe(w http.ResponseWriter, r *http.Request) {
	userID, ok := a.cfg.UserID(r)
	if !ok {
		httpx.Error(w, 401, "Unauthorized")
		return
	}
	body, err := readJSONObject(r)
	if err != nil {
		httpx.Error(w, 400, err.Error())
		return
	}
	audioBase64 := livevoice.TrimJS(jsString(body["audioBase64"]))
	mimeType := livevoice.TrimJS(jsString(body["mimeType"]))
	if mimeType == "" {
		mimeType = audiox.DefaultMime
	}
	if audioBase64 == "" {
		httpx.Error(w, 400, "audioBase64 is required.")
		return
	}
	if len(audioBase64)*3/4 > maxTranscribeBytes {
		httpx.Error(w, 400, "Audio exceeds maximum size of 25MB.")
		return
	}
	clip := audioClip(audiox.DecodeBase64(audioBase64), mimeType)
	transcript, err := a.cfg.Manager.Transcriber().TranscribeClip(r.Context(), userID, jsString(body["agentId"]), clip, transcribeTimeout)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"transcript": transcript})
}

// audioClip prepares dictated audio for a provider: raw PCM is wrapped as a
// WAV, anything else goes as sent under its own type.
func audioClip(audio []byte, mimeType string) Clip {
	var suffix [16]byte
	_, _ = rand.Read(suffix[:])
	name := "neoagent-voice-" + hex.EncodeToString(suffix[:])
	if format, isPCM := audiox.ParsePCMMime(mimeType); isPCM {
		return Clip{Audio: audiox.WrapWAV(audio, format), FileName: name + ".wav", MimeType: "audio/wav"}
	}
	return Clip{Audio: audio, FileName: name + "." + audiox.FileExtension(mimeType), MimeType: audiox.NormalizeMime(mimeType, "")}
}

func (a *API) fail(w http.ResponseWriter, err error) {
	message := err.Error()
	if a.cfg.Sanitize != nil {
		message = a.cfg.Sanitize(message)
	}
	httpx.WriteJSON(w, 500, map[string]any{"error": message})
}

// readJSONObject reads the JSON object a request carries; a request without a
// JSON body, or with a list, has no members.
func readJSONObject(r *http.Request) (map[string]any, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return map[string]any{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, errors.New("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] == '[' {
		return map[string]any{}, nil
	}
	var body map[string]any
	if err := json.Unmarshal(raw, &body); err != nil || body == nil {
		return nil, errors.New("Invalid JSON body")
	}
	return body, nil
}
