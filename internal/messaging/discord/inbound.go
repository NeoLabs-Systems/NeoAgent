package discord

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
	"github.com/bwmarrin/discordgo"
)

const maxAudioBytes = 25 << 20

func isoTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

func first(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// displayName is a member's server nickname, else the account's display name.
func displayName(u *discordgo.User, member *discordgo.Member) string {
	if member != nil && member.Nick != "" {
		return member.Nick
	}
	return u.DisplayName()
}

func roleIDs(member *discordgo.Member) []string {
	if member == nil || len(member.Roles) == 0 {
		return []string{}
	}
	return member.Roles
}

// mentioned is discord.js's mentions.has(bot): @everyone, the bot itself, or a
// role the bot holds.
func mentioned(s *discordgo.Session, m *discordgo.Message, bot *discordgo.User) bool {
	if bot == nil {
		return false
	}
	if m.MentionEveryone || slices.ContainsFunc(m.Mentions, func(u *discordgo.User) bool { return u.ID == bot.ID }) {
		return true
	}
	if member, err := s.State.Member(m.GuildID, bot.ID); err == nil {
		return slices.ContainsFunc(m.MentionRoles, func(role string) bool { return slices.Contains(member.Roles, role) })
	}
	return false
}

var repeatedSpace = regexp.MustCompile(`[\s\x{a0}\x{2028}\x{2029}\x{feff}\p{Zs}]{2,}`)
var edgeSpace = regexp.MustCompile(`^[\s\x{a0}\x{2028}\x{2029}\x{feff}\p{Zs}]+|[\s\x{a0}\x{2028}\x{2029}\x{feff}\p{Zs}]+$`)

func stripMention(content string, bot *discordgo.User) string {
	if bot != nil {
		content = regexp.MustCompile(`<@!?`+regexp.QuoteMeta(bot.ID)+`>`).ReplaceAllString(content, "")
		content = repeatedSpace.ReplaceAllString(content, " ")
	}
	return edgeSpace.ReplaceAllString(content, "")
}

type contextEntry struct {
	id string
	messaging.ContextEntry
}

func (p *Platform) contextEntry(m *discordgo.Message, bot *discordgo.User) contextEntry {
	username := m.Author.String()
	display := first(displayName(m.Author, m.Member), username)
	author := username
	if display != username {
		author = display + " (" + username + ")"
	}
	if m.Author.Bot {
		author = "[bot] " + author
	}
	// The mention token lets a reply tag this person instead of guessing an id.
	author += " <@" + m.Author.ID + ">"
	content := m.Content
	if content == "" {
		content = "[empty]"
		if len(m.Attachments) > 0 {
			content = "[attachment]"
		}
	}
	return contextEntry{m.ID, messaging.ContextEntry{Author: author, Content: content, Mine: bot != nil && m.Author.ID == bot.ID}}
}

// fetchContext is the channel's last messages, oldest first. Discord failing
// leaves the context empty.
func (p *Platform) fetchContext(s *discordgo.Session, channelID string, bot *discordgo.User) []contextEntry {
	fetched, err := s.ChannelMessages(channelID, 20, "", "", "")
	if err != nil {
		return nil
	}
	entries := make([]contextEntry, 0, len(fetched))
	for i := len(fetched) - 1; i >= 0; i-- {
		entries = append(entries, p.contextEntry(fetched[i], bot))
	}
	return entries
}

// replyTarget is the message a reply points at, from the fetched history when
// it is recent and from Discord otherwise.
func (p *Platform) replyTarget(s *discordgo.Session, m *discordgo.Message, history []contextEntry, bot *discordgo.User) *messaging.ReplyRef {
	ref := m.MessageReference
	known := slices.IndexFunc(history, func(e contextEntry) bool { return e.id == ref.MessageID })
	var entry contextEntry
	if known >= 0 {
		entry = history[known]
	} else {
		target, err := s.ChannelMessage(first(ref.ChannelID, m.ChannelID), ref.MessageID)
		if err != nil {
			return nil
		}
		entry = p.contextEntry(target, bot)
	}
	reply := &messaging.ReplyRef{FromAgent: entry.Mine, Content: entry.Content}
	if !entry.Mine {
		author := entry.Author
		reply.Sender = &author
	}
	return reply
}

func (p *Platform) isDirect(s *discordgo.Session, guildID, channelID string) bool {
	if guildID != "" {
		return false
	}
	ch, err := channel(s, channelID)
	return err != nil || ch.Type == discordgo.ChannelTypeDM
}

func (p *Platform) onMessage(s *discordgo.Session, event *discordgo.MessageCreate) {
	m := event.Message
	if m.Author == nil || m.Author.Bot {
		return
	}
	_, bot := p.current()
	isDM := p.isDirect(s, m.GuildID, m.ChannelID)
	userID := m.Author.ID
	chatID := m.ChannelID
	channelName := ""
	if isDM {
		chatID = dmPrefix + userID
	} else if ch, err := channel(s, m.ChannelID); err == nil {
		channelName = ch.Name
	}
	roles := []string{}
	if !isDM {
		roles = roleIDs(m.Member)
	}
	guild := guildName(s, m.GuildID)
	wasMentioned := !isDM && mentioned(s, m, bot)

	ctx := messaging.AccessContext{
		Platform: name, SenderID: userID, ChatID: chatID, IsDirect: isDM, IsShared: !isDM,
		ServerID: m.GuildID, RoleIDs: roles, WasMentioned: wasMentioned,
	}
	opts := messaging.BlockedOptions{SenderName: m.Author.Username, ServerLabel: guild}
	if !isDM {
		ctx.GroupID, ctx.ChannelID = m.ChannelID, m.ChannelID
		opts.ChannelLabel = "#" + first(channelName, m.ChannelID)
	}
	if guild != "" {
		opts.Meta = "Server: " + guild
	}
	if !p.guard.Check(ctx, opts).Allowed {
		return
	}

	content := m.Content
	if wasMentioned {
		content = stripMention(m.Content, bot)
	}
	var audio *discordgo.MessageAttachment
	for _, a := range m.Attachments {
		if strings.HasPrefix(a.ContentType, "audio/") {
			audio = a
			break
		}
	}
	var stored *storedAudio
	if audio != nil {
		stored = p.storeAudio(m, audio)
	}
	var urls []string
	for _, a := range m.Attachments {
		if stored == nil || a != audio {
			urls = append(urls, a.URL)
		}
	}
	if len(urls) > 0 {
		if content != "" {
			content += "\n"
		}
		content += "[Attachment: " + strings.Join(urls, ", ") + "]"
	}
	if content == "" && stored == nil {
		return
	}

	username := m.Author.Username
	display := first(m.Author.GlobalName, username, userID)
	if !isDM {
		display = first(displayName(m.Author, m.Member), m.Author.GlobalName, username, userID)
	}
	senderName := display
	if !isDM {
		senderName = display + " in #" + first(channelName, m.ChannelID)
		if guild != "" {
			senderName += " (" + guild + ")"
		}
	}
	in := messaging.Inbound{
		Platform: name, ChatID: chatID, MessageID: m.ID, Sender: userID,
		SenderName: senderName, SenderDisplayName: display, SenderUsername: username,
		SenderTag: first(m.Author.String(), username, userID),
		ServerID:  m.GuildID, GuildID: m.GuildID, GuildName: guild, RoleIDs: roles,
		WasMentioned: wasMentioned, Content: content, IsGroup: !isDM,
		Timestamp: isoTime(m.Timestamp),
	}
	if bot != nil {
		in.BotUsername, in.BotDisplayName, in.BotTag = bot.Username, first(bot.GlobalName, bot.Username), bot.String()
	}
	var history []contextEntry
	if !isDM {
		in.GroupID, in.ChannelID, in.ChannelName = m.ChannelID, m.ChannelID, first(channelName, m.ChannelID)
		history = p.fetchContext(s, m.ChannelID, bot)
		for _, e := range history {
			in.ChannelContext = append(in.ChannelContext, e.ContextEntry)
		}
	}
	if m.MessageReference != nil && m.MessageReference.MessageID != "" {
		in.ReplyToMessageID = m.MessageReference.MessageID
		in.ReplyTo = p.replyTarget(s, m, history, bot)
		in.RepliedToAgent = !isDM && bot != nil && m.ReferencedMessage != nil &&
			m.ReferencedMessage.Author != nil && m.ReferencedMessage.Author.ID == bot.ID
	}
	if stored != nil {
		in.MediaType, in.LocalMediaPath, in.VoiceNote = "audio", stored.path, stored.voiceNote
	}
	p.ev.Message(in)
}

type storedAudio struct {
	path      string
	voiceNote map[string]any
}

func audioExtension(mimeType string) string {
	switch {
	case strings.HasPrefix(mimeType, "audio/mpeg") || strings.Contains(mimeType, "mp3"):
		return "mp3"
	case strings.HasPrefix(mimeType, "audio/webm"):
		return "webm"
	case strings.HasPrefix(mimeType, "audio/ogg"):
		return "ogg"
	case strings.HasPrefix(mimeType, "audio/mp4") || strings.Contains(mimeType, "m4a"):
		return "m4a"
	}
	return "wav"
}

// storeAudio downloads a voice message or audio file once and keeps it as
// inbound media for the shared voice-note flow. Failures leave the attachment
// as a link.
func (p *Platform) storeAudio(m *discordgo.Message, a *discordgo.MessageAttachment) *storedAudio {
	if p.deps.Media == nil || p.userID == 0 {
		return nil
	}
	saved, err := p.downloadAudio(m, a)
	if err != nil {
		p.log.Error("Discord audio attachment download failed: " + err.Error())
		return nil
	}
	return saved
}

func (p *Platform) downloadAudio(m *discordgo.Message, a *discordgo.MessageAttachment) (*storedAudio, error) {
	client := p.deps.Download
	if client == nil {
		client = ssrf.NewClient(ssrf.Options{})
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.URL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxAudioBytes+1))
	if err != nil {
		return nil, err
	}
	if len(body) > maxAudioBytes {
		return nil, fmt.Errorf("attachment is larger than %d bytes", maxAudioBytes)
	}
	mimeType, _, _ := strings.Cut(a.ContentType, ";")
	path, err := p.deps.Media.SaveInboundMedia(ctx, p.userID, InboundMedia{
		FilenameBase: fmt.Sprintf("%d_%s", time.Now().UnixMilli(), a.ID),
		Extension:    audioExtension(mimeType),
		ContentType:  mimeType,
		Content:      body,
		Metadata:     map[string]any{"platform": name, "mediaType": "audio", "messageId": m.ID},
	})
	if err != nil {
		return nil, err
	}
	source := "discord_audio_file"
	if m.Flags&discordgo.MessageFlagsIsVoiceMessage != 0 {
		source = "discord_voice_message"
	}
	note := map[string]any{"source": source, "durationSec": nil}
	if a.DurationSecs != 0 {
		note["durationSec"] = a.DurationSecs
	}
	return &storedAudio{path: path, voiceNote: note}, nil
}

// onReaction records a reaction as context (direct messages only, access
// checked quietly) or, on an approval prompt, as the owner's answer.
func (p *Platform) onReaction(s *discordgo.Session, r *discordgo.MessageReactionAdd) {
	_, bot := p.current()
	if bot != nil && r.UserID == bot.ID {
		return
	}
	user := (*discordgo.User)(nil)
	if r.Member != nil {
		user = r.Member.User
	}
	if user == nil {
		var err error
		if user, err = s.User(r.UserID); err != nil {
			return
		}
	}
	if user.Bot {
		return
	}
	p.mu.Lock()
	options, isApproval := p.approvals[r.MessageID]
	p.mu.Unlock()
	isDM := p.isDirect(s, r.GuildID, r.ChannelID)
	if isApproval {
		p.answerApproval(s, r, user, options, isDM)
		return
	}
	if !isDM {
		return
	}
	access := p.guard.Evaluate(messaging.AccessContext{
		Platform: name, SenderID: user.ID, ChatID: dmPrefix + user.ID, IsDirect: true, RoleIDs: []string{},
	})
	if !access.Allowed {
		return
	}
	p.ev.Reaction(messaging.Reaction{
		Platform: name, ChatID: dmPrefix + user.ID, Sender: user.ID,
		SenderName: first(user.GlobalName, user.Username, user.ID), TargetMessageID: r.MessageID,
		Emoji: r.Emoji.MessageFormat(), Timestamp: isoTime(time.Now()),
	})
}

func (p *Platform) answerApproval(s *discordgo.Session, r *discordgo.MessageReactionAdd, user *discordgo.User, options []messaging.ApprovalOption, isDM bool) {
	i := slices.IndexFunc(options, func(o messaging.ApprovalOption) bool { return o.Emoji == r.Emoji.Name })
	if i < 0 {
		return
	}
	chatID := r.ChannelID
	actor := messaging.Actor{Sender: user.ID, SenderName: first(user.GlobalName, user.Username, user.ID), IsGroup: !isDM}
	if isDM {
		chatID = dmPrefix + user.ID
	} else {
		member := r.Member
		if member == nil {
			member, _ = s.GuildMember(r.GuildID, user.ID)
		}
		actor.GroupID = r.ChannelID
		actor.ChannelID = r.ChannelID
		actor.GuildID = r.GuildID
		actor.RoleIDs = roleIDs(member)
	}
	p.ev.ApprovalResponse(messaging.ApprovalResponse{
		Platform: name, ChatID: chatID, PromptID: r.MessageID, ChoiceID: options[i].ID, Actor: actor,
	})
}

// onMembership turns joins and leaves into events. They never start a chat run
// and skip the access policy.
func (p *Platform) onMembership(s *discordgo.Session, kind string, member *discordgo.Member) {
	if member == nil || member.User == nil || member.User.Bot {
		return
	}
	var spaceName, systemChannel string
	if g, err := s.State.Guild(member.GuildID); err == nil {
		spaceName, systemChannel = g.Name, g.SystemChannelID
	} else if g, err := s.Guild(member.GuildID); err == nil {
		spaceName, systemChannel = g.Name, g.SystemChannelID
	}
	occurred := time.Now()
	if kind == "member_joined" && !member.JoinedAt.IsZero() {
		occurred = member.JoinedAt
	}
	p.ev.Membership(messaging.Membership{
		Kind: kind, SpaceID: member.GuildID, SpaceName: spaceName, ChatID: systemChannel,
		MemberID: member.User.ID, MemberName: first(displayName(member.User, member), member.User.ID),
		DMChatID: dmPrefix + member.User.ID, OccurredAt: isoTime(occurred),
	})
}
