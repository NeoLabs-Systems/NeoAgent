package httpplatforms

import (
	"context"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

func obj(v any) map[string]any {
	m, _ := v.(map[string]any)
	return m
}

func get(v any, path string) any { return jsonPath(v, path) }

func orStr(values ...any) string { return text(firstTruthy(values...)) }

// GoogleChat receives Google Chat app callbacks.
type GoogleChat struct{ *Configurable }

func newGoogleChat(cfg messaging.Config, ev messaging.Events, deps Deps) *GoogleChat {
	return &GoogleChat{newConfigurable("google_chat", cfg, ev, deps, defaults{label: "Google Chat", contentField: "text"})}
}

func (g *GoogleChat) HandleWebhook(r *http.Request, raw []byte) messaging.WebhookResult {
	body := ParseBody(raw)
	if !InboundAllowed(g.s, r.Header, body) {
		return forbidden()
	}
	incoming := firstTruthy(get(body, "message"), body)
	content := firstTruthy(get(incoming, "argumentText"), get(incoming, "text"), get(body, "text"))
	mentioned := strings.TrimSpace(text(get(incoming, "argumentText"))) != ""
	if !truthy(content) {
		return messaging.WebhookResult{Handled: true, Status: 202, Body: "ignored"}
	}
	spaceType := strings.ToUpper(orStr(get(incoming, "space.type"), get(body, "space.type")))
	isGroup := spaceType != "DIRECT_MESSAGE"
	name := firstTruthy(get(body, "user.displayName"), get(incoming, "sender.displayName"))
	tag := firstTruthy(get(body, "user.name"), get(incoming, "sender.name"))
	in := messaging.Inbound{
		Platform:   "google_chat",
		ChatID:     text(firstTruthy(get(incoming, "space.name"), get(body, "space.name"), nilIfEmpty(g.s.Str("defaultTo")), "google_chat")),
		Sender:     text(firstTruthy(get(body, "user.name"), get(incoming, "sender.name"), "google_chat")),
		SenderName: text(name), SenderDisplayName: text(name), SenderTag: text(tag),
		Content: text(content), IsGroup: isGroup, WasMentioned: mentioned,
		MessageID: text(firstTruthy(get(incoming, "name"), newUUID())), Timestamp: isoNow(),
	}
	ctx := messaging.AccessContext{SenderID: in.Sender, ChatID: in.ChatID, IsDirect: !isGroup, IsShared: isGroup, WasMentioned: mentioned}
	if isGroup {
		ctx.RoomID = in.ChatID
	}
	if !g.admit(ctx, messaging.BlockedOptions{SenderName: in.SenderName, Meta: "Space: " + in.ChatID, RoomLabel: in.ChatID}) {
		return messaging.WebhookResult{Handled: true, Status: 202, Body: "blocked"}
	}
	g.ev.Message(in)
	return messaging.WebhookResult{Handled: true, Status: 200, Body: map[string]any{"text": "Received."}}
}

// Teams receives Microsoft Teams outgoing webhooks.
type Teams struct{ *Configurable }

func newTeams(cfg messaging.Config, ev messaging.Events, deps Deps) *Teams {
	return &Teams{newConfigurable("teams", cfg, ev, deps, defaults{label: "Microsoft Teams", contentField: "text"})}
}

var htmlTag = regexp.MustCompile(`<[^>]+>`)

func (t *Teams) HandleWebhook(r *http.Request, raw []byte) messaging.WebhookResult {
	body := ParseBody(raw)
	if !InboundAllowed(t.s, r.Header, body) {
		return forbidden()
	}
	content := firstTruthy(get(body, "text"), get(body, "message.text"), get(body, "value.text"))
	if !truthy(content) {
		return messaging.WebhookResult{Handled: true, Status: 202, Body: "ignored"}
	}
	recipient := strings.TrimSpace(text(get(body, "recipient.id")))
	mentioned := false
	if recipient != "" {
		entities, _ := get(body, "entities").([]any)
		for _, e := range entities {
			if text(get(e, "type")) == "mention" && text(get(e, "mentioned.id")) == recipient {
				mentioned = true
			}
		}
	}
	isGroup := true
	if b, ok := get(body, "conversation.isGroup").(bool); ok {
		isGroup = b
	}
	name := get(body, "from.name")
	timestamp := isoNow()
	if truthy(get(body, "timestamp")) {
		timestamp = text(get(body, "timestamp"))
	}
	in := messaging.Inbound{
		Platform:   "teams",
		ChatID:     text(firstTruthy(get(body, "conversation.id"), get(body, "channelData.channel.id"), nilIfEmpty(t.s.Str("defaultTo")), "teams")),
		Sender:     text(firstTruthy(get(body, "from.id"), "teams")),
		SenderName: text(name), SenderDisplayName: text(name), SenderTag: text(get(body, "from.id")),
		Content: strings.TrimSpace(htmlTag.ReplaceAllString(text(content), "")),
		IsGroup: isGroup, WasMentioned: mentioned,
		MessageID: text(firstTruthy(get(body, "id"), newUUID())), Timestamp: timestamp,
	}
	ctx := messaging.AccessContext{SenderID: in.Sender, ChatID: in.ChatID, IsDirect: !isGroup, IsShared: isGroup, WasMentioned: mentioned}
	if isGroup {
		ctx.ChannelID = in.ChatID
	}
	if !t.admit(ctx, messaging.BlockedOptions{SenderName: in.SenderName, Meta: "Conversation: " + in.ChatID, ChannelLabel: in.ChatID}) {
		return messaging.WebhookResult{Handled: true, Status: 202, Body: "blocked"}
	}
	t.ev.Message(in)
	return messaging.WebhookResult{Handled: true, Status: 200, Body: map[string]any{"type": "message", "text": "Received."}}
}

// Line receives LINE webhooks and pushes messages through its API.
type Line struct{ *Configurable }

const linePushURL = "https://api.line.me/v2/bot/message/push"

func newLine(cfg messaging.Config, ev messaging.Events, deps Deps) *Line {
	return &Line{newConfigurable("line", cfg, ev, deps, defaults{label: "LINE", outboundURL: linePushURL})}
}

func (l *Line) Connect(context.Context) error {
	if l.s.Str("channelAccessToken", "token", "inboundSecret") == "" {
		return &messaging.ConfigurationRequiredError{Message: "LINE channel access token or inbound secret is required"}
	}
	l.connected()
	return nil
}

func (l *Line) SendMessage(ctx context.Context, to, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	token, err := requireText(l.s.Str("channelAccessToken", "token"), "LINE channel access token")
	if err != nil {
		return messaging.SendResult{}, err
	}
	body := []byte(`{"to":` + string(jsonString(to)) + `,"messages":[{"type":"text","text":` + string(jsonString(content)) + `}]}`)
	_, err = FetchJSON(ctx, l.deps.HTTPClient(), "LINE", http.MethodPost, linePushURL, map[string]string{"Authorization": "Bearer " + token}, body)
	return messaging.SendResult{Success: err == nil}, err
}

func (l *Line) HandleWebhook(r *http.Request, raw []byte) messaging.WebhookResult {
	body := ParseBody(raw)
	if !InboundAllowed(l.s, r.Header, body) {
		return forbidden()
	}
	events, _ := get(body, "events").([]any)
	for _, event := range events {
		content := text(get(event, "message.text"))
		if content == "" {
			continue
		}
		groupID, roomID := text(get(event, "source.groupId")), text(get(event, "source.roomId"))
		isGroup := groupID != "" || roomID != ""
		in := messaging.Inbound{
			Platform:  "line",
			ChatID:    text(firstTruthy(get(event, "source.groupId"), get(event, "source.roomId"), get(event, "source.userId"), "line")),
			Sender:    text(firstTruthy(get(event, "source.userId"), "line")),
			SenderTag: text(get(event, "source.userId")),
			Content:   content, IsGroup: isGroup,
			MessageID: text(firstTruthy(get(event, "message.id"), get(event, "webhookEventId"), newUUID())),
			Timestamp: isoNow(),
		}
		if truthy(get(event, "timestamp")) {
			in.Timestamp = isoMillis(time.UnixMilli(int64(jsNum(get(event, "timestamp")))))
		}
		meta := ""
		switch {
		case groupID != "":
			meta = "Group: " + groupID
		case roomID != "":
			meta = "Room: " + roomID
		}
		ctx := messaging.AccessContext{SenderID: in.Sender, ChatID: in.ChatID, IsDirect: !isGroup, IsShared: isGroup, GroupID: groupID, RoomID: roomID}
		if !l.admit(ctx, messaging.BlockedOptions{Meta: meta, GroupLabel: groupID, RoomLabel: roomID}) {
			continue
		}
		l.ev.Message(in)
	}
	return messaging.WebhookResult{Handled: true, Status: 200, Body: "OK"}
}

// Mattermost posts through an incoming webhook or its REST API.
type Mattermost struct{ *Configurable }

func newMattermost(cfg messaging.Config, ev messaging.Events, deps Deps) *Mattermost {
	return &Mattermost{newConfigurable("mattermost", cfg, ev, deps, defaults{label: "Mattermost"})}
}

func (m *Mattermost) Connect(context.Context) error {
	if m.s.Str("webhookUrl", "baseUrl", "inboundSecret") == "" {
		return &messaging.ConfigurationRequiredError{Message: "Mattermost webhook URL, base URL, or inbound secret is required"}
	}
	m.connected()
	return nil
}

func (m *Mattermost) SendMessage(ctx context.Context, to, content string, opts messaging.SendOptions) (messaging.SendResult, error) {
	if m.hasOutboundURL() {
		return m.Configurable.SendMessage(ctx, to, content, opts)
	}
	token, err := requireText(m.s.Str("token"), "Mattermost token")
	if err != nil {
		return messaging.SendResult{}, err
	}
	body := []byte(`{"channel_id":` + string(jsonString(to)) + `,"message":` + string(jsonString(content)) + `}`)
	_, err = FetchJSON(ctx, m.deps.HTTPClient(), "Mattermost", http.MethodPost, trimTrailingSlash(m.s.Str("baseUrl"))+"/api/v4/posts",
		map[string]string{"Authorization": "Bearer " + token}, body)
	return messaging.SendResult{Success: err == nil}, err
}

// BlueBubbles serves BlueBubbles and iMessage.
type BlueBubbles struct {
	*Configurable
	serverURL string
	password  string
}

func newBlueBubbles(name string, cfg messaging.Config, ev messaging.Events, deps Deps) *BlueBubbles {
	label := "BlueBubbles"
	if name == "imessage" {
		label = "iMessage"
	}
	c := newConfigurable(name, cfg, ev, deps, defaults{label: label})
	return &BlueBubbles{Configurable: c, serverURL: trimTrailingSlash(c.s.Str("serverUrl", "baseUrl")), password: c.s.Str("password", "apiPassword", "token")}
}

func (b *BlueBubbles) Connect(context.Context) error {
	if _, err := requireText(firstNonEmptyStr(b.serverURL, b.s.Str("outboundUrl")), b.d.label+" server URL"); err != nil {
		return err
	}
	b.connected()
	return nil
}

func firstNonEmptyStr(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func (b *BlueBubbles) SendMessage(ctx context.Context, to, content string, opts messaging.SendOptions) (messaging.SendResult, error) {
	if b.hasOutboundURL() {
		return b.Configurable.SendMessage(ctx, to, content, opts)
	}
	path := b.s.Str("sendPath")
	if path == "" {
		path = "/api/v1/message/text"
	}
	rawURL := b.serverURL + path + "?guid=" + queryEscape(to) + "&tempGuid=" + queryEscape(newUUID())
	if b.password != "" {
		rawURL += "&password=" + queryEscape(b.password)
	}
	body := []byte(`{"message":` + string(jsonString(content)) + `}`)
	_, err := FetchJSON(ctx, b.deps.HTTPClient(), b.d.label, http.MethodPost, rawURL, nil, body)
	return messaging.SendResult{Success: err == nil}, err
}
