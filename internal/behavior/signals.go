package behavior

import (
	"context"
	"database/sql"
	"encoding/json"
	"math"
	"regexp"
	"strings"
	"time"
	"unicode"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// --- Addressing ---------------------------------------------------------------

// weakNames are too generic to count as the agent being named.
var weakNames = map[string]bool{"main": true, "agent": true, "bot": true, "assistant": true, "user": true, "admin": true, "test": true}

// Addressing is how a message reached the agent.
type Addressing struct {
	Names                 []string
	AddressedByName       bool
	StructurallyAddressed bool
	Addressed             bool
}

func isJSSpace(r rune) bool { return unicode.IsSpace(r) || r == '\uFEFF' }

func tokenizeName(name string) []string {
	value := strings.TrimFunc(strings.TrimPrefix(name, "@"), isJSSpace)
	if utf16Len(value) < 3 {
		return nil
	}
	tokens := []string{value}
	for _, part := range strings.FieldsFunc(value, func(r rune) bool { return isJSSpace(r) || r == '_' || r == '-' }) {
		if utf16Len(part) >= 3 {
			tokens = append(tokens, part)
		}
	}
	return tokens
}

type nameSet struct {
	seen  map[string]bool
	names []string
}

func (s *nameSet) add(name string) {
	for _, token := range tokenizeName(name) {
		if weakNames[strings.ToLower(token)] || s.seen[token] {
			continue
		}
		s.seen[token] = true
		s.names = append(s.names, token)
	}
}

// AgentNames are the names the agent answers to in a chat.
func AgentNames(ctx context.Context, db *dbx.DB, userID int64, agentID string, m *messaging.Message) []string {
	set := &nameSet{seen: map[string]bool{}}
	if userID > 0 && agentID != "" && db != nil {
		var display, slug sql.NullString
		if db.R.QueryRowContext(ctx, `SELECT display_name, slug FROM agents WHERE user_id = ? AND id = ?`, userID, agentID).Scan(&display, &slug) == nil {
			set.add(display.String)
			set.add(slug.String)
		}
	}
	if m != nil {
		set.add(string(m.BotUsername))
		set.add(string(m.BotDisplayName))
		set.add(string(m.BotTag))
	}
	if set.names == nil {
		return []string{}
	}
	return set.names
}

// ContentAddressesAgent reports whether a text names the agent as a word.
func ContentAddressesAgent(content string, names []string) bool {
	if strings.TrimFunc(content, isJSSpace) == "" {
		return false
	}
	for _, name := range names {
		token := strings.TrimFunc(name, isJSSpace)
		if utf16Len(token) < 3 {
			continue
		}
		pattern := regexp.MustCompile(`(?i)(^|[^\p{L}\p{N}])` + regexp.QuoteMeta(token) + `([^\p{L}\p{N}]|$)`)
		if pattern.MatchString(content) {
			return true
		}
	}
	return false
}

func resolveAddressing(ctx context.Context, db *dbx.DB, userID int64, agentID string, m *messaging.Message) Addressing {
	names := AgentNames(ctx, db, userID, agentID, m)
	byName := ContentAddressesAgent(m.Content, names)
	structural := m.WasMentioned || m.RepliedToAgent
	return Addressing{Names: names, AddressedByName: byName, StructurallyAddressed: structural, Addressed: structural || byName}
}

// --- Room context -----------------------------------------------------------

// truncate flattens whitespace and cuts a text to max UTF-16 units.
func truncate(text string, max int) string {
	value := strings.TrimFunc(jsWhitespace.ReplaceAllString(text, " "), isJSSpace)
	if utf16Len(value) <= max {
		return value
	}
	return utf16Slice(value, max-1) + "…"
}

var jsWhitespace = regexp.MustCompile(`[\s\x{00A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]+`)

// RoomMessage is one stored line of a chat.
type RoomMessage struct {
	Role       string  `json:"role"`
	Sender     string  `json:"sender"`
	Content    string  `json:"content"`
	Kind       *string `json:"kind"`
	TargetText *string `json:"targetText"`
	CreatedAt  string  `json:"createdAt"`
}

func loadRecentRoomMessages(ctx context.Context, db *dbx.DB, userID int64, agentID, platform, chatID string, limit int) []RoomMessage {
	if limit <= 0 {
		limit = 12
	}
	limit = max(1, min(limit, 30))
	var agent any
	if agentID != "" {
		agent = agentID
	}
	rows, err := db.R.QueryContext(ctx, `SELECT role, content, created_at, metadata FROM messages
		WHERE user_id = ? AND agent_id IS ? AND platform = ? AND platform_chat_id = ? ORDER BY created_at DESC LIMIT ?`, userID, agent, platform, chatID, limit)
	if err != nil {
		return []RoomMessage{}
	}
	defer rows.Close()
	var out []RoomMessage
	for rows.Next() {
		var role, content, created, metadata sql.NullString
		if rows.Scan(&role, &content, &created, &metadata) != nil {
			continue
		}
		var meta map[string]any
		if metadata.String != "" {
			_ = json.Unmarshal([]byte(metadata.String), &meta)
		}
		sender := "assistant"
		if role.String != "assistant" {
			sender = firstText(metaText(meta, "senderDisplayName"), metaText(meta, "senderName"), metaText(meta, "sender"), "participant")
		}
		item := RoomMessage{Role: role.String, Sender: sender, Content: truncate(content.String, 320), CreatedAt: created.String}
		if k := metaText(meta, "kind"); k != "" {
			item.Kind = &k
		}
		if t := metaText(meta, "targetText"); t != "" {
			t = truncate(t, 120)
			item.TargetText = &t
		}
		out = append(out, item)
	}
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	if out == nil {
		return []RoomMessage{}
	}
	return out
}

func metaText(meta map[string]any, key string) string {
	if meta == nil {
		return ""
	}
	return jsTruthyString(meta[key])
}

// --- Decision packet --------------------------------------------------------

type packetLine struct {
	Sender  string `json:"sender"`
	Content string `json:"content"`
}

type packetChat struct {
	Platform  string  `json:"platform"`
	ChatID    string  `json:"chatId"`
	IsGroup   bool    `json:"isGroup"`
	GroupName *string `json:"groupName"`
}

type packetSender struct {
	ID       *string `json:"id"`
	Name     *string `json:"name"`
	Username *string `json:"username"`
	Tag      *string `json:"tag"`
}

type packetEvent struct {
	Content         string      `json:"content"`
	HasMedia        bool        `json:"hasMedia"`
	MediaType       *string     `json:"mediaType"`
	WasMentioned    bool        `json:"wasMentioned"`
	RepliedToAgent  bool        `json:"repliedToAgent"`
	AddressedByName bool        `json:"addressedByName"`
	ReplyTo         *packetLine `json:"replyTo"`
	Timestamp       string      `json:"timestamp"`
}

type packetRoom struct {
	RecentMessages         []packetLine `json:"recentMessages"`
	SecondsSinceAgentSpoke *int64       `json:"secondsSinceAgentSpoke"`
	RecentSilenceCount     int          `json:"recentSilenceCount"`
	AgentNames             []string     `json:"agentNames"`
}

type packetPolicy struct {
	ParticipationMode   string          `json:"participationMode"`
	MinimumNeedScore    json.RawMessage `json:"minimumNeedScore"`
	GroupDefaultPosture string          `json:"groupDefaultPosture"`
}

// Packet is what the turn-taking gate judges.
type Packet struct {
	Chat   packetChat   `json:"chat"`
	Sender packetSender `json:"sender"`
	Event  packetEvent  `json:"event"`
	Room   packetRoom   `json:"room"`
	Policy packetPolicy `json:"policy"`
}

func buildDecisionPacket(m *messaging.Message, cfg *Effective, state ThreadState, room []RoomMessage, a Addressing, now time.Time) Packet {
	var history []packetLine
	if len(m.ChannelContext) > 0 {
		for _, item := range m.ChannelContext {
			sender := "assistant"
			if !item.Mine {
				sender = firstText(item.Author, item.Sender, "participant")
			}
			history = append(history, packetLine{Sender: sender, Content: truncate(item.Content, 280)})
		}
	} else {
		for _, item := range room {
			history = append(history, packetLine{Sender: item.Sender, Content: item.Content})
		}
	}
	var last *packetLine
	if len(history) > 0 {
		last = &history[len(history)-1]
	}
	latestInHistory := last != nil && truncate(last.Content, 280) == truncate(m.Content, 280)
	recent := history
	if latestInHistory {
		recent = history[:len(history)-1]
	}
	if len(recent) > 12 {
		recent = recent[len(recent)-12:]
	}
	recent = append([]packetLine{}, recent...)

	var since *int64
	if state.LastSpokeAt != nil {
		if t, err := time.Parse(time.RFC3339Nano, *state.LastSpokeAt); err == nil {
			s := int64(math.Max(0, math.Floor(float64(now.Sub(t).Milliseconds())/1000+0.5)))
			since = &s
		}
	}
	name := ""
	if latestInHistory {
		name = last.Sender
	}
	name = firstText(name, string(m.SenderDisplayName), string(m.SenderName), string(m.SenderUsername))
	var replyTo *packetLine
	if m.ReplyTo != nil && m.ReplyTo.Content != "" && !m.ReplyTo.FromAgent {
		sender := "participant"
		if m.ReplyTo.Sender != nil && *m.ReplyTo.Sender != "" {
			sender = *m.ReplyTo.Sender
		}
		replyTo = &packetLine{Sender: sender, Content: truncate(m.ReplyTo.Content, 280)}
	}
	timestamp := m.Timestamp
	if timestamp == "" {
		timestamp = isoTime(now)
	}
	names := a.Names
	if len(names) > 8 {
		names = names[:8]
	}
	if names == nil {
		names = []string{}
	}
	mode := cfg.ParticipationMode
	if mode == "" {
		mode = "automatic"
	}
	return Packet{
		Chat:   packetChat{Platform: m.Platform, ChatID: m.ChatID, IsGroup: m.IsGroup, GroupName: optional(firstText(string(m.GroupName), string(m.GuildName), string(m.ChannelName)))},
		Sender: packetSender{ID: optional(m.Sender), Name: optional(name), Username: optional(string(m.SenderUsername)), Tag: optional(string(m.SenderTag))},
		Event: packetEvent{Content: truncate(m.Content, 800), HasMedia: m.LocalMediaPath != "" || m.MediaType != "", MediaType: optional(string(m.MediaType)),
			WasMentioned: m.WasMentioned, RepliedToAgent: m.RepliedToAgent, AddressedByName: a.AddressedByName, ReplyTo: replyTo, Timestamp: timestamp},
		Room:   packetRoom{RecentMessages: recent, SecondsSinceAgentSpoke: since, RecentSilenceCount: state.RecentSilenceCount, AgentNames: names},
		Policy: packetPolicy{ParticipationMode: mode, MinimumNeedScore: json.RawMessage(numberText(cfg.MinimumNeedScore)), GroupDefaultPosture: "hold_side_chatter"},
	}
}

func numberText(f float64) string {
	b, _ := json.Marshal(f)
	return string(b)
}

// Truncate flattens whitespace and cuts a text to max characters with an
// ellipsis, as the behavior modules show texts.
func Truncate(text string, max int) string { return truncate(text, max) }
