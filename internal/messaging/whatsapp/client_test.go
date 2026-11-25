package whatsapp

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp/wastore"
)

func copyDir(t *testing.T, from, to string) {
	t.Helper()
	if err := os.CopyFS(to, os.DirFS(from)); err != nil {
		t.Fatal(err)
	}
}

func TestBaileysLoginIsPickedUpOnFirstConnect(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "auth")
	copyDir(t, "baileysconv/testdata/alice-snap", dir)

	cl, err := openClient(context.Background(), dir)
	if err != nil {
		t.Fatal(err)
	}
	defer cl.Close()
	if !cl.IsPaired() {
		t.Fatal("the converted login is not linked")
	}
	jid, lid := cl.Own()
	if jid.String() != "111111@s.whatsapp.net" || lid.String() != "999999@lid" {
		t.Fatalf("own %s %s", jid, lid)
	}
	info, err := os.Stat(filepath.Join(dir, wastore.FileName))
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("store file: %v %v", info, err)
	}
	if _, err := os.Stat(filepath.Join(dir, "creds.json")); err != nil {
		t.Fatal("the Baileys files must stay as the only copy of the login until the user has seen it work")
	}

	// A second start finds the store and does not convert again.
	cl.Close()
	again, err := openClient(context.Background(), dir)
	if err != nil {
		t.Fatal(err)
	}
	defer again.Close()
	if !again.IsPaired() {
		t.Fatal("store lost the login")
	}
}

func TestUnlinkedBaileysFolderStartsPairing(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "auth")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "creds.json"), []byte(`{"registered":false}`), 0o600); err != nil {
		t.Fatal(err)
	}
	cl, err := openClient(context.Background(), dir)
	if err != nil {
		t.Fatal(err)
	}
	defer cl.Close()
	if cl.IsPaired() {
		t.Fatal("nothing was linked")
	}
}

func TestBrokenBaileysLoginNeedsTheUser(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "auth")
	copyDir(t, "baileysconv/testdata/alice-snap", dir)
	if err := os.WriteFile(filepath.Join(dir, "creds.json"), []byte(`{"me":{"id":"1:2@s.whatsapp.net"},"account":{},"noiseKey":{}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	_, err := openClient(context.Background(), dir)
	var needsUser interface {
		RequiresUserAction() bool
		Reason() string
	}
	if !errors.As(err, &needsUser) || !needsUser.RequiresUserAction() || needsUser.Reason() != "authentication_required" {
		t.Fatalf("%v", err)
	}
	if _, statErr := os.Stat(filepath.Join(dir, wastore.FileName)); !os.IsNotExist(statErr) {
		t.Fatal("a half-written store must not stay behind")
	}
}
