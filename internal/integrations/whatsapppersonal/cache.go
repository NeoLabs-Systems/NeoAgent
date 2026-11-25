package whatsapppersonal

import (
	"sort"
	"strings"
	"sync"
	"time"

	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/proto/waHistorySync"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"
)

const maxMessagesPerChat = 200

// Chat is a cached chat as the tools return it.
type Chat struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	IsGroup       bool    `json:"isGroup"`
	UnreadCount   int     `json:"unreadCount"`
	Archived      bool    `json:"archived"`
	MuteEndTime   any     `json:"muteEndTime"`
	LastMessageAt *string `json:"lastMessageAt"`
}

// Message is a cached message as the tools return it.
type Message struct {
	ID        any    `json:"id"`
	ChatID    string `json:"chatId"`
	Sender    string `json:"sender"`
	SenderTag string `json:"senderTag"`
	FromMe    bool   `json:"fromMe"`
	Kind      string `json:"kind"`
	Text      string `json:"text"`
	Timestamp string `json:"timestamp"`
}

// cache holds what a linked account synchronised in this process: the read
// tools only see this, like the Node integration.
type cache struct {
	mu       sync.Mutex
	chats    map[string]Chat
	messages map[string][]Message
}

func newCache() *cache {
	return &cache{chats: map[string]Chat{}, messages: map[string][]Message{}}
}

func iso(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

func (c *cache) upsertConversation(conv *waHistorySync.Conversation) {
	id := conv.GetID()
	if id == "" {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	existing, had := c.chats[id]
	name := conv.GetName()
	if name == "" {
		name = conv.GetDisplayName()
	}
	if name == "" && had {
		name = existing.Name
	}
	if name == "" {
		name = id
	}
	item := Chat{ID: id, Name: name, IsGroup: strings.HasSuffix(id, "@g.us"), UnreadCount: int(conv.GetUnreadCount()),
		Archived: conv.GetArchived() || existing.Archived, LastMessageAt: existing.LastMessageAt}
	if item.UnreadCount == 0 {
		item.UnreadCount = existing.UnreadCount
	}
	if mute := conv.GetMuteEndTime(); mute != 0 {
		item.MuteEndTime = mute
	} else if had {
		item.MuteEndTime = existing.MuteEndTime
	}
	if ts := conv.GetConversationTimestamp(); ts != 0 {
		s := iso(time.Unix(int64(ts), 0))
		item.LastMessageAt = &s
	}
	c.chats[id] = item
}

func messageText(m *waE2E.Message) string {
	for _, t := range []string{
		m.GetConversation(), m.GetExtendedTextMessage().GetText(), m.GetImageMessage().GetCaption(),
		m.GetVideoMessage().GetCaption(), m.GetDocumentMessage().GetCaption(), m.GetPollCreationMessage().GetName(),
	} {
		if t != "" {
			return t
		}
	}
	return ""
}

func messageKind(m *waE2E.Message) string {
	switch {
	case m.GetImageMessage() != nil:
		return "image"
	case m.GetVideoMessage() != nil:
		return "video"
	case m.GetAudioMessage() != nil:
		return "audio"
	case m.GetDocumentMessage() != nil:
		return "document"
	case m.GetStickerMessage() != nil:
		return "sticker"
	}
	return "text"
}

func jidText(j types.JID) string {
	if j.IsEmpty() {
		return ""
	}
	return j.String()
}

// simplify is a message as the tools show it.
func simplify(evt *events.Message) Message {
	chat := jidText(evt.Info.Chat)
	var addresses []string
	for _, j := range []types.JID{evt.Info.Sender, evt.Info.SenderAlt, evt.Info.Chat} {
		if s := jidText(j); s != "" {
			addresses = append(addresses, s)
		}
	}
	sender := ""
	for _, a := range addresses {
		if strings.HasSuffix(a, "@s.whatsapp.net") {
			sender = a
			break
		}
	}
	if sender == "" && len(addresses) > 0 {
		sender = addresses[0]
	}
	kind := messageKind(evt.Message)
	text := messageText(evt.Message)
	if text == "" && kind != "text" {
		text = "[" + kind + "]"
	}
	tag := normalizeID(sender)
	if tag == "" {
		tag = sender
	}
	ts := evt.Info.Timestamp
	if ts.IsZero() {
		ts = time.Now()
	}
	var id any
	if evt.Info.ID != "" {
		id = evt.Info.ID
	}
	return Message{ID: id, ChatID: chat, Sender: sender, SenderTag: tag, FromMe: evt.Info.IsFromMe, Kind: kind, Text: text, Timestamp: iso(ts)}
}

// record stores a message and bumps its chat.
func (c *cache) record(m Message) bool {
	if m.ChatID == "" {
		return false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	list := append(c.messages[m.ChatID], m)
	if len(list) > maxMessagesPerChat {
		list = list[len(list)-maxMessagesPerChat:]
	}
	c.messages[m.ChatID] = list
	chat, ok := c.chats[m.ChatID]
	if !ok {
		chat = Chat{ID: m.ChatID, Name: m.ChatID, IsGroup: strings.HasSuffix(m.ChatID, "@g.us")}
	}
	ts := m.Timestamp
	chat.LastMessageAt = &ts
	c.chats[m.ChatID] = chat
	return true
}

func (c *cache) counts() (chats, messageChats int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.chats), len(c.messages)
}

// recentChats are the most recently active chats first.
func (c *cache) recentChats(limit int) []Chat {
	c.mu.Lock()
	out := make([]Chat, 0, len(c.chats))
	for _, chat := range c.chats {
		out = append(out, chat)
	}
	c.mu.Unlock()
	last := func(ch Chat) string {
		if ch.LastMessageAt == nil {
			return ""
		}
		return *ch.LastMessageAt
	}
	sort.SliceStable(out, func(i, j int) bool { return last(out[i]) > last(out[j]) })
	if len(out) > limit {
		out = out[:limit]
	}
	return out
}

// latest are a chat's newest messages, newest first.
func (c *cache) latest(chat string, limit int) []Message {
	c.mu.Lock()
	defer c.mu.Unlock()
	list := c.messages[chat]
	if len(list) > limit {
		list = list[len(list)-limit:]
	}
	out := make([]Message, len(list))
	for i, m := range list {
		out[len(list)-1-i] = m
	}
	return out
}
