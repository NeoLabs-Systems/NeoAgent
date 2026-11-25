package runtime

import (
	"embed"
	"encoding/json"
	"fmt"
	"path"
	"regexp"
	"strings"
)

//go:embed all:assets/guest
var guestAssets embed.FS

// GuestFile is a file the guest image carries.
type GuestFile struct {
	Path    string
	Content string
	Mode    string
}

type guestManifest struct {
	System []manifestEntry `json:"system"`
	Home   []manifestEntry `json:"home"`
}

type manifestEntry struct {
	Path string `json:"path"`
	Mode string `json:"mode"`
}

func loadGuestFiles(entries func(guestManifest) []manifestEntry) []GuestFile {
	raw, err := guestAssets.ReadFile("assets/guest/manifest.json")
	if err != nil {
		panic(fmt.Sprintf("guest asset manifest: %v", err))
	}
	var manifest guestManifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		panic(fmt.Sprintf("guest asset manifest: %v", err))
	}
	var files []GuestFile
	for _, entry := range entries(manifest) {
		content, err := guestAssets.ReadFile("assets/guest/rootfs" + entry.Path)
		if err != nil {
			panic(fmt.Sprintf("guest asset %s: %v", entry.Path, err))
		}
		files = append(files, GuestFile{Path: entry.Path, Content: string(content), Mode: entry.Mode})
	}
	return files
}

// GuestDesktopSystemFiles are the system-wide files of the guest's desktop:
// helper scripts, units, window manager and panel configuration.
func GuestDesktopSystemFiles() []GuestFile {
	return loadGuestFiles(func(m guestManifest) []manifestEntry { return m.System })
}

// GuestDesktopHomeFiles are the files the desktop session puts in the user's home.
func GuestDesktopHomeFiles() []GuestFile {
	return loadGuestFiles(func(m guestManifest) []manifestEntry { return m.Home })
}

var homePrefix = regexp.MustCompile(`^/home/neo`)

// GuestDesktopSkelFiles are the home files as a skeleton the image keeps under
// /usr/share/neoagent/desktop-skel, copied into the home disk on every start.
func GuestDesktopSkelFiles() []GuestFile {
	files := GuestDesktopHomeFiles()
	for i := range files {
		files[i].Path = "/usr/share/neoagent/desktop-skel" + homePrefix.ReplaceAllString(files[i].Path, "")
	}
	return files
}

// GuestDesktopBringUpScript is the root script that installs and starts the
// guest's graphical session and prints DESKTOP_READY or diagnostics.
func GuestDesktopBringUpScript() string {
	raw, err := guestAssets.ReadFile("assets/guest/desktop-bringup.sh")
	if err != nil {
		panic(fmt.Sprintf("guest asset desktop-bringup.sh: %v", err))
	}
	return string(raw)
}

// GuestDesktopRepairCommand runs the bring-up script as root in a guest.
func GuestDesktopRepairCommand() string {
	return "sudo -n /bin/sh -c " + jsString(GuestDesktopBringUpScript())
}

var (
	repairNoise      = regexp.MustCompile(`(?i)systemd-sysv-install|Synchronizing state of \S+ with SysV|Executing:\s*/usr/lib/systemd/systemd-sysv-install`)
	repairSection    = regexp.MustCompile(`^--- `)
	repairDiagnostic = regexp.MustCompile(`(?i)\(EE\)|Failed|failed|error|fatal|not found|No screens`)
	whitespaceRun    = regexp.MustCompile(`\s+`)
	lineBreak        = regexp.MustCompile(`\r?\n`)
)

const defaultDesktopFailure = "The Linux graphical session is not running."

// SummarizeDesktopRepairOutput turns the output of the repair command into the
// desktop state clients see: available, or an error naming what went wrong.
func SummarizeDesktopRepairOutput(stdout, stderr, fallback string) *omap {
	if strings.Contains(stdout, "DESKTOP_READY") {
		return obj("available", true, "error", nil)
	}
	var parts []string
	for _, p := range []string{stdout, stderr} {
		if p != "" {
			parts = append(parts, p)
		}
	}
	combined := strings.Join(parts, "\n")
	diagnostic := combined
	if i := strings.Index(combined, "DESKTOP_FAILED"); i >= 0 {
		diagnostic = combined[i+len("DESKTOP_FAILED"):]
	}
	var lines []string
	for _, line := range lineBreak.Split(diagnostic, -1) {
		line = strings.TrimSpace(line)
		if line != "" && !repairNoise.MatchString(line) && !repairSection.MatchString(line) {
			lines = append(lines, line)
		}
	}
	var preferred []string
	for _, line := range lines {
		if repairDiagnostic.MatchString(line) {
			preferred = append(preferred, line)
		}
	}
	pick := lines
	if len(preferred) > 0 {
		pick = preferred
	}
	if len(pick) > 8 {
		pick = pick[len(pick)-8:]
	}
	picked := strings.TrimSpace(whitespaceRun.ReplaceAllString(strings.Join(pick, " "), " "))
	fallback = strings.TrimSpace(fallback)
	if fallback == "" {
		fallback = defaultDesktopFailure
	}
	if picked == "" {
		picked = fallback
	}
	if runes := []rune(picked); len(runes) > 500 {
		// JavaScript slices UTF-16 code units; the text here is ASCII diagnostics.
		picked = string(runes[:500])
	}
	return obj("available", false, "error", picked)
}

// RenderDesktopFileCommands writes files from a shell script with here-documents.
func RenderDesktopFileCommands(files []GuestFile) []string {
	var commands []string
	for _, file := range files {
		delimiter := fmt.Sprintf("NEOAGENT_FILE_%d", len(commands))
		lines := map[string]bool{}
		for _, line := range strings.Split(file.Content, "\n") {
			lines[line] = true
		}
		for lines[delimiter] {
			delimiter += "_"
		}
		commands = append(commands,
			"install -d -m 0755 "+jsString(path.Dir(file.Path)),
			"cat > "+jsString(file.Path)+" <<'"+delimiter+"'",
			strings.TrimSuffix(file.Content, "\n"),
			delimiter,
			"chmod "+file.Mode+" "+jsString(file.Path),
		)
	}
	return commands
}

// RenderDesktopCloudInitWriteFiles lists files as cloud-init write_files items.
func RenderDesktopCloudInitWriteFiles(files []GuestFile, indent string) []string {
	var out []string
	for _, file := range files {
		out = append(out,
			indent+"- path: "+file.Path,
			indent+"  permissions: '"+file.Mode+"'",
			indent+"  owner: root:root",
			indent+"  content: |",
		)
		for _, line := range strings.Split(strings.TrimSuffix(file.Content, "\n"), "\n") {
			out = append(out, indent+"    "+line)
		}
	}
	return out
}
