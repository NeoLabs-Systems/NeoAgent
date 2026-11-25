package manager

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/sharedmessaging"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/skip2/go-qrcode"
)

const messagingUsage = "Usage: neoagent messaging [list | setup <telegram|whatsapp> [--no-personal] [--token-stdin] | disconnect <platform> | remove <platform> [--yes]]"

// messagingWait is how long setup watches for the server to connect.
var messagingWait = map[string]time.Duration{"telegram": 45 * time.Second, "whatsapp": 3 * time.Minute}

func (a *App) sharedStore(ctx context.Context) (*sharedmessaging.Store, func(), error) {
	// Shared credentials are sealed with the server's key, from the env file.
	box, err := config.SecretBox(os.Getenv)
	if err != nil {
		return nil, nil, err
	}
	db, err := a.openDB(ctx)
	if err != nil {
		return nil, nil, err
	}
	return &sharedmessaging.Store{DB: db, Box: box}, func() { db.Close() }, nil
}

func describeShared(o sharedmessaging.Overview) string {
	parts := []string{strings.ReplaceAll(o.Status, "_", " ")}
	if o.AccountLabel != nil {
		parts = append(parts, *o.AccountLabel)
	}
	parts = append(parts, fmt.Sprintf("%d linked", o.LinkedUsers))
	if o.Configured && !o.Available {
		parts = append(parts, "hidden from users")
	}
	if o.Configured && !o.AllowPersonal {
		parts = append(parts, "personal accounts off")
	}
	return strings.Join(parts, " · ")
}

func (a *App) cmdMessaging(ctx context.Context, args []string) error {
	pos := cli.Positionals(args)
	sub, platform := "list", ""
	if len(pos) > 0 {
		sub = pos[0]
	}
	if len(pos) > 1 {
		platform = pos[1]
	}
	store, done, err := a.sharedStore(ctx)
	if err != nil {
		return err
	}
	defer done()
	if sub == "list" {
		list, err := store.AdminOverview(ctx)
		if err != nil {
			return err
		}
		if a.JSON {
			for i := range list {
				list[i].QR = nil
			}
			return cli.WriteJSONLine(a.Out, map[string]any{"connections": list})
		}
		for _, o := range list {
			tone, detail := "info", "not set up"
			if o.Status == "connected" {
				tone = "ok"
			}
			if o.Configured {
				detail = describeShared(o)
			}
			a.UI.Item(tone, o.Platform, detail)
		}
		return nil
	}
	if platform == "" {
		return usageError("%s", messagingUsage)
	}
	if err := sharedmessaging.AssertShared(platform); err != nil {
		return err
	}
	switch sub {
	case "setup":
		return a.messagingSetup(ctx, store, platform, args)
	case "remove":
		existing, err := store.Get(ctx, platform)
		if err != nil {
			return err
		}
		if existing == nil {
			return fmt.Errorf("No shared %s account is set up.", platform)
		}
		linked, _ := store.CountLinks(ctx, platform)
		if !cli.HasFlag(args, "--yes") && !cli.HasFlag(args, "-y") {
			if !a.UI.Interactive() {
				return fmt.Errorf("Re-run with --yes to confirm.")
			}
			people := "people"
			if linked == 1 {
				people = "person"
			}
			ok, err := a.UI.Confirm(fmt.Sprintf("Remove the shared %s account and unlink %d %s?", platform, linked, people), false)
			if err != nil {
				return err
			}
			if !ok {
				return cli.ErrCancelled
			}
		}
		if err := store.Remove(ctx, platform, "cli"); err != nil {
			return err
		}
		if a.JSON {
			return cli.WriteJSONLine(a.Out, map[string]any{"platform": platform, "removed": true})
		}
		a.UI.OK("Removed the shared " + platform + " account.")
	case "disconnect":
		existing, err := store.Get(ctx, platform)
		if err != nil {
			return err
		}
		if existing == nil {
			return fmt.Errorf("No shared %s account is set up.", platform)
		}
		off := false
		if err := store.Configure(ctx, platform, sharedmessaging.Input{Enabled: &off}, "cli"); err != nil {
			return err
		}
		if a.JSON {
			return cli.WriteJSONLine(a.Out, map[string]any{"platform": platform, "enabled": false})
		}
		a.UI.OK("Disconnected the shared " + platform + " account. Links are kept; run setup to reconnect.")
	default:
		return usageError("%s", messagingUsage)
	}
	return nil
}

func (a *App) messagingSetup(ctx context.Context, store *sharedmessaging.Store, platform string, args []string) error {
	on := true
	in := sharedmessaging.Input{Enabled: &on, Reconnect: true}
	tokenStdin := cli.HasFlag(args, "--token-stdin")
	if platform == "telegram" {
		existing, err := store.Get(ctx, platform)
		if err != nil {
			return err
		}
		if tokenStdin || existing == nil || a.UI.Interactive() {
			// Prompted or piped, never an argument: it stays out of shell
			// history and process listings.
			var token string
			switch {
			case tokenStdin:
				raw, _ := bufio.NewReader(os.Stdin).ReadString(0)
				token = strings.TrimSpace(raw)
			case !a.UI.Interactive():
				return fmt.Errorf("Pipe the bot token in with --token-stdin when there is no terminal.")
			default:
				if token, err = a.UI.AskSecret("Telegram bot token from @BotFather", ""); err != nil {
					return err
				}
			}
			in.BotToken = &token
		}
	}
	if cli.HasFlag(args, "--no-personal") {
		off := false
		in.AllowPersonal = &off
	} else if a.UI.Interactive() {
		ok, err := a.UI.Confirm("Let people connect their own account instead?", true)
		if err != nil {
			return err
		}
		in.AllowPersonal = &ok
	}
	if err := store.Configure(ctx, platform, in, "cli"); err != nil {
		return err
	}
	connected, err := a.waitForShared(ctx, store, platform, messagingWait[platform])
	if err != nil {
		return err
	}
	if a.JSON {
		if err := cli.WriteJSONLine(a.Out, map[string]any{"platform": platform, "connected": connected}); err != nil {
			return err
		}
	} else if connected {
		a.UI.Info("People can now link under Settings › Platforms in the app.")
	}
	if !connected {
		return eventEmitted{fmt.Errorf("the shared %s account is not connected yet", platform)}
	}
	return nil
}

// waitForShared watches the row the server reports its progress in; the
// WhatsApp pairing QR arrives there too.
func (a *App) waitForShared(ctx context.Context, store *sharedmessaging.Store, platform string, timeout time.Duration) (bool, error) {
	deadline := time.Now().Add(timeout)
	shown := ""
	for time.Now().Before(deadline) {
		row, err := store.Get(ctx, platform)
		if err != nil {
			return false, err
		}
		if row != nil && row.Status == "connected" {
			label := platform
			if row.AccountLabel.Valid && row.AccountLabel.String != "" {
				label = row.AccountLabel.String
			}
			if !a.JSON {
				a.UI.OK("Connected as " + label + ".")
			}
			return true, nil
		}
		if row != nil && (row.Status == "error" || row.Status == "logged_out") {
			if !a.JSON {
				reason := row.Status
				if row.StatusReason.Valid && row.StatusReason.String != "" {
					reason = row.StatusReason.String
				}
				a.UI.Warn("The account could not connect (" + reason + ").")
			}
			return false, nil
		}
		if qr := store.QR(row); qr != "" && qr != shown && !a.JSON {
			shown = qr
			if code, err := qrcode.New(qr, qrcode.Low); err == nil {
				a.UI.Printf("%s", code.ToSmallString(false))
			}
			a.UI.Print("Scan this in WhatsApp › Linked devices with the shared number.")
		}
		select {
		case <-ctx.Done():
			return false, ctx.Err()
		case <-time.After(time.Second):
		}
	}
	if !a.JSON {
		a.UI.Warn("Saved, but not connected yet. It connects once NeoAgent is running: `neoagent status`.")
	}
	return false, nil
}
