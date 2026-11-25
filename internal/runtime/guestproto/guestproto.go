// Package guestproto is the contract between the host runtime and the guest
// agent that runs inside a computer: the guest's file system layout, the
// ports and environment variables, and the small text rules both sides apply
// to workspace files.
package guestproto

import (
	"encoding/json"
	"strings"
)

// Filesystem layout inside the guest image. The guest user is `neo`, its home
// is the mount point of the data disk, and the agent works out of `workspace`.
// These are a contract between the bootstrap that builds the image, the
// backends that talk to it, and the tools that report paths back to the model.
const (
	Home         = "/home/neo"
	WorkspaceDir = Home + "/workspace"
	Tailscaled   = "/usr/local/bin/tailscaled"
	Timeout      = "/usr/bin/timeout"
	VolatileDir  = "/dev/shm"
	// BinaryPath is where both the QEMU guest and the Docker image install the
	// guest agent.
	BinaryPath = "/usr/local/bin/neoagent-guest"
)

// Guest agent endpoint configuration.
const (
	DefaultPort     = 8421
	EnvPort         = "NEOAGENT_GUEST_AGENT_PORT"
	EnvToken        = "NEOAGENT_VM_GUEST_TOKEN"
	EnvTokenB64     = "NEOAGENT_VM_GUEST_TOKEN_B64"
	EnvProfile      = "NEOAGENT_GUEST_PROFILE"
	EnvWorkspaceDir = "NEOAGENT_WORKSPACE_DIR"
)

// ToWorkspacePath turns a workspace-relative path into the absolute one the
// model and the UI see.
func ToWorkspacePath(relative string) string { return WorkspaceDir + "/" + relative }

// FromWorkspacePath is the inverse: guest tools speak workspace-relative
// paths. Every boundary crossing goes through these two helpers.
func FromWorkspacePath(value, fallback string) string {
	if value == "" {
		value = fallback
	}
	normalized := strings.ReplaceAll(strings.TrimSpace(value), `\`, "/")
	if normalized == WorkspaceDir {
		return ""
	}
	if strings.HasPrefix(normalized, WorkspaceDir+"/") {
		return normalized[len(WorkspaceDir)+1:]
	}
	if normalized == "" {
		return fallback
	}
	return normalized
}

// Profile is the capability set a guest runs with.
const (
	ProfileAndroid    = "android"
	ProfileBrowser    = "browser"
	ProfileCLI        = "cli"
	ProfileBrowserCLI = "browser_cli"
)

// NormalizeProfile maps anything unknown to browser_cli.
func NormalizeProfile(profile string) string {
	switch p := strings.TrimSpace(profile); p {
	case ProfileAndroid, ProfileBrowser, ProfileCLI, ProfileBrowserCLI:
		return p
	}
	return ProfileBrowserCLI
}

// CoerceWritableText turns whatever a tool sent as file content into text:
// null is empty, scalars are their text, a list of strings is joined by
// newlines, anything else is indented JSON.
func CoerceWritableText(value any) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		if v {
			return "true"
		}
		return "false"
	case float64, int, int64, json.Number:
		return jsNumber(v)
	case []any:
		parts := make([]string, 0, len(v))
		for _, item := range v {
			s, ok := item.(string)
			if !ok {
				return indentedJSON(value)
			}
			parts = append(parts, s)
		}
		return strings.Join(parts, "\n")
	case []string:
		return strings.Join(v, "\n")
	}
	return indentedJSON(value)
}

func jsNumber(v any) string {
	body, err := json.Marshal(v)
	if err != nil {
		return ""
	}
	return string(body)
}

func indentedJSON(value any) string {
	var out strings.Builder
	enc := json.NewEncoder(&out)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(value); err != nil {
		return ""
	}
	return strings.TrimSuffix(out.String(), "\n")
}
