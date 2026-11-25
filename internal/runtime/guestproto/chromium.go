package guestproto

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Chromium in the guest is started with a fixed profile and a loopback CDP port.
const (
	ChromiumCDPPort         = 9222
	ChromiumUserDataDir     = Home + "/.neoagent/data/browser-profiles/default"
	chromiumCDPEndpointHost = "http://127.0.0.1:"
)

// ChromiumCDPEndpoint is where the guest's Chromium answers DevTools requests.
func ChromiumCDPEndpoint() string { return chromiumCDPEndpointHost + strconv.Itoa(ChromiumCDPPort) }

// ChromiumDesktopArgs are the flags every Chromium launched on the desktop gets.
func ChromiumDesktopArgs(userDataDir string) []string {
	if userDataDir == "" {
		userDataDir = ChromiumUserDataDir
	}
	return []string{
		"--user-data-dir=" + userDataDir,
		"--no-first-run",
		"--no-default-browser-check",
		"--restore-last-session",
		"--hide-crash-restore-bubble",
		"--disable-session-crashed-bubble",
		"--remote-debugging-address=127.0.0.1",
		fmt.Sprintf("--remote-debugging-port=%d", ChromiumCDPPort),
		"--remote-allow-origins=*",
	}
}

// ChromiumDesktopCommand is the command line of a desktop shortcut.
func ChromiumDesktopCommand(binary string) string {
	if binary == "" {
		binary = "chromium"
	}
	return strings.Join(append([]string{binary}, ChromiumDesktopArgs("")...), " ")
}

// IsChromiumProfileInUse reports whether a running Chromium holds the profile.
func IsChromiumProfileInUse(profileDir string) bool {
	lock := filepath.Join(profileDir, "SingletonLock")
	target, err := os.Readlink(lock)
	if err != nil {
		if os.IsNotExist(err) {
			return false
		}
		_, statErr := os.Lstat(lock)
		return statErr == nil
	}
	parts := strings.Split(target, "-")
	pid, err := strconv.Atoi(parts[len(parts)-1])
	if err != nil || pid <= 0 {
		return true
	}
	return processExists(pid)
}

// MarkChromiumSessionClean rewrites the profile's preferences as a clean exit,
// so the next start restores tabs without a crash bubble. It does nothing
// while Chromium is running, and reports whether it changed a file.
func MarkChromiumSessionClean(profileDir string) bool {
	if IsChromiumProfileInUse(profileDir) {
		return false
	}
	updated := false
	for _, path := range []string{filepath.Join(profileDir, "Default", "Preferences"), filepath.Join(profileDir, "Preferences")} {
		raw, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		var prefs map[string]json.RawMessage
		if json.Unmarshal(raw, &prefs) != nil || prefs == nil {
			continue
		}
		profile := map[string]any{}
		if p, ok := prefs["profile"]; ok {
			_ = json.Unmarshal(p, &profile)
			if profile == nil {
				profile = map[string]any{}
			}
		}
		if profile["exit_type"] == "Normal" && profile["exited_cleanly"] == true {
			continue
		}
		profile["exit_type"] = "Normal"
		profile["exited_cleanly"] = true
		body, _ := json.Marshal(profile)
		prefs["profile"] = body
		out, _ := json.Marshal(prefs)
		if os.WriteFile(path, out, 0o600) == nil {
			updated = true
		}
	}
	return updated
}
