package whatsapppersonal

import (
	"context"
	"os"
	"path/filepath"
	"strings"

	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/proto/waWeb"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"
	"google.golang.org/protobuf/proto"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp/wastore"
)

// Device is the part of a whatsmeow client the provider uses; tests replace
// it with a fake.
type Device interface {
	// AddEventHandler receives whatsmeow events (go.mau.fi/whatsmeow/types/events).
	AddEventHandler(func(any))
	IsPaired() bool
	// QRChannel streams pairing codes; only valid before Connect on an
	// unpaired device. Event is "code", "success", "timeout" or an error.
	QRChannel(ctx context.Context) (<-chan QRItem, error)
	Connect() error
	Disconnect()
	Logout(ctx context.Context) error
	// OwnJID is the linked account's phone address.
	OwnJID() string
	SendText(ctx context.Context, to types.JID, text string) error
	ParseWebMessage(chat types.JID, msg *waWeb.WebMessageInfo) (*events.Message, error)
	// Close releases the device store.
	Close() error
}

// QRItem is one pairing event.
type QRItem struct {
	Event string
	Code  string
}

// Opener opens the device store kept in authDir.
type Opener func(ctx context.Context, authDir string) (Device, error)

// OpenStore opens the whatsmeow store in authDir, moving a Baileys login of an
// earlier Node install there first.
func OpenStore(ctx context.Context, authDir string) (Device, error) {
	if err := os.MkdirAll(authDir, 0o700); err != nil {
		return nil, err
	}
	_ = os.Chmod(authDir, 0o700)
	storePath := filepath.Join(authDir, wastore.FileName)
	if err := whatsapp.ConvertBaileysLogin(ctx, authDir, storePath); err != nil {
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
	cli.EnableAutoReconnect = true
	return &realDevice{cli: cli, store: st}, nil
}

type realDevice struct {
	cli   *whatsmeow.Client
	store *wastore.Store
}

func (d *realDevice) AddEventHandler(fn func(any)) { d.cli.AddEventHandler(fn) }
func (d *realDevice) IsPaired() bool               { return d.cli.Store.ID != nil }
func (d *realDevice) Connect() error               { return d.cli.Connect() }
func (d *realDevice) Disconnect()                  { d.cli.Disconnect() }
func (d *realDevice) Logout(ctx context.Context) error {
	return d.cli.Logout(ctx)
}
func (d *realDevice) Close() error { return d.store.Close() }

func (d *realDevice) OwnJID() string {
	if id := d.cli.Store.GetJID(); !id.IsEmpty() {
		return id.String()
	}
	return ""
}

func (d *realDevice) QRChannel(ctx context.Context) (<-chan QRItem, error) {
	src, err := d.cli.GetQRChannel(ctx)
	if err != nil {
		return nil, err
	}
	out := make(chan QRItem)
	go func() {
		defer close(out)
		for item := range src {
			select {
			case out <- QRItem{Event: item.Event, Code: item.Code}:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out, nil
}

func (d *realDevice) SendText(ctx context.Context, to types.JID, text string) error {
	_, err := d.cli.SendMessage(ctx, to, &waE2E.Message{Conversation: proto.String(text)})
	return err
}

func (d *realDevice) ParseWebMessage(chat types.JID, msg *waWeb.WebMessageInfo) (*events.Message, error) {
	return d.cli.ParseWebMessage(chat, msg)
}

// normalizeID reduces an address to the digits of its user part, or to the
// user part when it has none (normalizeWhatsAppId).
func normalizeID(value string) string {
	raw := strings.ToLower(strings.TrimSpace(value))
	if raw == "" {
		return ""
	}
	base, _, _ := strings.Cut(raw, "@")
	primary, _, _ := strings.Cut(base, ":")
	digits := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, primary)
	if digits != "" {
		return digits
	}
	return primary
}

// chatJID is the chat address of a JID or a phone number.
func chatJID(value string) string {
	raw := strings.TrimSpace(value)
	if strings.Contains(raw, "@") {
		return raw
	}
	id := normalizeID(raw)
	if id == "" {
		return ""
	}
	return id + "@s.whatsapp.net"
}
