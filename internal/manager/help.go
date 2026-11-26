package manager

import (
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/cli"
)

type helpEntry struct{ command, description string }

type helpGroup struct {
	name    string
	entries []helpEntry
}

// Everyday commands, grouped by what someone is trying to do.
var helpGroups = []helpGroup{
	{"Getting started", []helpEntry{
		{"setup", "Set up NeoAgent, step by step"},
		{"account create", "Make the first account"},
		{"login", "Connect an AI account you already have"},
		{"migrate", "Move over from OpenClaw or Hermes Agent"},
	}},
	{"Everyday", []helpEntry{
		{"status", "Is everything working?"},
		{"update", "Get the latest version — your data stays"},
		{"restart", "Turn it off and on again"},
	}},
	{"When something's wrong", []helpEntry{
		{"doctor", "Find problems and explain them"},
		{"repair", "Fix common problems for you"},
		{"logs", "See what NeoAgent is doing right now"},
	}},
	{"Your data", []helpEntry{
		{"backup", "Save a copy of your settings and chats"},
		{"start · stop", "Turn NeoAgent on or off"},
		{"uninstall", "Stop NeoAgent starting with your computer"},
	}},
}

// Every command and flag, for developers and admins.
var helpReference = []helpGroup{
	{"Setup", []helpEntry{
		{"install", "Install dependencies, settings and the background service"},
		{"install --channel stable|beta", "Install from a release channel"},
		{"setup --quick", "Apply safe defaults"},
		{"setup --full", "Configure every setup section"},
		{"setup --resume", "Continue an interrupted setup"},
		{"--json", "Write versioned JSON events instead of text (install, setup, status, doctor)"},
	}},
	{"Running", []helpEntry{
		{"start · stop · restart", "Control the background service"},
		{"status --details", "Health plus install folder, versions and process IDs"},
		{"doctor", "Read-only diagnostics"},
		{"logs", "Follow the server logs"},
		{"backup", "Snapshot settings, data and computer disks"},
		{"restore <backup folder>", "Put a backup back; the current data is saved first"},
		{"repair [--runtime-package]", "Back up, reinstall dependencies and restart"},
		{"uninstall", "Remove the background service"},
	}},
	{"Updates", []helpEntry{
		{"update [stable|beta]", "Update, optionally switching channel; rolls back if it fails"},
		{"update --notes (or --check)", "See whether a newer version is ready, without updating"},
		{"channel [stable|beta]", "Show or switch the release channel"},
		{"version", "Print the installed version"},
		{"rebuild-web", "Rebuild the bundled Flutter web client"},
	}},
	{"Accounts & AI", []helpEntry{
		{"login claude-code|openai-codex|github-copilot|grok-oauth", "Sign in to an AI account"},
		{"account create --username U --password P", "Create the first account"},
		{"reset-password <username>", "Set a new password and sign the account out"},
		{"admin [grant|revoke <user>]", "List or change admins"},
		{"messaging setup telegram|whatsapp", "Set up an instance-wide account people can link to"},
		{"messaging list|disconnect|remove", "See or change shared messaging accounts"},
	}},
	{"Configuration", []helpEntry{
		{"env list|get|set|unset", "Read or change settings (secrets masked)"},
		{"migrate [openclaw|hermes] [--dry-run] [--from DIR] [--yes]", "Import from OpenClaw or Hermes Agent"},
	}},
	{"Automation", []helpEntry{
		{`exec "<task>"`, "Run one task in this folder on this computer, then exit"},
		{"exec --model M --provider P", `Pick the model ("provider/model" works with --model alone)`},
		{"exec --allow-all-tools --yes", "Skip approval prompts and the local-run warning"},
	}},
	{"Server", []helpEntry{
		{"serve", "Run the server in the foreground"},
		{"healthcheck", "Exit 0 when the server answers (containers)"},
	}},
}

func (a *App) printGroupColumns(groups []helpGroup) {
	u := a.UI
	columns := make([][]string, len(groups))
	columnWidth := 0
	for i, g := range groups {
		col := []string{u.Accent(u.Bold(g.name))}
		for _, e := range g.entries {
			col = append(col, u.Bold("neoagent "+e.command), u.Muted(e.description))
		}
		for _, line := range col {
			columnWidth = max(columnWidth, cli.VisibleLength(line))
		}
		columns[i] = col
	}
	columnWidth += 4
	perRow := 1
	if u.Width() > 2+columnWidth*2 {
		perRow = 2
	}
	for i := 0; i < len(columns); i += perRow {
		left, right := columns[i], []string(nil)
		if perRow == 2 && i+1 < len(columns) {
			right = columns[i+1]
		}
		u.Blank()
		for row := 0; row < max(len(left), len(right)); row++ {
			l, r := "", ""
			if row < len(left) {
				l = left[row]
			}
			if row < len(right) {
				r = right[row]
			}
			u.Print(strings.TrimRight("  "+cli.PadEnd(l, columnWidth)+r, " "))
		}
	}
}

func (a *App) printHelp(all bool) {
	u := a.UI
	if all {
		u.Title("Every neoagent command", "")
		for _, g := range helpReference {
			u.Section(u.Accent(g.name))
			for _, e := range g.entries {
				u.Print("  " + cli.PadEnd("neoagent "+e.command, 48) + "  " + u.Muted(e.description))
			}
		}
		u.Blank()
		return
	}
	u.Title("Here's what you can do", "Not sure? Just type neoagent and pick from a menu.")
	a.printGroupColumns(helpGroups)
	u.Blank()
	u.Print("  " + u.Muted("More for developers and admins:") + " " + u.Command("neoagent help --all"))
	u.Blank()
}
