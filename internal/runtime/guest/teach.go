package guest

import (
	"bufio"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

var sysvNoise = regexp.MustCompile(`(?i)systemd-sysv-install|Synchronizing state of \S+ with SysV`)

// accessibilityScript lists the focused application's accessibility nodes,
// hiding password fields and noting whether one has focus.
const accessibilityScript = `import json, pyatspi
desktop = pyatspi.Registry.getDesktop(0)
result = []
sensitive = [False]
def walk(node, depth=0):
    if depth > 4 or len(result) >= 300: return
    try:
        role = node.getRoleName()
        name = str(node.name or "")[:200]
        if role == "password text": name = "[sensitive]"
        if role or name: result.append({"role": role, "name": name})
        if role == "password text" and node.getState().contains(pyatspi.STATE_FOCUSED): sensitive[0] = True
        for child in node: walk(child, depth + 1)
    except Exception: pass
walk(desktop)
print(json.dumps({"nodes": result, "sensitiveInputActive": sensitive[0]}, separators=(",", ":")))`

func (s *Server) teachContext(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) {
		var activeWindow any
		if out, err := s.runDesktop("sh", "-lc", `window=$(xdotool getactivewindow 2>/dev/null) && xdotool getwindowname "$window"`); err == nil {
			activeWindow = utf16Prefix(out, 300)
			if out == "" {
				activeWindow = nil
			}
		}
		accessibility := []any{}
		sensitive := false
		if out, err := s.desktopCommand(10*time.Second, "python3", "-c", accessibilityScript); err == nil {
			var parsed struct {
				Nodes     []any `json:"nodes"`
				Sensitive bool  `json:"sensitiveInputActive"`
			}
			if json.Unmarshal([]byte(out), &parsed) == nil {
				if parsed.Nodes != nil {
					accessibility = parsed.Nodes
				}
				sensitive = parsed.Sensitive
			}
		}
		if sensitive {
			return orderedContext(activeWindow, accessibility, sensitive, []any{}, []any{}), nil
		}
		return orderedContext(activeWindow, accessibility, sensitive, s.shellEvents(), s.workspaceFiles()), nil
	})
}

type contextBody struct {
	ActiveWindow  any   `json:"activeWindow"`
	Accessibility []any `json:"accessibility"`
	Sensitive     bool  `json:"sensitiveInputActive"`
	ShellEvents   []any `json:"shellEvents"`
	Files         []any `json:"files"`
}

func orderedContext(window any, accessibility []any, sensitive bool, events, files []any) contextBody {
	return contextBody{window, accessibility, sensitive, events, files}
}

// shellEvents are the last 50 lines of the guest shell's audit log; one bad
// line discards them all, as before.
func (s *Server) shellEvents() []any {
	f, err := os.Open(filepath.Join(s.cfg.HomeDir, ".neoagent", "teach-shell-events.jsonl"))
	if err != nil {
		return []any{}
	}
	defer f.Close()
	var lines []string
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 0, 64*1024), 8<<20)
	for scanner.Scan() {
		if line := strings.TrimSpace(scanner.Text()); line != "" {
			lines = append(lines, line)
		}
	}
	if len(lines) > 50 {
		lines = lines[len(lines)-50:]
	}
	events := make([]any, 0, len(lines))
	for _, line := range lines {
		var event any
		if json.Unmarshal([]byte(line), &event) != nil {
			return []any{}
		}
		events = append(events, event)
	}
	return events
}

func (s *Server) workspaceFiles() []any {
	files := []any{}
	pending := []string{s.ws.root}
	for len(pending) > 0 && len(files) < 500 {
		current := pending[0]
		pending = pending[1:]
		entries, err := os.ReadDir(current)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if len(files) >= 500 {
				break
			}
			abs := filepath.Join(current, entry.Name())
			if entry.IsDir() {
				pending = append(pending, abs)
			} else if entry.Type().IsRegular() {
				info, err := entry.Info()
				if err != nil {
					continue
				}
				files = append(files, map[string]any{"path": s.ws.relative(abs), "size": info.Size(), "modifiedAt": isoTime(info.ModTime())})
			}
		}
	}
	return files
}
