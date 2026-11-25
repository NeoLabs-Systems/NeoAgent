package schema

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/testkit"
)

func open(t *testing.T) *dbx.DB {
	t.Helper()
	d, err := dbx.Open(context.Background(), filepath.Join(t.TempDir(), "n.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { d.Close() })
	return d
}

func TestFreshDatabaseGetsBaselineAndVersion(t *testing.T) {
	d := open(t)
	ctx := context.Background()
	if err := Ensure(ctx, d.W); err != nil {
		t.Fatal(err)
	}
	var tables, version int
	d.W.QueryRowContext(ctx, `SELECT COUNT(*) FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'`).Scan(&tables)
	d.W.QueryRowContext(ctx, `PRAGMA user_version`).Scan(&version)
	if tables < 100 || version != BaselineVersion() || version != 4 {
		t.Fatalf("tables=%d version=%d", tables, version)
	}
	// Idempotent on a second start.
	if err := Ensure(ctx, d.W); err != nil {
		t.Fatalf("second Ensure: %v", err)
	}
}

func TestFTSTablesAndFirstUserAdminTrigger(t *testing.T) {
	d := open(t)
	ctx := context.Background()
	if err := Ensure(ctx, d.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		`INSERT INTO users (username, password) VALUES ('first', 'x')`,
		`INSERT INTO users (username, password) VALUES ('second', 'x')`,
	} {
		if _, err := d.W.ExecContext(ctx, q); err != nil {
			t.Fatal(err)
		}
	}
	var first, second int
	d.W.QueryRowContext(ctx, `SELECT is_admin FROM users WHERE username='first'`).Scan(&first)
	d.W.QueryRowContext(ctx, `SELECT is_admin FROM users WHERE username='second'`).Scan(&second)
	if first != 1 || second != 0 {
		t.Fatalf("the first account on an install is admin, later ones are not: %d %d", first, second)
	}
	if _, err := d.W.ExecContext(ctx, `SELECT * FROM memories_fts WHERE memories_fts MATCH 'x' LIMIT 1`); err != nil {
		t.Fatalf("memories_fts: %v", err)
	}
}

func TestVerifyDetectsDriftAndOldVersions(t *testing.T) {
	d := open(t)
	ctx := context.Background()
	if err := Ensure(ctx, d.W); err != nil {
		t.Fatal(err)
	}
	if _, err := d.W.ExecContext(ctx, `ALTER TABLE users DROP COLUMN allowed_models`); err != nil {
		t.Fatal(err)
	}
	err := Verify(ctx, d.W)
	if err == nil || !strings.Contains(err.Error(), "missing column users.allowed_models") || !strings.Contains(err.Error(), "3.x") {
		t.Fatalf("drift not reported clearly: %v", err)
	}

	old := open(t)
	if err := Ensure(ctx, old.W); err != nil {
		t.Fatal(err)
	}
	old.W.ExecContext(ctx, `PRAGMA user_version = 2`)
	if err := Verify(ctx, old.W); err == nil || !strings.Contains(err.Error(), "version 2") {
		t.Fatalf("old version accepted: %v", err)
	}

	newer := open(t)
	Ensure(ctx, newer.W)
	newer.W.ExecContext(ctx, `PRAGMA user_version = 99`)
	if err := Ensure(ctx, newer.W); err == nil || !strings.Contains(err.Error(), "newer") {
		t.Fatalf("newer database accepted: %v", err)
	}
}

// Set NEOAGENT_TEST_DB to a real neoagent.db to prove a production database is
// accepted. It is copied read-only first; the original is never opened for writing.
func TestRealDatabaseCopyIsAccepted(t *testing.T) {
	src := os.Getenv("NEOAGENT_TEST_DB")
	if src == "" {
		t.Skip("set NEOAGENT_TEST_DB to a neoagent.db to run this")
	}
	copyPath := testkit.CopySQLite(t, src)
	d, err := dbx.Open(context.Background(), copyPath, dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	if err := Verify(context.Background(), d.W); err != nil {
		t.Fatalf("production database rejected: %v", err)
	}
}
