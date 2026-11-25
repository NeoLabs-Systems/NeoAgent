package runtime

import (
	"os"
)

// NewComputerVMManager turns TERMINAL_ENV into the guest technology behind
// every user's computer, or nil for TERMINAL_ENV=host. The server and the CLI
// both go through it, so they never disagree about the runtime.
func NewComputerVMManager(dirs Dirs, env Env, serverPort int) VMManager {
	switch ParseTerminalEnv(env.get("TERMINAL_ENV")) {
	case TerminalHost:
		return nil
	case TerminalDocker:
		return NewDockerManager(DockerOptions{Dirs: dirs, Env: env})
	}
	return NewQemuManager(QemuOptions{Dirs: dirs, Env: env, ServerPort: serverPort})
}

// Validation is the runtime check /api/health and the admin page report.
func Validation(m *Manager, getenv func(string) string) *omap {
	if getenv == nil {
		getenv = os.Getenv
	}
	terminal := ParseTerminalEnv(getenv("TERMINAL_ENV"))
	var readiness *omap
	if m != nil && m.cloud != nil {
		readiness = m.cloud.Readiness()
	}
	issues := []string{}
	warnings := []string{}
	switch {
	case readiness == nil:
		issues = append(issues, "The computer runtime is not available.")
	case !readiness.Bool("ready"):
		switch terminal {
		case TerminalDocker:
			issues = append(issues, "The container computer runtime needs a reachable Docker daemon. Run neoagent repair.")
		case TerminalHost:
			issues = append(issues, "The host computer runtime is unavailable.")
		default:
			issues = append(issues, "The QEMU computer runtime is not installed. Run neoagent repair.")
		}
	}
	if terminal == TerminalHost {
		host := "this server"
		if readiness != nil && readiness.String("host") != "" {
			host = readiness.String("host")
		}
		warnings = append(warnings, "TERMINAL_ENV=host: every account's agent runs directly on "+host+
			" as the server's own OS user, with no isolation between accounts or from the host. "+
			"Only sign in accounts you would trust with a shell on this machine.")
	}
	var computer any
	if readiness != nil {
		computer = readiness
	}
	return obj(
		"ready", len(issues) == 0,
		"issues", issues,
		"warnings", warnings,
		"vm", obj("computer", computer, "android", nil),
		"guestTokenConfigured", true,
		"policy", Policy(getenv),
	)
}

// ValidationIssues returns ready and the issues of a validation.
func ValidationIssues(v *omap) (bool, []string) {
	var issues []string
	v.Decode("issues", &issues)
	return v.Bool("ready"), issues
}
