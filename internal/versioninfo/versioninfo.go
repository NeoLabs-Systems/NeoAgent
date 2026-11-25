// Package versioninfo answers what /api/version and the admin version view
// report: the release version, where it came from and what the deployment
// allows.
package versioninfo

import (
	"runtime/debug"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/cli/release"

	"github.com/NeoLabs-Systems/neoagent/internal/buildinfo"
	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
)

// Info is the deployment and version description, in the order clients see.
func Info(getenv func(string) string) *jsonobj.Object {
	version := buildinfo.Version
	channel := Channel(getenv)
	mode := runtime.ParseDeploymentMode(getenv("NEOAGENT_DEPLOYMENT_MODE"))
	terminal := runtime.ParseTerminalEnv(getenv("TERMINAL_ENV"))
	container := ContainerImage(getenv)
	return jsonobj.New(
		"name", "neoagent",
		"version", version,
		"packageVersion", version,
		"gitVersion", nil,
		"gitBranch", nil,
		"gitSha", revision(),
		"installedVersion", version,
		"releaseChannel", channel,
		"targetBranch", BranchPolicy(channel),
		"deploymentMode", mode,
		"managedDeployment", mode == runtime.ModeManaged,
		"allowSelfUpdate", mode != runtime.ModeManaged && !container,
		"containerImage", container,
		"runtimeDefaults", jsonobj.New(
			"runtime_profile", "cloud-computer",
			"runtime_backend", string(terminal),
			"computer_backend", "cloud",
			"android_backend", "host",
			"mcp_backend", "host-remote",
		),
		"allowHostRuntime", terminal == runtime.TerminalHost,
	)
}

// Channel is the configured release channel, "stable" or "beta".
func Channel(getenv func(string) string) string {
	return release.NormalizeChannel(getenv("NEOAGENT_RELEASE_CHANNEL"))
}

// BranchPolicy says which branch a channel follows.
func BranchPolicy(channel string) string {
	if release.NormalizeChannel(channel) == release.Beta {
		return "newest of beta or main"
	}
	return "main only"
}

// ContainerImage reports the official container image, which never updates
// itself: a newer image replaces it.
func ContainerImage(getenv func(string) string) bool {
	v := strings.ToLower(strings.TrimSpace(getenv("NEOAGENT_CONTAINER_IMAGE")))
	return v == "1" || v == "true"
}

// revision is the short commit the binary was built from, when Go recorded it.
func revision() any {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return nil
	}
	for _, s := range info.Settings {
		if s.Key == "vcs.revision" && len(s.Value) >= 8 {
			return s.Value[:8]
		}
	}
	return nil
}
