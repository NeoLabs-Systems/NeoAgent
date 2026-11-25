package runtimeapi

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
)

// SystemAPI serves the runtime self-tests under /api/system.
type SystemAPI struct {
	Manager *runtime.Manager
	Getenv  func(string) string
}

// Routes registers the self-test endpoints.
func (s *SystemAPI) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/system/health-check", s.auth(s.healthCheck))
	mux.HandleFunc("GET /api/system/test/cli", s.auth(s.testCLI))
	mux.HandleFunc("GET /api/system/test/computer", s.auth(s.testComputer))
}

func (s *SystemAPI) auth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		user, _, ok := userFrom(r)
		if !ok {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		next(w, r, user)
	}
}

func (s *SystemAPI) getenv() func(string) string {
	if s.Getenv != nil {
		return s.Getenv
	}
	return os.Getenv
}

// cut120 is String(x).slice(0, 120) for the ASCII-ish details shown here.
func cut120(text string) string {
	if r := []rune(text); len(r) > 120 {
		return string(r[:120])
	}
	return text
}

// RuntimeCheck is the vm_runtime row of the health checks.
func RuntimeCheck(m *runtime.Manager, getenv func(string) string) map[string]any {
	ready, issues := runtime.ValidationIssues(runtime.Validation(m, getenv))
	detail := "Available"
	if !ready {
		detail = "Not configured"
		if len(issues) > 0 {
			detail = issues[0]
		}
	}
	return map[string]any{"id": "vm_runtime", "label": "Cloud VM runtime", "passed": ready, "detail": detail}
}

func outputDetail(result *runtime.Object) string {
	stderr := result.String("stderr")
	if stderr == "" {
		stderr = result.String("stdout")
	}
	code := "?"
	var c float64
	if result.Decode("exitCode", &c) {
		code = fmt.Sprint(c)
	}
	return fmt.Sprintf("Exit %s: %s", code, cut120(stderr))
}

func commandPassed(result *runtime.Object, marker string) bool {
	var code float64
	ok := result.Decode("exitCode", &code)
	stdout := result.String("stdout")
	return ok && code == 0 && strings.Contains(stdout, marker)
}

func (s *SystemAPI) healthCheck(w http.ResponseWriter, r *http.Request, user int64) {
	results := []map[string]any{
		{"id": "backend", "label": "Backend server", "passed": true, "detail": "Reachable"},
		RuntimeCheck(s.Manager, s.getenv()),
	}
	vmCLI := map[string]any{"id": "vm_cli", "label": "Cloud VM — command execution", "passed": false, "detail": "VM runtime unavailable"}
	if s.Manager != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 15*time.Minute)
		result, err := s.Manager.ExecuteCommand(ctx, key(user), `echo "health_check_ok"`, "", runtime.ExecOptions{TimeoutMs: 15000})
		cancel()
		switch {
		case err != nil:
			vmCLI["detail"] = cut120(err.Error())
		case commandPassed(result, "health_check_ok"):
			vmCLI["passed"], vmCLI["detail"] = true, "Commands running"
		default:
			vmCLI["detail"] = outputDetail(result)
		}
	}
	results = append(results, vmCLI)
	passed := true
	for _, res := range results {
		passed = passed && res["passed"] == true
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"passed": passed, "results": results})
}

func (s *SystemAPI) testCLI(w http.ResponseWriter, r *http.Request, user int64) {
	if s.Manager == nil {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"passed": false, "backendUsed": "vm", "detail": "Runtime not configured on this server."})
		return
	}
	result, err := s.Manager.ExecuteCLICommand(r.Context(), key(user), `echo "cli_test_ok"`, "", runtime.ExecOptions{TimeoutMs: 15000})
	if err != nil {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"passed": false, "backendUsed": "unknown", "detail": cut120(err.Error())})
		return
	}
	ok := commandPassed(result, "cli_test_ok")
	detail := "Command executed successfully"
	if !ok {
		detail = outputDetail(result)
	}
	backend := result.String("backend")
	if backend == "" {
		backend = "unknown"
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"passed": ok, "backendUsed": backend, "detail": detail})
}

func (s *SystemAPI) testComputer(w http.ResponseWriter, _ *http.Request, user int64) {
	if s.Manager == nil {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"passed": false, "detail": "Cloud computer runtime is unavailable."})
		return
	}
	status, err := s.Manager.Status(key(user), "")
	if err != nil {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"passed": false, "detail": cut120(err.Error())})
		return
	}
	state := status.String("state")
	passed := state == runtime.StateReady || state == runtime.StateStopped
	detail := "Cloud computer is " + state + "."
	if !passed {
		detail = status.String("lastError")
		if detail == "" {
			detail = state
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"passed": passed, "state": state, "detail": detail})
}
