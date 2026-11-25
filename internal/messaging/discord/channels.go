package discord

import (
	"context"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/bwmarrin/discordgo"
)

// channel is a channel from the session state, or from Discord when the state
// has not seen it.
func channel(s *discordgo.Session, id string) (*discordgo.Channel, error) {
	if ch, err := s.State.Channel(id); err == nil {
		return ch, nil
	}
	return s.Channel(id)
}

func guildName(s *discordgo.Session, id string) string {
	if id == "" {
		return ""
	}
	if g, err := s.State.Guild(id); err == nil && g.Name != "" {
		return g.Name
	}
	if g, err := s.Guild(id); err == nil {
		return g.Name
	}
	return ""
}

// isTextBased is discord.js's isTextBased(): channels messages can be sent to.
func isTextBased(t discordgo.ChannelType) bool {
	switch t {
	case discordgo.ChannelTypeGuildText, discordgo.ChannelTypeDM, discordgo.ChannelTypeGroupDM,
		discordgo.ChannelTypeGuildNews, discordgo.ChannelTypeGuildNewsThread,
		discordgo.ChannelTypeGuildPublicThread, discordgo.ChannelTypeGuildPrivateThread,
		discordgo.ChannelTypeGuildVoice, discordgo.ChannelTypeGuildStageVoice:
		return true
	}
	return false
}

// textChannelID resolves a chat id ("dm_<user>" or a channel id) to the
// channel messages go to.
func (p *Platform) textChannelID(s *discordgo.Session, chatID string) (string, error) {
	if userID, ok := strings.CutPrefix(chatID, dmPrefix); ok {
		return p.dmChannel(s, userID)
	}
	ch, err := channel(s, chatID)
	if err != nil {
		return "", err
	}
	if !isTextBased(ch.Type) {
		return "", fmt.Errorf("Channel %s is not text-based", chatID)
	}
	return ch.ID, nil
}

func (p *Platform) dmChannel(s *discordgo.Session, userID string) (string, error) {
	p.mu.Lock()
	id, ok := p.dms[userID]
	p.mu.Unlock()
	if ok {
		return id, nil
	}
	ch, err := s.UserChannelCreate(userID)
	if err != nil {
		return "", err
	}
	p.mu.Lock()
	p.dms[userID] = ch.ID
	p.mu.Unlock()
	return ch.ID, nil
}

// SendMessage sends text to a DM ("dm_<userId>") or a channel.
func (p *Platform) SendMessage(_ context.Context, to, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	s, err := p.connected()
	if err != nil {
		return messaging.SendResult{}, err
	}
	channelID, err := p.textChannelID(s, to)
	if err != nil {
		return messaging.SendResult{}, err
	}
	sent, err := s.ChannelMessageSendComplex(channelID, &discordgo.MessageSend{Content: content})
	if err != nil {
		return messaging.SendResult{}, err
	}
	return messaging.SendResult{Success: true, MessageID: sent.ID}, nil
}

// SendApprovalPrompt posts the prompt and one reaction per option.
func (p *Platform) SendApprovalPrompt(_ context.Context, chatID string, prompt messaging.ApprovalPrompt) (messaging.PromptRef, error) {
	s, err := p.connected()
	if err != nil {
		return messaging.PromptRef{}, err
	}
	channelID, err := p.textChannelID(s, chatID)
	if err != nil {
		return messaging.PromptRef{}, err
	}
	labels := make([]string, len(prompt.Options))
	for i, option := range prompt.Options {
		labels[i] = option.Label
	}
	lines := []string{"🔐 **" + prompt.Title + "**", prompt.Action}
	if prompt.Detail != "" {
		lines = append(lines, "```\n"+strings.ReplaceAll(prompt.Detail, "`", "ˋ")+"\n```")
	}
	if prompt.Reason != "" {
		lines = append(lines, "> "+prompt.Reason)
	}
	lines = append(lines, "", strings.Join(labels, "   ·   "), "-# "+prompt.Note)
	sent, err := s.ChannelMessageSendComplex(channelID, &discordgo.MessageSend{
		Content:         strings.Join(lines, "\n"),
		AllowedMentions: &discordgo.MessageAllowedMentions{Parse: []discordgo.AllowedMentionType{}},
	})
	if err != nil {
		return messaging.PromptRef{}, err
	}
	// Known before the reactions exist, so a quick answer is not missed.
	p.mu.Lock()
	p.approvals[sent.ID] = prompt.Options
	p.mu.Unlock()
	for _, option := range prompt.Options {
		if err := s.MessageReactionAdd(channelID, sent.ID, option.Emoji); err != nil {
			return messaging.PromptRef{}, err
		}
	}
	return messaging.PromptRef{PromptID: sent.ID}, nil
}

// DeleteApprovalPrompt forgets a prompt and removes its message.
func (p *Platform) DeleteApprovalPrompt(_ context.Context, chatID, promptID string) error {
	p.mu.Lock()
	delete(p.approvals, promptID)
	s := p.session
	p.mu.Unlock()
	if s == nil {
		return nil
	}
	channelID, err := p.textChannelID(s, chatID)
	if err != nil {
		return err
	}
	return s.ChannelMessageDelete(channelID, promptID)
}

// SendReaction reacts to a message.
func (p *Platform) SendReaction(_ context.Context, chatID, messageID, emoji string) error {
	s, err := p.connected()
	if err != nil {
		return err
	}
	channelID, err := p.textChannelID(s, chatID)
	if err != nil {
		return err
	}
	if _, err := s.ChannelMessage(channelID, messageID); err != nil {
		return err
	}
	return s.MessageReactionAdd(channelID, messageID, emoji)
}

// SendTyping shows the typing indicator; clearing it is not possible and
// failures are ignored.
func (p *Platform) SendTyping(_ context.Context, chatID string, typing bool) error {
	s, err := p.connected()
	if err != nil || !typing {
		return nil
	}
	if channelID, err := p.textChannelID(s, chatID); err == nil {
		_ = s.ChannelTyping(channelID)
	}
	return nil
}

// ListAccessTargets names the servers, channels, roles and private chats the
// bot knows.
func (p *Platform) ListAccessTargets(context.Context) ([]messaging.AccessTarget, error) {
	s, err := p.connected()
	if err != nil {
		return nil, nil
	}
	var targets []messaging.AccessTarget
	s.State.RLock()
	defer s.State.RUnlock()
	for _, g := range s.State.Guilds {
		label := orID(g.Name, g.ID)
		targets = append(targets, messaging.AccessTarget{Source: "live", Bucket: "sharedSpaceRules", Scope: "server", Value: g.ID, Label: label, Subtitle: "Discord server"})
		for _, ch := range g.Channels {
			if !isTextBased(ch.Type) {
				continue
			}
			targets = append(targets, messaging.AccessTarget{Source: "live", Bucket: "sharedSpaceRules", Scope: "channel", Value: ch.ID, Label: "#" + orID(ch.Name, ch.ID), Subtitle: orID(g.Name, "Discord channel")})
		}
		for _, role := range g.Roles {
			if role.Managed || role.Name == "@everyone" {
				continue
			}
			targets = append(targets, messaging.AccessTarget{Source: "live", Bucket: "sharedActorRules", Scope: "role", Value: role.ID, Label: orID(role.Name, role.ID), Subtitle: orID(g.Name, "Discord role")})
		}
	}
	for _, ch := range s.State.PrivateChannels {
		if ch.Type != discordgo.ChannelTypeDM || len(ch.Recipients) == 0 {
			continue
		}
		r := ch.Recipients[0]
		if r.ID == "" {
			continue
		}
		label := r.GlobalName
		if label == "" {
			label = orID(r.Username, "Private chat")
		}
		targets = append(targets, messaging.AccessTarget{Source: "live", Bucket: "directRules", Scope: "user", Value: r.ID, Label: label, Subtitle: "Discord private chat"})
	}
	return targets, nil
}

func orID(value, fallback string) string {
	if value != "" {
		return value
	}
	return fallback
}
