package runtime

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"path/filepath"
	"strings"
	"time"
)

// BrowserProvider drives the browser inside the user's computer through the
// guest agent's /browser endpoints. Screenshots come back as artifacts.
type BrowserProvider struct {
	client    *GuestClient
	userKey   string
	artifacts ArtifactStore
}

func (p *BrowserProvider) request(ctx context.Context, method, path string, body any) (*Object, error) {
	return p.client.Request(ctx, method, path, body, RequestOptions{Timeout: 2 * time.Minute})
}

// materialize turns a screenshot path inside the guest into an artifact.
func (p *BrowserProvider) materialize(ctx context.Context, result *Object) (*Object, error) {
	if result == nil || p.artifacts == nil || p.userKey == "" {
		return result, nil
	}
	var candidates []string
	if full := result.String("fullPath"); full != "" {
		candidates = append(candidates, full)
	}
	shot := result.String("screenshotPath")
	if strings.TrimSpace(shot) != "" {
		candidates = append(candidates, shot)
	}
	if len(candidates) == 0 {
		return result, nil
	}
	var content []byte
	for attempt := 0; attempt < 20 && len(content) == 0; attempt++ {
		for _, candidate := range candidates {
			file, err := p.client.Request(ctx, http.MethodPost, "/files/read", map[string]any{"path": candidate, "encoding": "base64"}, RequestOptions{Timeout: 10 * time.Second})
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			if err == nil {
				if content, _ = base64.StdEncoding.DecodeString(file.String("content")); len(content) > 0 {
					break
				}
			}
		}
		if len(content) == 0 {
			if err := sleepCtx(ctx, 250*time.Millisecond); err != nil {
				return nil, err
			}
		}
	}
	out := result.Clone()
	if len(content) == 0 {
		if strings.TrimSpace(shot) != "" {
			out.Set("screenshotPath", nil)
			if v, _ := out.Get("artifactId"); isNullish(v) {
				out.Set("artifactId", nil)
			}
			if v, _ := out.Get("fullPath"); isNullish(v) {
				out.Set("fullPath", nil)
			}
		}
		return out, nil
	}
	stored, err := p.artifacts.CreateBufferArtifact(ctx, p.userKey, Artifact{
		Kind: "browser-screenshot", Backend: "vm", Extension: "png", ContentType: "image/png",
		FilenameBase: "browser-screenshot", Content: content,
	})
	if err != nil {
		return nil, err
	}
	return out.Set("screenshotPath", stored.URL).Set("artifactId", stored.ID).Set("fullPath", stored.StoragePath), nil
}

// isNullish reports a missing, null or empty value (JavaScript's `|| null`).
func isNullish(v any) bool {
	switch t := v.(type) {
	case nil:
		return true
	case json.RawMessage:
		s := string(t)
		return s == "null" || s == `""` || s == "false" || s == "0"
	case string:
		return t == ""
	}
	return false
}

func (p *BrowserProvider) shot(ctx context.Context, path string, body map[string]any) (*Object, error) {
	result, err := p.request(ctx, http.MethodPost, path, body)
	if err != nil {
		return nil, err
	}
	return p.materialize(ctx, result)
}

func merge(base map[string]any, extra map[string]any) map[string]any {
	out := make(map[string]any, len(base)+len(extra))
	for k, v := range base {
		out[k] = v
	}
	for k, v := range extra {
		out[k] = v
	}
	return out
}

// Navigate opens url; options are passed through (waitFor, ...).
func (p *BrowserProvider) Navigate(ctx context.Context, url string, options map[string]any) (*Object, error) {
	return p.shot(ctx, "/browser/navigate", merge(map[string]any{"url": url}, options))
}

// Click clicks an element by selector or visible text.
func (p *BrowserProvider) Click(ctx context.Context, selector, text any, screenshot bool) (*Object, error) {
	return p.shot(ctx, "/browser/click", map[string]any{"selector": selector, "text": text, "screenshot": screenshot})
}

// ClickPoint clicks page coordinates.
func (p *BrowserProvider) ClickPoint(ctx context.Context, x, y any, screenshot bool) (*Object, error) {
	return p.shot(ctx, "/browser/click-point", map[string]any{"x": x, "y": y, "screenshot": screenshot})
}

// Fill sets the value of an input.
func (p *BrowserProvider) Fill(ctx context.Context, selector any, value string, options map[string]any) (*Object, error) {
	return p.shot(ctx, "/browser/fill", merge(map[string]any{"selector": selector, "value": value}, options))
}

// TypeText types into the focused element.
func (p *BrowserProvider) TypeText(ctx context.Context, text string, options map[string]any) (*Object, error) {
	return p.shot(ctx, "/browser/type-text", merge(map[string]any{"text": text}, options))
}

// PressKey presses a key or combination.
func (p *BrowserProvider) PressKey(ctx context.Context, key string, screenshot bool) (*Object, error) {
	return p.shot(ctx, "/browser/press-key", map[string]any{"key": key, "screenshot": screenshot})
}

// Scroll scrolls the page.
func (p *BrowserProvider) Scroll(ctx context.Context, deltaX, deltaY any, screenshot bool) (*Object, error) {
	return p.shot(ctx, "/browser/scroll", map[string]any{"deltaX": deltaX, "deltaY": deltaY, "screenshot": screenshot})
}

// Extract reads text or an attribute of matching elements.
func (p *BrowserProvider) Extract(ctx context.Context, selector, attribute any, all bool) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/extract", map[string]any{"selector": selector, "attribute": attribute, "all": all})
}

// ExtractContent reads the readable content of the page.
func (p *BrowserProvider) ExtractContent(ctx context.Context, options map[string]any) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/extract", options)
}

// Evaluate runs JavaScript in the page.
func (p *BrowserProvider) Evaluate(ctx context.Context, script string) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/execute", map[string]any{"code": script})
}

// Screenshot captures the page (options: fullPage, selector).
func (p *BrowserProvider) Screenshot(ctx context.Context, options map[string]any) (*Object, error) {
	return p.shot(ctx, "/browser/screenshot", options)
}

// ScreenshotJPEG captures the viewport as JPEG bytes.
func (p *BrowserProvider) ScreenshotJPEG(ctx context.Context, quality int, options map[string]any) ([]byte, error) {
	result, err := p.request(ctx, http.MethodPost, "/browser/screenshot-jpeg", merge(options, map[string]any{"quality": quality}))
	if err != nil {
		return nil, err
	}
	encoded := result.String("contentBase64")
	if encoded == "" {
		return nil, errors.New("VM browser screenshot-jpeg returned no data.")
	}
	return base64.StdEncoding.DecodeString(encoded)
}

// Launch starts the browser.
func (p *BrowserProvider) Launch(ctx context.Context, options map[string]any) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/launch", options)
}

// Close closes the browser.
func (p *BrowserProvider) Close(ctx context.Context) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/close", nil)
}

// FillCredential fills a login form from a stored credential.
func (p *BrowserProvider) FillCredential(ctx context.Context, input map[string]any) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/credential-fill", input)
}

// SubmitProtectedCredential submits a protected fill after approval.
func (p *BrowserProvider) SubmitProtectedCredential(ctx context.Context, id string) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/credential-submit", map[string]any{"protectedFillId": id})
}

// CancelProtectedCredential discards a protected fill.
func (p *BrowserProvider) CancelProtectedCredential(ctx context.Context, id string) (*Object, error) {
	return p.request(ctx, http.MethodPost, "/browser/credential-cancel", map[string]any{"protectedFillId": id})
}

// Status is the guest's /browser/status answer.
func (p *BrowserProvider) Status(ctx context.Context) (*Object, error) {
	return p.client.Request(ctx, http.MethodGet, "/browser/status", nil, RequestOptions{})
}

// Cookies lists the browser's cookies.
func (p *BrowserProvider) Cookies(ctx context.Context) (*Object, error) {
	return p.client.Request(ctx, http.MethodGet, "/browser/cookies", nil, RequestOptions{})
}

// DesktopProvider drives the Linux desktop of the user's computer.
type DesktopProvider struct {
	backend   *VMBackend
	userKey   string
	artifacts ArtifactStore
}

func (d *DesktopProvider) post(ctx context.Context, path string, body map[string]any) (*Object, error) {
	if d.backend == nil || d.userKey == "" {
		return nil, errors.New("Cloud computer desktop is unavailable.")
	}
	return d.backend.RequestGuest(ctx, d.userKey, http.MethodPost, path, body, RequestOptions{})
}

// Status is the computer's status with the guest's desktop state.
func (d *DesktopProvider) Status(ctx context.Context) *Object {
	status := d.backend.vm.Status(d.userKey).Clone()
	if !d.backend.vm.Tracked(d.userKey) {
		return status
	}
	desktop, err := d.backend.RequestGuest(ctx, d.userKey, http.MethodGet, "/desktop/status", nil, RequestOptions{})
	if err != nil {
		return status
	}
	return status.Set("desktop", desktop)
}

// Screenshot captures the screen into an artifact.
func (d *DesktopProvider) Screenshot(ctx context.Context) (*Object, error) {
	result, err := d.post(ctx, "/desktop/screenshot", map[string]any{})
	if err != nil {
		return nil, err
	}
	guestPath := result.String("path")
	if strings.TrimSpace(guestPath) == "" || d.artifacts == nil {
		return result, nil
	}
	file, err := d.backend.RequestGuest(ctx, d.userKey, http.MethodPost, "/files/read", map[string]any{"path": guestPath, "encoding": "base64", "delete_after_read": true},
		RequestOptions{Timeout: 30 * time.Second, MaxResponseBytes: 24 << 20, Retries: Retries(0)})
	if err != nil {
		return nil, err
	}
	content, _ := base64.StdEncoding.DecodeString(file.String("content"))
	stored, err := d.artifacts.CreateBufferArtifact(ctx, d.userKey, Artifact{
		Kind: "desktop-screenshot", Backend: "cloud-computer", Extension: "png", ContentType: "image/png",
		FilenameBase: "computer-screen", Content: content,
	})
	if err != nil {
		return nil, err
	}
	return result.Clone().Set("screenshotPath", stored.URL).Set("artifactId", stored.ID).
		Set("filename", filepath.Base(stored.StoragePath)).Set("fullPath", stored.StoragePath), nil
}

// Observe is the status and a fresh screenshot.
func (d *DesktopProvider) Observe(ctx context.Context) (*Object, error) {
	status := d.Status(ctx)
	shot, err := d.Screenshot(ctx)
	if err != nil {
		return nil, err
	}
	return status.Merge(shot), nil
}

// ClickPoint clicks screen coordinates.
func (d *DesktopProvider) ClickPoint(ctx context.Context, x, y, button any) (*Object, error) {
	return d.post(ctx, "/desktop/click", map[string]any{"x": x, "y": y, "button": button})
}

// MouseMove moves the pointer.
func (d *DesktopProvider) MouseMove(ctx context.Context, x, y any) (*Object, error) {
	return d.post(ctx, "/desktop/mouse-move", map[string]any{"x": x, "y": y})
}

// Drag drags from (x1,y1) to (x2,y2).
func (d *DesktopProvider) Drag(ctx context.Context, x1, y1, x2, y2, durationMs any) (*Object, error) {
	return d.post(ctx, "/desktop/drag", map[string]any{"startX": x1, "startY": y1, "endX": x2, "endY": y2, "durationMs": durationMs})
}

// Scroll scrolls the screen.
func (d *DesktopProvider) Scroll(ctx context.Context, deltaX, deltaY any) (*Object, error) {
	return d.post(ctx, "/desktop/scroll", map[string]any{"deltaX": deltaX, "deltaY": deltaY})
}

// TypeText types text, then Return when pressEnter is set.
func (d *DesktopProvider) TypeText(ctx context.Context, text string, pressEnter bool) (*Object, error) {
	result, err := d.post(ctx, "/desktop/type-text", map[string]any{"text": text})
	if err != nil {
		return nil, err
	}
	if pressEnter {
		if _, err := d.PressKey(ctx, "Return"); err != nil {
			return nil, err
		}
	}
	return result, nil
}

// PressKey presses a key.
func (d *DesktopProvider) PressKey(ctx context.Context, key string) (*Object, error) {
	return d.post(ctx, "/desktop/press-key", map[string]any{"key": key})
}

// LaunchApp starts a desktop application.
func (d *DesktopProvider) LaunchApp(ctx context.Context, app string) (*Object, error) {
	return d.post(ctx, "/desktop/launch-app", map[string]any{"application": app})
}

// AccessibilityTree reports the active window; the guest exposes no tree.
func (d *DesktopProvider) AccessibilityTree(ctx context.Context) (*Object, error) {
	var desktop struct {
		Available    bool `json:"available"`
		ActiveWindow any  `json:"activeWindow"`
	}
	d.Status(ctx).Decode("desktop", &desktop)
	return obj("available", desktop.Available, "activeWindow", desktop.ActiveWindow, "nodes", []any{}), nil
}
