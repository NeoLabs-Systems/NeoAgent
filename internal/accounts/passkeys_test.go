package accounts

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/webauthnx"
)

func newPasskeyStore(t *testing.T) *PasskeyStore {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`); err != nil {
		t.Fatal(err)
	}
	return &PasskeyStore{DB: db}
}

// TestPasskeyStoreKeepsNodeRows covers the credential rows the passkey
// ceremonies read and write, with the statements of services/account/webauthn.js:
// newest first per account, one key per credential id, counters and renames
// scoped to the owner.
func TestPasskeyStoreKeepsNodeRows(t *testing.T) {
	ctx := context.Background()
	s := newPasskeyStore(t)
	insert := func(c webauthnx.Credential) {
		t.Helper()
		if err := s.Insert(ctx, c); err != nil {
			t.Fatal(err)
		}
	}
	insert(webauthnx.Credential{UserID: "1", CredentialID: "cred-a", PublicKey: "pk-a", RPID: "localhost", Transports: []string{"usb", "nfc"}, DeviceType: "singleDevice", Label: "YubiKey"})
	insert(webauthnx.Credential{UserID: "1", CredentialID: "cred-b", PublicKey: "pk-b", Counter: 7, RPID: "agent.example.com", BackedUp: true, UserVerified: true, Label: "Phone"})
	insert(webauthnx.Credential{UserID: "2", CredentialID: "cred-c", PublicKey: "pk-c", RPID: "localhost", Label: "Bob key"})
	if err := s.Insert(ctx, webauthnx.Credential{UserID: "2", CredentialID: "cred-a", PublicKey: "x", RPID: "localhost", Label: "dup"}); err == nil {
		t.Fatal("a credential id is registered once")
	}

	var transports string
	if err := s.DB.R.QueryRow(`SELECT transports_json FROM user_webauthn_credentials WHERE credential_id = 'cred-b'`).Scan(&transports); err != nil || transports != "[]" {
		t.Fatalf("no transports are stored as [] like Node: %q %v", transports, err)
	}

	keys, err := s.ListForUser(ctx, "1")
	if err != nil || len(keys) != 2 || keys[0].CredentialID != "cred-b" || keys[1].CredentialID != "cred-a" {
		t.Fatalf("newest first (created_at, then id): %+v %v", keys, err)
	}
	if a := keys[1]; a.UserID != "1" || len(a.Transports) != 2 || a.DeviceType != "singleDevice" || a.BackedUp || a.Counter != 0 {
		t.Fatalf("fields read back: %+v", a)
	}
	if b := keys[0]; !b.BackedUp || !b.UserVerified || b.Counter != 7 || b.DeviceType != "" {
		t.Fatalf("fields read back: %+v", b)
	}
	if forRP, _ := s.ForUserAndRP(ctx, "1", "localhost"); len(forRP) != 1 || forRP[0].CredentialID != "cred-a" {
		t.Fatalf("keys of one relying party: %+v", forRP)
	}
	if n, _ := s.CountForRP(ctx, "localhost"); n != 2 {
		t.Fatalf("CountForRP = %d", n)
	}
	if c, _ := s.FindByCredentialID(ctx, "cred-a", "agent.example.com"); c != nil {
		t.Fatal("a key is found only for the relying party it was made for")
	}
	found, err := s.FindByCredentialID(ctx, "cred-a", "localhost")
	if err != nil || found == nil || found.Label != "YubiKey" {
		t.Fatalf("FindByCredentialID: %+v %v", found, err)
	}
	if ok, _ := s.Exists(ctx, "cred-c"); !ok {
		t.Fatal("Exists for any account")
	}
	if ok, _ := s.Exists(ctx, "nope"); ok {
		t.Fatal("Exists for a missing key")
	}

	if err := s.UpdateAfterLogin(ctx, found.RowID, 12, true); err != nil {
		t.Fatal(err)
	}
	after, _ := s.FindByCredentialID(ctx, "cred-a", "localhost")
	if after.Counter != 12 || !after.UserVerified || after.LastUsedAt == "" {
		t.Fatalf("after sign-in: %+v", after)
	}

	if ok, _ := s.Rename(ctx, "2", found.RowID, "stolen"); ok {
		t.Fatal("another account cannot rename the key")
	}
	if ok, _ := s.Rename(ctx, "1", found.RowID, "Desk key"); !ok {
		t.Fatal("the owner renames the key")
	}
	if ok, _ := s.Delete(ctx, "2", found.RowID); ok {
		t.Fatal("another account cannot delete the key")
	}
	if ok, _ := s.Delete(ctx, "1", found.RowID); !ok {
		t.Fatal("the owner deletes the key")
	}
	if ok, _ := s.Delete(ctx, "1", found.RowID); ok {
		t.Fatal("a deleted key is gone")
	}
}
