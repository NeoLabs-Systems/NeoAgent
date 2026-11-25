package httpplatforms

import (
	"bufio"
	"context"
	"crypto/tls"
	"errors"
	"net"
	"regexp"
	"strconv"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// IRC serves IRC and Twitch chat over a plain or TLS socket.
type IRC struct {
	*base
	server   string
	port     int
	useTLS   bool
	nick     string
	password string
	channels []string

	connMu sync.Mutex
	conn   net.Conn
	manual bool
}

var privmsg = regexp.MustCompile(`^:([^! ]+)!?[^ ]* PRIVMSG ([^ ]+) :(.+)$`)

func newIRC(name string, cfg messaging.Config, ev messaging.Events, deps Deps) *IRC {
	b := newBase(name, cfg, ev, deps)
	twitch := name == "twitch"
	server := b.s.Str("server")
	if server == "" && twitch {
		server = "irc.chat.twitch.tv"
	}
	defaultPort := 6667
	if twitch || truthy(b.s["tls"]) {
		defaultPort = 6697
	}
	var channels []string
	for _, c := range strings.Split(b.s.Str("channels", "channel"), ",") {
		if c = strings.TrimSpace(c); c != "" {
			channels = append(channels, c)
		}
	}
	return &IRC{
		base: b, server: server, port: int(b.s.num("port", float64(defaultPort))),
		useTLS: b.s["tls"] != false && (twitch || b.s["tls"] == true),
		nick:   b.s.Str("nick", "nickname"), password: b.s.Str("password", "oauthToken"), channels: channels,
	}
}

func (i *IRC) Connect(ctx context.Context) error {
	if _, err := requireText(i.server, i.name+" server"); err != nil {
		return err
	}
	if _, err := requireText(i.nick, i.name+" nickname"); err != nil {
		return err
	}
	address := net.JoinHostPort(i.server, strconv.Itoa(i.port))
	dialer := i.deps.dialer()
	var conn net.Conn
	var err error
	if i.useTLS {
		conn, err = (&tls.Dialer{NetDialer: dialer}).DialContext(ctx, "tcp", address)
	} else {
		conn, err = dialer.DialContext(ctx, "tcp", address)
	}
	if err != nil {
		return err
	}
	i.connMu.Lock()
	i.conn, i.manual = conn, false
	i.connMu.Unlock()
	if i.password != "" {
		i.write("PASS " + i.password)
	}
	i.write("NICK " + i.nick)
	i.write("USER " + i.nick + " 0 * :" + i.nick)
	for _, c := range i.channels {
		i.write("JOIN " + channelName(c))
	}
	i.connected()
	go i.read(conn)
	return nil
}

func channelName(v string) string {
	v = strings.TrimSpace(v)
	if strings.HasPrefix(v, "#") {
		return v
	}
	return "#" + v
}

func (i *IRC) write(line string) {
	i.connMu.Lock()
	defer i.connMu.Unlock()
	if i.conn != nil {
		_, _ = i.conn.Write([]byte(line + "\r\n"))
	}
}

func (i *IRC) Disconnect(context.Context) error {
	i.connMu.Lock()
	i.manual = true
	conn := i.conn
	i.conn = nil
	i.connMu.Unlock()
	if conn != nil {
		_, _ = conn.Write([]byte("QUIT :NeoAgent disconnecting\r\n"))
		_ = conn.Close()
	}
	i.stopped()
	return nil
}

func (i *IRC) Logout(ctx context.Context) error { return i.Disconnect(ctx) }

func (i *IRC) AuthInfo() map[string]any {
	if i.nick == "" {
		return nil
	}
	return map[string]any{"username": i.nick}
}

func (i *IRC) read(conn net.Conn) {
	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 0, 4096), 1<<20)
	for scanner.Scan() {
		i.handleLine(strings.TrimSuffix(scanner.Text(), "\r"))
	}
	i.connMu.Lock()
	manual := i.manual || i.conn != conn
	i.connMu.Unlock()
	if manual {
		return
	}
	i.setStatus(messaging.StatusDisconnected)
	i.ev.Disconnected(messaging.Disconnect{Reason: "connection_lost"})
}

func (i *IRC) handleLine(line string) {
	if rest, ok := strings.CutPrefix(line, "PING "); ok {
		i.write("PONG " + rest)
		return
	}
	m := privmsg.FindStringSubmatch(line)
	if m == nil {
		return
	}
	nick, target, content := m[1], m[2], m[3]
	if nick == i.nick {
		return
	}
	isGroup := strings.HasPrefix(target, "#")
	quoted := regexp.QuoteMeta(i.nick)
	mentioned := isGroup && regexp.MustCompile(`(?i)(^|\s)`+quoted+`[:,]?\b`).MatchString(content)
	clean := content
	if mentioned {
		clean = strings.TrimSpace(regexp.MustCompile(`(?i)(^|\s)`+quoted+`[:,]?\s*`).ReplaceAllLiteralString(content, " "))
	}
	if clean == "" {
		return
	}
	in := messaging.Inbound{
		Platform: i.name, ChatID: target, Sender: nick, SenderName: nick, SenderUsername: nick, SenderTag: nick,
		Content: clean, IsGroup: isGroup, WasMentioned: mentioned, MessageID: newUUID(), Timestamp: isoNow(),
	}
	ctx := messaging.AccessContext{SenderID: nick, ChatID: target, IsDirect: !isGroup, IsShared: isGroup, WasMentioned: mentioned}
	meta := ""
	if isGroup {
		ctx.ChannelID = target
		meta = "Channel: " + target
	}
	if i.admit(ctx, messaging.BlockedOptions{SenderName: nick, Meta: meta, ChannelLabel: target}) {
		i.ev.Message(in)
	}
}

var lineBreaks = regexp.MustCompile(`\r?\n`)

func (i *IRC) SendMessage(_ context.Context, to, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	i.connMu.Lock()
	connected := i.conn != nil
	i.connMu.Unlock()
	if !connected || i.Status() != messaging.StatusConnected {
		return messaging.SendResult{}, errors.New(i.name + " not connected")
	}
	i.write("PRIVMSG " + to + " :" + lineBreaks.ReplaceAllString(content, " "))
	return messaging.SendResult{Success: true}, nil
}
