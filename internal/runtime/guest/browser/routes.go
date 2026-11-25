package browser

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

const bodyLimit = 10 << 20

// Mount registers the /browser endpoints. handle adds the guest's bearer
// token check. A nil controller (a guest profile without a browser) answers
// every endpoint with an error.
func Mount(handle func(pattern string, h http.Handler), c *Controller) {
	route := func(pattern string, fn func(ctx context.Context, b map[string]any) (any, error)) {
		handle(pattern, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if c == nil {
				httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "browser runtime is unavailable in this guest profile."})
				return
			}
			path := strings.TrimPrefix(r.URL.Path, "/browser")
			if path != "/status" && path != "/credential-submit" && path != "/credential-cancel" && path != "/close" && c.HasProtectedFill() {
				httpx.WriteJSON(w, http.StatusLocked, map[string]any{
					"error": "Browser control is paused while a protected credential fill is active. Submit or cancel it first.",
					"code":  "PROTECTED_CREDENTIAL_FILL_ACTIVE",
				})
				return
			}
			result, err := fn(r.Context(), readBody(r))
			if err != nil {
				status := http.StatusInternalServerError
				if r.Context().Err() != nil {
					status = 499
				}
				httpx.WriteJSON(w, status, map[string]any{"error": err.Error()})
				return
			}
			httpx.WriteJSON(w, http.StatusOK, result)
		}))
	}
	route("GET /browser/status", func(ctx context.Context, _ map[string]any) (any, error) { return c.Status(ctx) })
	route("POST /browser/launch", func(ctx context.Context, _ map[string]any) (any, error) { return c.Launch(ctx) })
	route("POST /browser/navigate", func(ctx context.Context, b map[string]any) (any, error) {
		return c.Navigate(ctx, str(b["url"]), NavigateOptions{
			WaitFor: str(b["waitFor"]), WaitUntil: str(b["waitUntil"]), ReferrerMode: str(b["referrerMode"]),
			ChallengeRetry: b["challengeRetry"] != false, Screenshot: b["screenshot"] != false, FullPage: truthy(b["fullPage"]),
		})
	})
	route("POST /browser/screenshot", func(ctx context.Context, b map[string]any) (any, error) {
		return c.Screenshot(ctx, truthy(b["fullPage"]), str(b["selector"]))
	})
	route("POST /browser/screenshot-jpeg", func(ctx context.Context, b map[string]any) (any, error) {
		jpeg, err := c.ScreenshotJPEG(ctx, b["quality"], b["fullPage"] == true, str(b["selector"]))
		if err != nil {
			return nil, err
		}
		return struct {
			ContentType   string `json:"contentType"`
			ContentBase64 string `json:"contentBase64"`
		}{"image/jpeg", base64.StdEncoding.EncodeToString(jpeg)}, nil
	})
	route("POST /browser/click", func(ctx context.Context, b map[string]any) (any, error) {
		return c.Click(ctx, str(b["selector"]), str(b["text"]), b["screenshot"] != false)
	})
	route("POST /browser/click-point", func(ctx context.Context, b map[string]any) (any, error) {
		return c.ClickPoint(ctx, b["x"], b["y"], b["screenshot"] != false)
	})
	route("POST /browser/fill", func(ctx context.Context, b map[string]any) (any, error) {
		value := b["value"]
		if value == nil {
			value = b["text"]
		}
		text := ""
		if value != nil {
			text = jsText(value)
		}
		return c.Fill(ctx, str(b["selector"]), text, FillOptions{Clear: b["clear"] != false, PressEnter: truthy(b["pressEnter"]), Screenshot: b["screenshot"] != false})
	})
	route("POST /browser/credential-fill", func(ctx context.Context, b map[string]any) (any, error) {
		return c.FillCredential(ctx, CredentialInput{
			AllowedOrigin: str(b["allowedOrigin"]), UsernameSelector: str(b["usernameSelector"]), PasswordSelector: str(b["passwordSelector"]),
			Username: str(b["username"]), Password: str(b["password"]),
		})
	})
	route("POST /browser/credential-submit", func(ctx context.Context, b map[string]any) (any, error) {
		return c.SubmitProtectedCredential(ctx, str(b["protectedFillId"]))
	})
	route("POST /browser/credential-cancel", func(ctx context.Context, b map[string]any) (any, error) {
		return c.CancelProtectedCredential(ctx, str(b["protectedFillId"]))
	})
	route("POST /browser/type-text", func(ctx context.Context, b map[string]any) (any, error) {
		return c.TypeText(ctx, str(b["text"]), truthy(b["pressEnter"]), b["screenshot"] != false)
	})
	route("POST /browser/press-key", func(ctx context.Context, b map[string]any) (any, error) {
		return c.PressKey(ctx, str(b["key"]), b["screenshot"] != false)
	})
	route("POST /browser/scroll", func(ctx context.Context, b map[string]any) (any, error) {
		return c.Scroll(ctx, orZero(b["deltaX"]), orZero(b["deltaY"]), b["screenshot"] != false)
	})
	route("POST /browser/extract", func(ctx context.Context, b map[string]any) (any, error) {
		return c.Extract(ctx, str(b["selector"]), str(b["attribute"]), truthy(b["all"]))
	})
	route("POST /browser/execute", func(ctx context.Context, b map[string]any) (any, error) {
		return c.Evaluate(ctx, str(b["code"]))
	})
	route("POST /browser/close", func(context.Context, map[string]any) (any, error) {
		c.Close()
		return struct {
			Success bool `json:"success"`
		}{true}, nil
	})
}

func readBody(r *http.Request) map[string]any {
	out := map[string]any{}
	if r.Body == nil || !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return out
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, bodyLimit))
	if err != nil {
		return out
	}
	_ = json.Unmarshal(raw, &out)
	if out == nil {
		out = map[string]any{}
	}
	return out
}

func orZero(v any) any {
	if v == nil {
		return float64(0)
	}
	return v
}

// truthy is JavaScript truthiness for a JSON value.
func truthy(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case bool:
		return t
	case float64:
		return t != 0
	case string:
		return t != ""
	}
	return true
}

// str is String(value || "").
func str(v any) string {
	if !truthy(v) {
		return ""
	}
	return jsText(v)
}

// jsText is String(value) for a JSON value.
func jsText(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case string:
		return t
	case bool:
		return strconv.FormatBool(t)
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case []any:
		parts := make([]string, len(t))
		for i, e := range t {
			if e != nil {
				parts[i] = jsText(e)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}
