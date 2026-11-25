package manager

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/admin"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

// The setup wizard's stages, shown as a progress bar above each screen.
var setupStages = []string{"Welcome", "AI", "Install", "Done"}

func (a *App) printSetupProgress(current int) {
	u := a.UI
	u.Blank()
	if u.IsNarrow() {
		u.Print("  " + u.Faint(fmt.Sprintf("Step %d of %d ·", current+1, len(setupStages))) + " " + u.Command(setupStages[current]))
		return
	}
	const segment = 12
	bars := make([]string, len(setupStages))
	var labels strings.Builder
	for i, name := range setupStages {
		if i <= current {
			bars[i] = u.Accent(strings.Repeat("━", segment-1))
		} else {
			bars[i] = u.SGR(u.Foreground("unlit"), strings.Repeat("━", segment-1))
		}
		text := cli.PadEnd(name, segment)
		switch {
		case i == current:
			labels.WriteString(u.Command(text))
		case i < current:
			labels.WriteString(u.Muted(text))
		default:
			labels.WriteString(u.Faint(text))
		}
	}
	u.Print("  " + strings.Join(bars, " "))
	u.Print(strings.TrimRight("  "+labels.String(), " "))
}

// statusFacts is what `neoagent status` and the home screen know about this
// installation.
type statusFacts struct {
	Port             int
	URL              string
	Running          bool
	Version          string
	RunningVersion   string
	Channel          string
	ServiceActive    bool
	ConfigPresent    bool
	WebClientPresent bool
	ComputerReady    bool
	ComputerDetail   string
	Admins           *adminFacts
	PIDs             []int
	Update           string // the newer version that is ready, if any
	UpdateChecked    bool
}

type adminFacts struct {
	Names   []string
	Missing bool
}

func (a *App) collectStatusFacts(ctx context.Context, checkForUpdate bool) statusFacts {
	port := a.Port()
	f := statusFacts{Port: port, URL: fmt.Sprintf("http://localhost:%d", port), Running: cli.PortOpen(port), Version: version(), Channel: a.channel()}
	if f.Running {
		if h := fetchHandshake(ctx, port); h != nil {
			f.RunningVersion = h.ServerVersion
		}
	}
	f.ServiceActive = a.Service.Active()
	f.ConfigPresent = exists(a.Paths.EnvFile)
	f.WebClientPresent = exists(filepath.Join(a.AppDir, "public", "index.html"))
	f.ComputerReady, _, _, f.ComputerDetail = a.computerReadiness()
	// Reading admins opens the database, so only do it once one exists.
	if exists(a.dbPath()) {
		if db, err := a.openDB(ctx); err == nil {
			store := &admin.Store{DB: db}
			if list, err := store.ListAdmins(ctx); err == nil {
				f.Admins = &adminFacts{}
				for _, adm := range list {
					f.Admins.Names = append(f.Admins.Names, adm.Username)
				}
				f.Admins.Missing, _ = store.NeedsAdminGrant(ctx)
			}
			db.Close()
		}
	}
	for _, p := range a.serverProcesses() {
		f.PIDs = append(f.PIDs, p.PID)
	}
	if checkForUpdate {
		if available, err := a.findRuntime(ctx, f.Channel); err == nil {
			f.UpdateChecked = true
			if release.CompareVersions(available.Version, f.Version) > 0 {
				f.Update = available.Version
			}
		}
	}
	return f
}

// statusCheck is one plain-language health check; Fix is a command to run.
type statusCheck struct {
	ID, Tone, Label, Detail, Fix string
}

func statusChecks(f statusFacts) []statusCheck {
	var checks []statusCheck
	if f.Running {
		checks = append(checks, statusCheck{ID: "server", Tone: "ok", Label: "NeoAgent", Detail: "Running at " + f.URL})
	} else {
		checks = append(checks, statusCheck{ID: "server", Tone: "error", Label: "NeoAgent", Detail: "Not running", Fix: "neoagent start"})
	}
	if f.RunningVersion != "" && f.RunningVersion != f.Version {
		checks = append(checks, statusCheck{Tone: "warn", Label: "Restart needed",
			Detail: fmt.Sprintf("%s is installed, but %s is still running", f.Version, f.RunningVersion), Fix: "neoagent restart"})
	}
	if len(f.PIDs) > 1 {
		checks = append(checks, statusCheck{Tone: "warn", Label: "Extra copies",
			Detail: fmt.Sprintf("%d copies of NeoAgent are running", len(f.PIDs)), Fix: "neoagent restart"})
	}
	if f.ServiceActive {
		checks = append(checks, statusCheck{Tone: "ok", Label: "Starts automatically", Detail: "Turns on when your computer does"})
	} else {
		checks = append(checks, statusCheck{Tone: "warn", Label: "Starts automatically", Detail: "Not set up on this computer", Fix: "neoagent install"})
	}
	if f.ConfigPresent {
		checks = append(checks, statusCheck{Tone: "ok", Label: "Settings", Detail: "Saved"})
	} else {
		checks = append(checks, statusCheck{Tone: "error", Label: "Settings", Detail: "Not set up yet", Fix: "neoagent setup"})
	}
	if f.ComputerReady {
		checks = append(checks, statusCheck{Tone: "ok", Label: "Agent's computer", Detail: f.ComputerDetail})
	} else {
		checks = append(checks, statusCheck{Tone: "warn", Label: "Agent's computer", Detail: "Needs to be prepared", Fix: "neoagent repair"})
	}
	if f.WebClientPresent {
		checks = append(checks, statusCheck{Tone: "ok", Label: "App in your browser", Detail: "Installed"})
	} else {
		checks = append(checks, statusCheck{Tone: "error", Label: "App in your browser", Detail: "Missing", Fix: "neoagent repair"})
	}
	if f.Admins != nil {
		switch {
		case f.Admins.Missing:
			checks = append(checks, statusCheck{Tone: "warn", Label: "Admin account", Detail: "No account is an admin", Fix: "neoagent admin grant <username>"})
		case len(f.Admins.Names) > 0:
			checks = append(checks, statusCheck{Tone: "ok", Label: "Accounts", Detail: "Admin: " + strings.Join(f.Admins.Names, ", ")})
		default:
			checks = append(checks, statusCheck{Tone: "ok", Label: "Accounts", Detail: "The first account you create becomes the admin"})
		}
	}
	if f.Update != "" {
		checks = append(checks, statusCheck{ID: "version", Tone: "warn", Label: "Version " + f.Version,
			Detail: "A newer version (" + f.Update + ") is ready", Fix: "neoagent update"})
	} else {
		detail := ""
		if f.UpdateChecked {
			detail = "Up to date"
		}
		checks = append(checks, statusCheck{ID: "version", Tone: "ok", Label: "Version " + f.Version, Detail: detail})
	}
	return checks
}

func needsAttention(c statusCheck) bool { return c.Tone == "warn" || c.Tone == "error" }

func statusHeadline(f statusFacts, checks []statusCheck) (tone, text string) {
	if !f.Running {
		return "error", "NeoAgent isn't running"
	}
	suggestions := 0
	for _, c := range checks {
		if c.Tone == "error" {
			return "error", "NeoAgent needs attention"
		}
		if c.Tone == "warn" {
			suggestions++
		}
	}
	switch {
	case suggestions == 1:
		return "warn", "Running — 1 thing needs a look"
	case suggestions > 1:
		return "warn", fmt.Sprintf("Running — %d things need a look", suggestions)
	}
	return "ok", "Everything's working"
}

const statusLabelWidth = 24

// printChecks shows label and detail side by side, or the detail under its
// label when the window is narrow. A failed check says how to fix it.
func (a *App) printChecks(checks []statusCheck) {
	u := a.UI
	narrow := u.IsNarrow()
	indent := statusLabelWidth + 6
	if narrow {
		indent = 4
	}
	u.Blank()
	for _, c := range checks {
		if narrow {
			u.Item(c.Tone, u.Bold(c.Label), "")
			if c.Detail != "" {
				u.Paragraph(c.Detail, indent, u.Muted)
			}
		} else {
			u.ItemWidth(c.Tone, u.Bold(c.Label), c.Detail, statusLabelWidth)
		}
		if c.Fix != "" {
			u.Print(strings.Repeat(" ", indent) + u.Faint("run") + " " + u.Command(c.Fix))
		}
	}
}

func (a *App) printStatus(f statusFacts, details bool) {
	u := a.UI
	checks := statusChecks(f)
	tone, text := statusHeadline(f, checks)
	u.Blank()
	u.Print("  " + u.InTone(tone, cli.Tones[tone].Mark) + " " + u.Bold(text))
	// The headline already says whether NeoAgent runs.
	if f.Running {
		u.Print("    " + u.Accent(f.URL))
	} else {
		u.Print("    " + u.Faint("run") + " " + u.Command("neoagent start"))
	}
	shown := checks
	if !details {
		shown = nil
		for _, c := range checks {
			if c.ID != "server" && needsAttention(c) {
				shown = append(shown, c)
			}
		}
	}
	if len(shown) > 0 {
		a.printChecks(shown)
	}
	if details {
		u.Section("Details")
		running := f.RunningVersion
		if running == "" {
			running = "not running"
		}
		pids := make([]string, len(f.PIDs))
		for i, p := range f.PIDs {
			pids[i] = fmt.Sprint(p)
		}
		pidText := strings.Join(pids, ", ")
		if pidText == "" {
			pidText = "none"
		}
		for _, row := range [][2]string{
			{"Installed in", a.AppDir},
			{"Version", f.Version},
			{"Running version", running},
			{"Release channel", release.ChannelLabel(f.Channel)},
			{"Settings file", a.Paths.EnvFile},
			{"Port", fmt.Sprint(f.Port)},
			{"Process IDs", pidText},
		} {
			u.Print("  " + cli.PadEnd(u.Faint(row[0]), 18) + row[1])
		}
	}
	u.Blank()
}

// The first few problems in a column; the rest are one status away.
const problemsShown = 3

func (a *App) printProblems(problems []statusCheck) {
	u := a.UI
	shown := problems[:min(len(problems), problemsShown)]
	width := 0
	for _, p := range shown {
		width = max(width, cli.VisibleLength(p.Label))
	}
	width += 2
	for _, p := range shown {
		u.ItemWidth(p.Tone, p.Label, p.Detail, width)
	}
	if len(problems) > len(shown) {
		u.Print("    " + u.Faint(fmt.Sprintf("and %d more —", len(problems)-len(shown))) + " " + u.Command("neoagent status"))
	}
}

// printHomeHeader shows the mascot beside one line of state and the address,
// then only the checks that need attention: the menu below covers the rest.
func (a *App) printHomeHeader(f statusFacts, problems []statusCheck) {
	u := a.UI
	lines := []string{u.Bold("NeoAgent isn't running"), u.Faint("run") + " " + u.Command("neoagent start")}
	if f.Running {
		lines = []string{u.Bold("NeoAgent is running"), u.Accent(f.URL)}
	}
	u.Blank()
	u.Columns(renderFace(u, "idle"), lines, 3)
	if len(problems) > 0 {
		u.Blank()
		a.printProblems(problems)
	}
}

// printSetupFinished is the last setup screen: where NeoAgent is, and anything
// left to do.
func (a *App) printSetupFinished(url string, startsItself, hasAccount bool, notes []string) {
	u := a.UI
	runs := "NeoAgent is running."
	if startsItself {
		runs = "NeoAgent starts by itself with your computer."
	}
	next := "and create your account."
	if hasAccount {
		next = "and sign in."
	}
	u.Blank()
	u.Columns(renderFace(u, "done"), []string{
		u.Bold("You're all set"),
		u.Muted(runs),
		"",
		"Open " + u.Accent(url),
		u.Muted(next),
	}, 3)
	if len(notes) > 0 {
		u.Blank()
		for _, n := range notes {
			u.Item("info", n, "")
		}
	}
	u.Blank()
}
