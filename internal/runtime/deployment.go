package runtime

import (
	"strings"
)

// TerminalEnv is where every user's computer runs: a QEMU micro-VM (default),
// a per-user Docker container, or this server process itself. Only the first
// two isolate users from the host and from each other.
type TerminalEnv string

// The computer runtimes TERMINAL_ENV can select.
const (
	TerminalQEMU   TerminalEnv = "qemu"
	TerminalDocker TerminalEnv = "docker"
	TerminalHost   TerminalEnv = "host"
)

// ParseTerminalEnv reads a TERMINAL_ENV value; anything unknown is QEMU.
func ParseTerminalEnv(value string) TerminalEnv {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "docker", "container", "containers":
		return TerminalDocker
	case "host", "local", "server":
		return TerminalHost
	}
	return TerminalQEMU
}

// Deployment modes.
const (
	ModeSelfHosted = "self_hosted"
	ModeManaged    = "managed"
)

// ParseDeploymentMode reads NEOAGENT_DEPLOYMENT_MODE.
func ParseDeploymentMode(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "managed", "saas", "hosted", "cloud":
		return ModeManaged
	}
	return ModeSelfHosted
}

// Policy is what the deployment's environment allows. It is reported by the
// runtime validation and the admin health view.
func Policy(getenv func(string) string) *omap {
	mode := ParseDeploymentMode(getenv("NEOAGENT_DEPLOYMENT_MODE"))
	terminal := ParseTerminalEnv(getenv("TERMINAL_ENV"))
	containerImage := isTruthy(getenv("NEOAGENT_CONTAINER_IMAGE"))
	return obj(
		"mode", mode,
		"managed", mode == ModeManaged,
		"containerImage", containerImage,
		"allowSelfUpdate", mode != ModeManaged && !containerImage,
		"signupKeyRequired", !allowSignup(getenv("NEOAGENT_ALLOW_SIGNUP")),
		"runtimeDefaults", obj(
			"runtime_profile", "cloud-computer",
			"runtime_backend", string(terminal),
			"computer_backend", "cloud",
			"android_backend", "host",
			"mcp_backend", "host-remote",
		),
		"allowHostRuntime", terminal == TerminalHost,
	)
}

func isTruthy(raw string) bool {
	v := strings.ToLower(strings.TrimSpace(raw))
	return v == "1" || v == "true"
}

// allowSignup mirrors getAllowSignup: open sign-up unless explicitly turned off.
func allowSignup(raw string) bool {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "false", "0", "no":
		return false
	}
	return true
}
