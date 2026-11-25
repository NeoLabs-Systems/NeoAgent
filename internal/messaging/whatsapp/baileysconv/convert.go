// Package baileysconv moves a WhatsApp login from a Baileys multi-file auth
// folder (what the Node server kept) into a whatsmeow store, so linked devices
// survive the move to Go without a new QR scan.
//
// Converted: the device identity (noise, identity and signed pre-keys,
// registration id, ADV secret and signed identity, JID, LID, push name,
// platform), pre-keys, Signal sessions (libsignal-node JSON records rebuilt as
// libsignal protobuf records), group sender keys, remote identity keys,
// app-state sync keys, app-state versions with their mutation MACs, and the
// LID/phone-number map.
//
// Not converted, because whatsmeow rebuilds or never had them: device-list and
// tctoken files, sender-key-memory files (who already received our sender key),
// closed-only session records (no open session to continue) and the pairing
// bookkeeping inside creds.json.
package baileysconv

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"go.mau.fi/libsignal/groups/ratchet"
	grouprecord "go.mau.fi/libsignal/groups/state/record"
	"go.mau.fi/libsignal/kdf"
	"go.mau.fi/libsignal/keys/chain"
	"go.mau.fi/libsignal/keys/message"
	"go.mau.fi/libsignal/serialize"
	"go.mau.fi/libsignal/state/record"
	"go.mau.fi/libsignal/util/optional"
	"go.mau.fi/whatsmeow/proto/waAdv"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/store"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/util/keys"
	"google.golang.org/protobuf/proto"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp/wastore"
)

// ErrNotLinked means creds.json describes no linked account: there is nothing
// to convert and the device has to be paired with a QR code.
var ErrNotLinked = errors.New("baileys auth folder holds no linked WhatsApp account")

// ErrStoreHasDevice means the target store already holds a login.
var ErrStoreHasDevice = errors.New("whatsapp store already holds a device")

// Result counts what was converted and what was left behind.
type Result struct {
	JID              string
	PreKeys          int
	Sessions         int
	SessionsSkipped  int // records without an open session
	SenderKeys       int
	Identities       int
	AppStateKeys     int
	AppStateVersions int
	LIDMappings      int
}

const sessionVersion = 3

// Convert reads the Baileys folder authDir and writes the login into the
// whatsmeow store at storePath. It does not touch authDir.
func Convert(ctx context.Context, authDir, storePath string) (Result, error) {
	var res Result
	creds, err := readCreds(authDir)
	if err != nil {
		return res, err
	}
	st, err := wastore.Open(ctx, storePath)
	if err != nil {
		return res, err
	}
	defer st.Close()

	jid, err := types.ParseJID(creds.Me.ID)
	if err != nil {
		return res, fmt.Errorf("creds.me.id: %w", err)
	}
	if existing, err := st.Container.GetDevice(ctx, jid); err != nil {
		return res, err
	} else if existing != nil {
		return res, ErrStoreHasDevice
	}
	device, err := newDevice(st, creds, jid)
	if err != nil {
		return res, err
	}
	if err := device.Save(ctx); err != nil {
		return res, err
	}
	res.JID = jid.String()

	files, err := readFiles(authDir)
	if err != nil {
		return res, err
	}
	c := &converter{ctx: ctx, st: st, device: device, creds: creds, res: &res, jid: jid.String()}
	for _, step := range []func(keyFiles) error{c.preKeys, c.sessions, c.senderKeys, c.identities, c.appStateKeys, c.appStateVersions, c.lidMappings} {
		if err := step(files); err != nil {
			return res, err
		}
	}
	return res, nil
}

type converter struct {
	ctx    context.Context
	st     *wastore.Store
	device *store.Device
	creds  *credsFile
	res    *Result
	jid    string
}

// --- creds.json ---------------------------------------------------------------

type keyPair struct {
	Private buf `json:"private"`
	Public  buf `json:"public"`
}

type credsFile struct {
	NoiseKey          keyPair `json:"noiseKey"`
	SignedIdentityKey keyPair `json:"signedIdentityKey"`
	SignedPreKey      struct {
		KeyPair   keyPair `json:"keyPair"`
		Signature buf     `json:"signature"`
		KeyID     uint32  `json:"keyId"`
	} `json:"signedPreKey"`
	RegistrationID          uint32 `json:"registrationId"`
	AdvSecretKey            buf    `json:"advSecretKey"`
	FirstUnuploadedPreKeyID uint32 `json:"firstUnuploadedPreKeyId"`
	Platform                string `json:"platform"`
	Me                      struct {
		ID   string `json:"id"`
		LID  string `json:"lid"`
		Name string `json:"name"`
	} `json:"me"`
	Account *struct {
		Details             buf `json:"details"`
		AccountSignatureKey buf `json:"accountSignatureKey"`
		AccountSignature    buf `json:"accountSignature"`
		DeviceSignature     buf `json:"deviceSignature"`
	} `json:"account"`
}

func readCreds(dir string) (*credsFile, error) {
	raw, err := os.ReadFile(filepath.Join(dir, "creds.json"))
	if err != nil {
		return nil, fmt.Errorf("read creds.json: %w", err)
	}
	var c credsFile
	if err := json.Unmarshal(raw, &c); err != nil {
		return nil, fmt.Errorf("parse creds.json: %w", err)
	}
	if c.Me.ID == "" || c.Account == nil {
		return nil, ErrNotLinked
	}
	return &c, nil
}

func array32(b []byte, what string) (*[32]byte, error) {
	if len(b) != 32 {
		return nil, fmt.Errorf("%s: want 32 bytes, got %d", what, len(b))
	}
	return (*[32]byte)(b), nil
}

func newKeyPair(kp keyPair, what string) (*keys.KeyPair, error) {
	priv, err := array32(kp.Private, what+" private key")
	if err != nil {
		return nil, err
	}
	pub, err := array32(kp.Public, what+" public key")
	if err != nil {
		return nil, err
	}
	return &keys.KeyPair{Priv: priv, Pub: pub}, nil
}

func newDevice(st *wastore.Store, c *credsFile, jid types.JID) (*store.Device, error) {
	d := st.Container.NewDevice()
	var err error
	if d.NoiseKey, err = newKeyPair(c.NoiseKey, "noise key"); err != nil {
		return nil, err
	}
	if d.IdentityKey, err = newKeyPair(c.SignedIdentityKey, "identity key"); err != nil {
		return nil, err
	}
	signedPre, err := newKeyPair(c.SignedPreKey.KeyPair, "signed pre-key")
	if err != nil {
		return nil, err
	}
	if len(c.SignedPreKey.Signature) != 64 {
		return nil, fmt.Errorf("signed pre-key signature: want 64 bytes, got %d", len(c.SignedPreKey.Signature))
	}
	d.SignedPreKey = &keys.PreKey{KeyPair: *signedPre, KeyID: c.SignedPreKey.KeyID, Signature: (*[64]byte)(c.SignedPreKey.Signature)}
	d.RegistrationID = c.RegistrationID
	d.AdvSecretKey = c.AdvSecretKey
	a := c.Account
	if len(a.AccountSignature) != 64 || len(a.AccountSignatureKey) != 32 || len(a.DeviceSignature) != 64 {
		return nil, errors.New("creds.account signatures have the wrong length")
	}
	d.Account = &waAdv.ADVSignedDeviceIdentity{
		Details: a.Details, AccountSignatureKey: a.AccountSignatureKey,
		AccountSignature: a.AccountSignature, DeviceSignature: a.DeviceSignature,
	}
	d.ID = &jid
	if c.Me.LID != "" {
		lid, err := types.ParseJID(c.Me.LID)
		if err != nil {
			return nil, fmt.Errorf("creds.me.lid: %w", err)
		}
		d.LID = lid
	}
	d.Platform = c.Platform
	d.PushName = c.Me.Name
	return d, nil
}

// --- file access ---------------------------------------------------------------

// buf is a byte string in any form Baileys wrote it: {"type":"Buffer","data":
// "<base64>"}, the same with a number array (Buffer.toJSON), a plain base64
// string, or null.
type buf []byte

func (b *buf) UnmarshalJSON(data []byte) error {
	data = bytes.TrimSpace(data)
	if bytes.Equal(data, []byte("null")) {
		*b = nil
		return nil
	}
	if data[0] == '"' {
		var s string
		if err := json.Unmarshal(data, &s); err != nil {
			return err
		}
		return b.fromBase64(s)
	}
	var wrapped struct {
		Type string          `json:"type"`
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(data, &wrapped); err != nil {
		return err
	}
	if wrapped.Type != "Buffer" {
		return fmt.Errorf("not a Buffer: %.40s", data)
	}
	if len(wrapped.Data) > 0 && wrapped.Data[0] == '"' {
		var s string
		if err := json.Unmarshal(wrapped.Data, &s); err != nil {
			return err
		}
		return b.fromBase64(s)
	}
	var nums []byte
	if err := json.Unmarshal(wrapped.Data, &nums); err != nil {
		return err
	}
	*b = nums
	return nil
}

func (b *buf) fromBase64(s string) error {
	out, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return fmt.Errorf("base64: %w", err)
	}
	*b = out
	return nil
}

// keyFiles is the folder's key files by key type: type -> id -> path. Baileys
// names them <type>-<id>.json with "/" in the id written as "__" and ":" as "-".
type keyFiles map[string]map[string]string

var keyTypes = []string{"app-state-sync-version", "app-state-sync-key", "sender-key-memory", "sender-key", "lid-mapping", "identity-key", "pre-key", "session", "device-list", "tctoken"}

func readFiles(dir string) (keyFiles, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	out := keyFiles{}
	for _, e := range entries {
		name, ok := strings.CutSuffix(e.Name(), ".json")
		if !ok || e.IsDir() || name == "creds" {
			continue
		}
		for _, t := range keyTypes {
			if id, ok := strings.CutPrefix(name, t+"-"); ok {
				if out[t] == nil {
					out[t] = map[string]string{}
				}
				out[t][id] = filepath.Join(dir, e.Name())
				break
			}
		}
	}
	return out, nil
}

func (f keyFiles) sorted(keyType string) []string {
	ids := make([]string, 0, len(f[keyType]))
	for id := range f[keyType] {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

func readJSON(path string, into any) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(raw, into); err != nil {
		return fmt.Errorf("%s: %w", filepath.Base(path), err)
	}
	return nil
}

// --- pre-keys, identities, LID map --------------------------------------------------

func (c *converter) preKeys(f keyFiles) error {
	tx, err := c.st.DB.BeginTx(c.ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, id := range f.sorted("pre-key") {
		n, err := strconv.ParseUint(id, 10, 32)
		if err != nil {
			continue
		}
		var k keyPair
		if err := readJSON(f["pre-key"][id], &k); err != nil {
			return err
		}
		priv, err := array32(k.Private, "pre-key "+id)
		if err != nil {
			return err
		}
		uploaded := uint32(n) < c.creds.FirstUnuploadedPreKeyID
		if _, err := tx.ExecContext(c.ctx, `INSERT INTO whatsmeow_pre_keys (jid, key_id, key, uploaded) VALUES (?, ?, ?, ?)`, c.jid, n, priv[:], uploaded); err != nil {
			return err
		}
		c.res.PreKeys++
	}
	return tx.Commit()
}

// signalAddress turns a Baileys address ("491234.7", "123_1.5") into whatsmeow's
// ("491234:7", "123_1:5").
func signalAddress(id string) (string, bool) {
	i := strings.LastIndex(id, ".")
	if i <= 0 || i == len(id)-1 {
		return "", false
	}
	return id[:i] + ":" + id[i+1:], true
}

func (c *converter) putIdentity(address string, key []byte) error {
	if len(key) == 33 && key[0] == 5 {
		key = key[1:]
	}
	k, err := array32(key, "identity key of "+address)
	if err != nil {
		return err
	}
	if err := c.device.Identities.PutIdentity(c.ctx, address, *k); err != nil {
		return err
	}
	c.res.Identities++
	return nil
}

func (c *converter) identities(f keyFiles) error {
	for _, id := range f.sorted("identity-key") {
		address, ok := signalAddress(id)
		if !ok {
			continue
		}
		var key buf
		if err := readJSON(f["identity-key"][id], &key); err != nil {
			return err
		}
		if err := c.putIdentity(address, key); err != nil {
			return err
		}
	}
	return nil
}

func (c *converter) lidMappings(f keyFiles) error {
	for _, pn := range f.sorted("lid-mapping") {
		if strings.HasSuffix(pn, "_reverse") {
			continue
		}
		var lid string
		if err := readJSON(f["lid-mapping"][pn], &lid); err != nil {
			return err
		}
		if lid == "" {
			continue
		}
		err := c.device.LIDs.PutLIDMapping(c.ctx,
			types.NewJID(lid, types.HiddenUserServer), types.NewJID(pn, types.DefaultUserServer))
		if err != nil {
			return err
		}
		c.res.LIDMappings++
	}
	return nil
}

// --- app state -------------------------------------------------------------------------

type longValue int64

// UnmarshalJSON reads a protobuf int64 as number, numeric string or Long object.
func (l *longValue) UnmarshalJSON(data []byte) error {
	var s string
	if err := json.Unmarshal(data, &s); err == nil {
		n, err := strconv.ParseInt(s, 10, 64)
		*l = longValue(n)
		return err
	}
	var long struct {
		Low  int32 `json:"low"`
		High int32 `json:"high"`
	}
	if err := json.Unmarshal(data, &long); err == nil && bytes.HasPrefix(bytes.TrimSpace(data), []byte("{")) {
		*l = longValue(int64(long.High)<<32 | int64(uint32(long.Low)))
		return nil
	}
	var n int64
	if err := json.Unmarshal(data, &n); err != nil {
		return err
	}
	*l = longValue(n)
	return nil
}

func (c *converter) appStateKeys(f keyFiles) error {
	for _, id := range f.sorted("app-state-sync-key") {
		keyID, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(id, "__", "/"))
		if err != nil {
			return fmt.Errorf("app-state-sync-key-%s: %w", id, err)
		}
		var k struct {
			KeyData     buf `json:"keyData"`
			Fingerprint *struct {
				RawID         uint32   `json:"rawId"`
				CurrentIndex  uint32   `json:"currentIndex"`
				DeviceIndexes []uint32 `json:"deviceIndexes"`
			} `json:"fingerprint"`
			Timestamp longValue `json:"timestamp"`
		}
		if err := readJSON(f["app-state-sync-key"][id], &k); err != nil {
			return err
		}
		fp := &waE2E.AppStateSyncKeyFingerprint{}
		if k.Fingerprint != nil {
			fp.RawID, fp.CurrentIndex, fp.DeviceIndexes = &k.Fingerprint.RawID, &k.Fingerprint.CurrentIndex, k.Fingerprint.DeviceIndexes
		}
		marshaled, err := proto.Marshal(fp)
		if err != nil {
			return err
		}
		err = c.device.AppStateKeys.PutAppStateSyncKey(c.ctx, keyID, store.AppStateSyncKey{Data: k.KeyData, Fingerprint: marshaled, Timestamp: int64(k.Timestamp)})
		if err != nil {
			return err
		}
		c.res.AppStateKeys++
	}
	return nil
}

func (c *converter) appStateVersions(f keyFiles) error {
	for _, name := range f.sorted("app-state-sync-version") {
		var v struct {
			Version       uint64 `json:"version"`
			Hash          buf    `json:"hash"`
			IndexValueMap map[string]struct {
				ValueMac buf `json:"valueMac"`
			} `json:"indexValueMap"`
		}
		if err := readJSON(f["app-state-sync-version"][name], &v); err != nil {
			return err
		}
		if v.Version == 0 {
			continue
		}
		if len(v.Hash) != 128 {
			return fmt.Errorf("app-state-sync-version-%s: hash has %d bytes, want 128", name, len(v.Hash))
		}
		if err := c.device.AppState.PutAppStateVersion(c.ctx, name, v.Version, [128]byte(v.Hash)); err != nil {
			return err
		}
		var macs []store.AppStateMutationMAC
		for index, entry := range v.IndexValueMap {
			indexMAC, err := base64.StdEncoding.DecodeString(index)
			if err != nil {
				return fmt.Errorf("app-state-sync-version-%s index: %w", name, err)
			}
			macs = append(macs, store.AppStateMutationMAC{IndexMAC: indexMAC, ValueMAC: entry.ValueMac})
		}
		sort.Slice(macs, func(i, j int) bool { return bytes.Compare(macs[i].IndexMAC, macs[j].IndexMAC) < 0 })
		if len(macs) > 0 {
			if err := c.device.AppState.PutAppStateMutationMACs(c.ctx, name, v.Version, macs); err != nil {
				return err
			}
		}
		c.res.AppStateVersions++
	}
	return nil
}

// --- sender keys -----------------------------------------------------------------------

func (c *converter) senderKeys(f keyFiles) error {
	for _, id := range f.sorted("sender-key") {
		// <group>--<id>--<device>: Baileys wrote "group::id::device" and the file
		// name turned ":" into "-".
		parts := strings.Split(id, "--")
		if len(parts) < 3 {
			continue
		}
		device := parts[len(parts)-1]
		sender := parts[len(parts)-2]
		group := strings.Join(parts[:len(parts)-2], "--")
		var wrapped buf
		if err := readJSON(f["sender-key"][id], &wrapped); err != nil {
			return err
		}
		record, err := senderKeyRecord(wrapped)
		if err != nil {
			return fmt.Errorf("sender-key-%s: %w", id, err)
		}
		if err := c.device.SenderKeys.PutSenderKey(c.ctx, group, sender+":"+device, record); err != nil {
			return err
		}
		c.res.SenderKeys++
	}
	return nil
}

type nodeSenderState struct {
	SenderKeyID    uint32 `json:"senderKeyId"`
	SenderChainKey struct {
		Iteration uint32 `json:"iteration"`
		Seed      buf    `json:"seed"`
	} `json:"senderChainKey"`
	SenderSigningKey struct {
		Public  buf `json:"public"`
		Private buf `json:"private"`
	} `json:"senderSigningKey"`
	SenderMessageKeys []struct {
		Iteration uint32 `json:"iteration"`
		Seed      buf    `json:"seed"`
	} `json:"senderMessageKeys"`
}

// senderKeyRecord rebuilds a Baileys sender-key record (a Buffer holding JSON
// text) as a libsignal protobuf record.
func senderKeyRecord(text []byte) ([]byte, error) {
	var states []nodeSenderState
	if err := json.Unmarshal(text, &states); err != nil {
		return nil, err
	}
	structure := &grouprecord.SenderKeyStructure{}
	for _, s := range states {
		public := []byte(s.SenderSigningKey.Public)
		if len(public) == 32 {
			public = append([]byte{5}, public...)
		}
		state := &grouprecord.SenderKeyStateStructure{
			KeyID:             s.SenderKeyID,
			SenderChainKey:    &ratchet.SenderChainKeyStructure{Iteration: s.SenderChainKey.Iteration, ChainKey: s.SenderChainKey.Seed},
			SigningKeyPublic:  public,
			SigningKeyPrivate: s.SenderSigningKey.Private,
		}
		for _, k := range s.SenderMessageKeys {
			derived, err := ratchet.NewSenderMessageKey(k.Iteration, k.Seed)
			if err != nil {
				return nil, err
			}
			state.Keys = append(state.Keys, ratchet.NewStructFromSenderMessageKey(derived))
		}
		structure.SenderKeyStates = append(structure.SenderKeyStates, state)
	}
	return serialize.NewProtoBufSerializer().SenderKeyRecord.Serialize(structure), nil
}

// --- sessions --------------------------------------------------------------------------

type orderedChains []namedChain

type namedChain struct {
	key   string
	chain nodeChain
}

type nodeChain struct {
	ChainKey struct {
		Counter int64 `json:"counter"`
		Key     buf   `json:"key"`
	} `json:"chainKey"`
	ChainType   int            `json:"chainType"`
	MessageKeys map[string]buf `json:"messageKeys"`
}

// UnmarshalJSON keeps the chains in file order: that is the order libsignal
// evicts the oldest receiver chain in.
func (o *orderedChains) UnmarshalJSON(data []byte) error {
	dec := json.NewDecoder(bytes.NewReader(data))
	if _, err := dec.Token(); err != nil {
		return err
	}
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return err
		}
		var ch nodeChain
		if err := dec.Decode(&ch); err != nil {
			return err
		}
		*o = append(*o, namedChain{key: keyTok.(string), chain: ch})
	}
	return nil
}

type nodeEntry struct {
	RegistrationID uint32 `json:"registrationId"`
	CurrentRatchet struct {
		EphemeralKeyPair struct {
			PubKey  buf `json:"pubKey"`
			PrivKey buf `json:"privKey"`
		} `json:"ephemeralKeyPair"`
		LastRemoteEphemeralKey buf    `json:"lastRemoteEphemeralKey"`
		PreviousCounter        uint32 `json:"previousCounter"`
		RootKey                buf    `json:"rootKey"`
	} `json:"currentRatchet"`
	IndexInfo struct {
		BaseKey           buf   `json:"baseKey"`
		Closed            int64 `json:"closed"`
		Used              int64 `json:"used"`
		RemoteIdentityKey buf   `json:"remoteIdentityKey"`
	} `json:"indexInfo"`
	Chains        orderedChains `json:"_chains"`
	PendingPreKey *struct {
		PreKeyID    *uint32 `json:"preKeyId"`
		SignedKeyID uint32  `json:"signedKeyId"`
		BaseKey     buf     `json:"baseKey"`
	} `json:"pendingPreKey"`
}

type nodeSessionRecord struct {
	Sessions map[string]nodeEntry `json:"_sessions"`
}

func (c *converter) sessions(f keyFiles) error {
	localIdentity := append([]byte{5}, c.creds.SignedIdentityKey.Public...)
	for _, id := range f.sorted("session") {
		address, ok := signalAddress(id)
		if !ok {
			continue
		}
		var rec nodeSessionRecord
		if err := readJSON(f["session"][id], &rec); err != nil {
			return err
		}
		structure, err := sessionStructure(rec, localIdentity, c.creds.RegistrationID)
		if err != nil {
			return fmt.Errorf("session-%s: %w", id, err)
		}
		if structure == nil {
			c.res.SessionsSkipped++
			continue
		}
		raw := serialize.NewProtoBufSerializer().Session.Serialize(structure)
		if err := c.device.Sessions.PutSession(c.ctx, address, raw); err != nil {
			return err
		}
		c.res.Sessions++
		if remote := structure.SessionState.RemoteIdentityPublic; len(remote) == 33 {
			if err := c.putIdentityIfMissing(address, remote); err != nil {
				return err
			}
		}
	}
	return nil
}

func (c *converter) putIdentityIfMissing(address string, key []byte) error {
	trusted, err := c.device.Identities.IsTrustedIdentity(c.ctx, address, [32]byte(key[1:]))
	if err != nil || !trusted {
		return err
	}
	// IsTrustedIdentity is true both for an equal key and for no key at all;
	// writing the session's own key is right in either case.
	return c.putIdentity(address, key)
}

// sessionStructure rebuilds one libsignal-node session record. The open
// session becomes the current state and the closed ones the archive, most
// recently used first. It returns nil when no session is open.
func sessionStructure(rec nodeSessionRecord, localIdentity []byte, localRegistrationID uint32) (*record.SessionStructure, error) {
	var open []nodeEntry
	var closed []nodeEntry
	keysSorted := make([]string, 0, len(rec.Sessions))
	for k := range rec.Sessions {
		keysSorted = append(keysSorted, k)
	}
	sort.Strings(keysSorted)
	for _, k := range keysSorted {
		if e := rec.Sessions[k]; e.IndexInfo.Closed == -1 {
			open = append(open, e)
		} else {
			closed = append(closed, e)
		}
	}
	if len(open) == 0 {
		return nil, nil
	}
	sort.SliceStable(open, func(i, j int) bool { return open[i].IndexInfo.Used > open[j].IndexInfo.Used })
	sort.SliceStable(closed, func(i, j int) bool { return closed[i].IndexInfo.Used > closed[j].IndexInfo.Used })

	current, err := stateStructure(open[0], localIdentity, localRegistrationID)
	if err != nil {
		return nil, err
	}
	out := &record.SessionStructure{SessionState: current}
	for _, e := range append(open[1:], closed...) {
		archived, err := stateStructure(e, localIdentity, localRegistrationID)
		if err != nil {
			continue // an archived state that cannot be rebuilt is not worth failing the session
		}
		out.PreviousStates = append(out.PreviousStates, archived)
	}
	return out, nil
}

func stateStructure(e nodeEntry, localIdentity []byte, localRegistrationID uint32) (*record.StateStructure, error) {
	ratchetPub := []byte(e.CurrentRatchet.EphemeralKeyPair.PubKey)
	s := &record.StateStructure{
		LocalIdentityPublic:  localIdentity,
		LocalRegistrationID:  localRegistrationID,
		PreviousCounter:      e.CurrentRatchet.PreviousCounter,
		RemoteIdentityPublic: e.IndexInfo.RemoteIdentityKey,
		RemoteRegistrationID: e.RegistrationID,
		RootKey:              e.CurrentRatchet.RootKey,
		SenderBaseKey:        e.IndexInfo.BaseKey,
		SessionVersion:       sessionVersion,
	}
	if e.PendingPreKey != nil {
		pending := &record.PendingPreKeyStructure{SignedPreKeyID: e.PendingPreKey.SignedKeyID, BaseKey: e.PendingPreKey.BaseKey}
		if e.PendingPreKey.PreKeyID != nil {
			pending.PreKeyID = optional.NewOptionalUint32(*e.PendingPreKey.PreKeyID)
		}
		s.PendingPreKey = pending
	}
	sendingKey := base64.StdEncoding.EncodeToString(ratchetPub)
	for _, named := range e.Chains {
		ch := named.chain
		pub, err := base64.StdEncoding.DecodeString(named.key)
		if err != nil {
			return nil, fmt.Errorf("chain key: %w", err)
		}
		messageKeys, err := chainMessageKeys(ch.MessageKeys)
		if err != nil {
			return nil, err
		}
		if len(ch.ChainKey.Key) == 0 && len(messageKeys) == 0 {
			continue // a spent chain nothing can be decrypted with
		}
		structure := &record.ChainStructure{
			SenderRatchetKeyPublic: pub,
			// libsignal-node counts the last index used (-1 before any), libsignal
			// the index of the next message key.
			ChainKey:    &chain.KeyStructure{Key: ch.ChainKey.Key, Index: uint32(ch.ChainKey.Counter + 1)},
			MessageKeys: messageKeys,
		}
		if named.key == sendingKey && ch.ChainType == 1 {
			structure.SenderRatchetKeyPrivate = e.CurrentRatchet.EphemeralKeyPair.PrivKey
			s.SenderChain = structure
		} else if ch.ChainType == 2 {
			s.ReceiverChains = append(s.ReceiverChains, structure)
		}
	}
	if s.SenderChain == nil || len(s.SenderChain.ChainKey.Key) == 0 {
		return nil, errors.New("session has no usable sending chain")
	}
	return s, nil
}

// chainMessageKeys derives the cipher key, MAC key and IV libsignal stores for
// each skipped message from the 32-byte seed libsignal-node kept.
func chainMessageKeys(seeds map[string]buf) ([]*message.KeysStructure, error) {
	indexes := make([]uint32, 0, len(seeds))
	for idx := range seeds {
		n, err := strconv.ParseUint(idx, 10, 32)
		if err != nil {
			return nil, fmt.Errorf("message key index %q", idx)
		}
		indexes = append(indexes, uint32(n))
	}
	sort.Slice(indexes, func(i, j int) bool { return indexes[i] < indexes[j] })
	out := make([]*message.KeysStructure, 0, len(indexes))
	for _, n := range indexes {
		material, err := kdf.DeriveSecrets(seeds[strconv.FormatUint(uint64(n), 10)], nil, []byte(message.KdfSalt), message.DerivedSecretsSize)
		if err != nil {
			return nil, err
		}
		out = append(out, &message.KeysStructure{CipherKey: material[:32], MacKey: material[32:64], IV: material[64:80], Index: n})
	}
	return out, nil
}
