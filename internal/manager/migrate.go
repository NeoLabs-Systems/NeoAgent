package manager

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentimport"
	"github.com/NeoLabs-Systems/neoagent/internal/wiring"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
)

type migrateOptions struct {
	from, only string
	preview    bool
	help       bool
	yes        bool
}

func parseMigrateArguments(args []string) (migrateOptions, error) {
	var o migrateOptions
	for i := 0; i < len(args); i++ {
		switch arg := args[i]; arg {
		case "--from":
			if i+1 >= len(args) || strings.HasPrefix(args[i+1], "--") {
				return o, fmt.Errorf("Usage: neoagent migrate --from <folder>")
			}
			i++
			o.from = args[i]
		case "--yes", "-y":
			o.yes = true
		case "--dry-run", "dry-run", "status":
			o.preview = true
		case "openclaw", "hermes":
			o.only = arg
		case "--help", "-h", "help":
			o.help = true
		case "--json":
		default:
			return o, fmt.Errorf("Unknown option: %s. See `neoagent migrate --help`.", arg)
		}
	}
	return o, nil
}

func plural(n int, word, many string) string {
	if n == 1 {
		return fmt.Sprintf("1 %s", word)
	}
	return fmt.Sprintf("%d %s", n, many)
}

func (a *App) printSourceCard(s agentimport.SourceView) {
	a.UI.Blank()
	home, _ := os.UserHomeDir()
	a.UI.Print("  %s  %s", a.UI.Bold(s.Label), a.UI.Muted(strings.Replace(s.Path, home, "~", 1)))
	for _, c := range s.Contents {
		label, detail := "", strings.Join(c.Names, ", ")
		switch c.Part {
		case "agents":
			label = plural(c.Count, "agent", "agents")
		case "memories":
			label, detail = plural(c.Count, "memory", "memories"), ""
			if c.Days != nil && *c.Days > 0 {
				detail = "and " + plural(*c.Days, "day", "days") + " of notes"
			}
		case "skills":
			label = plural(c.Count, "skill", "skills")
		case "keys":
			label = plural(c.Count, "connection", "connections")
		case "model":
			label = "Model"
		case "tasks":
			label = plural(c.Count, "automation", "automations")
		case "mcp":
			label = plural(c.Count, "MCP server", "MCP servers")
		default:
			label = "Chat apps"
		}
		a.UI.Item("ok", label, detail)
	}
	if s.NeedsHand > 0 {
		a.UI.Item("warn", plural(s.NeedsHand, "thing needs", "things need")+" a hand", "listed in the report")
	}
}

func (a *App) migrateHelp() {
	a.UI.Title("neoagent migrate", "Bring OpenClaw or Hermes Agent over to NeoAgent")
	for _, line := range [][2]string{
		{"neoagent migrate", "Find both on this computer, preview, then import"},
		{"neoagent migrate --dry-run", "Only show what would come over"},
		{"neoagent migrate openclaw", "Only OpenClaw (or: hermes)"},
		{"neoagent migrate --from <folder>", "A copied or non-default folder"},
		{"neoagent migrate --yes", "No questions: import everything and restart"},
	} {
		a.UI.Print("  %-36s%s", a.UI.Command(line[0]), a.UI.Muted(line[1]))
	}
	a.UI.Note("Nothing is removed from the old agent, and running it twice does not duplicate anything.")
}

// cmdMigrate copies an OpenClaw or Hermes Agent installation into an account:
// keys, agents, memory, skills, model, automations, MCP servers and chat apps.
func (a *App) cmdMigrate(ctx context.Context, args []string) error {
	o, err := parseMigrateArguments(args)
	if err != nil {
		return err
	}
	if o.help {
		a.migrateHelp()
		return nil
	}
	scanner := agentimport.Scanner{Getenv: os.Getenv}
	if o.from != "" {
		home, _ := os.UserHomeDir()
		dir := o.from
		if dir == "~" || strings.HasPrefix(dir, "~/") {
			dir = filepath.Join(home, strings.TrimPrefix(dir, "~"))
		}
		if dir, err = filepath.Abs(dir); err != nil {
			return err
		}
		if agentimport.SourceKind(dir) == "" {
			return fmt.Errorf("%s does not look like an OpenClaw or Hermes Agent folder.", dir)
		}
		scanner.From = dir
	}
	if !exists(a.dbPath()) {
		return fmt.Errorf("NeoAgent is not set up yet. Run `neoagent setup` first.")
	}
	if a.boot == nil {
		return fmt.Errorf("neoagent migrate is not available in this build")
	}
	// The import writes through the app's own domains; its background
	// services stay off, since the server may be running alongside.
	restart := false
	err = a.boot(ctx, false, func(ctx context.Context, app *wiring.App) error {
		importer := app.Importer(scanner)
		all, aiReady := importer.Sources()
		var sources []agentimport.SourceView
		for _, s := range all {
			if o.only == "" || s.Source == o.only {
				sources = append(sources, s)
			}
		}
		a.UI.Title("Bring your agent to NeoAgent", "Everything is copied. The old agent keeps working as it did.")
		if len(sources) == 0 {
			a.UI.Item("info", "No OpenClaw or Hermes Agent found", "looked in ~/.openclaw and ~/.hermes")
			a.UI.Note("If it lives somewhere else, run " + a.UI.Command("neoagent migrate --from <folder>") + ".")
			return nil
		}
		for _, s := range sources {
			a.printSourceCard(s)
		}
		if o.preview {
			a.UI.Note("Run " + a.UI.Command("neoagent migrate") + " to bring it over.")
			return nil
		}
		if len(sources) > 1 && !o.yes {
			choices := []cli.Choice{{Value: "all", Label: "Everything above", Hint: "recommended"}}
			for _, s := range sources {
				choices = append(choices, cli.Choice{Value: s.ID, Label: "Only " + s.Label, Hint: s.Path})
			}
			choices = append(choices, cli.Choice{Value: "", Label: "Cancel"})
			picked, err := a.UI.Select("What should come over?", choices)
			if err != nil || picked == "" {
				return err
			}
			if picked != "all" {
				for _, s := range sources {
					if s.ID == picked {
						sources = []agentimport.SourceView{s}
					}
				}
			}
		}
		userID, err := a.importAccount(ctx, o.yes)
		if err != nil {
			return err
		}
		finish := o.yes
		if !o.yes && a.UI.Interactive() {
			a.UI.Note("NeoAgent can then look at what was left behind and rebuild what it can itself: automations, MCP servers and rules worth remembering.")
			if finish, err = a.UI.Confirm("Let NeoAgent finish moving in afterwards?", true); err != nil {
				return err
			}
		}
		if finish && !aiReady {
			a.UI.Note("The finish needs an AI; connect one (`neoagent login` or `neoagent setup`), then run `neoagent migrate` again.")
		}
		if err := a.UI.Step("Saving a backup of NeoAgent", "Saved a backup of NeoAgent", func() error {
			_, err := a.backupRuntimeData(ctx, "pre-import")
			return err
		}); err != nil {
			return err
		}
		ids := make([]string, len(sources))
		for i, s := range sources {
			ids[i] = s.ID
		}
		var summary agentimport.Summary
		if err := a.UI.Step("Bringing it over", "Brought it over", func() (err error) {
			summary, err = importer.RunImport(ctx, userID, ids, agentimport.Parts, finish)
			return err
		}); err != nil {
			return err
		}
		a.printImportSummary(summary)
		restart = summary.RestartRequired
		if a.JSON {
			return cli.WriteJSONLine(a.Out, summary)
		}
		return nil
	})
	if err != nil || !restart {
		return err
	}
	if !a.Service.Managed() {
		a.UI.Note("Start NeoAgent with " + a.UI.Command("neoagent start") + " to load everything.")
		return nil
	}
	if !o.yes {
		if ok, err := a.UI.Confirm("Restart NeoAgent now to load everything?", true); err != nil || !ok {
			a.UI.Note("Everything loads at the next " + a.UI.Command("neoagent restart") + ".")
			return err
		}
	}
	return a.cmdRestart(ctx, nil)
}

func (a *App) printImportSummary(s agentimport.Summary) {
	headline := "Already moved in"
	if len(s.BroughtOver) > 0 {
		headline = "Moved in"
	}
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold(headline), "")
	if len(s.BroughtOver) > 0 {
		a.UI.Section("Brought over")
		for _, line := range s.BroughtOver {
			a.UI.Item("ok", line, "")
		}
		if s.AlreadyThere > 0 {
			a.UI.Item("info", fmt.Sprintf("%d already in NeoAgent", s.AlreadyThere), "left as they were")
		}
	}
	if len(s.Attention) > 0 {
		a.UI.Section("Needs a hand")
		for _, e := range s.Attention {
			tone := "warn"
			if e.Status == "failed" {
				tone = "error"
			}
			a.UI.Item(tone, e.Kind+" "+e.Name, e.Detail)
		}
		if s.AttentionTotal > len(s.Attention) {
			a.UI.Note(fmt.Sprintf("  …and %d more in the report.", s.AttentionTotal-len(s.Attention)))
		}
	}
	if s.FinishTask != nil {
		a.UI.Item("ok", "Queued", fmt.Sprintf("%q starts two minutes after NeoAgent restarts; you'll get a message when it's done.", *s.FinishTask))
	}
	home, _ := os.UserHomeDir()
	a.UI.Note("Full report: " + strings.Replace(s.ReportFile, home, "~", 1))
}

// importAccount is the account the import writes into. A fresh install has
// none yet: it can be made right here.
func (a *App) importAccount(ctx context.Context, yes bool) (int64, error) {
	db, err := a.openDB(ctx)
	if err != nil {
		return 0, err
	}
	defer db.Close()
	rows, err := db.R.QueryContext(ctx, `SELECT id, username, is_admin FROM users ORDER BY id`)
	if err != nil {
		return 0, err
	}
	type account struct {
		id    int64
		name  string
		admin bool
	}
	var accounts []account
	for rows.Next() {
		var acc account
		var admin sql.NullInt64
		if err := rows.Scan(&acc.id, &acc.name, &admin); err != nil {
			rows.Close()
			return 0, err
		}
		acc.admin = admin.Int64 == 1
		accounts = append(accounts, acc)
	}
	rows.Close()
	switch {
	case len(accounts) == 1:
		return accounts[0].id, nil
	case len(accounts) > 1:
		if yes {
			return 0, errors.New("This install has more than one account; run `neoagent migrate` without --yes to choose one.")
		}
		var choices []cli.Choice
		for _, acc := range accounts {
			hint := ""
			if acc.admin {
				hint = "admin"
			}
			choices = append(choices, cli.Choice{Value: fmt.Sprint(acc.id), Label: acc.name, Hint: hint})
		}
		picked, err := a.UI.Select("Which account should receive everything?", choices)
		if err != nil {
			return 0, err
		}
		var id int64
		fmt.Sscan(picked, &id)
		return id, nil
	}
	if yes || !a.UI.Interactive() {
		return 0, errors.New("No account exists yet. Create one with `neoagent account create`, then run `neoagent migrate` again.")
	}
	a.UI.Note("First, your NeoAgent account. You will use it to sign in to the app.")
	def := ""
	if u, err := user.Current(); err == nil {
		def = u.Username
	}
	name, err := a.UI.Ask("Username", def)
	if err != nil {
		return 0, err
	}
	password, err := a.UI.AskSecret("Password (at least 8 characters)", "")
	if err != nil {
		return 0, err
	}
	if err := a.cmdAccount(ctx, []string{"create", "--username", name, "--password", password}); err != nil {
		return 0, err
	}
	var id int64
	return id, db.R.QueryRowContext(ctx, `SELECT id FROM users WHERE username = ?`, name).Scan(&id)
}
