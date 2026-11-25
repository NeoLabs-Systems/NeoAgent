package whatsapp

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp/baileysconv"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp/wastore"
)

// waClient is the part of whatsmeow the adapter uses. The adapter's decisions
// are tested against a fake of it; realClient is the whatsmeow client.
type waClient interface {
	// AddEventHandler registers the handler for whatsmeow events (the types of
	// go.mau.fi/whatsmeow/types/events).
	AddEventHandler(func(any))
	// IsPaired reports whether a device is linked.
	IsPaired() bool
	// QRChannel returns the pairing codes; only valid before Connect on an
	// unpaired client.
	QRChannel(ctx context.Context) (<-chan qrItem, error)
	Connect() error
	Disconnect()
	// Logout unlinks the device on WhatsApp's side.
	Logout(ctx context.Context) error
	// Own returns the account's phone and LID addresses (either may be empty).
	Own() (jid, lid types.JID)
	Send(ctx context.Context, to types.JID, msg *waE2E.Message) (id string, err error)
	Upload(ctx context.Context, data []byte, kind mediaKind) (uploaded, error)
	BuildPoll(name string, options []string) *waE2E.Message
	BuildReaction(chat, sender types.JID, id, emoji string) *waE2E.Message
	BuildRevoke(chat, sender types.JID, id string) *waE2E.Message
	MarkRead(ctx context.Context, id string, chat, sender types.JID, at time.Time) error
	SetTyping(ctx context.Context, chat types.JID, typing bool) error
	// DecryptVote returns the option hashes a poll vote selected.
	DecryptVote(ctx context.Context, evt *events.Message) ([][]byte, error)
	Download(ctx context.Context, m whatsmeow.DownloadableMessage) ([]byte, error)
	LIDForPN(ctx context.Context, pn types.JID) (types.JID, error)
	PNForLID(ctx context.Context, lid types.JID) (types.JID, error)
	Groups(ctx context.Context) ([]groupInfo, error)
	Contacts(ctx context.Context) ([]contactInfo, error)
	// Close releases the device store.
	Close() error
}

type qrItem struct {
	// Event is "code" for a new code, "success" or "timeout" for the end of
	// pairing, anything else for a pairing error.
	Event string
	Code  string
}

type mediaKind int

const (
	mediaImage mediaKind = iota
	mediaVideo
	mediaAudio
	mediaDocument
)

type uploaded struct {
	URL, DirectPath                     string
	MediaKey, FileEncSHA256, FileSHA256 []byte
	Length                              uint64
}

type groupInfo struct{ JID, Name string }

type contactInfo struct {
	JID  types.JID
	Name string
}

// openClient opens the agent's device store in authDir, moving a Baileys login
// there first when that is all authDir holds, and builds the whatsmeow client.
func openClient(ctx context.Context, authDir string) (waClient, error) {
	storePath := filepath.Join(authDir, wastore.FileName)
	if err := convertBaileysLogin(ctx, authDir, storePath); err != nil {
		return nil, err
	}
	st, err := wastore.Open(ctx, storePath)
	if err != nil {
		return nil, err
	}
	device, err := st.Container.GetFirstDevice(ctx)
	if err != nil {
		_ = st.Close()
		return nil, err
	}
	cli := whatsmeow.NewClient(device, nil)
	// The adapter owns reconnecting: it backs off like the Node server did and
	// tells the manager what is going on.
	cli.EnableAutoReconnect = false
	return &realClient{cli: cli, store: st}, nil
}

// legacyLoginError is a login the adapter cannot continue and only the user can
// fix: unlinking and scanning a new QR code.
type legacyLoginError struct{ err error }

func (e *legacyLoginError) Error() string {
	return "WhatsApp login could not be moved to the new store: " + e.err.Error()
}
func (e *legacyLoginError) Unwrap() error            { return e.err }
func (e *legacyLoginError) RequiresUserAction() bool { return true }
func (e *legacyLoginError) Reason() string           { return "authentication_required" }

// convertBaileysLogin converts a Baileys auth folder (creds.json) into the
// whatsmeow store when there is no store yet. The Baileys files stay where they
// are: they hold the only copy of the login should the move have to be redone.
func convertBaileysLogin(ctx context.Context, authDir, storePath string) error {
	if _, err := os.Stat(storePath); err == nil {
		return nil
	}
	if _, err := os.Stat(filepath.Join(authDir, "creds.json")); errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return err
	}
	_, err := baileysconv.Convert(ctx, authDir, storePath)
	if err == nil {
		return nil
	}
	_ = os.Remove(storePath)
	if errors.Is(err, baileysconv.ErrNotLinked) {
		return nil // never linked: there is nothing to keep, pairing starts fresh
	}
	return &legacyLoginError{err}
}

type realClient struct {
	cli   *whatsmeow.Client
	store *wastore.Store
}

func (c *realClient) AddEventHandler(fn func(any)) { c.cli.AddEventHandler(fn) }
func (c *realClient) IsPaired() bool               { return c.cli.Store.ID != nil }
func (c *realClient) Connect() error               { return c.cli.Connect() }
func (c *realClient) Disconnect()                  { c.cli.Disconnect() }
func (c *realClient) Logout(ctx context.Context) error {
	return c.cli.Logout(ctx)
}
func (c *realClient) Close() error { return c.store.Close() }

func (c *realClient) QRChannel(ctx context.Context) (<-chan qrItem, error) {
	src, err := c.cli.GetQRChannel(ctx)
	if err != nil {
		return nil, err
	}
	out := make(chan qrItem)
	go func() {
		defer close(out)
		for item := range src {
			select {
			case out <- qrItem{Event: item.Event, Code: item.Code}:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out, nil
}

func (c *realClient) Own() (types.JID, types.JID) {
	return c.cli.Store.GetJID().ToNonAD(), c.cli.Store.GetLID().ToNonAD()
}

func (c *realClient) Send(ctx context.Context, to types.JID, msg *waE2E.Message) (string, error) {
	resp, err := c.cli.SendMessage(ctx, to, msg)
	return resp.ID, err
}

func (c *realClient) Upload(ctx context.Context, data []byte, kind mediaKind) (uploaded, error) {
	appInfo := map[mediaKind]whatsmeow.MediaType{
		mediaImage: whatsmeow.MediaImage, mediaVideo: whatsmeow.MediaVideo,
		mediaAudio: whatsmeow.MediaAudio, mediaDocument: whatsmeow.MediaDocument,
	}[kind]
	r, err := c.cli.Upload(ctx, data, appInfo)
	return uploaded{URL: r.URL, DirectPath: r.DirectPath, MediaKey: r.MediaKey, FileEncSHA256: r.FileEncSHA256, FileSHA256: r.FileSHA256, Length: r.FileLength}, err
}

func (c *realClient) BuildPoll(name string, options []string) *waE2E.Message {
	return c.cli.BuildPollCreation(name, options, 1)
}

func (c *realClient) BuildReaction(chat, sender types.JID, id, emoji string) *waE2E.Message {
	return c.cli.BuildReaction(chat, sender, id, emoji)
}

func (c *realClient) BuildRevoke(chat, sender types.JID, id string) *waE2E.Message {
	return c.cli.BuildRevoke(chat, sender, id)
}

func (c *realClient) MarkRead(ctx context.Context, id string, chat, sender types.JID, at time.Time) error {
	return c.cli.MarkRead(ctx, []types.MessageID{id}, at, chat, sender)
}

func (c *realClient) SetTyping(ctx context.Context, chat types.JID, typing bool) error {
	state := types.ChatPresencePaused
	if typing {
		state = types.ChatPresenceComposing
	}
	return c.cli.SendChatPresence(ctx, chat, state, types.ChatPresenceMediaText)
}

func (c *realClient) DecryptVote(ctx context.Context, evt *events.Message) ([][]byte, error) {
	vote, err := c.cli.DecryptPollVote(ctx, evt)
	if err != nil {
		return nil, err
	}
	return vote.GetSelectedOptions(), nil
}

func (c *realClient) Download(ctx context.Context, m whatsmeow.DownloadableMessage) ([]byte, error) {
	return c.cli.Download(ctx, m)
}

func (c *realClient) LIDForPN(ctx context.Context, pn types.JID) (types.JID, error) {
	return c.cli.Store.LIDs.GetLIDForPN(ctx, pn)
}

func (c *realClient) PNForLID(ctx context.Context, lid types.JID) (types.JID, error) {
	return c.cli.Store.LIDs.GetPNForLID(ctx, lid)
}

func (c *realClient) Groups(ctx context.Context) ([]groupInfo, error) {
	groups, err := c.cli.GetJoinedGroups(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]groupInfo, len(groups))
	for i, g := range groups {
		out[i] = groupInfo{JID: g.JID.String(), Name: g.Name}
	}
	return out, nil
}

func (c *realClient) Contacts(ctx context.Context) ([]contactInfo, error) {
	all, err := c.cli.Store.Contacts.GetAllContacts(ctx)
	if err != nil {
		return nil, fmt.Errorf("read contacts: %w", err)
	}
	out := make([]contactInfo, 0, len(all))
	for jid, info := range all {
		out = append(out, contactInfo{JID: jid, Name: firstNonEmpty(info.FullName, info.PushName, info.FirstName)})
	}
	return out, nil
}
