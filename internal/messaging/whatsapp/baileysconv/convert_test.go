package baileysconv

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"go.mau.fi/libsignal/groups"
	"go.mau.fi/libsignal/protocol"
	"go.mau.fi/libsignal/session"
	"go.mau.fi/whatsmeow/store"
	"go.mau.fi/whatsmeow/types"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp/wastore"
)

// The fixtures are written by gen/gen.mjs with Baileys' own signal code: two
// parties talk, their auth folders are snapshotted mid-conversation, and the
// ciphertexts produced afterwards are recorded.

type ciphertext struct {
	Type       string `json:"type"`
	Ciphertext string `json:"ciphertext"`
	Plaintext  string `json:"plaintext"`
}

type fixture struct {
	M1, M2, M3, M4, M5, M6, M7 ciphertext
	G2, G3                     ciphertext
	AppState                   struct{ KeyID, IndexMac, ValueMac string }
	Alice                      struct{ Early, Snap, JID, Peer string }
	Bob                        struct{ Snap, JID, Peer string }
	Group                      string
}

func loadFixture(t *testing.T) fixture {
	t.Helper()
	raw, err := os.ReadFile("testdata/expected.json")
	if err != nil {
		t.Fatal(err)
	}
	var f fixture
	if err := json.Unmarshal(raw, &f); err != nil {
		t.Fatal(err)
	}
	return f
}

// convertTo converts a fixture folder into a fresh store and returns the
// device with its stores.
func convertTo(t *testing.T, folder string) (*store.Device, Result) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "auth", wastore.FileName)
	res, err := Convert(context.Background(), filepath.Join("testdata", folder), path)
	if err != nil {
		t.Fatalf("convert %s: %v", folder, err)
	}
	st, err := wastore.Open(context.Background(), path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	jid, _ := types.ParseJID(res.JID)
	device, err := st.Container.GetDevice(context.Background(), jid)
	if err != nil || device == nil {
		t.Fatalf("device %s not stored: %v", res.JID, err)
	}
	return device, res
}

func raw(t *testing.T, c ciphertext) []byte {
	t.Helper()
	b, err := base64.StdEncoding.DecodeString(c.Ciphertext)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func peerAddress(t *testing.T, jid string) *protocol.SignalAddress {
	t.Helper()
	parsed, err := types.ParseJID(jid)
	if err != nil {
		t.Fatal(err)
	}
	return parsed.SignalAddress()
}

func cipherFor(device *store.Device, addr *protocol.SignalAddress) *session.Cipher {
	builder := session.NewBuilderFromSignal(device, addr, store.SignalProtobufSerializer)
	return session.NewCipher(builder, addr)
}

func decrypt(t *testing.T, c *session.Cipher, m ciphertext) {
	t.Helper()
	ctx := context.Background()
	var got []byte
	var err error
	if m.Type == "pkmsg" {
		var msg *protocol.PreKeySignalMessage
		msg, err = protocol.NewPreKeySignalMessageFromBytes(raw(t, m), store.SignalProtobufSerializer.PreKeySignalMessage, store.SignalProtobufSerializer.SignalMessage)
		if err == nil {
			got, err = c.DecryptMessage(ctx, msg)
		}
	} else {
		var msg *protocol.SignalMessage
		msg, err = protocol.NewSignalMessageFromBytes(raw(t, m), store.SignalProtobufSerializer.SignalMessage)
		if err == nil {
			got, err = c.Decrypt(ctx, msg)
		}
	}
	if err != nil {
		t.Fatalf("decrypt %q: %v", m.Plaintext, err)
	}
	if string(got) != m.Plaintext {
		t.Fatalf("decrypted %q, want %q", got, m.Plaintext)
	}
}

func TestConvertedSessionsDecryptWhatBaileysEncrypted(t *testing.T) {
	f := loadFixture(t)

	t.Run("initiator before any reply keeps its pending pre-key", func(t *testing.T) {
		alice, res := convertTo(t, f.Alice.Early)
		if res.Sessions != 1 || res.PreKeys != 1 {
			t.Fatalf("result %+v", res)
		}
		c := cipherFor(alice, peerAddress(t, f.Alice.Peer))
		// A message sent before the peer answered is still a pre-key message.
		sent, err := c.Encrypt(context.Background(), []byte("again"))
		if err != nil {
			t.Fatal(err)
		}
		if sent.Type() != protocol.PREKEY_TYPE {
			t.Fatalf("type %d, want pre-key", sent.Type())
		}
		decrypt(t, c, f.M2) // the peer's first reply steps the ratchet
	})

	t.Run("skipped message key and the next message on the same chain", func(t *testing.T) {
		alice, _ := convertTo(t, f.Alice.Snap)
		c := cipherFor(alice, peerAddress(t, f.Alice.Peer))
		decrypt(t, c, f.M4) // out of order: its key was stored when m5 arrived first
		decrypt(t, c, f.M6)
	})

	t.Run("responder decrypts the initiator's later message", func(t *testing.T) {
		bob, _ := convertTo(t, f.Bob.Snap)
		decrypt(t, cipherFor(bob, peerAddress(t, f.Bob.Peer)), f.M7)
	})

	t.Run("converted stores talk to each other", func(t *testing.T) {
		alice, _ := convertTo(t, f.Alice.Snap)
		bob, _ := convertTo(t, f.Bob.Snap)
		a := cipherFor(alice, peerAddress(t, f.Alice.Peer))
		b := cipherFor(bob, peerAddress(t, f.Bob.Peer))
		for _, step := range []struct {
			from, to *session.Cipher
			text     string
		}{{a, b, "from converted alice"}, {b, a, "from converted bob"}, {a, b, "alice again"}} {
			sent, err := step.from.Encrypt(context.Background(), []byte(step.text))
			if err != nil {
				t.Fatal(err)
			}
			msg, err := protocol.NewSignalMessageFromBytes(sent.Serialize(), store.SignalProtobufSerializer.SignalMessage)
			if err != nil {
				t.Fatal(err)
			}
			got, err := step.to.Decrypt(context.Background(), msg)
			if err != nil || string(got) != step.text {
				t.Fatalf("%q: got %q, %v", step.text, got, err)
			}
		}
	})
}

func TestConvertedSenderKeysDecryptGroupMessages(t *testing.T) {
	f := loadFixture(t)
	bob, res := convertTo(t, f.Bob.Snap)
	if res.SenderKeys != 1 {
		t.Fatalf("result %+v", res)
	}
	sender := peerAddress(t, f.Bob.Peer)
	builder := groups.NewGroupSessionBuilder(bob, store.SignalProtobufSerializer)
	c := groups.NewGroupCipher(builder, protocol.NewSenderKeyName(f.Group, sender), bob)
	for _, m := range []ciphertext{f.G3, f.G2} { // g3 first: g2's key must come from the skipped list
		msg, err := protocol.NewSenderKeyMessageFromBytes(raw(t, m), store.SignalProtobufSerializer.SenderKeyMessage)
		if err != nil {
			t.Fatal(err)
		}
		got, err := c.Decrypt(context.Background(), msg)
		if err != nil || string(got) != m.Plaintext {
			t.Fatalf("%s: got %q, %v", m.Plaintext, got, err)
		}
	}

	// The sender's own record carries the private signing key: it can encrypt
	// and the converted recipient can read it.
	alice, _ := convertTo(t, f.Alice.Snap)
	aliceCipher := groups.NewGroupCipher(groups.NewGroupSessionBuilder(alice, store.SignalProtobufSerializer),
		protocol.NewSenderKeyName(f.Group, sender), alice)
	sent, err := aliceCipher.Encrypt(context.Background(), []byte("g4"))
	if err != nil {
		t.Fatal(err)
	}
	msg, err := protocol.NewSenderKeyMessageFromBytes(sent.SignedSerialize(), store.SignalProtobufSerializer.SenderKeyMessage)
	if err != nil {
		t.Fatal(err)
	}
	if got, err := c.Decrypt(context.Background(), msg); err != nil || string(got) != "g4" {
		t.Fatalf("g4: got %q, %v", got, err)
	}
}

func TestConvertedDeviceAndMetadata(t *testing.T) {
	f := loadFixture(t)
	alice, res := convertTo(t, f.Alice.Snap)
	if res.JID != f.Alice.JID {
		t.Fatalf("jid %s", res.JID)
	}
	want := Result{JID: f.Alice.JID, PreKeys: 1, Sessions: 1, SenderKeys: 1, Identities: 2, AppStateKeys: 1, AppStateVersions: 1, LIDMappings: 1}
	if res != want {
		t.Fatalf("result %+v, want %+v", res, want)
	}
	if alice.LID.String() != "999999:7@lid" || alice.PushName != "Alice" || alice.Platform != "android" {
		t.Fatalf("identity %v %q %q", alice.LID, alice.PushName, alice.Platform)
	}
	if alice.SignedPreKey.KeyID == 0 || alice.Account == nil || len(alice.Account.AccountSignature) != 64 || len(alice.AdvSecretKey) != 32 {
		t.Fatal("device secrets not carried over")
	}
	ctx := context.Background()
	keyID, _ := base64.StdEncoding.DecodeString(f.AppState.KeyID)
	if key, err := alice.AppStateKeys.GetAppStateSyncKey(ctx, keyID); err != nil || key == nil || len(key.Data) != 32 || key.Timestamp != 1700000000000 {
		t.Fatalf("app state key %+v %v", key, err)
	}
	version, hash, err := alice.AppState.GetAppStateVersion(ctx, "regular")
	if err != nil || version != 9 || hash == [128]byte{} {
		t.Fatalf("app state version %d %v", version, err)
	}
	indexMAC, _ := base64.StdEncoding.DecodeString(f.AppState.IndexMac)
	valueMAC, _ := base64.StdEncoding.DecodeString(f.AppState.ValueMac)
	if got, err := alice.AppState.GetAppStateMutationMAC(ctx, "regular", indexMAC); err != nil || string(got) != string(valueMAC) {
		t.Fatalf("mutation mac %x %v", got, err)
	}
	if pn, err := alice.LIDs.GetPNForLID(ctx, types.NewJID("555666", types.HiddenUserServer)); err != nil || pn.User != "111222" {
		t.Fatalf("lid map %v %v", pn, err)
	}
	if pre, err := alice.PreKeys.GetPreKey(ctx, 1); err != nil || pre == nil {
		t.Fatalf("pre-key %v", err)
	}
}

func TestConvertRefusesWhatCannotBeConverted(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "creds.json"), []byte(`{"registered":false}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := Convert(context.Background(), dir, filepath.Join(t.TempDir(), wastore.FileName)); err != ErrNotLinked {
		t.Fatalf("err %v, want ErrNotLinked", err)
	}

	f := loadFixture(t)
	target := filepath.Join(t.TempDir(), wastore.FileName)
	if _, err := Convert(context.Background(), filepath.Join("testdata", f.Alice.Snap), target); err != nil {
		t.Fatal(err)
	}
	if _, err := Convert(context.Background(), filepath.Join("testdata", f.Alice.Snap), target); err != ErrStoreHasDevice {
		t.Fatalf("err %v, want ErrStoreHasDevice", err)
	}
}

func TestSignalAddressNames(t *testing.T) {
	for in, want := range map[string]string{"491234.7": "491234:7", "123_1.5": "123_1:5", "1.0": "1:0"} {
		if got, ok := signalAddress(in); !ok || got != want {
			t.Fatalf("%s -> %s %v, want %s", in, got, ok, want)
		}
	}
	if _, ok := signalAddress("nodevice"); ok {
		t.Fatal("address without device accepted")
	}
}

func TestBufDecodesEveryBaileysEncoding(t *testing.T) {
	for _, in := range []string{`{"type":"Buffer","data":"AQID"}`, `{"type":"Buffer","data":[1,2,3]}`, `"AQID"`} {
		var b buf
		if err := json.Unmarshal([]byte(in), &b); err != nil || string(b) != "\x01\x02\x03" {
			t.Fatalf("%s -> %v %v", in, b, err)
		}
	}
}
