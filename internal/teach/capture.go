package teach

import (
	"context"
	"fmt"
	"math"
	"strconv"
	"time"
)

// Scripts run in the user's browser. They are the ones Node sent, unchanged.
const sensitiveInputScript = `(() => Array.from(document.querySelectorAll('input,textarea,[contenteditable="true"]')).some((element) => {
        const style = getComputedStyle(element);
        const visible = style.display !== 'none' && style.visibility !== 'hidden' && element.getClientRects().length > 0;
        const type = String(element.getAttribute('type') || '').toLowerCase();
        const autocomplete = String(element.getAttribute('autocomplete') || '').toLowerCase();
        return visible && (type === 'password' || autocomplete === 'current-password' || autocomplete === 'new-password');
      }))()`

const interactiveElementsScript = `(() => Array.from(document.querySelectorAll('a,button,input,select,textarea,[role],[contenteditable="true"]')).filter((element) => {
          const style = getComputedStyle(element);
          return style.display !== 'none' && style.visibility !== 'hidden' && element.getClientRects().length > 0;
        }).slice(0, 300).map((element) => ({
          tag: element.tagName.toLowerCase(),
          role: element.getAttribute('role'),
          name: element.getAttribute('aria-label') || element.getAttribute('title') || element.getAttribute('placeholder') || String(element.innerText || '').trim().slice(0, 200),
          inputType: element.tagName === 'INPUT' ? String(element.getAttribute('type') || 'text').toLowerCase() : null,
          disabled: Boolean(element.disabled),
        })))()`

type changedFile struct {
	Path       string  `json:"path"`
	Size       float64 `json:"size"`
	ModifiedAt any     `json:"modifiedAt"`
}

type deletedFile struct {
	Path    string `json:"path"`
	Deleted bool   `json:"deleted"`
}

func (s *Service) request(ctx context.Context, sess *session, method, path string, body any, timeout time.Duration, maxBytes int64) (map[string]any, error) {
	return s.cfg.Runtime.RequestComputer(ctx, sess.userKey, method, path, body, RequestOptions{Timeout: timeout, MaxResponseBytes: maxBytes})
}

// captureScreenshot returns a base64 PNG of the desktop, or "" when none is
// taken: a password field is on screen (a screenshot could show the typed
// secret), there is no file, or the frame is too large.
func (s *Service) captureScreenshot(ctx context.Context, sess *session) (string, error) {
	if guest, err := s.request(ctx, sess, "GET", "/teach/context", nil, 10*time.Second, 0); err == nil && guest != nil && guest["sensitiveInputActive"] == true {
		return "", nil
	}
	if browser, err := s.cfg.Runtime.Browser(ctx, sess.userKey); err == nil {
		if sensitive, err := browser.Evaluate(ctx, sensitiveInputScript); err == nil && ParseEvaluationResult(sensitive) == true {
			return "", nil
		}
	}
	result, err := s.request(ctx, sess, "POST", "/desktop/screenshot", map[string]any{}, 30*time.Second, 0)
	if err != nil {
		return "", err
	}
	guestPath := normalizeTrim(result["path"])
	if guestPath == "" {
		return "", nil
	}
	file, err := s.request(ctx, sess, "POST", "/files/read",
		map[string]any{"path": guestPath, "encoding": "base64", "delete_after_read": true}, 30*time.Second, 8*1024*1024)
	if err != nil {
		return "", err
	}
	content, _ := file["content"].(string)
	if len(content) > maxFrameChars {
		return "", nil
	}
	return content, nil
}

func normalizeTrim(v any) string { return normalize(v, 1<<30) }

func list(v any) []any {
	l, _ := v.([]any)
	return l
}

// rawContext is what the computer and browser reported before it is trimmed.
type rawContext struct {
	ActiveWindow  *string
	Accessibility []any
	ShellEvents   []any
	Files         []any
	Browser       *BrowserContext
}

// captureContext reads the guest's semantic state and the browser page. Parts
// that cannot be read stay empty.
func (s *Service) captureContext(ctx context.Context, sess *session) rawContext {
	out := rawContext{Accessibility: []any{}, ShellEvents: []any{}, Files: []any{}}
	if status, err := s.request(ctx, sess, "GET", "/teach/context", nil, 10*time.Second, 0); err == nil && status != nil {
		if w := normalize(status["activeWindow"], 300); w != "" {
			out.ActiveWindow = &w
		}
		if a := list(status["accessibility"]); a != nil {
			out.Accessibility = a[:min(len(a), 300)]
		}
		if e := list(status["shellEvents"]); e != nil {
			out.ShellEvents = e[max(0, len(e)-50):]
		}
		if f := list(status["files"]); f != nil {
			out.Files = f[:min(len(f), 500)]
		}
	}
	browser, err := s.cfg.Runtime.Browser(ctx, sess.userKey)
	if err != nil {
		return out
	}
	pageInfo, err := browser.PageInfo(ctx)
	if err != nil {
		return out
	}
	extracted, err := browser.ExtractContent(ctx, 12000)
	if err != nil {
		return out
	}
	dom, err := browser.Evaluate(ctx, interactiveElementsScript)
	if err != nil {
		return out
	}
	var text any
	for _, key := range []string{"text", "content", "result"} {
		if v := extracted[key]; v != nil && v != "" {
			text = v
			break
		}
	}
	elements := []any{}
	if parsed, ok := ParseEvaluationResult(dom).([]any); ok {
		elements = parsed[:min(len(parsed), 300)]
	}
	out.Browser = &BrowserContext{PageInfo: pageInfo, Content: normalize(text, 12000), Elements: elements}
	return out
}

func jsNumber(v any) float64 {
	switch x := v.(type) {
	case float64:
		if math.IsNaN(x) {
			return 0
		}
		return x
	case bool:
		if x {
			return 1
		}
	}
	return 0
}

// compact trims a raw context to what is stored with an event, reporting only
// what changed since the previous event: files whose size or time moved (or
// vanished) and shell events newer than the last one seen. The session lock
// must be held.
func (s *Service) compact(sess *session, raw rawContext, initialize bool) *Context {
	files := []any{}
	next := map[string]string{}
	for _, item := range raw.Files {
		m, _ := item.(map[string]any)
		key := normalize(m["path"], 500)
		if key == "" {
			continue
		}
		signature := fmt.Sprintf("%s:%s", numberText(jsNumber(m["size"])), normalize(m["modifiedAt"], 64))
		next[key] = signature
		if !initialize && sess.lastFileState[key] != signature {
			var modified any
			if v := m["modifiedAt"]; v != nil && v != "" {
				modified = v
			}
			files = append(files, changedFile{Path: key, Size: jsNumber(m["size"]), ModifiedAt: modified})
		}
	}
	if !initialize {
		for key := range sess.lastFileState {
			if _, still := next[key]; !still {
				files = append(files, deletedFile{Path: key, Deleted: true})
			}
		}
	}
	sess.lastFileState = next

	shell := []any{}
	for _, item := range raw.ShellEvents {
		m, _ := item.(map[string]any)
		if jsNumber(m["at"]) > sess.lastShellAt {
			shell = append(shell, item)
		}
	}
	shell = shell[max(0, len(shell)-20):]
	for _, item := range shell {
		m, _ := item.(map[string]any)
		sess.lastShellAt = math.Max(sess.lastShellAt, jsNumber(m["at"]))
	}
	if initialize {
		shell = []any{}
	}
	out := &Context{
		ActiveWindow:  raw.ActiveWindow,
		Accessibility: raw.Accessibility[:min(len(raw.Accessibility), 120)],
		ShellEvents:   shell,
		Files:         files[:min(len(files), 100)],
	}
	if b := raw.Browser; b != nil {
		out.Browser = &BrowserContext{PageInfo: b.PageInfo, Content: truncateUnits(b.Content, 4000), Elements: b.Elements[:min(len(b.Elements), 120)]}
	}
	return out
}

func numberText(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }
