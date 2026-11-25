package wastore

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestOpenCreatesPrivateStore(t *testing.T) {
	path := filepath.Join(t.TempDir(), "agent", "auth", FileName)
	st, err := Open(context.Background(), path)
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	if info, err := os.Stat(path); err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("file %v %v", info, err)
	}
	if info, err := os.Stat(filepath.Dir(path)); err != nil || info.Mode().Perm() != 0o700 {
		t.Fatalf("dir %v %v", info, err)
	}
	var n int
	if err := st.DB.QueryRow(`SELECT COUNT(*) FROM whatsmeow_device`).Scan(&n); err != nil || n != 0 {
		t.Fatalf("schema not applied: %d %v", n, err)
	}
	var fk int
	if err := st.DB.QueryRow(`PRAGMA foreign_keys`).Scan(&fk); err != nil || fk != 1 {
		t.Fatalf("foreign keys %d %v", fk, err)
	}
}
