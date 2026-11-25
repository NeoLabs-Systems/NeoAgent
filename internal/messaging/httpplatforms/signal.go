package httpplatforms

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// Signal talks to a signal-cli REST API.
type Signal struct {
	*Configurable
	restURL      string
	account      string
	poll         bool
	pollInterval time.Duration
	poller       *poller
	log          *slog.Logger
}

func newSignal(cfg messaging.Config, ev messaging.Events, deps Deps) *Signal {
	c := newConfigurable("signal", cfg, ev, deps, defaults{label: "Signal", contentField: "message"})
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	return &Signal{
		Configurable: c, restURL: trimTrailingSlash(c.s.Str("restUrl", "baseUrl")), account: c.s.Str("account", "number"),
		poll: c.s["pollEnabled"] == true, pollInterval: time.Duration(max(3000, c.s.num("pollIntervalMs", 10000))) * time.Millisecond, log: log,
	}
}

func (s *Signal) Connect(context.Context) error {
	if _, err := requireText(firstNonEmptyStr(s.restURL, s.s.Str("outboundUrl")), "Signal REST API URL"); err != nil {
		return err
	}
	if s.s.Str("outboundUrl") == "" {
		if _, err := requireText(s.account, "Signal account number"); err != nil {
			return err
		}
	}
	s.connected()
	if s.poll {
		s.poller = s.startPoller(0, s.pollInterval, func(ctx context.Context) {
			if err := s.receive(ctx); err != nil {
				s.log.Error("Signal poll failed", "error", err)
			}
		})
	}
	return nil
}

func (s *Signal) Disconnect(ctx context.Context) error {
	s.setStatus(messaging.StatusDisconnected)
	s.poller.stop()
	s.poller = nil
	return s.Configurable.Disconnect(ctx)
}

func (s *Signal) Logout(ctx context.Context) error { return s.Disconnect(ctx) }

func (s *Signal) receive(ctx context.Context) error {
	messages, err := FetchJSON(ctx, s.deps.HTTPClient(), "Signal", http.MethodGet,
		s.restURL+"/v1/receive/"+encodeURIComponent(s.account), nil, nil)
	if err != nil {
		return err
	}
	list, _ := messages.([]any)
	for _, item := range list {
		s.deliver(item)
	}
	return nil
}

func (s *Signal) mentionsAccount(values ...any) bool {
	for _, v := range values {
		if v != nil && text(v) == s.account {
			return true
		}
	}
	return false
}

func (s *Signal) deliver(item any) {
	envelope := firstTruthy(get(item, "envelope"), item)
	data := get(envelope, "dataMessage")
	content := text(get(data, "message"))
	if content == "" {
		return
	}
	groupInfo := get(data, "groupInfo")
	groupID := text(firstTruthy(get(groupInfo, "groupId"), get(groupInfo, "groupIdV2"), get(groupInfo, "id")))
	isGroup := truthy(groupInfo)
	senderID := text(firstTruthy(get(envelope, "sourceNumber"), get(envelope, "source"), "signal"))
	mentioned := false
	mentions, _ := get(data, "mentions").([]any)
	for _, mention := range mentions {
		if s.mentionsAccount(get(mention, "number"), get(mention, "uuid"), get(mention, "aci")) {
			mentioned = true
		}
	}
	replied := s.mentionsAccount(get(data, "quote.authorNumber"), get(data, "quote.author"), get(data, "quote.authorUuid"))
	chatID := groupID
	if chatID == "" {
		chatID = senderID
	}
	name := text(get(envelope, "sourceName"))
	in := messaging.Inbound{
		Platform: "signal", ChatID: chatID, Sender: senderID, SenderName: name, SenderDisplayName: name,
		SenderTag: text(firstTruthy(get(envelope, "sourceNumber"), get(envelope, "source"))),
		Content:   content, IsGroup: isGroup, WasMentioned: mentioned, RepliedToAgent: replied,
		MessageID: text(firstTruthy(get(envelope, "timestamp"), newUUID())), Timestamp: isoNow(),
	}
	if truthy(get(envelope, "timestamp")) {
		in.Timestamp = isoMillis(time.UnixMilli(int64(jsNum(get(envelope, "timestamp")))))
	}
	ctx := messaging.AccessContext{SenderID: senderID, ChatID: chatID, IsDirect: !isGroup, IsShared: isGroup, PhoneNumber: senderID, WasMentioned: mentioned}
	meta := ""
	if isGroup {
		ctx.GroupID = firstNonEmptyStr(groupID, chatID)
		meta = "Group: " + chatID
	}
	if s.admit(ctx, messaging.BlockedOptions{SenderName: name, Meta: meta, GroupLabel: chatID}) {
		s.ev.Message(in)
	}
}

func (s *Signal) SendMessage(ctx context.Context, to, content string, opts messaging.SendOptions) (messaging.SendResult, error) {
	if s.hasOutboundURL() {
		return s.Configurable.SendMessage(ctx, to, content, opts)
	}
	body := []byte(`{"message":` + string(jsonString(content)) + `,"number":` + string(jsonString(s.account)) + `,"recipients":[` + string(jsonString(to)) + `]}`)
	_, err := FetchJSON(ctx, s.deps.HTTPClient(), "Signal", http.MethodPost, s.restURL+"/v2/send", nil, body)
	return messaging.SendResult{Success: err == nil}, err
}
