// Package whatsapp is the WhatsApp platform adapter, on whatsmeow. There is no call handling:
// incoming calls are left to ring.
package whatsapp

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

const (
	sentMessageMemory    = 200
	badSessionRetryLimit = 5
	stableConnection     = 2 * time.Minute
	pollNameLimit        = 255
	aliasLookup          = 3 * time.Second
	reconnectBase        = time.Second
	reconnectMax         = time.Minute
)

// InboundMedia is an attachment to store for the account that received it.
type InboundMedia struct {
	FilenameBase string
	Extension    string
	ContentType  string
	Content      []byte
	MessageID    string
	MediaType    string
}

// MediaStore keeps inbound attachments (the per-user artifact store).
type MediaStore interface {
	// SaveInboundMedia stores the attachment and returns the file's path.
	SaveInboundMedia(ctx context.Context, userID int64, media InboundMedia) (path string, err error)
}

// Deps are what the adapter needs beyond messaging.Config.
type Deps struct {
	Media MediaStore
	// AgentName is the agent's display name, which labels its replies in the
	// self chat. It may be nil.
	AgentName func(userID int64, agentID string) string

	// open builds the client of an auth directory; tests replace it.
	open func(ctx context.Context, authDir string) (waClient, error)
}

// Factory returns the WhatsApp adapter factory for the manager.
func Factory(deps Deps) messaging.Factory {
	if deps.open == nil {
		deps.open = openClient
	}
	return func(cfg messaging.Config, ev messaging.Events) (messaging.Platform, error) {
		return newPlatform(cfg, ev, deps), nil
	}
}

type approvalPoll struct {
	options []messaging.ApprovalOption
}

// Platform is one WhatsApp connection.
type Platform struct {
	cfg      messaging.Config
	deps     Deps
	ev       messaging.Events
	guard    *messaging.AccessGuard
	log      *slog.Logger
	selfChat bool

	mu          sync.Mutex
	cl          waClient
	cancel      context.CancelFunc
	status      string
	qr          string
	attempts    int
	manual      bool
	timer       *time.Timer
	stableTimer *time.Timer
	connectedAt time.Time // zero until a connection opens: nothing counts as new before
	sent        []string
	polls       map[string]approvalPoll
}

func newPlatform(cfg messaging.Config, ev messaging.Events, deps Deps) *Platform {
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	selfChat := cfg.Settings["selfChatMode"] == true || cfg.Settings["selfChatMode"] == "true"
	return &Platform{
		cfg: cfg, deps: deps, ev: ev,
		guard:    messaging.NewAccessGuard("whatsapp", cfg, ev),
		log:      log.With("platform", "whatsapp"),
		selfChat: selfChat,
		status:   messaging.StatusDisconnected,
		polls:    map[string]approvalPoll{},
	}
}

var _ interface {
	messaging.Platform
	messaging.Logouter
	messaging.Reactor
	messaging.ReadMarker
	messaging.Typer
	messaging.ApprovalPrompter
	messaging.AccessTargetLister
	messaging.ChatAliaser
	messaging.OwnerChatter
} = (*Platform)(nil)

// --- messaging.Platform ---------------------------------------------------------

func (p *Platform) Status() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.status
}

func (p *Platform) SetAccessPolicy(policy messaging.AccessPolicy) { p.guard.SetPolicy(policy) }
func (p *Platform) AccessPolicy() messaging.AccessPolicy          { return p.guard.Policy() }

// AuthInfo is what the QR screen reads: the pairing code while waiting for a
// scan, the status and the linked number.
func (p *Platform) AuthInfo() map[string]any {
	p.mu.Lock()
	defer p.mu.Unlock()
	info := map[string]any{"qrCode": nil, "status": p.status, "number": nil}
	if p.qr != "" {
		info["qrCode"] = p.qr
	}
	if p.cl != nil {
		jid, _ := p.cl.Own()
		if n := normalizeID(jid.String()); n != "" {
			info["number"] = n
		}
	}
	return info
}

// Connect opens the store, starts whatsmeow and returns once the socket is up;
// the account is usable when Events.Connected follows (or Events.QR asks for a
// scan).
func (p *Platform) Connect(ctx context.Context) error {
	p.mu.Lock()
	p.manual = false
	p.stopTimerLocked()
	if p.cl != nil {
		p.log.Warn("Closing the previous WhatsApp client before connecting again.")
		p.discardLocked()
	}
	p.mu.Unlock()

	if err := os.MkdirAll(p.cfg.AuthDir, 0o700); err != nil {
		return err
	}
	cl, err := p.deps.open(ctx, p.cfg.AuthDir)
	if err != nil {
		return err
	}
	runCtx, cancel := context.WithCancel(context.Background())
	cl.AddEventHandler(func(evt any) { p.handleEvent(cl, evt) })

	p.mu.Lock()
	p.cl, p.cancel = cl, cancel
	p.mu.Unlock()

	if !cl.IsPaired() {
		codes, err := cl.QRChannel(runCtx)
		if err != nil {
			p.discard(cl)
			return err
		}
		go p.watchQR(cl, codes)
	}
	if err := cl.Connect(); err != nil {
		p.discard(cl)
		return err
	}
	return nil
}

// Disconnect stops the connection for good; the manager reconnects explicitly.
func (p *Platform) Disconnect(context.Context) error {
	p.mu.Lock()
	p.manual = true
	p.stopTimerLocked()
	p.discardLocked()
	p.status = messaging.StatusDisconnected
	p.mu.Unlock()
	p.ev.Disconnected(messaging.Disconnect{Manual: true})
	return nil
}

// Logout unlinks the device and deletes its login.
func (p *Platform) Logout(ctx context.Context) error {
	p.mu.Lock()
	p.manual = true
	p.stopTimerLocked()
	cl := p.cl
	p.mu.Unlock()
	if cl != nil && cl.IsPaired() {
		if err := cl.Logout(ctx); err != nil {
			return err
		}
	}
	p.mu.Lock()
	p.discardLocked()
	p.status, p.qr = messaging.StatusDisconnected, ""
	p.mu.Unlock()
	return os.RemoveAll(p.cfg.AuthDir)
}

// discard drops cl when it is still the current client.
func (p *Platform) discard(cl waClient) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.cl == cl {
		p.discardLocked()
	}
}

// discardLocked throws the client away. Two live clients on one login would
// make WhatsApp replace the first, and both would reconnect forever.
func (p *Platform) discardLocked() {
	cl := p.cl
	p.cl = nil
	if p.cancel != nil {
		p.cancel()
		p.cancel = nil
	}
	if p.stableTimer != nil {
		p.stableTimer.Stop()
		p.stableTimer = nil
	}
	if cl != nil {
		cl.Disconnect()
		if err := cl.Close(); err != nil {
			p.log.Warn("Closing the WhatsApp store failed.", "error", err)
		}
	}
}

func (p *Platform) stopTimerLocked() {
	if p.timer != nil {
		p.timer.Stop()
		p.timer = nil
	}
}

// --- connection events ------------------------------------------------------------

func (p *Platform) current(cl waClient) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.cl == cl
}

func (p *Platform) watchQR(cl waClient, codes <-chan qrItem) {
	for item := range codes {
		switch item.Event {
		case "code":
			p.mu.Lock()
			if p.cl != cl {
				p.mu.Unlock()
				return
			}
			first := p.status != messaging.StatusAwaitingQR
			p.qr, p.status = item.Code, messaging.StatusAwaitingQR
			p.mu.Unlock()
			if first {
				p.log.Warn("Waiting for a QR scan; WhatsApp is not linked and will not receive messages.")
			}
			p.ev.QR(item.Code)
		case "success":
			return
		default:
			// The code expired unscanned: connect again for a fresh one.
			p.connectionClosed(cl, false)
			return
		}
	}
}

func (p *Platform) handleEvent(cl waClient, evt any) {
	if !p.current(cl) {
		return
	}
	switch e := evt.(type) {
	case *events.Connected:
		p.opened(cl)
	case *events.Disconnected, *events.StreamReplaced:
		if _, replaced := e.(*events.StreamReplaced); replaced {
			p.log.Warn("Another WhatsApp Web session took this one over.")
		}
		p.connectionClosed(cl, false)
	case *events.ConnectFailure:
		p.connectionClosed(cl, true)
	case *events.LoggedOut:
		p.loggedOut(cl)
	case *events.Message:
		p.handleMessage(cl, e)
	case *events.GroupInfo:
		p.membership(cl, e)
	}
}

func (p *Platform) opened(cl waClient) {
	p.log.Info("Connection open; inbound messages will be processed.")
	p.mu.Lock()
	p.connectedAt = time.Now()
	p.status, p.qr = messaging.StatusConnected, ""
	// Only a link that survives a while earns a fresh backoff; resetting on open
	// made a link that dies right after opening retry every 2 seconds.
	if p.stableTimer != nil {
		p.stableTimer.Stop()
	}
	p.stableTimer = time.AfterFunc(stableConnection, func() {
		p.mu.Lock()
		defer p.mu.Unlock()
		if p.cl == cl {
			p.attempts = 0
		}
	})
	p.mu.Unlock()
	p.ev.Connected()
}

// connectionClosed handles a lost connection. A session WhatsApp keeps
// rejecting will not heal by reconnecting (every retry is a fresh device login
// that pings the phone), so repeated connect failures stop and ask the user.
func (p *Platform) connectionClosed(cl waClient, rejected bool) {
	p.mu.Lock()
	if p.cl != cl {
		p.mu.Unlock()
		return
	}
	if p.stableTimer != nil {
		p.stableTimer.Stop()
		p.stableTimer = nil
	}
	broken := rejected && p.attempts >= badSessionRetryLimit
	reconnect := !p.manual && !broken
	manual := p.manual
	p.status = messaging.StatusDisconnected
	p.mu.Unlock()

	switch {
	case manual:
		p.log.Warn("Connection closed. Stopped on request.")
	case reconnect:
		p.log.Warn("Connection closed. Reconnecting.")
	default:
		p.log.Warn("Connection closed. Not reconnecting.")
	}
	info := messaging.Disconnect{Manual: manual, RequiresUserAction: broken, ShouldReconnect: &reconnect, WillReconnect: reconnect}
	switch {
	case broken:
		info.Reason = "bad_session"
	case reconnect:
		info.Reason = "connection_lost"
	}
	p.ev.Disconnected(info)
	if reconnect {
		p.scheduleReconnect()
	}
}

func (p *Platform) loggedOut(cl waClient) {
	p.connectionClosedFinal(cl)
	// The dead client goes first so nothing it still writes can put the revoked
	// login back; the next connect then pairs from scratch.
	p.mu.Lock()
	if p.cl != cl {
		p.mu.Unlock()
		return
	}
	p.discardLocked()
	p.qr = ""
	p.mu.Unlock()
	if err := os.RemoveAll(p.cfg.AuthDir); err != nil {
		p.log.Error("Removing the revoked WhatsApp login failed.", "error", err)
	}
	p.ev.LoggedOut()
}

// connectionClosedFinal reports the disconnect that precedes a logout.
func (p *Platform) connectionClosedFinal(cl waClient) {
	p.mu.Lock()
	if p.cl != cl {
		p.mu.Unlock()
		return
	}
	manual := p.manual
	p.status = messaging.StatusDisconnected
	p.mu.Unlock()
	no := false
	p.ev.Disconnected(messaging.Disconnect{Manual: manual, ShouldReconnect: &no})
}

func (p *Platform) scheduleReconnect() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.manual || p.timer != nil {
		return
	}
	p.attempts++
	delay := min(reconnectBase<<min(p.attempts, 10), reconnectMax)
	p.log.Info("Reconnecting.", "inSeconds", int(delay.Seconds()), "attempt", p.attempts)
	p.timer = time.AfterFunc(delay, func() {
		p.mu.Lock()
		p.timer = nil
		manual := p.manual
		p.mu.Unlock()
		if manual {
			return
		}
		if err := p.Connect(context.Background()); err != nil {
			p.log.Error("Reconnect failed.", "error", err)
			p.scheduleReconnect()
		}
	})
}

// --- identity helpers --------------------------------------------------------------

// ownIDs are the digits of the account's own addresses.
func (p *Platform) ownIDs(cl waClient) map[string]bool {
	jid, lid := cl.Own()
	ids := map[string]bool{}
	for _, j := range []types.JID{jid, lid} {
		if n := normalizeID(j.String()); n != "" {
			ids[n] = true
		}
	}
	return ids
}

// ownJIDs are the account's own addresses, phone first.
func ownJIDs(cl waClient) []string {
	jid, lid := cl.Own()
	var out []string
	for _, j := range []types.JID{jid, lid} {
		if s := toJID(j.String()); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func (p *Platform) isSelfChat(cl waClient, chatID string) bool {
	n := normalizeID(chatID)
	return n != "" && p.ownIDs(cl)[n]
}

// OwnerChatID is the owner's own chat in self-chat mode.
func (p *Platform) OwnerChatID() string {
	if !p.selfChat {
		return ""
	}
	p.mu.Lock()
	cl := p.cl
	p.mu.Unlock()
	if cl == nil {
		return ""
	}
	jids := ownJIDs(cl)
	for _, j := range jids {
		if strings.HasSuffix(j, "@s.whatsapp.net") {
			return j
		}
	}
	if len(jids) > 0 {
		return jids[0]
	}
	return ""
}

// addresses is who sent a message in the two forms WhatsApp may use. Contacts
// arrive under a LID, but people are listed and linked by number, so the number
// wins whenever it is known.
type addresses struct{ primary, phone, sender string }

func (p *Platform) senderAddresses(ctx context.Context, cl waClient, src types.MessageSource) addresses {
	var primary, alt types.JID
	if src.IsGroup {
		primary, alt = src.Sender, src.SenderAlt
	} else {
		primary, alt = src.Chat, src.SenderAlt
		if src.IsFromMe {
			alt = src.RecipientAlt
		}
	}
	a := addresses{primary: primary.ToNonAD().String()}
	for _, candidate := range []types.JID{primary, alt} {
		if s := candidate.ToNonAD().String(); isPhoneJID(s) {
			a.phone = s
			break
		}
	}
	// WhatsApp usually sends the number along; otherwise it may be known from
	// earlier traffic.
	if a.phone == "" && primary.Server == types.HiddenUserServer {
		if pn, err := cl.PNForLID(ctx, primary.ToNonAD()); err == nil && !pn.IsEmpty() {
			a.phone = pn.ToNonAD().String()
		}
	}
	a.sender = firstNonEmpty(a.phone, a.primary)
	return a
}

func (p *Platform) addressedToBot(cl waClient, m *waE2E.Message) bool {
	own := p.ownIDs(cl)
	if len(own) == 0 {
		return false
	}
	ci := contextInfo(m)
	for _, jid := range ci.GetMentionedJID() {
		if own[normalizeID(jid)] {
			return true
		}
	}
	if own[normalizeID(ci.GetParticipant())] {
		return true
	}
	text := groupText(m)
	for id := range own {
		if strings.Contains(text, "@"+id) {
			return true
		}
	}
	return false
}

func (p *Platform) agentName() string {
	if p.deps.AgentName == nil {
		return ""
	}
	return strings.TrimSpace(p.deps.AgentName(p.cfg.UserID, p.cfg.AgentID))
}

// replyTarget is the message a quote-reply answers. WhatsApp sends the quoted
// message along, so it is there however old it is.
func (p *Platform) replyTarget(cl waClient, m *waE2E.Message, sender, pushName string) *messaging.ReplyRef {
	ci := contextInfo(m)
	if ci.GetStanzaID() == "" {
		return nil
	}
	content := quotedText(unwrap(ci.GetQuotedMessage()))
	author := normalizeID(ci.GetParticipant())
	// In the self chat both sides are the same account; the agent's label on its
	// replies tells them apart.
	name := p.agentName()
	fromAgent := author != "" && p.ownIDs(cl)[author] &&
		(!p.selfChat || name == "" || strings.HasPrefix(content, "("+name+"):"))
	ref := &messaging.ReplyRef{FromAgent: fromAgent, Content: content}
	if !fromAgent && author != "" && author == normalizeID(sender) && pushName != "" {
		ref.Sender = &pushName
	}
	return ref
}

// ConversationChatIDs lists every address a direct chat is known under, LID
// first, so the chat keeps one conversation whichever is used. A mapping
// WhatsApp has to be asked for is not waited on for long.
func (p *Platform) ConversationChatIDs(ctx context.Context, chatID string) ([]string, error) {
	p.mu.Lock()
	cl := p.cl
	p.mu.Unlock()
	if cl == nil {
		return []string{chatID}, nil
	}
	ctx, cancel := context.WithTimeout(ctx, aliasLookup)
	defer cancel()
	switch jid, err := types.ParseJID(chatID); {
	case err != nil:
		return []string{chatID}, nil
	case jid.Server == types.HiddenUserServer:
		if pn, err := cl.PNForLID(ctx, jid); err == nil && !pn.IsEmpty() {
			return []string{chatID, normalizedUser(pn.String())}, nil
		}
	case isPhoneJID(chatID):
		if lid, err := cl.LIDForPN(ctx, jid); err == nil && !lid.IsEmpty() {
			return []string{normalizedUser(lid.String()), chatID}, nil
		}
	}
	return []string{chatID}, nil
}

// --- inbound messages --------------------------------------------------------------

func (p *Platform) remember(id string) {
	if id == "" {
		return
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	p.sent = append(p.sent, id)
	if len(p.sent) > sentMessageMemory {
		p.sent = p.sent[1:]
	}
}

func (p *Platform) wasSent(id string) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, s := range p.sent {
		if s == id {
			return true
		}
	}
	return false
}

// shouldProcess keeps the agent from reading its own replies, which is what
// the remembered sent ids are for, and, in self-chat mode, from answering
// anything but notes in the owner's own chat. A note typed on the phone arrives
// from the account itself; backlog older than this connection is left alone,
// since working through it would bury the user in replies.
func (p *Platform) shouldProcess(cl waClient, info types.MessageInfo) bool {
	if p.wasSent(info.ID) {
		return false
	}
	if !p.selfChat {
		return !info.IsFromMe
	}
	if info.IsFromMe && !p.liveSince(info.Timestamp) {
		return false
	}
	if p.isSelfChat(cl, info.Chat.String()) {
		return true
	}
	// Self-chat mode answers notes in your own chat only. Everyone else is
	// dropped here, which looks exactly like a broken connection.
	p.log.Warn("Ignored a message because self-chat mode is on and it was not sent in your own chat." +
		" Turn self-chat mode off to answer other contacts.")
	return false
}

func (p *Platform) liveSince(at time.Time) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return !p.connectedAt.IsZero() && at.Unix() >= p.connectedAt.Unix()
}

func (p *Platform) accessContext(info types.MessageInfo, addr addresses, chatID string, isGroup bool, content, pushName string, m *waE2E.Message, cl waClient) messaging.AccessContext {
	senderID := normalizeID(firstNonEmpty(addr.phone, addr.sender))
	c := messaging.AccessContext{
		Platform: "whatsapp", SenderID: senderID, ChatID: chatID,
		IsDirect: !isGroup, IsShared: isGroup,
		PhoneNumber:    senderID,
		StableSenderID: senderID, // a contact can move between a number and a LID; the number stays the same person
		Text:           content, MessageID: info.ID, SenderName: pushName,
	}
	if isGroup {
		c.GroupID = chatID
		c.WasMentioned = m != nil && p.addressedToBot(cl, m)
	}
	return c
}

func (p *Platform) handleMessage(cl waClient, evt *events.Message) {
	ctx := context.Background()
	info := evt.Info
	m := unwrap(evt.Message)
	if m == nil {
		return
	}
	if m.GetPollUpdateMessage() != nil {
		p.pollVote(ctx, cl, evt)
		return
	}
	if !p.shouldProcess(cl, info) {
		return
	}
	// The phone's own sync traffic (history notices, app-state keys) is
	// addressed to the self chat as well; it is not a note.
	if m.GetProtocolMessage() != nil {
		return
	}

	chatID := info.Chat.ToNonAD().String()
	isGroup := info.IsGroup
	addr := p.senderAddresses(ctx, cl, info.MessageSource)
	pushName := info.PushName

	if m.GetReactionMessage() != nil {
		if !isGroup {
			p.reaction(cl, evt, m, chatID, addr.sender, pushName)
		}
		return
	}

	b := readBody(m)
	if b.content == "" && b.mediaType == "" {
		p.log.Warn("Ignored a message with no readable content (" + kinds(m) + ").")
		return
	}
	decision := p.checkAccess(cl, info, addr, chatID, isGroup, b.content, pushName, m)
	if !decision.Allowed {
		return
	}

	mediaPath, mediaError := p.saveMedia(ctx, cl, decision, info, b)
	// A failed read receipt is not worth losing the message over.
	_ = cl.MarkRead(ctx, info.ID, info.Chat, receiptSender(info), info.Timestamp)

	kind := "direct"
	if isGroup {
		kind = "group"
	}
	if b.mediaType != "" {
		kind += " (" + b.mediaType + ")"
	}
	p.log.Info("Accepted " + kind + " message for processing.")

	reply := p.replyTarget(cl, m, addr.sender, pushName)
	in := messaging.Inbound{
		Platform: "whatsapp", ChatID: chatID, Sender: addr.sender,
		SenderName: pushName, SenderDisplayName: pushName,
		SenderTag:    firstNonEmpty(normalizeID(addr.sender), addr.sender),
		WasMentioned: isGroup && p.addressedToBot(cl, m), RepliedToAgent: reply != nil && reply.FromAgent,
		ReplyToMessageID: contextInfo(m).GetStanzaID(), ReplyTo: reply,
		Content: b.content, MediaType: b.mediaType, LocalMediaPath: mediaPath,
		MediaFileName: b.mediaFileName, MediaError: mediaError,
		IsGroup: isGroup, MessageID: info.ID, Timestamp: isoTime(info.Timestamp),
	}
	if isGroup {
		in.GroupID = chatID
	}
	if mediaPath != "" {
		in.VoiceNote = b.voiceNote
	}
	if p.selfChat {
		in.Metadata = map[string]any{"selfChat": true}
	}
	p.ev.Message(in)
}

// receiptSender is whose message a read receipt names: the author in a group,
// the chat itself otherwise.
func receiptSender(info types.MessageInfo) types.JID {
	if !info.IsGroup {
		return info.Chat
	}
	return info.Sender
}

func isoTime(t time.Time) string {
	if t.IsZero() {
		t = time.Now()
	}
	return t.UTC().Format("2006-01-02T15:04:05.000Z")
}

// checkAccess applies the policy. Self-chat mode only ever reaches this point
// for notes the account owner wrote in their own chat, so the allowlist has
// nothing left to decide.
func (p *Platform) checkAccess(cl waClient, info types.MessageInfo, addr addresses, chatID string, isGroup bool, content, pushName string, m *waE2E.Message) messaging.AccessDecision {
	if p.selfChat {
		return messaging.AccessDecision{Allowed: true}
	}
	c := p.accessContext(info, addr, chatID, isGroup, content, pushName, m, cl)
	opts := messaging.BlockedOptions{SenderName: firstNonEmpty(pushName, c.SenderID), GroupLabel: chatID}
	if isGroup {
		opts.Meta = "Group: " + chatID
	}
	return p.guard.Check(c, opts)
}

// saveMedia downloads an attachment into the store of the account that owns
// the chat: on an instance-wide account that is the linked sender.
func (p *Platform) saveMedia(ctx context.Context, cl waClient, decision messaging.AccessDecision, info types.MessageInfo, b body) (path, failure string) {
	if b.mediaType == "" || b.mediaType == "sticker" || b.media == nil {
		return "", ""
	}
	data, err := cl.Download(ctx, b.media)
	if err != nil {
		p.log.Error("Media download failed.", "error", err)
		return "", err.Error()
	}
	owner := decision.OwnerUserID
	if owner == 0 {
		owner = p.cfg.UserID
	}
	if p.deps.Media == nil || owner == 0 {
		err := errors.New("Per-user artifact storage is unavailable.")
		p.log.Error("Media download failed.", "error", err)
		return "", err.Error()
	}
	safeID := strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
			return r
		}
		return -1
	}, firstNonEmpty(info.ID, "file"))
	path, err = p.deps.Media.SaveInboundMedia(ctx, owner, InboundMedia{
		FilenameBase: fmt.Sprintf("%d_%s", time.Now().UnixMilli(), safeID),
		Extension:    mediaExtension(b.mediaType, b.mediaFileName, b.audioMime),
		ContentType:  mediaContentType(b.mediaType, b.audioMime),
		Content:      data, MessageID: info.ID, MediaType: b.mediaType,
	})
	if err != nil {
		p.log.Error("Media download failed.", "error", err)
		return "", err.Error()
	}
	return path, ""
}

// reaction records feedback on an earlier message. It is context, never a
// request. Access is checked quietly, since a stranger's reaction is no reason
// to suggest allowlisting them.
func (p *Platform) reaction(cl waClient, evt *events.Message, m *waE2E.Message, chatID, sender, pushName string) {
	r := m.GetReactionMessage()
	emoji := strings.TrimSpace(r.GetText())
	// Empty text means the reaction was removed.
	if emoji == "" || r.GetKey().GetID() == "" {
		return
	}
	if !p.selfChat {
		addr := p.senderAddresses(context.Background(), cl, evt.Info.MessageSource)
		c := p.accessContext(evt.Info, addr, chatID, false, "", "", nil, cl)
		if !p.guard.Evaluate(c).Allowed {
			return
		}
	}
	p.ev.Reaction(messaging.Reaction{
		Platform: "whatsapp", ChatID: chatID, Sender: sender, SenderName: pushName,
		TargetMessageID: r.GetKey().GetID(), Emoji: emoji, Timestamp: isoTime(evt.Info.Timestamp),
	})
}

// membership reports joins and leaves. They never start a chat run and skip the
// access policy; they only feed the owner's tasks.
func (p *Platform) membership(cl waClient, e *events.GroupInfo) {
	own := p.ownIDs(cl)
	report := func(kind string, members []types.JID) {
		for _, member := range members {
			id := member.String()
			if id == "" || own[normalizeID(id)] {
				continue
			}
			p.ev.Membership(messaging.Membership{
				Kind: kind, SpaceID: e.JID.String(), ChatID: e.JID.String(),
				MemberID: id, MemberName: firstNonEmpty(normalizeID(id), id), DMChatID: id,
				OccurredAt: isoTime(time.Now()),
			})
		}
	}
	report("member_joined", e.Join)
	report("member_left", e.Leave)
}

// --- approvals --------------------------------------------------------------------

func optionHash(label string) string {
	sum := sha256.Sum256([]byte(label))
	return hex.EncodeToString(sum[:])
}

// pollVote turns a vote on an approval poll into an approval response.
func (p *Platform) pollVote(ctx context.Context, cl waClient, evt *events.Message) {
	update := unwrap(evt.Message).GetPollUpdateMessage()
	p.mu.Lock()
	poll, ok := p.polls[update.GetPollCreationMessageKey().GetID()]
	p.mu.Unlock()
	if !ok {
		return
	}
	selected, err := cl.DecryptVote(ctx, evt)
	if err != nil {
		p.log.Warn("Could not read a vote on an approval poll.", "error", err)
		return
	}
	chosen := map[string]bool{}
	for _, hash := range selected {
		chosen[hex.EncodeToString(hash)] = true
	}
	var option *messaging.ApprovalOption
	for i := range poll.options {
		if chosen[optionHash(poll.options[i].Label)] {
			option = &poll.options[i]
			break
		}
	}
	// An empty selection means the vote was taken back.
	if option == nil {
		return
	}
	info := evt.Info
	chatID := info.Chat.ToNonAD().String()
	fromMe := info.IsFromMe
	// An instance-wide account's holder is not whoever linked this chat, and
	// self-chat mode only answers in the account's own chat.
	if fromMe && p.guard.Gated() {
		return
	}
	if p.selfChat && !(fromMe && p.isSelfChat(cl, chatID)) {
		return
	}
	addr := p.senderAddresses(ctx, cl, info.MessageSource)
	actor := messaging.Actor{Sender: addr.sender, SenderName: info.PushName, IsGroup: info.IsGroup, IsAccountHolder: fromMe}
	if info.IsGroup {
		actor.GroupID = chatID
	}
	if p.selfChat {
		actor.Metadata = map[string]any{"selfChat": true}
	}
	p.ev.ApprovalResponse(messaging.ApprovalResponse{
		Platform: "whatsapp", ChatID: chatID, PromptID: update.GetPollCreationMessageKey().GetID(),
		ChoiceID: option.ID, Actor: actor,
	})
}

// SendApprovalPrompt asks as a one-choice poll, which the owner answers with a tap.
func (p *Platform) SendApprovalPrompt(ctx context.Context, chatID string, prompt messaging.ApprovalPrompt) (messaging.PromptRef, error) {
	cl, err := p.connected()
	if err != nil {
		return messaging.PromptRef{}, err
	}
	jid, err := parseTarget(chatID, "Invalid WhatsApp chat")
	if err != nil {
		return messaging.PromptRef{}, err
	}
	labels := make([]string, len(prompt.Options))
	for i, o := range prompt.Options {
		labels[i] = o.Label
	}
	id, err := cl.Send(ctx, jid, cl.BuildPoll(truncateUTF16(prompt.Text, pollNameLimit), labels))
	if err != nil {
		return messaging.PromptRef{}, err
	}
	p.remember(id)
	p.mu.Lock()
	p.polls[id] = approvalPoll{options: prompt.Options}
	p.mu.Unlock()
	return messaging.PromptRef{PromptID: id}, nil
}

// DeleteApprovalPrompt withdraws a prompt.
func (p *Platform) DeleteApprovalPrompt(ctx context.Context, chatID, promptID string) error {
	p.mu.Lock()
	_, known := p.polls[promptID]
	delete(p.polls, promptID)
	cl := p.cl
	p.mu.Unlock()
	if !known || cl == nil {
		return nil
	}
	jid, err := parseTarget(chatID, "Invalid WhatsApp chat")
	if err != nil {
		return err
	}
	id, err := cl.Send(ctx, jid, cl.BuildRevoke(jid, types.EmptyJID, promptID))
	p.remember(id)
	return err
}

// truncateUTF16 is text.slice(0, n): n UTF-16 code units.
func truncateUTF16(s string, n int) string {
	units := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > n {
			return s[:i]
		}
		units += w
	}
	return s
}

// --- outbound ---------------------------------------------------------------------

func (p *Platform) connected() (waClient, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.cl == nil || p.status != messaging.StatusConnected {
		return nil, errors.New("WhatsApp not connected")
	}
	return p.cl, nil
}

func parseTarget(to, invalid string) (types.JID, error) {
	raw := toJID(to)
	if raw == "" {
		return types.EmptyJID, errors.New(invalid)
	}
	return types.ParseJID(raw)
}

// withAgentLabel labels the agent's replies in the self chat, where both sides
// are the same account.
func (p *Platform) withAgentLabel(content string) string {
	text := strings.TrimSpace(content)
	if !p.selfChat || text == "" {
		return content
	}
	if name := p.agentName(); name != "" {
		return "(" + name + "): " + text
	}
	return content
}

// SendMessage delivers text, or an attachment with the text as its caption.
func (p *Platform) SendMessage(ctx context.Context, to, content string, opts messaging.SendOptions) (messaging.SendResult, error) {
	cl, err := p.connected()
	if err != nil {
		return messaging.SendResult{}, err
	}
	jid, err := parseTarget(to, "Invalid WhatsApp recipient")
	if err != nil {
		return messaging.SendResult{}, err
	}
	msg, err := p.outboundMessage(ctx, cl, p.withAgentLabel(content), opts.MediaPath)
	if err != nil {
		return messaging.SendResult{}, err
	}
	id, err := cl.Send(ctx, jid, msg)
	if err != nil {
		return messaging.SendResult{}, err
	}
	// Every send records its message id, which is what keeps this agent from
	// reading its own replies back.
	p.remember(id)
	return messaging.SendResult{Success: true, MessageID: id}, nil
}

func (p *Platform) outboundMessage(ctx context.Context, cl waClient, body, mediaPath string) (*waE2E.Message, error) {
	if mediaPath == "" {
		return &waE2E.Message{ExtendedTextMessage: &waE2E.ExtendedTextMessage{Text: &body}}, nil
	}
	data, err := os.ReadFile(mediaPath)
	if err != nil {
		return nil, err
	}
	kind, mime := mediaKindFor(mediaPath)
	up, err := cl.Upload(ctx, data, kind)
	if err != nil {
		return nil, err
	}
	var caption *string
	if body != "" {
		caption = &body
	}
	length := up.Length
	switch kind {
	case mediaImage:
		return &waE2E.Message{ImageMessage: &waE2E.ImageMessage{URL: &up.URL, DirectPath: &up.DirectPath, MediaKey: up.MediaKey,
			FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: &length, Mimetype: &mime, Caption: caption}}, nil
	case mediaVideo:
		return &waE2E.Message{VideoMessage: &waE2E.VideoMessage{URL: &up.URL, DirectPath: &up.DirectPath, MediaKey: up.MediaKey,
			FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: &length, Mimetype: &mime, Caption: caption}}, nil
	case mediaAudio:
		return &waE2E.Message{AudioMessage: &waE2E.AudioMessage{URL: &up.URL, DirectPath: &up.DirectPath, MediaKey: up.MediaKey,
			FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: &length, Mimetype: &mime}}, nil
	}
	name := filepath.Base(mediaPath)
	return &waE2E.Message{DocumentMessage: &waE2E.DocumentMessage{URL: &up.URL, DirectPath: &up.DirectPath, MediaKey: up.MediaKey,
		FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: &length, Mimetype: &mime, FileName: &name, Caption: caption}}, nil
}

// mediaKindFor picks how a file is sent from its extension.
func mediaKindFor(path string) (mediaKind, string) {
	switch ext := strings.ToLower(filepath.Ext(path)); ext {
	case ".jpg", ".jpeg":
		return mediaImage, "image/jpeg"
	case ".png":
		return mediaImage, "image/png"
	case ".gif":
		return mediaImage, "image/gif"
	case ".webp":
		return mediaImage, "image/webp"
	case ".mp4":
		return mediaVideo, "video/mp4"
	case ".avi":
		return mediaVideo, "video/x-msvideo"
	case ".mov":
		return mediaVideo, "video/quicktime"
	case ".mp3", ".ogg", ".m4a":
		return mediaAudio, "audio/mp4"
	}
	return mediaDocument, documentMime(path)
}

// SendReaction puts an emoji on a message. Self-chat echoes our own reaction
// back; remembering it keeps it from being read as the user's.
func (p *Platform) SendReaction(ctx context.Context, chatID, messageID, emoji string) error {
	cl, err := p.connected()
	if err != nil {
		return err
	}
	jid, err := parseTarget(chatID, "Invalid WhatsApp chat")
	if err != nil {
		return err
	}
	id, err := cl.Send(ctx, jid, cl.BuildReaction(jid, jid, messageID, emoji))
	if err != nil {
		return err
	}
	p.remember(id)
	return nil
}

// MarkRead sends a read receipt for a message in a direct chat. Group messages
// are marked read when they are accepted, where the author is known.
func (p *Platform) MarkRead(ctx context.Context, chatID, messageID string) error {
	p.mu.Lock()
	cl := p.cl
	p.mu.Unlock()
	if cl == nil || messageID == "" {
		return nil
	}
	jid := toJID(chatID)
	if jid == "" || strings.HasSuffix(jid, "@g.us") {
		return nil
	}
	chat, err := types.ParseJID(jid)
	if err != nil {
		return err
	}
	return cl.MarkRead(ctx, messageID, chat, chat, time.Now())
}

// SendTyping shows or clears the typing indicator.
func (p *Platform) SendTyping(ctx context.Context, chatID string, typing bool) error {
	p.mu.Lock()
	cl, status := p.cl, p.status
	p.mu.Unlock()
	if cl == nil || status != messaging.StatusConnected {
		return nil
	}
	jid := toJID(chatID)
	if jid == "" {
		return nil
	}
	chat, err := types.ParseJID(jid)
	if err != nil {
		return err
	}
	return cl.SetTyping(ctx, chat, typing)
}

// ListAccessTargets offers the phone contacts and joined groups the account
// knows.
func (p *Platform) ListAccessTargets(ctx context.Context) ([]messaging.AccessTarget, error) {
	p.mu.Lock()
	cl := p.cl
	p.mu.Unlock()
	if cl == nil {
		return nil, nil
	}
	contacts, err := cl.Contacts(ctx)
	if err != nil {
		return nil, err
	}
	groups, err := cl.Groups(ctx)
	if err != nil {
		return nil, err
	}
	var out []messaging.AccessTarget
	for _, c := range contacts {
		if c.JID.Server != types.DefaultUserServer {
			continue
		}
		out = append(out, messaging.AccessTarget{Source: "live", Bucket: "directRules", Scope: "phone_number",
			Value: c.JID.User, Label: firstNonEmpty(c.Name, c.JID.User), Subtitle: "WhatsApp contact"})
	}
	for _, g := range groups {
		out = append(out, messaging.AccessTarget{Source: "live", Bucket: "sharedSpaceRules", Scope: "group",
			Value: g.JID, Label: firstNonEmpty(g.Name, g.JID), Subtitle: "WhatsApp group"})
	}
	return out, nil
}
