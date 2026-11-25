package sharedmessaging

import (
	"context"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

func newStore(t *testing.T) *Store {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	box, _ := secretbox.New("enc:v1:", "test-secret")
	return &Store{DB: db, Box: box}
}

func code(err error) string {
	if e, ok := err.(*apperr.Error); ok {
		return e.Code
	}
	return ""
}

func TestConfigureRevisionAndRemove(t *testing.T) {
	s := newStore(t)
	ctx := context.Background()
	if err := s.Configure(ctx, "discord", Input{}, "cli"); code(err) != "SHARED_PLATFORM_UNSUPPORTED" {
		t.Fatal(err)
	}
	if err := s.Configure(ctx, "telegram", Input{}, "cli"); code(err) != "SHARED_TOKEN_REQUIRED" {
		t.Fatal(err)
	}
	bad := "nope"
	if err := s.Configure(ctx, "telegram", Input{BotToken: &bad}, "cli"); code(err) != "SHARED_TOKEN_INVALID" {
		t.Fatal(err)
	}
	token := "123456:ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	if err := s.Configure(ctx, "telegram", Input{BotToken: &token}, "cli"); err != nil {
		t.Fatal(err)
	}
	c, _ := s.Get(ctx, "telegram")
	if c.Revision != 1 || c.Status != "connecting" || !strings.HasPrefix(c.Config, "enc:v1:") || strings.Contains(c.Config, token) {
		t.Fatalf("%+v", c)
	}
	// Changing only availability keeps the revision; switching off bumps it.
	off := false
	if err := s.Configure(ctx, "telegram", Input{Available: &off}, "cli"); err != nil {
		t.Fatal(err)
	}
	if c, _ = s.Get(ctx, "telegram"); c.Revision != 1 || c.Available {
		t.Fatalf("%+v", c)
	}
	if err := s.Configure(ctx, "telegram", Input{Enabled: &off}, "cli"); err != nil {
		t.Fatal(err)
	}
	if c, _ = s.Get(ctx, "telegram"); c.Revision != 2 || c.Status != "disconnected" {
		t.Fatalf("%+v", c)
	}
	list, err := s.AdminOverview(ctx)
	if err != nil || len(list) != 2 || !list[0].Configured || list[1].Status != "not_configured" {
		t.Fatalf("%+v %v", list, err)
	}
	var audits int
	s.DB.R.QueryRow(`SELECT COUNT(*) FROM access_audit_log WHERE action = 'messaging.shared_configure' AND detail_json LIKE '{"platform":"telegram","source":"cli",%'`).Scan(&audits)
	if audits != 3 {
		t.Fatalf("audits %d", audits)
	}
	if err := s.Remove(ctx, "telegram", "cli"); err != nil {
		t.Fatal(err)
	}
	if c, _ = s.Get(ctx, "telegram"); c != nil {
		t.Fatal("not removed")
	}
}
