package httpplatforms

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// Matrix long-polls /sync on a homeserver.
type Matrix struct {
	*base
	homeserver   string
	accessToken  string
	userID       string
	poll         bool
	pollInterval time.Duration
	since        string
	poller       *poller
	log          *slog.Logger
}

func newMatrix(cfg messaging.Config, ev messaging.Events, deps Deps) *Matrix {
	b := newBase("matrix", cfg, ev, deps)
	interval := max(1000, b.s.num("pollIntervalMs", 5000))
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	return &Matrix{
		base: b, homeserver: trimTrailingSlash(b.s.Str("homeserver")), accessToken: b.s.Str("accessToken"),
		userID: b.s.Str("userId"), poll: b.s["pollEnabled"] != false,
		pollInterval: time.Duration(interval) * time.Millisecond, since: b.s.Str("since"), log: log,
	}
}

func (m *Matrix) call(ctx context.Context, method, path string, body []byte) (any, error) {
	return FetchJSON(ctx, m.deps.HTTPClient(), "Matrix", method, m.homeserver+"/_matrix/client/v3"+path,
		map[string]string{"Authorization": "Bearer " + m.accessToken}, body)
}

func (m *Matrix) Connect(ctx context.Context) error {
	if _, err := requireText(m.homeserver, "Matrix homeserver"); err != nil {
		return err
	}
	if _, err := requireText(m.accessToken, "Matrix access token"); err != nil {
		return err
	}
	if who, err := m.call(ctx, http.MethodGet, "/account/whoami", nil); err == nil && m.userID == "" {
		m.userID = text(get(who, "user_id"))
	}
	m.connected()
	if m.poll {
		m.poller = m.startPoller(0, m.pollInterval, func(ctx context.Context) {
			if err := m.syncOnce(ctx); err != nil {
				m.log.Error("Matrix poll failed", "error", err)
			}
		})
	}
	return nil
}

func (m *Matrix) Disconnect(context.Context) error {
	m.setStatus(messaging.StatusDisconnected)
	m.poller.stop()
	m.poller = nil
	m.ev.Disconnected(messaging.Disconnect{Manual: true})
	return nil
}

func (m *Matrix) Logout(ctx context.Context) error { return m.Disconnect(ctx) }

func (m *Matrix) AuthInfo() map[string]any {
	if m.userID == "" {
		return nil
	}
	return map[string]any{"username": m.userID}
}

// membership reports joins and leaves. They never start a chat run.
func (m *Matrix) membership(roomID string, event any) {
	member := text(get(event, "state_key"))
	if member == "" || member == m.userID {
		return
	}
	now, prev := text(get(event, "content.membership")), text(get(event, "unsigned.prev_content.membership"))
	kind := ""
	switch {
	case now == "join" && prev != "join":
		kind = "member_joined"
	case (now == "leave" || now == "ban") && prev == "join":
		kind = "member_left"
	}
	if kind == "" {
		return
	}
	m.ev.Membership(messaging.Membership{
		Kind: kind, SpaceID: roomID, ChatID: roomID, MemberID: member,
		MemberName: text(firstTruthy(get(event, "content.displayname"), member)), OccurredAt: eventTime(event),
	})
}

func eventTime(event any) string {
	if ts := get(event, "origin_server_ts"); truthy(ts) {
		return isoMillis(time.UnixMilli(int64(jsNum(ts))))
	}
	return isoNow()
}

func (m *Matrix) syncOnce(ctx context.Context) error {
	timeout := min(m.pollInterval.Milliseconds(), 30000)
	query := "timeout=" + strconv.FormatInt(timeout, 10)
	continues := m.since != ""
	if continues {
		query += "&since=" + url.QueryEscape(m.since)
	}
	sync, err := m.call(ctx, http.MethodGet, "/sync?"+query, nil)
	if err != nil {
		return err
	}
	if next := text(get(sync, "next_batch")); next != "" {
		m.since = next
	}
	rooms := obj(get(sync, "rooms.join"))
	ids := make([]string, 0, len(rooms))
	for id := range rooms {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, roomID := range ids {
		events, _ := get(rooms[roomID], "timeline.events").([]any)
		for _, event := range events {
			switch text(get(event, "type")) {
			case "m.room.member":
				if continues {
					m.membership(roomID, event)
				}
			case "m.room.message":
				m.message(roomID, event)
			}
		}
	}
	return nil
}

func (m *Matrix) message(roomID string, event any) {
	sender := text(get(event, "sender"))
	if sender != "" && m.userID != "" && sender == m.userID {
		return
	}
	content := text(get(event, "content.body"))
	if content == "" {
		return
	}
	mentioned := m.userID != "" && strings.Contains(content, m.userID)
	clean := content
	if mentioned {
		clean = strings.TrimSpace(strings.ReplaceAll(content, m.userID, ""))
	}
	if clean == "" {
		return
	}
	from := sender
	if from == "" {
		from = roomID
	}
	in := messaging.Inbound{
		Platform: "matrix", ChatID: roomID, Sender: from, SenderName: sender, SenderUsername: sender, SenderTag: sender,
		Content: clean, IsGroup: true, WasMentioned: mentioned,
		MessageID: text(firstTruthy(get(event, "event_id"), newUUID())), Timestamp: eventTime(event),
	}
	ctx := messaging.AccessContext{SenderID: from, ChatID: roomID, IsShared: true, RoomID: roomID, WasMentioned: mentioned}
	if m.admit(ctx, messaging.BlockedOptions{SenderName: in.SenderName, Meta: "Room: " + roomID, RoomLabel: roomID}) {
		m.ev.Message(in)
	}
}

func (m *Matrix) SendMessage(ctx context.Context, to, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	if m.Status() != messaging.StatusConnected {
		return messaging.SendResult{}, errors.New("Matrix not connected")
	}
	path := "/rooms/" + encodeURIComponent(to) + "/send/m.room.message/" + encodeURIComponent(newUUID())
	body := []byte(`{"msgtype":"m.text","body":` + string(jsonString(content)) + `}`)
	if _, err := m.call(ctx, http.MethodPut, path, body); err != nil {
		return messaging.SendResult{}, err
	}
	return messaging.SendResult{Success: true}, nil
}
