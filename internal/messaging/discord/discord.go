// Package discord is the Discord bot adapter (text chat only). It keeps a gateway session open and
// turns its events into messaging events.
//
// chatId on inbound messages: "dm_<userId>" for direct messages, the channel
// id for server channels.
package discord

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/bwmarrin/discordgo"
)

const (
	name         = "discord"
	dmPrefix     = "dm_"
	loginTimeout = 20 * time.Second
	reconnectMin = 2 * time.Second
	reconnectMax = time.Minute
)

// fatalCloseCodes are gateway close codes no retry can fix: bad token, bad
// shard setup, an unsupported API version or missing intents.
var fatalCloseCodes = map[int]bool{4004: true, 4010: true, 4011: true, 4012: true, 4013: true, 4014: true}

const disallowedIntentsCode = 4014

var closeCode = regexp.MustCompile(`close (\d{4})`)

// codeOf is the gateway close code inside a connect error, or 0.
func codeOf(err error) int {
	if err == nil {
		return 0
	}
	if m := closeCode.FindStringSubmatch(err.Error()); m != nil {
		code, _ := strconv.Atoi(m[1])
		return code
	}
	return 0
}

// isDisallowedIntents: the refusal arrives as the close code or as the login
// rejection text.
func isDisallowedIntents(err error) bool {
	return codeOf(err) == disallowedIntentsCode || strings.Contains(strings.ToLower(fmt.Sprint(err)), "disallowed intents")
}

// MediaStore keeps inbound media (voice messages, audio files) for the agent.
type MediaStore interface {
	// SaveInboundMedia stores content for the user and returns its file path.
	SaveInboundMedia(ctx context.Context, userID int64, media InboundMedia) (string, error)
}

// InboundMedia is one downloaded attachment.
type InboundMedia struct {
	FilenameBase string
	Extension    string
	ContentType  string
	Content      []byte
	Metadata     map[string]any
}

// Deps is what the adapter needs beyond messaging.Config.
type Deps struct {
	// Media stores inbound audio. Without it audio attachments stay links.
	Media MediaStore
	// Client is the HTTP client of Discord's REST API; nil uses the default.
	// Tests point it at a fake server.
	Client *http.Client
	// Download fetches attachments; nil uses an SSRF-safe client.
	Download *http.Client
}

// Factory builds Discord adapters.
func Factory(deps Deps) messaging.Factory {
	return func(cfg messaging.Config, ev messaging.Events) (messaging.Platform, error) {
		token, _ := cfg.Settings["token"].(string)
		log := cfg.Log
		if log == nil {
			log = slog.Default()
		}
		return &Platform{
			deps: deps, token: token, userID: cfg.UserID, ev: ev, log: log,
			guard:     messaging.NewAccessGuard(name, cfg, ev),
			status:    messaging.StatusDisconnected,
			approvals: map[string][]messaging.ApprovalOption{},
			dms:       map[string]string{},
		}, nil
	}
}

// Platform is one bot connection.
type Platform struct {
	deps   Deps
	token  string
	userID int64
	ev     messaging.Events
	log    *slog.Logger
	guard  *messaging.AccessGuard

	mu        sync.Mutex
	status    string
	session   *discordgo.Session
	botUser   *discordgo.User
	approvals map[string][]messaging.ApprovalOption // open prompts: message id -> options
	dms       map[string]string                     // user id -> DM channel id
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

// AuthInfo is the bot's tag and id.
func (p *Platform) AuthInfo() map[string]any {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.botUser == nil {
		return nil
	}
	return map[string]any{"tag": p.botUser.String(), "id": p.botUser.ID}
}

func (p *Platform) current() (*discordgo.Session, *discordgo.User) {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.session, p.botUser
}

// connected is the session when the bot is logged in.
func (p *Platform) connected() (*discordgo.Session, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.session == nil || p.status != messaging.StatusConnected {
		return nil, errors.New("Discord not connected")
	}
	return p.session, nil
}

// Connect logs in. Joins are delivered only with the privileged Server Members
// Intent; a bot that has not enabled it is refused at login, so the connection
// retries without it and join triggers stay quiet.
func (p *Platform) Connect(ctx context.Context) error {
	if p.token == "" {
		return &messaging.ConfigurationRequiredError{Message: "Discord bot token is required"}
	}
	err := p.login(ctx, true)
	if err == nil || !isDisallowedIntents(err) {
		return err
	}
	p.log.Warn("Server Members Intent is not enabled for this bot; enable it in the Developer Portal for member-join task triggers.")
	return p.login(ctx, false)
}

func (p *Platform) newSession(memberEvents bool) (*discordgo.Session, error) {
	s, err := discordgo.New("Bot " + p.token)
	if err != nil {
		return nil, err
	}
	s.Identify.Intents = discordgo.IntentsGuilds | discordgo.IntentsGuildMessages | discordgo.IntentMessageContent |
		discordgo.IntentsDirectMessages | discordgo.IntentsDirectMessageReactions | discordgo.IntentsGuildMessageReactions
	if memberEvents {
		s.Identify.Intents |= discordgo.IntentsGuildMembers
	}
	if p.deps.Client != nil {
		s.Client = p.deps.Client
	}
	// Reconnecting is ours, so close codes that need the user are not retried.
	s.ShouldReconnectOnError = false
	s.AddHandler(p.onMessage)
	s.AddHandler(p.onReaction)
	s.AddHandler(func(s *discordgo.Session, e *discordgo.GuildMemberAdd) { p.onMembership(s, "member_joined", e.Member) })
	s.AddHandler(func(s *discordgo.Session, e *discordgo.GuildMemberRemove) { p.onMembership(s, "member_left", e.Member) })
	s.AddHandler(p.onDisconnect)
	return s, nil
}

func (p *Platform) login(ctx context.Context, memberEvents bool) error {
	p.closeSession()
	s, err := p.newSession(memberEvents)
	if err != nil {
		return err
	}
	p.setStatus(messaging.StatusConnecting)
	if err := openWithin(ctx, s, loginTimeout); err != nil {
		p.setStatus(messaging.StatusError)
		return err
	}
	p.mu.Lock()
	p.session, p.botUser = s, s.State.User
	p.status = messaging.StatusConnected
	p.mu.Unlock()
	p.ev.Connected()
	return nil
}

// openWithin opens the gateway session, giving up after limit.
func openWithin(ctx context.Context, s *discordgo.Session, limit time.Duration) error {
	done := make(chan error, 1)
	go func() { done <- s.Open() }()
	select {
	case err := <-done:
		return err
	case <-time.After(limit):
		_ = s.Close()
		return fmt.Errorf("Discord login timed out after %d s", int(limit.Seconds()))
	case <-ctx.Done():
		_ = s.Close()
		return ctx.Err()
	}
}

func (p *Platform) closeSession() {
	p.mu.Lock()
	s := p.session
	p.session = nil
	p.mu.Unlock()
	if s != nil {
		_ = s.Close()
	}
}

// Disconnect closes the session for good.
func (p *Platform) Disconnect(context.Context) error {
	p.closeSession()
	p.mu.Lock()
	p.status = messaging.StatusDisconnected
	p.botUser = nil
	p.mu.Unlock()
	p.ev.Disconnected(messaging.Disconnect{Manual: true})
	return nil
}

// Logout is a disconnect: Discord keeps no login on our side.
func (p *Platform) Logout(ctx context.Context) error { return p.Disconnect(ctx) }

// onDisconnect handles a dropped gateway connection: it reports it and keeps
// trying to reconnect until a close code says the user has to act.
func (p *Platform) onDisconnect(s *discordgo.Session, _ *discordgo.Disconnect) {
	p.mu.Lock()
	stale := p.session != s
	if !stale {
		p.status = messaging.StatusDisconnected
	}
	p.mu.Unlock()
	if stale {
		return
	}
	p.log.Warn("Discord gateway disconnected")
	p.ev.Disconnected(messaging.Disconnect{WillReconnect: true})
	go p.reconnect(s)
}

func (p *Platform) reconnect(s *discordgo.Session) {
	for delay := reconnectMin; ; delay = min(delay*2, reconnectMax) {
		time.Sleep(delay)
		p.mu.Lock()
		stale := p.session != s
		p.mu.Unlock()
		if stale {
			return
		}
		p.setStatus(messaging.StatusConnecting)
		err := s.Open()
		if err == nil {
			p.setStatus(messaging.StatusConnected)
			p.ev.Connected()
			return
		}
		if errors.Is(err, discordgo.ErrWSAlreadyOpen) {
			return
		}
		if code := codeOf(err); fatalCloseCodes[code] {
			p.setStatus(messaging.StatusDisconnected)
			p.ev.Disconnected(messaging.Disconnect{RequiresUserAction: true, Reason: "authentication_required"})
			return
		}
	}
}
