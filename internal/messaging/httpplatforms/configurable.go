package httpplatforms

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// defaults are the per-platform settings a user's own configuration overrides.
type defaults struct {
	label        string
	contentField string
	outboundURL  string
}

// Configurable is a platform that sends through a configurable HTTP request
// and receives through a secret-protected webhook, the base of most platforms
// in this package and the whole of the generic ones.
type Configurable struct {
	*base
	d defaults
}

func newConfigurable(name string, cfg messaging.Config, ev messaging.Events, deps Deps, d defaults) *Configurable {
	return &Configurable{base: newBase(name, cfg, ev, deps), d: d}
}

func (c *Configurable) label() string {
	if c.d.label != "" {
		return c.d.label
	}
	return c.name
}

func (c *Configurable) Connect(context.Context) error {
	hasOutbound := c.s.Str("webhookUrl", "outboundUrl") != "" || c.d.outboundURL != ""
	hasInbound := c.s.Str("inboundSecret", "webhookSecret") != ""
	if !hasOutbound && !hasInbound {
		return errors.New(c.label() + " requires an outbound URL/token or an inbound secret")
	}
	c.connected()
	return nil
}

func (c *Configurable) Disconnect(context.Context) error {
	c.stopped()
	return nil
}

// Logout holds no login, so it is a disconnect.
func (c *Configurable) Logout(ctx context.Context) error { return c.Disconnect(ctx) }

func (c *Configurable) AuthInfo() map[string]any {
	label := c.s.Str("displayName")
	if label == "" {
		label = c.label()
	}
	return map[string]any{"label": label}
}

func (c *Configurable) hasOutboundURL() bool { return c.s.Str("outboundUrl", "webhookUrl") != "" }

// SendMessage posts through the configured outbound URL.
func (c *Configurable) SendMessage(ctx context.Context, to, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	urlTemplate := c.s.Str("outboundUrl", "webhookUrl")
	if urlTemplate == "" {
		urlTemplate = c.d.outboundURL
	}
	if urlTemplate == "" {
		return messaging.SendResult{}, errors.New(c.label() + " outbound URL is not configured")
	}
	token := c.s.Str("token", "accessToken", "botToken")
	rawURL := buildURL(urlTemplate, map[string]string{
		"to": to, "content": content, "token": token,
		"baseUrl": trimTrailingSlash(c.s.Str("baseUrl")),
	})
	headers := parseHeaders(c.s["headers"])
	if headers == nil {
		headers = map[string]string{}
	}
	if token != "" && c.s.Str("authHeader") != "none" && headers["authorization"] == "" && headers["Authorization"] == "" {
		scheme := c.s.Str("authScheme")
		if scheme == "" {
			scheme = "Bearer"
		}
		headers["Authorization"] = scheme + " " + token
	}
	body, err := c.requestBody(to, content, token)
	if err != nil {
		return messaging.SendResult{}, err
	}
	method := c.s.Str("method")
	if method == "" {
		method = http.MethodPost
	}
	if _, err := FetchJSON(ctx, c.deps.HTTPClient(), c.label(), method, rawURL, headers, body); err != nil {
		return messaging.SendResult{}, err
	}
	return messaging.SendResult{Success: true}, nil
}

func (c *Configurable) requestBody(to, content, token string) ([]byte, error) {
	if tpl := c.s.Str("bodyTemplate"); tpl != "" {
		filled := buildURL(tpl, map[string]string{"to": to, "content": content, "token": token})
		var raw json.RawMessage
		if err := json.Unmarshal([]byte(filled), &raw); err != nil {
			return nil, err
		}
		return raw, nil
	}
	field := c.s.Str("contentField")
	if field == "" {
		field = c.d.contentField
	}
	if field == "" {
		field = "text"
	}
	out := []byte("{")
	out = append(out, jsonString(field)...)
	out = append(out, ':')
	out = append(out, jsonString(content)...)
	if recipient := c.s.Str("recipientField"); recipient != "" {
		out = append(out, ',')
		out = append(out, jsonString(recipient)...)
		out = append(out, ':')
		out = append(out, jsonString(to)...)
	}
	return append(out, '}'), nil
}

// jsonString is JSON.stringify of a string: no HTML escaping.
func jsonString(s string) []byte {
	var b strings.Builder
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(s)
	return []byte(strings.TrimRight(b.String(), "\n"))
}

// HandleWebhook accepts a generic JSON webhook.
func (c *Configurable) HandleWebhook(r *http.Request, rawBody []byte) messaging.WebhookResult {
	body := ParseBody(rawBody)
	if !InboundAllowed(c.s, r.Header, body) {
		return forbidden()
	}
	in, ok := c.genericMessage(body)
	if !ok {
		return messaging.WebhookResult{Handled: true, Status: 202, Body: "ignored"}
	}
	label := in.ChatID
	ctx := messaging.AccessContext{SenderID: in.Sender, ChatID: in.ChatID, IsDirect: !in.IsGroup, IsShared: in.IsGroup, WasMentioned: in.WasMentioned}
	var opts messaging.BlockedOptions
	opts.SenderName = in.SenderName
	if in.IsGroup {
		ctx.GroupID, ctx.ChannelID, ctx.RoomID = in.ChatID, in.ChatID, in.ChatID
		opts.Meta = "Chat: " + in.ChatID
	}
	opts.GroupLabel, opts.ChannelLabel, opts.RoomLabel = label, label, label
	if !c.admit(ctx, opts) {
		return messaging.WebhookResult{Handled: true, Status: 202, Body: "blocked"}
	}
	c.ev.Message(in)
	return messaging.WebhookResult{Handled: true, Status: 200, Body: "OK"}
}

func forbidden() messaging.WebhookResult {
	return messaging.WebhookResult{Handled: false, Status: 403, Body: "Forbidden"}
}

func (c *Configurable) path(key, fallback string) string {
	if p := c.s.Str(key); p != "" {
		return p
	}
	return fallback
}

func (c *Configurable) genericMessage(body any) (messaging.Inbound, bool) {
	content := firstTruthy(
		jsonPath(body, c.path("contentPath", "content")), jsonPath(body, "text"), jsonPath(body, "message.text"),
		jsonPath(body, "message"), jsonPath(body, "body"))
	chatID := firstTruthy(
		jsonPath(body, c.path("chatIdPath", "chatId")), jsonPath(body, "channel"), jsonPath(body, "channel_id"),
		jsonPath(body, "room"), jsonPath(body, "room_id"), jsonPath(body, "conversation.id"),
		nilIfEmpty(c.s.Str("defaultTo")), "webhook")
	sender := firstTruthy(
		jsonPath(body, c.path("senderPath", "sender")), jsonPath(body, "user"), jsonPath(body, "user.id"),
		jsonPath(body, "from.id"), jsonPath(body, "sender_id"), chatID)
	senderName := firstTruthy(jsonPath(body, c.path("senderNamePath", "senderName")), jsonPath(body, "user.name"), jsonPath(body, "from.name"))
	senderUsername := firstTruthy(jsonPath(body, c.path("senderUsernamePath", "senderUsername")), jsonPath(body, "user.username"), jsonPath(body, "from.username"))
	senderTag := firstTruthy(jsonPath(body, c.path("senderTagPath", "senderTag")), senderUsername)
	mentioned := jsonPath(body, "wasMentioned") == true
	if p := c.s.Str("mentionedPath"); p != "" {
		mentioned = jsonPath(body, p) == true
	}
	replied := jsonPath(body, "repliedToAgent") == true
	if p := c.s.Str("repliedToAgentPath"); p != "" {
		replied = jsonPath(body, p) == true
	}
	if strings.TrimSpace(text(content)) == "" {
		return messaging.Inbound{}, false
	}
	messageID := firstTruthy(jsonPath(body, c.path("messageIdPath", "messageId")))
	id := newUUID()
	if messageID != nil {
		id = text(messageID)
	}
	return messaging.Inbound{
		Platform: c.name, ChatID: text(chatID), Sender: text(sender),
		SenderName: text(senderName), SenderUsername: text(senderUsername), SenderTag: text(senderTag),
		Content: text(content), WasMentioned: mentioned, RepliedToAgent: replied, MessageID: id,
		IsGroup: truthy(c.s["groupByDefault"]) || text(chatID) != text(sender), Timestamp: isoNow(),
	}, true
}
