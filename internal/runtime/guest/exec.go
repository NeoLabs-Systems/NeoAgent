package guest

import (
	"errors"
	"math"
	"net/http"
	"regexp"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/cli"
)

var envName = regexp.MustCompile(`^[A-Z_][A-Z0-9_]*$`)

// commandEnv keeps only well-formed variable names with text values, as the
// host's per-command routing sends them.
func commandEnv(v any) map[string]string {
	raw, ok := v.(map[string]any)
	if !ok {
		return nil
	}
	env := map[string]string{}
	for key, value := range raw {
		if s, ok := value.(string); ok && envName.MatchString(key) {
			env[key] = s
		}
	}
	return env
}

func scriptedInputs(v any) []cli.Input {
	list, _ := v.([]any)
	inputs := make([]cli.Input, 0, len(list))
	for _, item := range list {
		if m, ok := item.(map[string]any); ok {
			input := cli.Input{Input: stringOf(m["input"]), WaitFor: text(m, "waitFor")}
			inputs = append(inputs, input)
			continue
		}
		inputs = append(inputs, cli.Input{Input: stringOf(item)})
	}
	return inputs
}

var errNoCLI = errors.New("cli runtime is unavailable in this guest profile.")

func (s *Server) execute(w http.ResponseWriter, r *http.Request) {
	body, err := readBody(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorBody(err.Error()))
		return
	}
	status, answer := func() (int, any) {
		if err := s.assertDiskSafety(0); err != nil {
			return http.StatusInternalServerError, errorBody(err.Error())
		}
		if s.exec == nil {
			return http.StatusInternalServerError, errorBody(errNoCLI.Error())
		}
		command := trimSpace(text(body, "command"))
		if command == "" {
			return http.StatusOK, errorBody("command is required")
		}
		opts := cli.Options{Cwd: text(body, "cwd"), TimeoutMs: number(body, "timeout"), Env: commandEnv(body["env"])}
		if math.IsNaN(opts.TimeoutMs) {
			opts.TimeoutMs = 0
		}
		if truthy(body["pty"]) {
			return http.StatusOK, s.exec.ExecuteInteractive(r.Context(), command, scriptedInputs(body["inputs"]), opts)
		}
		opts.StdinInput = text(body, "stdin_input")
		return http.StatusOK, s.exec.Execute(r.Context(), command, opts)
	}()
	if r.Context().Err() != nil && status == http.StatusInternalServerError {
		status = 499
	}
	writeJSON(w, status, answer)
}

func (s *Server) execKill(w http.ResponseWriter, r *http.Request) {
	body, err := readBody(r)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, errorBody(err.Error()))
		return
	}
	work(w, func() (any, error) {
		if s.exec == nil {
			return nil, errNoCLI
		}
		pid := number(body, "pid")
		if !finite(pid) || pid != math.Trunc(pid) || pid <= 0 {
			return errorBody("pid is required"), nil
		}
		reason := trimSpace(text(body, "reason"))
		if reason == "" {
			reason = "aborted"
		}
		if !s.exec.IsManaged(int(pid)) {
			return errorBody("pid not managed"), nil
		}
		return obj("success", s.exec.Kill(int(pid), reason), "pid", int(pid)), nil
	})
}
