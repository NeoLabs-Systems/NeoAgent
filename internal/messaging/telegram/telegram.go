// Package telegram is the Telegram bot adapter. It long-polls the Bot API and turns
// updates into messaging events.
package telegram

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/go-telegram/bot"
	"github.com/go-telegram/bot/models"
)

const (
	name             = "telegram"
	loginTimeout     = 20 * time.Second
	contextMaxSize   = 25
	contextMaxChats  = 200
	dmPrefix         = "dm_"
	approvalDataPref = "approval:"
)

// Deps is what the adapter needs beyond messaging.Config.
type Deps struct {
	// APIBase replaces https://api.telegram.org (tests, self-hosted Bot API).
	APIBase string
}

// Factory builds Telegram adapters.
func Factory(deps Deps) messaging.Factory {
	return func(cfg messaging.Config, ev messaging.Events) (messaging.Platform, error) {
		token, _ := cfg.Settings["botToken"].(string)
		return &Platform{
			deps:    deps,
			token:   token,
			ev:      ev,
			guard:   messaging.NewAccessGuard(name, cfg, ev),
			status:  messaging.StatusDisconnected,
			context: newContextBuffers(),
			users:   &seenSet{},
			groups:  &seenSet{},
		}, nil
	}
}

// Platform is one bot connection.
type Platform struct {
	deps  Deps
	token string
	ev    messaging.Events
	guard *messaging.AccessGuard

	mu     sync.Mutex
	status string
	bot    *bot.Bot
	me     *models.User
	cancel context.CancelFunc
	done   chan struct{}

	context *contextBuffers
	users   *seenSet
	groups  *seenSet
}

func (p *Platform) Status() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.status
}

func (p *Platform) setStatus(s string) {
	p.mu.Lock()
	p.status = s
	p.mu.Unlock()
}

func (p *Platform) SetAccessPolicy(policy messaging.AccessPolicy) { p.guard.SetPolicy(policy) }
func (p *Platform) AccessPolicy() messaging.AccessPolicy          { return p.guard.Policy() }

// AuthInfo is the bot's username and id.
func (p *Platform) AuthInfo() map[string]any {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.me == nil {
		return nil
	}
	return map[string]any{"username": p.me.Username, "id": p.me.ID}
}

func (p *Platform) client() *bot.Bot {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.bot
}

func (p *Platform) botUser() *models.User {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.me
}

// Connect logs in with getMe and starts polling. Reactions are not in
// Telegram's default update set, so the allowed updates are listed.
func (p *Platform) Connect(ctx context.Context) error {
	if p.token == "" {
		return &messaging.ConfigurationRequiredError{Message: "Telegram bot token is required"}
	}
	p.stop()
	options := []bot.Option{
		bot.WithSkipGetMe(),
		bot.WithAllowedUpdates(bot.AllowedUpdates{"message", "message_reaction", "callback_query"}),
		bot.WithDefaultHandler(p.handleUpdate),
		bot.WithErrorsHandler(p.pollError),
	}
	if p.deps.APIBase != "" {
		options = append(options, bot.WithServerURL(p.deps.APIBase))
	}
	b, err := bot.New(p.token, options...)
	if err != nil {
		return err
	}
	p.setStatus(messaging.StatusConnecting)
	loginCtx, cancel := context.WithTimeout(ctx, loginTimeout)
	defer cancel()
	me, err := b.GetMe(loginCtx)
	if err != nil {
		p.setStatus(messaging.StatusError)
		return fmt.Errorf("Telegram login: %w", err)
	}

	runCtx, stop := context.WithCancel(context.Background())
	done := make(chan struct{})
	p.mu.Lock()
	p.bot, p.me, p.cancel, p.done = b, me, stop, done
	p.status = messaging.StatusConnected
	p.mu.Unlock()
	p.ev.Connected()
	go func() {
		defer close(done)
		b.Start(runCtx)
	}()
	return nil
}

// pollError reports a rejected token as needing the user; other polling
// errors are retried by the library.
func (p *Platform) pollError(err error) {
	if !errors.Is(err, bot.ErrorUnauthorized) {
		return
	}
	p.setStatus(messaging.StatusError)
	p.ev.Error(messaging.ErrorInfo{Message: "Invalid bot token", RequiresUserAction: true, Reason: "authentication_required"})
}

func (p *Platform) stop() {
	p.mu.Lock()
	cancel, done := p.cancel, p.done
	p.cancel, p.done, p.bot = nil, nil, nil
	p.mu.Unlock()
	if cancel != nil {
		cancel()
		<-done
	}
}

// Disconnect stops polling and forgets what it has seen.
func (p *Platform) Disconnect(context.Context) error {
	p.stop()
	p.mu.Lock()
	p.status = messaging.StatusDisconnected
	p.me = nil
	p.mu.Unlock()
	p.context.clear()
	p.users.clear()
	p.groups.clear()
	p.ev.Disconnected(messaging.Disconnect{Manual: true})
	return nil
}

// Logout is a disconnect: Telegram keeps no login on our side.
func (p *Platform) Logout(ctx context.Context) error { return p.Disconnect(ctx) }

func (p *Platform) handleUpdate(ctx context.Context, b *bot.Bot, update *models.Update) {
	switch {
	case update.Message != nil:
		p.handleMessage(update.Message)
	case update.MessageReaction != nil:
		p.handleReaction(update.MessageReaction)
	case update.CallbackQuery != nil:
		p.handleApprovalButton(ctx, b, update.CallbackQuery)
	}
}

// --- Inbound ----------------------------------------------------------------

func joinName(u *models.User) string {
	return strings.Join(nonEmpty(u.FirstName, u.LastName), " ")
}

func nonEmpty(values ...string) []string {
	var out []string
	for _, v := range values {
		if v != "" {
			out = append(out, v)
		}
	}
	return out
}

func first(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func isoTime(unix int) string {
	return time.Unix(int64(unix), 0).UTC().Format("2006-01-02T15:04:05.000Z")
}

func textOf(m *models.Message) string { return first(m.Text, m.Caption) }

// utf16Slice cuts text the way JavaScript's slice does: by UTF-16 code unit,
// the unit Telegram's entity offsets are in.
func utf16Slice(text string, offset, length int) string {
	units := utf16.Encode([]rune(text))
	end := min(offset+length, len(units))
	if offset < 0 || offset > end {
		return ""
	}
	return string(utf16.Decode(units[offset:end]))
}

func (p *Platform) isMentioned(m *models.Message) bool {
	me := p.botUser()
	if me == nil {
		return false
	}
	text := textOf(m)
	entities := m.Entities
	if len(entities) == 0 {
		entities = m.CaptionEntities
	}
	botID := strconv.FormatInt(me.ID, 10)
	mention := "@" + strings.ToLower(me.Username)
	for _, e := range entities {
		value := strings.ToLower(utf16Slice(text, e.Offset, e.Length))
		switch e.Type {
		case models.MessageEntityTypeMention:
			if value == mention {
				return true
			}
		case models.MessageEntityTypeBotCommand:
			if strings.HasSuffix(value, mention) {
				return true
			}
		case models.MessageEntityTypeTextMention:
			if e.User != nil && strconv.FormatInt(e.User.ID, 10) == botID {
				return true
			}
		}
	}
	if m.ReplyToMessage != nil && m.ReplyToMessage.From != nil && strconv.FormatInt(m.ReplyToMessage.From.ID, 10) == botID {
		return true
	}
	if me.Username != "" {
		pattern := regexp.MustCompile(`(?i)(^|\s)@` + regexp.QuoteMeta(strings.ToLower(me.Username)) + `\b`)
		return pattern.MatchString(text)
	}
	return false
}

// jsSpace matches JavaScript's \s and what String.trim removes.
const jsSpace = "\\s\\x{a0}\\x{2028}\\x{2029}\\x{feff}\\p{Zs}"

var repeatedSpace = regexp.MustCompile("[" + jsSpace + "]{2,}")
var edgeSpace = regexp.MustCompile("^[" + jsSpace + "]+|[" + jsSpace + "]+$")

func trim(s string) string { return edgeSpace.ReplaceAllString(s, "") }

func (p *Platform) stripMention(text string) string {
	me := p.botUser()
	if me == nil {
		return trim(text)
	}
	text = regexp.MustCompile(`(?i)@`+regexp.QuoteMeta(me.Username)).ReplaceAllString(text, "")
	return trim(repeatedSpace.ReplaceAllString(text, " "))
}

func (p *Platform) handleMessage(msg *models.Message) {
	if len(msg.NewChatMembers) > 0 || msg.LeftChatMember != nil {
		p.handleMembership(msg)
		return
	}
	if msg.From == nil || msg.From.IsBot {
		return
	}
	private := msg.Chat.Type == models.ChatTypePrivate
	userID := strconv.FormatInt(msg.From.ID, 10)
	rawChatID := strconv.FormatInt(msg.Chat.ID, 10)
	outputChatID := rawChatID
	if private {
		outputChatID = dmPrefix + userID
	}
	text := textOf(msg)
	username := ""
	if msg.From.Username != "" {
		username = "@" + msg.From.Username
	}
	displayName := first(joinName(msg.From), username, userID)
	if !p.guard.Gated() {
		p.users.set(userID, displayName)
		if !private {
			p.groups.set(rawChatID, first(msg.Chat.Title, rawChatID))
		}
	}
	p.context.add(rawChatID, messaging.ContextEntry{Author: displayName, Content: contextText(msg), Mine: false})

	mentioned := !private && p.isMentioned(msg)
	groupID := ""
	if !private {
		groupID = rawChatID
	}
	access := p.guard.Check(messaging.AccessContext{
		Platform: name, SenderID: userID, ChatID: outputChatID,
		IsDirect: private, IsShared: !private, GroupID: groupID, RoleIDs: []string{},
		WasMentioned: mentioned, Text: text, MessageID: strconv.Itoa(msg.ID), SenderName: displayName,
	}, messaging.BlockedOptions{
		SenderName: displayName,
		Meta:       groupMeta(msg.Chat.Title),
		GroupLabel: first(msg.Chat.Title, rawChatID),
	})
	if !access.Allowed {
		return
	}

	content := text
	if mentioned {
		content = p.stripMention(text)
	}
	if content == "" && len(msg.Photo) > 0 {
		content = "[photo]"
	}
	if content == "" && msg.Document != nil {
		content = "[document: " + first(msg.Document.FileName, "file") + "]"
	}
	if content == "" {
		return
	}

	senderName := displayName
	if !private {
		senderName = displayName + " in " + first(msg.Chat.Title, rawChatID)
	}
	in := messaging.Inbound{
		Platform: name, ChatID: outputChatID, MessageID: strconv.Itoa(msg.ID),
		Sender: userID, SenderName: senderName, SenderDisplayName: displayName,
		SenderUsername: username, SenderTag: username,
		WasMentioned: mentioned, Content: content, IsGroup: !private,
		GroupName: msg.Chat.Title, Timestamp: isoTime(msg.Date), ReplyToMessageID: replyID(msg),
	}
	if me := p.botUser(); me != nil {
		in.BotUsername, in.BotDisplayName, in.BotTag = me.Username, first(me.FirstName, me.Username), atName(me.Username)
	}
	if !private {
		in.GroupID = rawChatID
		in.ChannelName = first(msg.Chat.Title, rawChatID)
		in.ChannelContext = p.context.get(rawChatID)
	}
	// In a forum topic every message points at the topic's opening notice,
	// which is not a reply to anything the sender chose.
	if replied := msg.ReplyToMessage; replied != nil && replied.ForumTopicCreated == nil {
		botID := p.botUser().ID
		fromBot := replied.From != nil && replied.From.ID == botID
		ref := &messaging.ReplyRef{FromAgent: fromBot, Content: replyText(replied)}
		if !fromBot && replied.From != nil {
			sender := first(joinName(replied.From), atName(replied.From.Username), strconv.FormatInt(replied.From.ID, 10))
			ref.Sender = &sender
		}
		in.ReplyTo = ref
		in.RepliedToAgent = !private && fromBot
	}
	p.ev.Message(in)
}

func atName(username string) string {
	if username == "" {
		return ""
	}
	return "@" + username
}

func groupMeta(title string) string {
	if title == "" {
		return ""
	}
	return "Group: " + title
}

// contextText is what a message reads as in the channel context.
func contextText(m *models.Message) string {
	switch {
	case textOf(m) != "":
		return textOf(m)
	case len(m.Photo) > 0:
		return "[photo]"
	case m.Document != nil:
		return "[document]"
	}
	return "[empty]"
}

// replyText is what a replied-to message reads as.
func replyText(m *models.Message) string {
	switch {
	case textOf(m) != "":
		return textOf(m)
	case len(m.Photo) > 0:
		return "[photo]"
	}
	return "[message]"
}

func replyID(m *models.Message) string {
	if m.ReplyToMessage == nil || m.ReplyToMessage.ID == 0 {
		return ""
	}
	return strconv.Itoa(m.ReplyToMessage.ID)
}

// handleMembership turns joins and leaves into events. They never start a chat
// run and skip the access policy.
func (p *Platform) handleMembership(msg *models.Message) {
	members := msg.NewChatMembers
	kind := "member_joined"
	if len(members) == 0 {
		members = []models.User{*msg.LeftChatMember}
		kind = "member_left"
	}
	chatID := strconv.FormatInt(msg.Chat.ID, 10)
	for _, m := range members {
		if m.IsBot {
			continue
		}
		id := strconv.FormatInt(m.ID, 10)
		p.ev.Membership(messaging.Membership{
			Kind: kind, SpaceID: chatID, SpaceName: msg.Chat.Title, ChatID: chatID, MemberID: id,
			MemberName: first(joinName(&m), atName(m.Username), id), DMChatID: dmPrefix + id,
			OccurredAt: isoTime(msg.Date),
		})
	}
}

var approvalData = regexp.MustCompile(`^approval:(\w+)$`)

func (p *Platform) handleApprovalButton(ctx context.Context, b *bot.Bot, q *models.CallbackQuery) {
	// Telegram shows a spinner on the button until this is answered.
	_, _ = b.AnswerCallbackQuery(ctx, &bot.AnswerCallbackQueryParams{CallbackQueryID: q.ID})
	m := approvalData.FindStringSubmatch(q.Data)
	if m == nil || q.Message.Type != models.MaybeInaccessibleMessageTypeMessage || q.Message.Message == nil || q.From.IsBot {
		return
	}
	message := q.Message.Message
	userID := strconv.FormatInt(q.From.ID, 10)
	private := message.Chat.Type == models.ChatTypePrivate
	chatID := strconv.FormatInt(message.Chat.ID, 10)
	if private {
		chatID = dmPrefix + userID
	}
	actor := messaging.Actor{Sender: userID, SenderName: joinName(&q.From), SenderUsername: q.From.Username, IsGroup: !private}
	if !private {
		actor.GroupID = chatID
	}
	p.ev.ApprovalResponse(messaging.ApprovalResponse{
		Platform: name, ChatID: chatID, PromptID: strconv.Itoa(message.ID), ChoiceID: m[1], Actor: actor,
	})
}

// handleReaction records a reaction as context. Bots only receive reactions in
// private chats, and access is checked quietly so a stranger raises nothing.
func (p *Platform) handleReaction(update *models.MessageReactionUpdated) {
	if update.User == nil || update.Chat.Type != models.ChatTypePrivate {
		return
	}
	var emoji string
	for _, r := range update.NewReaction {
		if r.Type == models.ReactionTypeTypeEmoji && r.ReactionTypeEmoji != nil {
			emoji = r.ReactionTypeEmoji.Emoji
			break
		}
	}
	// No emoji left means the reaction was removed.
	if emoji == "" {
		return
	}
	userID := strconv.FormatInt(update.User.ID, 10)
	access := p.guard.Evaluate(messaging.AccessContext{
		Platform: name, SenderID: userID, ChatID: dmPrefix + userID, IsDirect: true, RoleIDs: []string{},
	})
	if !access.Allowed {
		return
	}
	p.ev.Reaction(messaging.Reaction{
		Platform: name, ChatID: dmPrefix + userID, Sender: userID,
		SenderName: first(joinName(update.User), userID), TargetMessageID: strconv.Itoa(update.MessageID),
		Emoji: emoji, Timestamp: isoTime(update.Date),
	})
}

// --- Outbound ---------------------------------------------------------------

var errNotConnected = errors.New("Telegram not connected")

func apiChatID(chatID string) string { return strings.TrimPrefix(chatID, dmPrefix) }

func (p *Platform) connected() (*bot.Bot, error) {
	b := p.client()
	if b == nil || p.Status() != messaging.StatusConnected {
		return nil, errNotConnected
	}
	return b, nil
}

// SendMessage sends plain text; the manager already split it to the limit.
func (p *Platform) SendMessage(ctx context.Context, to, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	b := p.client()
	if s := p.Status(); b == nil || s == messaging.StatusDisconnected || s == messaging.StatusError {
		return messaging.SendResult{}, errNotConnected
	}
	chatID := apiChatID(to)
	sent, err := b.SendMessage(ctx, &bot.SendMessageParams{ChatID: chatID, Text: content})
	if err != nil {
		return messaging.SendResult{}, err
	}
	if me := p.botUser(); me != nil {
		p.context.add(chatID, messaging.ContextEntry{Author: "[bot] " + me.Username, Content: content, Mine: true})
	}
	result := messaging.SendResult{Success: true}
	if sent != nil && sent.ID != 0 {
		result.MessageID = strconv.Itoa(sent.ID)
	}
	return result, nil
}

// SendReaction sets the bot's reaction on a message.
func (p *Platform) SendReaction(ctx context.Context, chatID, messageID, emoji string) error {
	b, err := p.connected()
	if err != nil {
		return err
	}
	id, err := strconv.Atoi(messageID)
	if err != nil {
		return fmt.Errorf("invalid Telegram message id %q", messageID)
	}
	_, err = b.SetMessageReaction(ctx, &bot.SetMessageReactionParams{
		ChatID: apiChatID(chatID), MessageID: id,
		Reaction: []models.ReactionType{{Type: models.ReactionTypeTypeEmoji, ReactionTypeEmoji: &models.ReactionTypeEmoji{Emoji: emoji}}},
	})
	return err
}

// SendTyping shows the typing indicator; clearing it is not possible and
// failures are ignored.
func (p *Platform) SendTyping(ctx context.Context, chatID string, typing bool) error {
	b, err := p.connected()
	if err != nil || !typing {
		return nil
	}
	_, _ = b.SendChatAction(ctx, &bot.SendChatActionParams{ChatID: apiChatID(chatID), Action: models.ChatActionTyping})
	return nil
}

func escapeHTML(s string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;").Replace(s)
}

// SendApprovalPrompt posts the prompt with one inline button per option.
func (p *Platform) SendApprovalPrompt(ctx context.Context, chatID string, prompt messaging.ApprovalPrompt) (messaging.PromptRef, error) {
	b, err := p.connected()
	if err != nil {
		return messaging.PromptRef{}, err
	}
	lines := []string{"🔐 <b>" + escapeHTML(prompt.Title) + "</b>", "", escapeHTML(prompt.Action)}
	if prompt.Detail != "" {
		lines = append(lines, "<pre>"+escapeHTML(prompt.Detail)+"</pre>")
	}
	if prompt.Reason != "" {
		lines = append(lines, "<i>"+escapeHTML(prompt.Reason)+"</i>")
	}
	lines = append(lines, "", "<i>"+escapeHTML(prompt.Note)+"</i>")
	// One per row, so longer labels in any language stay whole.
	rows := make([][]models.InlineKeyboardButton, len(prompt.Options))
	for i, option := range prompt.Options {
		rows[i] = []models.InlineKeyboardButton{{Text: option.Label, CallbackData: approvalDataPref + option.ID}}
	}
	sent, err := b.SendMessage(ctx, &bot.SendMessageParams{
		ChatID: apiChatID(chatID), Text: strings.Join(lines, "\n"), ParseMode: models.ParseModeHTML,
		ReplyMarkup: &models.InlineKeyboardMarkup{InlineKeyboard: rows},
	})
	if err != nil {
		return messaging.PromptRef{}, err
	}
	return messaging.PromptRef{PromptID: strconv.Itoa(sent.ID)}, nil
}

// DeleteApprovalPrompt removes a prompt message.
func (p *Platform) DeleteApprovalPrompt(ctx context.Context, chatID, promptID string) error {
	b := p.client()
	if b == nil {
		return nil
	}
	id, err := strconv.Atoi(promptID)
	if err != nil {
		return fmt.Errorf("invalid Telegram prompt id %q", promptID)
	}
	_, err = b.DeleteMessage(ctx, &bot.DeleteMessageParams{ChatID: apiChatID(chatID), MessageID: id})
	return err
}

// ListAccessTargets names the users and groups seen so far.
func (p *Platform) ListAccessTargets(context.Context) ([]messaging.AccessTarget, error) {
	var targets []messaging.AccessTarget
	for _, e := range p.users.entries() {
		targets = append(targets, messaging.AccessTarget{Source: "live", Bucket: "directRules", Scope: "user", Value: e.key, Label: e.label, Subtitle: "Telegram user"})
	}
	for _, e := range p.groups.entries() {
		targets = append(targets, messaging.AccessTarget{Source: "live", Bucket: "sharedSpaceRules", Scope: "group", Value: e.key, Label: e.label, Subtitle: "Telegram group"})
	}
	return targets, nil
}
