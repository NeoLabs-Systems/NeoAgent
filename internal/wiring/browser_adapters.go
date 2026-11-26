package wiring

import (
	"context"
	"strconv"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/credentials"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
)

const videoTranscriptionTimeout = 5 * time.Minute

// credentialBrowsers lets the credential broker fill forms in a user's browser
// without the model reading the values.
type credentialBrowsers struct{ m *runtime.Manager }

func (c credentialBrowsers) BrowserForUser(ctx context.Context, userID int64) (credentials.Browser, error) {
	b, err := c.m.Browser(ctx, strconv.FormatInt(userID, 10), "")
	if err != nil {
		return nil, err
	}
	return credentialBrowser{b}, nil
}

type credentialBrowser struct{ b runtime.Browser }

func (c credentialBrowser) PageURL(ctx context.Context) (string, error) {
	status, err := c.b.Status(ctx)
	if err != nil {
		return "", err
	}
	var page struct {
		URL string `json:"url"`
	}
	status.Decode("pageInfo", &page)
	return page.URL, nil
}

func (c credentialBrowser) FillCredential(ctx context.Context, req credentials.FillRequest) (string, error) {
	result, err := c.b.FillCredential(ctx, map[string]any{
		"usernameSelector": req.UsernameSelector, "passwordSelector": req.PasswordSelector,
		"username": req.Username, "password": req.Password, "allowedOrigin": req.AllowedOrigin,
	})
	if err != nil {
		return "", err
	}
	return result.String("protectedFillId"), nil
}

func (c credentialBrowser) SubmitProtected(ctx context.Context, fillID string) (map[string]any, error) {
	return guestMap(c.b.SubmitProtectedCredential(ctx, fillID))
}

func (c credentialBrowser) CancelProtected(ctx context.Context, fillID string) (map[string]any, error) {
	return guestMap(c.b.CancelProtectedCredential(ctx, fillID))
}

// videoTranscriber turns a video's audio into text with the account's
// transcription provider.
type videoTranscriber struct{ voice *voice.Manager }

func (v videoTranscriber) Transcribe(ctx context.Context, audioPath string, userID int64, agentID, mimeType string) (string, error) {
	return v.voice.Transcriber().TranscribeFile(ctx, userID, agentID, audioPath, mimeType, videoTranscriptionTimeout)
}
