package cli

import (
	"context"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/proc"
)

var (
	windowsCmd        = regexp.MustCompile(`(?i)(?:^|[\\/])cmd(?:\.exe)?$`)
	windowsPowerShell = regexp.MustCompile(`(?i)(?:^|[\\/])powershell(?:\.exe)?$`)
	pipefailShells    = regexp.MustCompile(`(?:^|/)(?:bash|zsh|ksh|mksh|yash)$`)
)

func isWindowsCmd(shell string) bool        { return windowsCmd.MatchString(shell) }
func isWindowsPowerShell(shell string) bool { return windowsPowerShell.MatchString(shell) }

func windowsShellCandidates() []string {
	if runtime.GOOS != "windows" {
		return nil
	}
	programFiles := envOr("ProgramFiles", `C:\Program Files`)
	programFilesX86 := envOr("ProgramFiles(x86)", `C:\Program Files (x86)`)
	systemRoot := envOr("SystemRoot", `C:\Windows`)
	return []string{
		os.Getenv("SHELL"),
		programFiles + `\Git\bin\bash.exe`,
		programFiles + `\Git\usr\bin\bash.exe`,
		programFilesX86 + `\Git\bin\bash.exe`,
		systemRoot + `\System32\WindowsPowerShell\v1.0\powershell.exe`,
		systemRoot + `\System32\cmd.exe`,
		"bash.exe", "powershell.exe", "cmd.exe",
	}
}

func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}

func shellProbeArgs(shell string) []string {
	switch {
	case isWindowsCmd(shell):
		return []string{"/d", "/s", "/c", "echo ok"}
	case isWindowsPowerShell(shell):
		return []string{"-NoProfile", "-Command", "Write-Output 'ok'"}
	}
	return []string{"-lc", "printf ok"}
}

// ShellArgs is how a shell is asked to run one command. Git Bash and other
// POSIX shells on Windows also accept -l -c.
func ShellArgs(shell, command string) []string {
	switch {
	case isWindowsCmd(shell):
		return []string{"/d", "/s", "/c", command}
	case isWindowsPowerShell(shell):
		return []string{"-NoProfile", "-Command", command}
	}
	return []string{"-l", "-c", command}
}

// WrapForShell makes a pipeline fail when any stage fails, where the shell
// supports it.
func WrapForShell(command, shell string) string {
	if !pipefailShells.MatchString(strings.ToLower(strings.TrimSpace(shell))) {
		return command
	}
	return "set -o pipefail; " + command
}

// ResolveDefaultShell returns the first shell that runs a probe command, or
// "" when none does.
func ResolveDefaultShell() string {
	candidates := append([]string{os.Getenv("SHELL"), "/bin/zsh", "/bin/bash", "/bin/sh"}, windowsShellCandidates()...)
	for _, candidate := range candidates {
		if candidate == "" {
			continue
		}
		if _, err := proc.Checked(context.Background(), 3*time.Second, proc.Spec{Path: candidate, Args: shellProbeArgs(candidate)}); err == nil {
			return candidate
		}
	}
	return ""
}

// loginPath asks the shell for the PATH a login session would have.
func loginPath(shell string) string {
	command := "echo $PATH"
	if isWindowsPowerShell(shell) {
		command = "Write-Output $env:PATH"
	} else if isWindowsCmd(shell) {
		command = "echo %PATH%"
	}
	if out, err := proc.Checked(context.Background(), 5*time.Second, proc.Spec{Path: shell, Args: ShellArgs(shell, command)}); err == nil {
		return out
	}
	if path := os.Getenv("PATH"); path != "" {
		return path
	}
	if runtime.GOOS == "windows" {
		return envOr("SystemRoot", `C:\Windows`) + `\System32`
	}
	return "/usr/local/bin:/usr/bin:/bin"
}

// mergePaths puts the login PATH first and appends what the process already
// had, without duplicates.
func mergePaths(login, current string) string {
	sep := string(os.PathListSeparator)
	seen := map[string]bool{}
	var merged []string
	for _, part := range append(strings.Split(login, sep), strings.Split(current, sep)...) {
		if part != "" && !seen[part] {
			seen[part] = true
			merged = append(merged, part)
		}
	}
	return strings.Join(merged, sep)
}

// resolveCwd keeps Node's default: the caller's directory, else $HOME.
func resolveCwd(cwd string) string {
	if cwd != "" {
		return cwd
	}
	if home := os.Getenv("HOME"); home != "" {
		return home
	}
	if wd, err := os.Getwd(); err == nil {
		return wd
	}
	return filepath.Clean(".")
}
