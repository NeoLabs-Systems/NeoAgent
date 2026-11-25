package manager

import (
	"bufio"
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/admin"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/envfile"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/passhash"
	"github.com/NeoLabs-Systems/neolabs-go/pwpolicy"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

func (a *App) cmdEnv(_ context.Context, args []string) error {
	pos := cli.Positionals(args)
	action := ""
	if len(pos) > 0 {
		action = strings.ToLower(pos[0])
	}
	switch action {
	case "":
		fmt.Fprint(a.Out, "Usage: neoagent env <subcommand>\n\n"+
			"  neoagent env list            List all variables (secrets masked)\n"+
			"  neoagent env get KEY         Print a single variable\n"+
			"  neoagent env set KEY VALUE   Set a variable\n"+
			"  neoagent env unset KEY       Remove a variable\n")
	case "list":
		values := a.env()
		if len(values) == 0 {
			a.UI.Warn("No .env found at " + a.Paths.EnvFile)
			return nil
		}
		for _, k := range envfile.SortedKeys(values) {
			fmt.Fprintf(a.Out, "%s=%s\n", k, envfile.Mask(k, values[k]))
		}
	case "get":
		if len(pos) < 2 {
			return usageError("Usage: neoagent env get <KEY>")
		}
		v, ok := a.env()[pos[1]]
		if !ok {
			return fmt.Errorf("Key not found: %s", pos[1])
		}
		fmt.Fprintln(a.Out, v)
	case "set":
		if len(pos) < 3 {
			return usageError("Usage: neoagent env set <KEY> <VALUE>")
		}
		key := pos[1]
		if !envfile.ValidKey(key) || strings.ToUpper(key) != key || key[0] == '_' {
			return fmt.Errorf("Invalid env key %q. Keys must be uppercase letters, digits, and underscores (e.g. PORT, ANTHROPIC_API_KEY).", key)
		}
		if err := envfile.Upsert(a.Paths.EnvFile, key, strings.Join(pos[2:], " ")); err != nil {
			return err
		}
		a.UI.OK("Set " + key + " in " + a.Paths.EnvFile)
	case "unset":
		if len(pos) < 2 {
			return usageError("Usage: neoagent env unset <KEY>")
		}
		if _, err := envfile.Remove(a.Paths.EnvFile, pos[1]); err != nil {
			return err
		}
		a.UI.OK("Removed " + pos[1] + " from " + a.Paths.EnvFile)
	default:
		return usageError("Usage: neoagent env [list|get|set|unset] ...")
	}
	return nil
}

// cmdAdmin lists, grants and revokes the admin flag. The server reads it on
// every request, so a change applies to a running server immediately.
func (a *App) cmdAdmin(ctx context.Context, args []string) error {
	pos := cli.Positionals(args)
	sub := "list"
	if len(pos) > 0 {
		sub = pos[0]
	}
	if sub != "list" && sub != "grant" && sub != "revoke" {
		return usageError("Usage: neoagent admin [list | grant <username> | revoke <username>]")
	}
	if sub != "list" && len(pos) < 2 {
		return usageError("Usage: neoagent admin %s <username>", sub)
	}
	db, err := a.openDB(ctx)
	if err != nil {
		return err
	}
	defer db.Close()
	store := &admin.Store{DB: db}
	if sub == "list" {
		admins, err := store.ListAdmins(ctx)
		if err != nil {
			return err
		}
		if a.JSON {
			if admins == nil {
				admins = []admin.Admin{}
			}
			return cli.WriteJSONLine(a.Out, map[string]any{"admins": admins})
		}
		needs, _ := store.NeedsAdminGrant(ctx)
		switch {
		case len(admins) > 0:
			for _, ad := range admins {
				a.UI.OK(ad.Username)
			}
		case needs:
			a.UI.Warn("No account is an admin yet. Run `neoagent admin grant <username>`.")
		default:
			a.UI.Info("No accounts yet. The first account you create becomes the admin.")
		}
		return nil
	}
	var res admin.GrantResult
	if sub == "grant" {
		res, err = store.GrantAdmin(ctx, pos[1], "cli")
	} else {
		res, err = store.RevokeAdmin(ctx, pos[1], "cli")
	}
	if err != nil {
		return err
	}
	if a.JSON {
		return cli.WriteJSONLine(a.Out, map[string]any{"username": res.Username, "changed": res.Changed})
	}
	verb := map[string][2]string{"grant": {"is already", "is now an admin"}, "revoke": {"is not", "is no longer an admin"}}[sub]
	if !res.Changed {
		a.UI.Info(fmt.Sprintf("%s %s an admin.", res.Username, verb[0]))
	} else {
		a.UI.OK(fmt.Sprintf("%s %s.", res.Username, verb[1]))
	}
	return nil
}

// cmdAccount creates the first account of an install with none (headless
// setups); it refuses once any account exists.
func (a *App) cmdAccount(ctx context.Context, args []string) error {
	pos := cli.Positionals(args, "--username", "--password")
	if len(pos) == 0 || pos[0] != "create" {
		return usageError("Usage: neoagent account create --username <name> --password <password>")
	}
	username, _ := cli.FlagValue(args, "--username")
	password, _ := cli.FlagValue(args, "--password")
	username = strings.TrimSpace(username)
	if username == "" {
		return errors.New("A username is required.")
	}
	if err := accounts.ValidateNewPassword(password, pwpolicy.Context{Username: username}); err != nil {
		return err
	}
	hash, err := passhash.Hash(password, accounts.PasswordCost)
	if err != nil {
		return err
	}
	db, err := a.openDB(ctx)
	if err != nil {
		return err
	}
	defer db.Close()
	var id int64
	err = inTx(ctx, db, func(tx *sql.Tx) error {
		var count int
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM users`).Scan(&count); err != nil {
			return err
		}
		if count > 0 {
			return errors.New("This install already has an account. Sign in, or use the web interface to add another.")
		}
		res, err := tx.ExecContext(ctx, `INSERT INTO users (username, password, email_verified_at) VALUES (?, ?, datetime('now'))`, username, hash)
		if err != nil {
			return err
		}
		id, err = res.LastInsertId()
		return err
	})
	if err != nil {
		return err
	}
	if a.JSON {
		return cli.WriteJSONLine(a.Out, map[string]any{"id": id, "username": username})
	}
	a.UI.OK("Created account " + username)
	return nil
}

// cmdResetPassword sets a new password for an account and signs it out
// everywhere. The password comes from a prompt or, with --password-stdin,
// from the first line of standard input.
func (a *App) cmdResetPassword(ctx context.Context, args []string) error {
	pos := cli.Positionals(args)
	if len(pos) != 1 {
		return usageError("Usage: neoagent reset-password <username> [--password-stdin]")
	}
	db, err := a.openDB(ctx)
	if err != nil {
		return err
	}
	defer db.Close()
	var id int64
	var username, email string
	err = db.R.QueryRowContext(ctx, `SELECT id, username, COALESCE(email, '') FROM users WHERE lower(username) = lower(?) ORDER BY username = ? DESC LIMIT 1`, pos[0], pos[0]).Scan(&id, &username, &email)
	if errors.Is(err, sql.ErrNoRows) {
		return fmt.Errorf("No account is named %s.", pos[0])
	}
	if err != nil {
		return err
	}
	var password string
	if cli.HasFlag(args, "--password-stdin") {
		line, err := bufio.NewReader(os.Stdin).ReadString('\n')
		if err != nil && line == "" {
			return errors.New("No password on standard input.")
		}
		password = strings.TrimRight(line, "\r\n")
	} else {
		if !a.UI.Interactive() {
			return errors.New("Run this in a terminal, or pass the password with --password-stdin.")
		}
		if password, err = a.UI.AskSecret("New password for "+username, ""); err != nil {
			return err
		}
		again, err := a.UI.AskSecret("Repeat it", "")
		if err != nil {
			return err
		}
		if again != password {
			return errors.New("The passwords do not match.")
		}
	}
	if err := accounts.ValidateNewPassword(password, pwpolicy.Context{Username: username, Email: email}); err != nil {
		return err
	}
	hash, err := passhash.Hash(password, accounts.PasswordCost)
	if err != nil {
		return err
	}
	if err := (&accounts.Repo{DB: db}).SetPassword(ctx, id, hash); err != nil {
		return err
	}
	if err := a.signOutEverywhere(ctx, id); err != nil {
		return err
	}
	a.UI.OK("Password changed for " + username + "; every session was signed out.")
	return nil
}

func (a *App) signOutEverywhere(ctx context.Context, userID int64) error {
	path := filepath.Join(a.Paths.DataDir, "sessions.db")
	if !exists(path) {
		return nil
	}
	db, err := dbx.Open(ctx, path, dbx.Options{})
	if err != nil {
		return err
	}
	defer db.Close()
	store, err := sessionx.NewStore(ctx, db.W)
	if err != nil {
		return err
	}
	return store.DestroyForUser(ctx, strconv.FormatInt(userID, 10))
}

func inTx(ctx context.Context, db *dbx.DB, fn func(*sql.Tx) error) error {
	tx, err := db.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}
