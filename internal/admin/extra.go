package admin

import (
	"context"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
)

// ExtraDeps supplies optional runtime/update/catalog/user-erasure hooks for
// the remaining admin endpoints.
type ExtraDeps struct {
	MarkSetupSection func(string) error
	Version          string
	DeleteUser       func(ctx context.Context, targetID, actorID int64) error
	ListModels       func(ctx context.Context, userID int64) (any, error)
	HealthCheck      func(ctx context.Context, userID int64) (any, error)
	Logs             func(ctx context.Context) any
	Analytics        func(ctx context.Context, rangeStr string) (any, error)
	MessagingList    func(ctx context.Context) (any, error)
	MessagingUpdate  func(ctx context.Context, platform string, body map[string]any) (any, error)
	MessagingDelete  func(ctx context.Context, platform string) (any, error)
	// Updates from the admin UI; nil leaves this server unable to update itself.
	Updates *UpdateDeps
}

func (a *API) getHealth(r *http.Request) (any, error) {
	uid, _ := sessionUser(r)
	if a.extra.HealthCheck != nil {
		return a.extra.HealthCheck(r.Context(), uid)
	}
	return map[string]any{"passed": true, "results": []map[string]any{{"id": "backend", "label": "Backend server", "passed": true, "detail": "Reachable"}}}, nil
}

func (a *API) getLogs(r *http.Request) (any, error) {
	if a.extra.Logs != nil {
		return map[string]any{"logs": a.extra.Logs(r.Context())}, nil
	}
	return map[string]any{"logs": []any{}}, nil
}

func (a *API) getAnalytics(r *http.Request) (any, error) {
	if a.extra.Analytics != nil {
		return a.extra.Analytics(r.Context(), r.URL.Query().Get("range"))
	}
	return map[string]any{"range": r.URL.Query().Get("range"), "series": []any{}}, nil
}

func (a *API) deleteUser(r *http.Request) (any, error) {
	targetID, err := userID(r)
	if err != nil {
		return nil, err
	}
	actorID, _ := sessionUser(r)
	if a.extra.DeleteUser != nil {
		if err := a.extra.DeleteUser(r.Context(), targetID, actorID); err != nil {
			return nil, err
		}
		return map[string]any{"success": true}, nil
	}
	if targetID == actorID {
		return nil, fail(http.StatusBadRequest, "Cannot delete your own account from admin.", "")
	}
	_, err = a.Store.DB.W.ExecContext(r.Context(), `DELETE FROM users WHERE id = ?`, targetID)
	if err != nil {
		return nil, err
	}
	return map[string]any{"success": true}, nil
}

func (a *API) getMessaging(r *http.Request) (any, error) {
	if a.extra.MessagingList != nil {
		list, err := a.extra.MessagingList(r.Context())
		if err != nil {
			return nil, err
		}
		return map[string]any{"connections": list}, nil
	}
	return map[string]any{"connections": []any{}}, nil
}

func (a *API) putMessaging(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	if a.extra.MessagingUpdate != nil {
		return a.extra.MessagingUpdate(r.Context(), r.PathValue("platform"), map[string]any(b))
	}
	return map[string]any{"ok": true}, nil
}

func (a *API) deleteMessaging(r *http.Request) (any, error) {
	if a.extra.MessagingDelete != nil {
		return a.extra.MessagingDelete(r.Context(), r.PathValue("platform"))
	}
	return map[string]any{"ok": true}, nil
}

func (a *API) getModels(r *http.Request) (any, error) {
	uid, _ := sessionUser(r)
	if a.extra.ListModels != nil {
		return a.extra.ListModels(r.Context(), uid)
	}
	return map[string]any{"models": []any{}}, nil
}

// getVMConfig reports the cloud computer limits. The memory and vCPU caps
// are upper limits: each computer gets less when the host is busy.
func (a *API) getVMConfig(r *http.Request) (any, error) {
	profile := runtime.ComputerResourceProfile(runtime.ProfileOptions{Getenv: os.Getenv})
	return map[string]any{"settings": map[string]any{
		"vmBaseImage": os.Getenv("NEOAGENT_VM_BASE_IMAGE"),
		"minMemoryMb": profile.MinimumGuestMemoryMb,
		"maxMemoryMb": profile.MaximumGuestMemoryMb,
		"maxCpus":     profile.MaximumGuestCPUs,
		"webSharing":  envBool("NEOAGENT_WEB_SHARING", true),
	}}, nil
}

// parseMinInt is parseInt(value, 10) with a lower bound.
func parseMinInt(v any, minimum int, field string) (int, error) {
	digits := intPrefix.FindString(strings.TrimLeftFunc(jsText(v), isJSSpace))
	n, err := strconv.Atoi(digits)
	if err != nil || n < minimum {
		return 0, fail(http.StatusBadRequest, field+" must be ≥ "+strconv.Itoa(minimum)+".", "")
	}
	return n, nil
}

func (a *API) putVMConfig(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	baseImage := cleanLine(b["vmBaseImage"])
	profile := runtime.ComputerResourceProfile(runtime.ProfileOptions{Getenv: os.Getenv})
	maxMemory, err := parseMinInt(b["maxMemoryMb"], profile.MinimumGuestMemoryMb, "maxMemoryMb")
	if err != nil {
		return nil, err
	}
	maxCPUs, err := parseMinInt(b["maxCpus"], 1, "maxCpus")
	if err != nil {
		return nil, err
	}
	changes := [][2]string{
		{"NEOAGENT_VM_BASE_IMAGE", baseImage},
		{"NEOAGENT_COMPUTER_MAX_MEMORY_MB", strconv.Itoa(maxMemory)},
		{"NEOAGENT_COMPUTER_MAX_CPUS", strconv.Itoa(maxCPUs)},
	}
	if v, ok := b["webSharing"]; ok {
		on, err := requireBoolean(v, "webSharing must be a boolean.")
		if err != nil {
			return nil, err
		}
		changes = append(changes, [2]string{"NEOAGENT_WEB_SHARING", strconv.FormatBool(on)})
	}
	for _, change := range changes {
		if err := a.Settings.Env.Persist(change[0], change[1]); err != nil {
			return nil, err
		}
	}
	return map[string]any{"ok": true}, nil
}

func (a *API) getIntegrationConfig(r *http.Request) (any, error) {
	return map[string]any{
		"googleClientIdSet":    os.Getenv("GOOGLE_CLIENT_ID") != "",
		"microsoftClientIdSet": os.Getenv("MICROSOFT_CLIENT_ID") != "",
		"githubClientIdSet":    os.Getenv("GITHUB_CLIENT_ID") != "",
		"slackClientIdSet":     os.Getenv("SLACK_CLIENT_ID") != "",
	}, nil
}

func (a *API) putIntegrationConfig(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	for k, v := range b {
		if strings.HasSuffix(k, "_CLIENT_ID") || strings.HasSuffix(k, "_CLIENT_SECRET") {
			_ = a.Settings.Env.Persist(k, strVal(v))
		}
	}
	return a.getIntegrationConfig(r)
}

func strVal(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case float64:
		return strconv.FormatFloat(x, 'f', -1, 64)
	case int:
		return strconv.Itoa(x)
	}
	return ""
}
