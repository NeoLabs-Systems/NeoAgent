package voice

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"net/url"
	"path/filepath"
	"strings"
	"time"
)

const (
	// maxProviderResponse bounds what a provider may answer.
	maxProviderResponse = 40 << 20
	defaultSTTTimeout   = 60 * time.Second
)

// ErrSTTTimeout marks a transcription that ran out of time (VOICE_STT_TIMEOUT).
var ErrSTTTimeout = errors.New("VOICE_STT_TIMEOUT")

type sttTimeout struct{ message string }

func (e sttTimeout) Error() string        { return e.message }
func (e sttTimeout) Is(target error) bool { return target == ErrSTTTimeout }

// sttTarget is a resolved provider with its credentials.
type sttTarget struct {
	Provider string
	Model    string
	APIKey   string
	BaseURL  string
}

// sttRequest is one recorded clip to transcribe.
type sttRequest struct {
	Audio    []byte
	FileName string
	MimeType string
}

// transcribe runs one provider with a timeout, as transcribeVoiceInput did.
// NeoRouter speaks OpenAI's transcription API.
func (t *Transcriber) transcribe(ctx context.Context, target sttTarget, req sttRequest, timeout time.Duration) (string, error) {
	provider := NormalizeSTTProvider(target.Provider)
	if provider == AutoSTTProvider {
		return "", fmt.Errorf("Unknown speech-to-text provider: %s", target.Provider)
	}
	model := ResolveSTTModel(provider, target.Model)
	if timeout <= 0 {
		timeout = defaultSTTTimeout
	}
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	var text string
	var err error
	switch provider {
	case "openai", "neorouter":
		text, err = t.openAI(ctx, target, model, req)
	case "deepgram":
		text, err = t.deepgram(ctx, target, model, req)
	case "gemini":
		text, err = t.gemini(ctx, target, model, req)
	}
	if err != nil && errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return "", sttTimeout{fmt.Sprintf("%s STT timed out after %dms.", provider, timeout.Milliseconds())}
	}
	return text, err
}

func (t *Transcriber) openAI(ctx context.Context, target sttTarget, model string, req sttRequest) (string, error) {
	key, err := t.requireKey("OpenAI transcription", []string{"OPENAI_API_KEY"}, target.APIKey)
	if err != nil {
		return "", err
	}
	base := strings.TrimRight(strings.TrimSpace(target.BaseURL), "/")
	if base == "" {
		base = "https://api.openai.com/v1"
	}
	var body bytes.Buffer
	form := multipart.NewWriter(&body)
	header := textproto.MIMEHeader{}
	header.Set("Content-Disposition", fmt.Sprintf(`form-data; name="file"; filename=%q`, req.FileName))
	header.Set("Content-Type", contentTypeFor(req.FileName))
	part, err := form.CreatePart(header)
	if err != nil {
		return "", err
	}
	_, _ = part.Write(req.Audio)
	_ = form.WriteField("model", model)
	if err := form.Close(); err != nil {
		return "", err
	}
	payload, err := t.call(ctx, http.MethodPost, base+"/audio/transcriptions", http.Header{
		"Authorization": {"Bearer " + key},
		"Content-Type":  {form.FormDataContentType()},
	}, body.Bytes(), "OpenAI STT failed")
	if err != nil {
		return "", err
	}
	var result struct{ Text string }
	_ = json.Unmarshal(payload, &result)
	return strings.TrimSpace(result.Text), nil
}

func (t *Transcriber) deepgram(ctx context.Context, target sttTarget, model string, req sttRequest) (string, error) {
	key, err := t.requireKey("Deepgram transcription", []string{"DEEPGRAM_API_KEY"}, target.APIKey)
	if err != nil {
		return "", err
	}
	query := url.Values{"model": {model}, "language": {"multi"}, "punctuate": {"true"}, "smart_format": {"true"}}
	contentType := req.MimeType
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	payload, err := t.call(ctx, http.MethodPost, "https://api.deepgram.com/v1/listen?"+query.Encode(), http.Header{
		"Authorization": {"Token " + key},
		"Content-Type":  {contentType},
	}, req.Audio, "Deepgram STT failed")
	if err != nil {
		return "", err
	}
	var result struct {
		Results struct {
			Channels []struct {
				Alternatives []struct{ Transcript string }
			}
		}
	}
	if err := json.Unmarshal(payload, &result); err != nil {
		return "", err
	}
	if len(result.Results.Channels) == 0 || len(result.Results.Channels[0].Alternatives) == 0 {
		return "", nil
	}
	return strings.TrimSpace(result.Results.Channels[0].Alternatives[0].Transcript), nil
}

func (t *Transcriber) gemini(ctx context.Context, target sttTarget, model string, req sttRequest) (string, error) {
	key, err := t.requireKey("Gemini transcription", []string{"GOOGLE_AI_KEY", "GEMINI_API_KEY"}, target.APIKey)
	if err != nil {
		return "", err
	}
	mime := req.MimeType
	if mime == "" {
		mime = "audio/mpeg"
	}
	body, err := json.Marshal(map[string]any{
		"contents": []any{map[string]any{"parts": []any{
			map[string]any{"text": "Transcribe this audio verbatim. Return only the transcript text."},
			map[string]any{"inlineData": map[string]any{"mimeType": mime, "data": base64.StdEncoding.EncodeToString(req.Audio)}},
		}}},
		"generationConfig": map[string]any{"temperature": 0},
	})
	if err != nil {
		return "", err
	}
	payload, err := t.call(ctx, http.MethodPost,
		"https://generativelanguage.googleapis.com/v1beta/models/"+url.PathEscape(model)+":generateContent",
		http.Header{"Content-Type": {"application/json"}, "x-goog-api-key": {key}}, body, "Gemini STT failed")
	if err != nil {
		return "", err
	}
	var result struct {
		Candidates []struct {
			Content struct{ Parts []struct{ Text string } }
		}
	}
	if err := json.Unmarshal(payload, &result); err != nil {
		return "", err
	}
	if len(result.Candidates) == 0 {
		return "", nil
	}
	var parts []string
	for _, p := range result.Candidates[0].Content.Parts {
		parts = append(parts, p.Text)
	}
	return strings.TrimSpace(strings.Join(parts, "\n")), nil
}

// call sends one provider request and returns its bounded body. A failure
// carries the provider's own words, trimmed.
func (t *Transcriber) call(ctx context.Context, method, target string, header http.Header, body []byte, label string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, method, target, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header = header
	resp, err := t.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		text, _ := io.ReadAll(io.LimitReader(resp.Body, 2000))
		message := string(text)
		if message == "" {
			message = "empty response"
		}
		return nil, fmt.Errorf("%s (%d): %s", label, resp.StatusCode, message)
	}
	payload, err := io.ReadAll(io.LimitReader(resp.Body, maxProviderResponse+1))
	if err != nil {
		return nil, err
	}
	if len(payload) > maxProviderResponse {
		return nil, errors.New("Voice provider response exceeded its safety limit.")
	}
	return payload, nil
}

func contentTypeFor(fileName string) string {
	switch strings.ToLower(filepath.Ext(fileName)) {
	case ".mp3":
		return "audio/mpeg"
	case ".webm":
		return "audio/webm"
	case ".ogg":
		return "audio/ogg"
	case ".m4a":
		return "audio/mp4"
	}
	return "audio/wav"
}
