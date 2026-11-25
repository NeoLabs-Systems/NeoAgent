// Package slack is the Slack adapter: outbound through the Web API, inbound
// through Events API webhooks verified with the signing secret or an inbound
// secret.
package slack

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/httpplatforms"
	slackapi "github.com/slack-go/slack"
)

// maxSignatureAge is how far a signed request's timestamp may be from now.
const maxSignatureAge = 5 * 60

// Deps are the adapter's outside dependencies.
type Deps struct {
	// APIURL overrides the Web API base ("https://slack.com/api/").
	APIURL string
	// Client overrides the HTTP client of Web API calls.
	Client *http.Client
	// Now overrides the clock used to check signature freshness.
	Now func() time.Time
}

// Factory builds Slack connections.
func Factory(deps Deps) messaging.Factory {
	return func(cfg messaging.Config, ev messaging.Events) (messaging.Platform, error) {
		s := httpplatforms.Settings(cfg.Settings)
		p := &Platform{
			deps: deps, ev: ev, settings: s,
			guard:         messaging.NewAccessGuard("slack", cfg, ev),
			botToken:      s.Str("botToken", "token"),
			signingSecret: s.Str("signingSecret"),
			inboundSecret: s.Str("inboundSecret"),
			status:        messaging.StatusDisconnected,
		}
		if deps.Now == nil {
			p.deps.Now = time.Now
		}
		opts := []slackapi.Option{}
		if deps.APIURL != "" {
			opts = append(opts, slackapi.OptionAPIURL(deps.APIURL))
		}
		if deps.Client != nil {
			opts = append(opts, slackapi.OptionHTTPClient(deps.Client))
		}
		p.api = slackapi.New(p.botToken, opts...)
		return p, nil
	}
}

// Platform is one Slack connection.
type Platform struct {
	deps     Deps
	ev       messaging.Events
	settings httpplatforms.Settings
	guard    *messaging.AccessGuard
	api      *slackapi.Client

	botToken, signingSecret, inboundSecret string

	mu        sync.Mutex
	status    string
	botUserID string
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

func (p *Platform) botID() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.botUserID
}

func (p *Platform) SetAccessPolicy(a messaging.AccessPolicy) { p.guard.SetPolicy(a) }
func (p *Platform) AccessPolicy() messaging.AccessPolicy     { return p.guard.Policy() }

func (p *Platform) Connect(ctx context.Context) error {
	if p.botToken == "" && p.inboundSecret == "" && p.signingSecret == "" {
		return &messaging.ConfigurationRequiredError{Message: "Slack bot token or inbound secret is required"}
	}
	if p.botToken != "" {
		auth, err := p.api.AuthTestContext(ctx)
		if err != nil {
			return fmt.Errorf("Slack auth failed: %w", err)
		}
		id := auth.UserID
		if id == "" {
			id = auth.BotID
		}
		p.mu.Lock()
		p.botUserID = id
		p.mu.Unlock()
	}
	p.setStatus(messaging.StatusConnected)
	p.ev.Connected()
	return nil
}

func (p *Platform) Disconnect(context.Context) error {
	p.setStatus(messaging.StatusDisconnected)
	p.ev.Disconnected(messaging.Disconnect{Manual: true})
	return nil
}

// Logout holds no login, so it is a disconnect.
func (p *Platform) Logout(ctx context.Context) error { return p.Disconnect(ctx) }

func (p *Platform) AuthInfo() map[string]any {
	if id := p.botID(); id != "" {
		return map[string]any{"username": id}
	}
	return nil
}

func (p *Platform) SendMessage(ctx context.Context, to, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	if p.botToken == "" {
		return messaging.SendResult{}, errors.New("Slack bot token is required for outbound messages")
	}
	if _, _, err := p.api.PostMessageContext(ctx, to, slackapi.MsgOptionText(content, false)); err != nil {
		return messaging.SendResult{}, fmt.Errorf("Slack post failed: %w", err)
	}
	return messaging.SendResult{Success: true}, nil
}

func (p *Platform) verify(r *http.Request, raw []byte, body any) bool {
	if p.signingSecret != "" {
		ts, sig := r.Header.Get("X-Slack-Request-Timestamp"), r.Header.Get("X-Slack-Signature")
		if ts == "" || sig == "" {
			return false
		}
		seconds, err := strconv.ParseFloat(strings.TrimSpace(ts), 64)
		if err == nil && math.Abs(float64(p.deps.Now().UnixMilli())/1000-seconds) > maxSignatureAge {
			return false
		}
		mac := hmac.New(sha256.New, []byte(p.signingSecret))
		mac.Write([]byte("v0:" + ts + ":"))
		mac.Write(raw)
		return hmac.Equal([]byte(sig), []byte("v0="+hex.EncodeToString(mac.Sum(nil))))
	}
	if p.inboundSecret != "" {
		return httpplatforms.InboundAllowed(p.settings, r.Header, body)
	}
	return false
}

func forbidden() messaging.WebhookResult {
	return messaging.WebhookResult{Status: http.StatusForbidden, Body: "Forbidden"}
}

func ignored() messaging.WebhookResult {
	return messaging.WebhookResult{Handled: true, Status: http.StatusAccepted, Body: "ignored"}
}

func str(v any) string {
	switch v := v.(type) {
	case string:
		return v
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	}
	return ""
}

func field(event map[string]any, key string) string { return str(event[key]) }

func eventTime(event map[string]any) string {
	if ts := field(event, "event_ts"); ts != "" {
		if f, err := strconv.ParseFloat(ts, 64); err == nil {
			return time.UnixMilli(int64(f * 1000)).UTC().Format("2006-01-02T15:04:05.000Z")
		}
	}
	return time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
}

func newID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[:4], b[4:6], b[6:8], b[8:10], b[10:])
}

// HandleWebhook handles an Events API request.
func (p *Platform) HandleWebhook(r *http.Request, raw []byte) messaging.WebhookResult {
	body := httpplatforms.ParseBody(raw)
	top, _ := body.(map[string]any)
	if !p.verify(r, raw, body) {
		return forbidden()
	}
	if top["type"] == "url_verification" && field(top, "challenge") != "" {
		return messaging.WebhookResult{Handled: true, Status: http.StatusOK, Body: map[string]any{"challenge": top["challenge"]}}
	}
	event := top
	if e, ok := top["event"].(map[string]any); ok && e != nil {
		event = e
	}
	bot := p.botID()
	eventType := field(event, "type")

	if eventType == "member_joined_channel" || eventType == "member_left_channel" {
		user := field(event, "user")
		if user != "" && user != bot {
			kind := "member_joined"
			if eventType == "member_left_channel" {
				kind = "member_left"
			}
			p.ev.Membership(messaging.Membership{
				Kind: kind, SpaceID: field(event, "channel"), ChatID: field(event, "channel"), MemberID: user,
				MemberName: "<@" + user + ">", DMChatID: user, OccurredAt: eventTime(event),
			})
		}
		return messaging.WebhookResult{Handled: true, Status: http.StatusOK, Body: "OK"}
	}
	text := field(event, "text")
	if (eventType != "message" && eventType != "app_mention") || event["subtype"] != nil && event["subtype"] != "" || text == "" {
		return ignored()
	}
	if bot != "" && field(event, "user") == bot {
		return ignored()
	}
	isGroup := field(event, "channel_type") != "im"
	mention := "<@" + bot + ">"
	mentioned := eventType == "app_mention" || bot != "" && strings.Contains(text, mention)
	content := text
	if bot != "" {
		content = strings.TrimSpace(strings.ReplaceAll(text, mention, ""))
	}
	if content == "" {
		return ignored()
	}
	chat := orDefault(field(event, "channel"), "slack")
	user := field(event, "user")
	sender := orDefault(user, orDefault(field(event, "bot_id"), "slack"))
	tag := field(event, "bot_id")
	if user != "" {
		tag = "<@" + user + ">"
	}
	in := messaging.Inbound{
		Platform: "slack", ChatID: chat, Sender: sender,
		SenderName: field(event, "username"), SenderUsername: field(event, "username"), SenderTag: tag,
		Content: content, IsGroup: isGroup, WasMentioned: mentioned,
		MessageID: orDefault(field(event, "client_msg_id"), orDefault(field(event, "ts"), newID())),
		Timestamp: eventTime(event), ThreadID: field(event, "thread_ts"),
		RepliedToAgent: field(event, "thread_ts") != "" && bot != "" && field(event, "parent_user_id") == bot,
	}
	ctx := messaging.AccessContext{Platform: "slack", SenderID: sender, ChatID: chat, IsDirect: !isGroup, IsShared: isGroup, RoleIDs: []string{}, WasMentioned: mentioned}
	opts := messaging.BlockedOptions{SenderName: in.SenderName, ChannelLabel: chat}
	if isGroup {
		in.ChannelID, in.GroupID = field(event, "channel"), field(event, "channel")
		ctx.GroupID, ctx.ChannelID = chat, chat
		opts.Meta = "Channel: " + chat
	}
	if !p.guard.Check(ctx, opts).Allowed {
		return messaging.WebhookResult{Handled: true, Status: http.StatusAccepted, Body: "blocked"}
	}
	p.ev.Message(in)
	return messaging.WebhookResult{Handled: true, Status: http.StatusOK, Body: "OK"}
}

func orDefault(v, fallback string) string {
	if v == "" {
		return fallback
	}
	return v
}
