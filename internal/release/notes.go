package release

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Markers around the download section of a release's notes.
const (
	notesStart = "<!-- neoagent-download:start -->"
	notesEnd   = "<!-- neoagent-download:end -->"
)

type appSlot struct {
	id, label, detail, badgeLabel, badgeMessage, badgeLogo, readyColor string
	pattern                                                            *regexp.Regexp
}

// appSlots are the installers shown as badges, in display order. The first
// pattern that matches an asset name wins (the launcher APK before the APK).
var appSlots = []appSlot{
	{"macos-arm64", "macOS", "Apple Silicon", "macOS", "Apple_Silicon", "apple", "1c2117", regexp.MustCompile(`^neoagent-macos-arm64-.+\.dmg$`)},
	{"macos-x64", "macOS", "Intel", "macOS", "Intel", "apple", "1c2117", regexp.MustCompile(`^neoagent-macos-x64-.+\.dmg$`)},
	{"windows-x64", "Windows", "x64 installer", "Windows", "x64", "windows", "0078d4", regexp.MustCompile(`^neoagent-windows-x64-setup-.+\.exe$`)},
	{"windows-arm64", "Windows", "ARM64 installer", "Windows", "ARM64", "windows", "0078d4", regexp.MustCompile(`^neoagent-windows-arm64-setup-.+\.exe$`)},
	{"linux-appimage", "Linux", "AppImage", "Linux", "AppImage", "linux", "2f7d6e", regexp.MustCompile(`^neoagent-linux-x86_64-.+\.AppImage$`)},
	{"linux-deb", "Linux", "Debian / Ubuntu", "Linux", "deb", "debian", "a80030", regexp.MustCompile(`^neoagent-linux-amd64-.+\.deb$`)},
	{"linux-arch", "Linux", "Arch", "Linux", "Arch", "archlinux", "1793d1", regexp.MustCompile(`^neoagent-arch-x86_64-.+\.pkg\.tar\.zst$`)},
	{"android", "Android", "APK", "Android", "APK", "android", "3ddc84", regexp.MustCompile(`^neoagent-android-.+\.apk$`)},
	{"android-launcher", "Android", "Launcher APK", "Android", "Launcher", "android", "3ddc84", regexp.MustCompile(`^neoagent-android-launcher-.+\.apk$`)},
}

func classify(name string) string {
	if appSlots[8].pattern.MatchString(name) {
		return "android-launcher"
	}
	for _, s := range appSlots {
		if s.pattern.MatchString(name) {
			return s.id
		}
	}
	return ""
}

// ReleaseAsset is an uploaded asset as the GitHub API lists it.
type ReleaseAsset struct {
	Name string `json:"name"`
	URL  string `json:"browser_download_url"`
}

func encodeURIComponent(s string) string {
	return strings.NewReplacer("+", "%20", "%21", "!", "%27", "'", "%28", "(", "%29", ")", "%2A", "*", "%7E", "~").Replace(url.QueryEscape(s))
}

func badge(label, message, color, logo string) string {
	return "https://img.shields.io/badge/" + encodeURIComponent(label) + "-" + encodeURIComponent(message) + "-" + color +
		"?style=for-the-badge&logo=" + encodeURIComponent(logo) + "&logoColor=white"
}

// DownloadNotes renders the download badge section for a release.
func DownloadNotes(tag, repository string, assets []ReleaseAsset) string {
	if repository = strings.TrimSpace(repository); repository == "" {
		repository = Repository
	}
	ready := map[string]string{}
	for _, a := range assets {
		id := classify(a.Name)
		if id == "" {
			continue
		}
		u := a.URL
		if u == "" {
			u = fmt.Sprintf("https://github.com/%s/releases/download/%s/%s", repository, encodeURIComponent(tag), encodeURIComponent(a.Name))
		}
		ready[id] = u
	}
	releaseURL := fmt.Sprintf("https://github.com/%s/releases/tag/%s", repository, encodeURIComponent(tag))
	var badges []string
	for _, s := range appSlots {
		href, color, message := releaseURL, "6b7280", "building"
		if u, ok := ready[s.id]; ok {
			href, color, message = u, s.readyColor, s.badgeMessage
		}
		badges = append(badges, fmt.Sprintf(`<a href="%s"><img alt="%s %s" src="%s"></a>`, href, s.label, s.detail, badge(s.badgeLabel, message, color, s.badgeLogo)))
	}
	status := "Every desktop and Android app for this release is ready."
	switch {
	case len(ready) == 0:
		status = "Installers are publishing now. Each platform appears here as soon as its build finishes."
	case len(ready) < len(appSlots):
		status = "Ready apps download in one click. Remaining platforms attach as soon as their builds finish."
	}
	return strings.Join([]string{
		notesStart, "", `<p align="center">`, "  <strong>Download NeoAgent " + tag + "</strong>", "</p>", "",
		`<p align="center">`, "  " + strings.Join(badges, "\n  "), "</p>", "",
		`<p align="center"><sub>` + status + `</sub></p>`, "", "---", "", notesEnd,
	}, "\n")
}

// MergeDownloadNotes replaces the download section in body, or puts it first.
func MergeDownloadNotes(body, section string) string {
	current := strings.TrimPrefix(body, "\uFEFF")
	section = strings.TrimSpace(section)
	if section == "" {
		return current
	}
	start, end := strings.Index(current, notesStart), strings.Index(current, notesEnd)
	if start >= 0 && end > start {
		before := strings.TrimRight(current[:start], " \t\r\n")
		after := strings.TrimLeft(current[end+len(notesEnd):], " \t\r\n")
		var parts []string
		for _, p := range []string{before, section, after} {
			if p != "" {
				parts = append(parts, p)
			}
		}
		return strings.TrimSpace(strings.Join(parts, "\n\n")) + "\n"
	}
	if strings.TrimSpace(current) == "" {
		return section + "\n"
	}
	return section + "\n\n" + strings.TrimLeft(current, " \t\r\n")
}

// UpdateDownloadNotes rewrites the download section of a published release
// through the gh CLI. It returns whether the notes changed.
func UpdateDownloadNotes(ctx context.Context, tag, repository string, dryRun bool) (bool, string, error) {
	out, err := exec.CommandContext(ctx, "gh", "api", "repos/"+repository+"/releases/tags/"+tag).Output()
	if err != nil {
		return false, "", fmt.Errorf("gh api: %w", err)
	}
	var rel struct {
		Body   string         `json:"body"`
		Assets []ReleaseAsset `json:"assets"`
	}
	if err := json.Unmarshal(out, &rel); err != nil {
		return false, "", err
	}
	next := MergeDownloadNotes(rel.Body, DownloadNotes(tag, repository, rel.Assets))
	if next == strings.TrimSpace(strings.TrimPrefix(rel.Body, "\uFEFF"))+"\n" {
		return false, next, nil
	}
	if dryRun {
		return true, next, nil
	}
	notes := filepath.Join(os.TempDir(), "neoagent-release-notes-"+strconv.Itoa(os.Getpid())+".md")
	if err := os.WriteFile(notes, []byte(next), 0o600); err != nil {
		return false, "", err
	}
	defer os.Remove(notes)
	cmd := exec.CommandContext(ctx, "gh", "release", "edit", tag, "--repo", repository, "--notes-file", notes)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return true, next, cmd.Run()
}

// WebBuildID is NEOAGENT_WEB_BUILD_ID when set, else base36 milliseconds and
// the short commit.
func WebBuildID(getenv func(string) string, now time.Time) string {
	if v := strings.TrimSpace(getenv("NEOAGENT_WEB_BUILD_ID")); v != "" {
		return v
	}
	sha := "nogit"
	if out, err := exec.Command("git", "rev-parse", "--short", "HEAD").Output(); err == nil {
		sha = strings.TrimSpace(string(out))
	}
	return strconv.FormatInt(now.UnixMilli(), 36) + "-" + sha
}
