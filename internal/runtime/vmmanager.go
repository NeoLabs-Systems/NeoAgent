package runtime

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// VMManager boots and tracks the per-user guests of one isolation technology
// (QEMU micro-VMs or Docker containers). The execution backend only ever sees
// a guest agent reachable over loopback, so the two are interchangeable.
type VMManager interface {
	// Readiness says whether this host can start computers at all.
	Readiness() *omap
	// Status is what clients see for the user's computer.
	Status(key string) *omap
	// Ensure starts the user's computer, or returns the running one.
	Ensure(ctx context.Context, key string) (*Session, error)
	// Alive reports a running guest process; Tracked any session at all.
	Alive(key string) bool
	Tracked(key string) bool
	Instance(key string) *Session
	Kill(key string)
	// Fail and Sleep stop the guest and remember why for Status.
	Fail(key string, err error)
	Sleep(key string)
	Shutdown()
	// BootTimeout is how long a guest that still has to provision may take.
	BootTimeout() time.Duration
	// GuestHostAddress is how a guest reaches this server.
	GuestHostAddress() string
	// OnStopped is called whenever a guest process ends.
	OnStopped(func(key string))
	// RemoveUserData deletes the user's persisted computer (account erasure).
	RemoveUserData(key string)
	// Capabilities lists what the guest offers.
	Capabilities() []string
}

// bootAssetCacher is implemented by managers that can boot the next start
// straight into the guest's kernel.
type bootAssetCacher interface {
	CacheDirectBootAssets(ctx context.Context, key string, client *GuestClient) error
}

// GuestAgentArch is the Go architecture name of a guest architecture.
func GuestAgentArch(architecture string) string {
	if normalizeArchitecture(architecture) == "arm64" {
		return "arm64"
	}
	return "amd64"
}

// GuestAgentFileName is the release asset name of the static guest agent.
func GuestAgentFileName(architecture string) string {
	return "neoagent-guest-linux-" + GuestAgentArch(architecture)
}

// guestAgentCandidates are where the static Linux guest agent is looked for:
// NEOAGENT_GUEST_AGENT_BINARY, next to the server executable, then the app and
// runtime directories.
func guestAgentCandidates(env Env, dirs Dirs, architecture string) []string {
	name := GuestAgentFileName(architecture)
	var out []string
	if explicit := trimmed(env.get("NEOAGENT_GUEST_AGENT_BINARY")); explicit != "" {
		out = append(out, explicit)
	}
	if exe, err := os.Executable(); err == nil {
		out = append(out, filepath.Join(filepath.Dir(exe), name))
	}
	for _, root := range []string{dirs.AppDir, dirs.RuntimeHome} {
		if root != "" {
			out = append(out, filepath.Join(root, "computer-runtime", "guest", name), filepath.Join(root, "bin", name))
		}
	}
	return out
}

func resolveGuestAgent(env Env, dirs Dirs, architecture string) string {
	for _, candidate := range guestAgentCandidates(env, dirs, architecture) {
		if info, err := os.Stat(candidate); err == nil && info.Mode().IsRegular() && info.Size() > 0 {
			return candidate
		}
	}
	return ""
}

func readGuestAgent(env Env, dirs Dirs, architecture string) ([]byte, error) {
	path := resolveGuestAgent(env, dirs, architecture)
	if path == "" {
		return nil, &CodedError{
			Message: fmt.Sprintf("The guest agent %s is missing. Searched: %s. Run neoagent repair.", GuestAgentFileName(architecture), strings.Join(guestAgentCandidates(env, dirs, architecture), ", ")),
			Code:    "COMPUTER_RUNTIME_UNAVAILABLE",
			Status:  503,
		}
	}
	return os.ReadFile(path)
}

func capabilityList(values ...string) []string { return values }
