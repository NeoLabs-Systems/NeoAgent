// Package repotools holds the coding tools that read a repository through the
// shell of whichever computer a run uses (services/workspace/workspace_shell.js
// and its users): search_files, repo_overview, repo_diff and run_tests. A guest
// VM, a desktop companion and host mode behave the same because every script
// sticks to POSIX sh and reports in marked sections.
package repotools

import (
	"context"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

const (
	marker      = "@@neoagent:"
	readTimeout = 60 * time.Second

	// GuestWorkspaceDir is where the agent works inside a guest computer.
	GuestWorkspaceDir = "/home/neo/workspace"
)

// GitFunction defines `g`: git without hooks, fsmonitor, pager, filters or
// textconv.
const GitFunction = `g() { GIT_PAGER=cat git --no-optional-locks -c core.fsmonitor=false -c core.hooksPath=/dev/null -c log.showSignature=false -c submodule.recurse=false -c core.quotepath=off "$@"; }`

// Shell runs a script in the run's computer, in its workspace. The result is
// the command executor's record (stdout, stderr, exitCode, error, timedOut,
// killed, durationMs, truncated, outputArtifact). A zero timeout means the
// 60-second read limit.
type Shell interface {
	Run(ctx context.Context, script string, timeout time.Duration) (dyn.Map, error)
}

// ShellQuote quotes a value for POSIX sh.
func ShellQuote(value string) string {
	if value == "" {
		return "''"
	}
	return "'" + strings.ReplaceAll(value, "'", `'\''`) + "'"
}

func section(name string) string {
	return `printf '%s\n' ` + ShellQuote(marker+name)
}

// FromGuestWorkspacePath turns a guest path into a workspace-relative one.
func FromGuestWorkspacePath(value string) string {
	normalized := strings.ReplaceAll(strings.TrimSpace(value), `\`, "/")
	if normalized == GuestWorkspaceDir {
		return ""
	}
	if rest, ok := strings.CutPrefix(normalized, GuestWorkspaceDir+"/"); ok {
		return rest
	}
	return normalized
}

// WorkspaceRelative is how a target reads relative to the workspace; "." for
// the workspace itself.
func WorkspaceRelative(value any) string {
	text := ""
	if value != nil {
		text = strings.TrimSpace(dyn.String(value))
	}
	if text == "" || text == "/workspace" {
		return "."
	}
	if rest, ok := strings.CutPrefix(text, "/workspace/"); ok {
		if rest == "" {
			return "."
		}
		return rest
	}
	if rel := FromGuestWorkspacePath(text); rel != "" {
		return rel
	}
	return "."
}

// enterScript moves into a directory, or a file's directory, or stops with a
// marker. Unless anywhere, it must stay in the workspace by physical path.
func enterScript(target any, anywhere bool) []string {
	lines := []string{
		"neo_root=$(pwd -P)",
		"neo_dir=" + ShellQuote(WorkspaceRelative(target)),
		"neo_name=.",
		`if [ -f "$neo_dir" ] && [ ! -L "$neo_dir" ]; then neo_name=$(basename -- "$neo_dir"); neo_dir=$(dirname -- "$neo_dir"); fi`,
		`CDPATH= cd -- "$neo_dir" 2>/dev/null || { ` + section("missing") + "; exit 0; }",
	}
	if !anywhere {
		lines = append(lines, `case "$(pwd -P)/" in "$neo_root"/*) ;; *) `+section("outside")+"; exit 0 ;; esac")
	}
	return lines
}

type shellSection struct {
	name  string
	lines []string
}

type sections []*shellSection

func parseSections(stdout any) sections {
	var out sections
	var current *shellSection
	text := ""
	if stdout != nil {
		text = dyn.Str(stdout)
	}
	for _, line := range strings.Split(text, "\n") {
		if name, ok := strings.CutPrefix(line, marker); ok {
			current = &shellSection{name: name, lines: []string{}}
			out = append(out, current)
		} else if current != nil {
			current.lines = append(current.lines, line)
		}
	}
	return out
}

func (s sections) first(name string) *shellSection {
	for _, entry := range s {
		if entry.name == name {
			return entry
		}
	}
	return nil
}

func (s sections) raw(name string) []string {
	if entry := s.first(name); entry != nil {
		return entry.lines
	}
	return nil
}

// lines are the non-empty lines of a section.
func (s sections) lines(name string) []string {
	var out []string
	for _, line := range s.raw(name) {
		if line != "" {
			out = append(out, line)
		}
	}
	return out
}

func (s sections) line(name string, i int) string {
	raw := s.raw(name)
	if i < len(raw) {
		return raw[i]
	}
	return ""
}

func locationError(s sections, target any) string {
	shown := WorkspaceRelative(target)
	if s.first("outside") != nil {
		return shown + " is outside the workspace."
	}
	if s.first("missing") != nil {
		return shown + " does not exist in the workspace."
	}
	return ""
}

func commandError(result dyn.Map) string {
	if dyn.Truthy(result["error"]) {
		return dyn.String(result["error"])
	}
	if dyn.Truthy(result["timedOut"]) {
		return "The command timed out."
	}
	if dyn.Truthy(result["killed"]) {
		return "The command was stopped."
	}
	return ""
}

// jsNumber is Number(v) of JavaScript (NaN for anything unreadable).
func jsNumber(v any) float64 { return jsv.Number(v) }
