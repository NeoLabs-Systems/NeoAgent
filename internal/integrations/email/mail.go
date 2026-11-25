package email

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"math"
	"net"
	netmail "net/mail"
	"net/smtp"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/emersion/go-imap/v2"
	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/emersion/go-message"
	_ "github.com/emersion/go-message/charset" // decodes non-UTF-8 mail
	"github.com/emersion/go-message/mail"
)

const maxBodyChars = 20000

var (
	imapPorts   = []int{143, 993}
	smtpPorts   = []int{25, 465, 587, 2525}
	hostPattern = regexp.MustCompile(`(?i)^[a-z0-9.-]{1,253}$`)
	special     = map[string]imap.MailboxAttr{"trash": imap.MailboxAttrTrash, "archive": imap.MailboxAttrArchive, "junk": imap.MailboxAttrJunk, "sent": imap.MailboxAttrSent}
)

// account is what a mail connection stores.
type account struct {
	Email         string    `json:"email"`
	Username      string    `json:"username"`
	Password      string    `json:"password"`
	IMAP          server    `json:"imap"`
	SMTP          server    `json:"smtp"`
	SavesSentMail bool      `json:"savesSentMail"`
	CalDAV        *location `json:"caldav"`
	CardDAV       *location `json:"carddav"`
}

type location struct {
	Origin string `json:"origin"`
	Home   string `json:"home"`
}

func contains(list []int, n int) bool {
	for _, v := range list {
		if v == n {
			return true
		}
	}
	return false
}

func joinPorts(list []int) string {
	parts := make([]string, len(list))
	for i, p := range list {
		parts[i] = strconv.Itoa(p)
	}
	return strings.Join(parts, ", ")
}

// parseServer validates a server a custom provider entered.
func parseServer(input any, kind string) (server, error) {
	host := strings.ToLower(text(integrations.Get(input, "host")))
	port, _ := integrations.JSNumber(integrations.Get(input, "port"))
	ports := smtpPorts
	if kind == "imap" {
		ports = imapPorts
	}
	label := strings.ToUpper(kind)
	if !hostPattern.MatchString(host) {
		return server{}, fmt.Errorf("%s server must be a host name.", label)
	}
	if port != math.Trunc(port) || !contains(ports, int(port)) {
		return server{}, fmt.Errorf("%s port must be one of %s.", label, joinPorts(ports))
	}
	p := int(port)
	return server{Host: host, Port: p, Secure: p == 993 || p == 465}, nil
}

// Dial opens connections to mail servers; tests replace it.
var Dial = func(ctx context.Context, s server) (net.Conn, error) {
	d := &net.Dialer{Timeout: 15 * time.Second}
	addr := net.JoinHostPort(s.Host, strconv.Itoa(s.Port))
	if s.Secure {
		return (&tls.Dialer{NetDialer: d, Config: &tls.Config{ServerName: s.Host}}).DialContext(ctx, "tcp", addr)
	}
	return d.DialContext(ctx, "tcp", addr)
}

// insecureForTests skips STARTTLS for plain test servers.
var insecureForTests = false

func authFailed(err error) bool {
	var imapErr *imap.Error
	return errors.As(err, &imapErr) && (imapErr.Code == imap.ResponseCodeAuthenticationFailed || imapErr.Code == imap.ResponseCodeAuthorizationFailed ||
		imapErr.Type == imap.StatusResponseTypeNo)
}

func withIMAP[T any](ctx context.Context, a account, work func(*imapclient.Client) (T, error)) (T, error) {
	var zero T
	conn, err := Dial(ctx, a.IMAP)
	if err != nil {
		return zero, err
	}
	var c *imapclient.Client
	opts := &imapclient.Options{TLSConfig: &tls.Config{ServerName: a.IMAP.Host}}
	if a.IMAP.Secure || insecureForTests {
		c = imapclient.New(conn, opts)
	} else if c, err = imapclient.NewStartTLS(conn, opts); err != nil {
		conn.Close()
		return zero, err
	}
	stop := context.AfterFunc(ctx, func() { c.Close() })
	defer stop()
	defer func() {
		if c.Logout().Wait() != nil {
			c.Close()
		}
	}()
	if err := c.Login(a.Username, a.Password).Wait(); err != nil {
		if authFailed(err) {
			return zero, errors.New("The mail server rejected the email address or app password.")
		}
		return zero, err
	}
	return work(c)
}

func folderName(v any) string {
	if f := text(v); f != "" {
		return f
	}
	return "INBOX"
}

func selectFolder(c *imapclient.Client, folder any) error {
	_, err := c.Select(folderName(folder), nil).Wait()
	return err
}

func specialUse(m *imap.ListData) any {
	for _, attr := range m.Attrs {
		switch attr {
		case imap.MailboxAttrAll, imap.MailboxAttrArchive, imap.MailboxAttrDrafts, imap.MailboxAttrFlagged,
			imap.MailboxAttrJunk, imap.MailboxAttrSent, imap.MailboxAttrTrash:
			return string(attr)
		}
	}
	if strings.EqualFold(m.Mailbox, "INBOX") {
		return `\Inbox`
	}
	return nil
}

// specialNames find the special folders of servers without SPECIAL-USE, as
// imapflow does from the folder name (a short English and German list).
var specialNames = map[string]imap.MailboxAttr{
	"sent": imap.MailboxAttrSent, "sent items": imap.MailboxAttrSent, "sent messages": imap.MailboxAttrSent, "sent mail": imap.MailboxAttrSent,
	"gesendet": imap.MailboxAttrSent, "gesendete elemente": imap.MailboxAttrSent, "gesendete objekte": imap.MailboxAttrSent,
	"trash": imap.MailboxAttrTrash, "deleted": imap.MailboxAttrTrash, "deleted items": imap.MailboxAttrTrash, "deleted messages": imap.MailboxAttrTrash,
	"bin": imap.MailboxAttrTrash, "papierkorb": imap.MailboxAttrTrash, "gelöschte elemente": imap.MailboxAttrTrash, "gelöschte objekte": imap.MailboxAttrTrash,
	"junk": imap.MailboxAttrJunk, "spam": imap.MailboxAttrJunk, "junk e-mail": imap.MailboxAttrJunk, "junk email": imap.MailboxAttrJunk,
	"drafts": imap.MailboxAttrDrafts, "draft": imap.MailboxAttrDrafts, "entwürfe": imap.MailboxAttrDrafts,
	"archive": imap.MailboxAttrArchive, "archiv": imap.MailboxAttrArchive,
}

func leafName(m *imap.ListData) string {
	leaf := m.Mailbox
	if m.Delim != 0 {
		if i := strings.LastIndex(leaf, string(m.Delim)); i >= 0 {
			leaf = leaf[i+1:]
		}
	}
	return leaf
}

// listFolders lists every folder; without any SPECIAL-USE attribute from the
// server the special folders are recognized by name.
func listFolders(c *imapclient.Client) ([]*imap.ListData, error) {
	folders, err := c.List("", "*", &imap.ListOptions{ReturnSpecialUse: true}).Collect()
	if err != nil {
		return nil, err
	}
	for _, f := range folders {
		if s, _ := specialUse(f).(string); s != "" && s != `\Inbox` {
			return folders, nil
		}
	}
	taken := map[imap.MailboxAttr]bool{}
	for _, f := range folders {
		if attr, ok := specialNames[strings.ToLower(leafName(f))]; ok && !taken[attr] {
			taken[attr] = true
			f.Attrs = append(f.Attrs, attr)
		}
	}
	return folders, nil
}

func specialFolder(c *imapclient.Client, name string) (string, error) {
	folders, err := listFolders(c)
	if err != nil {
		return "", err
	}
	for _, f := range folders {
		if specialUse(f) == string(special[name]) {
			return f.Mailbox, nil
		}
	}
	return "", fmt.Errorf("This mailbox has no %s folder.", name)
}

func formatAddresses(list []imap.Address) string {
	var parts []string
	for _, a := range list {
		addr := a.Addr()
		switch {
		case a.Name != "" && addr != "":
			parts = append(parts, a.Name+" <"+addr+">")
		case addr != "":
			parts = append(parts, addr)
		}
	}
	return strings.Join(parts, ", ")
}

func searchCriteria(args map[string]any) (*imap.SearchCriteria, error) {
	c := &imap.SearchCriteria{}
	for _, k := range []struct{ arg, header string }{{"from", "From"}, {"to", "To"}, {"subject", "Subject"}} {
		if v := text(args[k.arg]); v != "" {
			c.Header = append(c.Header, imap.SearchCriteriaHeaderField{Key: k.header, Value: v})
		}
	}
	if v := text(args["query"]); v != "" {
		c.Text = append(c.Text, v)
	}
	if args["unread_only"] == true {
		c.NotFlag = append(c.NotFlag, imap.FlagSeen)
	}
	for _, k := range []string{"since", "before"} {
		v := text(args[k])
		if v == "" {
			continue
		}
		ms, ok := jsx.ParseDate(v, time.Local)
		if !ok {
			return nil, fmt.Errorf("%s must be an ISO date.", k)
		}
		t := time.UnixMilli(ms)
		if k == "since" {
			c.Since = t
		} else {
			c.Before = t
		}
	}
	return c, nil
}

func hasFlag(flags []imap.Flag, f imap.Flag) bool {
	for _, x := range flags {
		if strings.EqualFold(string(x), string(f)) {
			return true
		}
	}
	return false
}

func isoMillis(t time.Time) any {
	if t.IsZero() {
		return nil
	}
	return t.UTC().Format("2006-01-02T15:04:05.000Z")
}

func summarize(m *imapclient.FetchMessageBuffer) dyn.Ordered {
	from, to, subject := "", "", ""
	if m.Envelope != nil {
		from, to, subject = formatAddresses(m.Envelope.From), formatAddresses(m.Envelope.To), m.Envelope.Subject
	}
	return dyn.Ordered{
		{Key: "uid", Value: uint32(m.UID)}, {Key: "from", Value: from}, {Key: "to", Value: to}, {Key: "subject", Value: subject},
		{Key: "date", Value: isoMillis(m.InternalDate)}, {Key: "unread", Value: !hasFlag(m.Flags, imap.FlagSeen)},
		{Key: "flagged", Value: hasFlag(m.Flags, imap.FlagFlagged)},
	}
}

func uidArg(v any) (imap.UID, bool) {
	n, ok := integrations.JSNumber(v)
	if !ok || n <= 0 || n != math.Trunc(n) || n > math.MaxUint32 {
		return 0, false
	}
	return imap.UID(n), true
}

func fetchRaw(c *imapclient.Client, uidValue any) ([]byte, error) {
	uid, ok := uidArg(uidValue)
	if !ok {
		return nil, fmt.Errorf("Message %s was not found.", integrations.Str(uidValue))
	}
	msgs, err := c.Fetch(imap.UIDSetNum(uid), &imap.FetchOptions{UID: true, BodySection: []*imap.FetchItemBodySection{{Peek: true}}}).Collect()
	if err != nil {
		return nil, err
	}
	if len(msgs) == 0 || len(msgs[0].BodySection) == 0 || len(msgs[0].BodySection[0].Bytes) == 0 {
		return nil, fmt.Errorf("Message %s was not found.", integrations.Str(uidValue))
	}
	return msgs[0].BodySection[0].Bytes, nil
}

// parsed is the part of a message the tools show.
type parsed struct {
	from, to, cc, subject string
	messageID             string
	references            []string
	date                  time.Time
	body                  string
	attachments           []dyn.Ordered
}

func addressText(h mail.Header, key string) string {
	list, err := h.AddressList(key)
	if err != nil || len(list) == 0 {
		raw, _ := h.Text(key)
		return raw
	}
	parts := make([]string, len(list))
	for i, a := range list {
		if a.Name != "" {
			parts[i] = displayName(a.Name) + " <" + a.Address + ">"
		} else {
			parts[i] = a.Address
		}
	}
	return strings.Join(parts, ", ")
}

// displayName quotes a name that would not read as one, as mailparser does.
func displayName(name string) string {
	if strings.ContainsAny(name, `",;:<>@()[]\`) {
		return `"` + strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(name) + `"`
	}
	return name
}

var tagPattern = regexp.MustCompile(`(?s)<style.*?</style>|<script.*?</script>|<[^>]+>`)

func parseMessage(raw []byte) (parsed, error) {
	r, err := mail.CreateReader(bytes.NewReader(raw))
	if err != nil && r == nil {
		return parsed{}, err
	}
	h := r.Header
	out := parsed{from: addressText(h, "From"), to: addressText(h, "To"), cc: addressText(h, "Cc")}
	out.subject, _ = h.Subject()
	out.messageID, _ = h.MessageID()
	if out.messageID != "" {
		out.messageID = "<" + out.messageID + ">"
	}
	if refs, err := h.MsgIDList("References"); err == nil {
		for _, ref := range refs {
			out.references = append(out.references, "<"+ref+">")
		}
	}
	out.date, _ = h.Date()
	var plain, html string
	for {
		part, err := r.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			if message.IsUnknownCharset(err) || message.IsUnknownEncoding(err) {
				continue
			}
			break
		}
		body, _ := io.ReadAll(part.Body)
		switch ph := part.Header.(type) {
		case *mail.InlineHeader:
			ct, _, _ := ph.ContentType()
			switch {
			case ct == "text/plain" && plain == "":
				plain = string(body)
			case ct == "text/html" && html == "":
				html = string(body)
			}
		case *mail.AttachmentHeader:
			name, _ := ph.Filename()
			ct, _, _ := ph.ContentType()
			out.attachments = append(out.attachments, dyn.Ordered{{Key: "filename", Value: orNull(name)}, {Key: "contentType", Value: ct}, {Key: "size", Value: len(body)}})
		}
	}
	out.body = plain
	if out.body == "" && html != "" {
		out.body = strings.TrimSpace(tagPattern.ReplaceAllString(html, ""))
	}
	return out, nil
}

func sliceUTF16(s string, n int) (string, bool) {
	units := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > n {
			return s[:i], true
		}
		units += w
	}
	return s, false
}

func randomID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// compose writes the plain-text message; Bcc stays out of the headers.
func compose(from, to, cc, subject, body, inReplyTo string, references []string) ([]byte, string, error) {
	var h mail.Header
	h.SetDate(time.Now())
	h.SetSubject(subject)
	domain := "neoagent"
	if at := strings.LastIndex(from, "@"); at >= 0 {
		domain = from[at+1:]
	}
	msgID := randomID() + "@" + domain
	h.SetMessageID(msgID)
	for _, f := range []struct{ key, value string }{{"From", from}, {"To", to}, {"Cc", cc}} {
		if f.value == "" {
			continue
		}
		if list, err := netmail.ParseAddressList(f.value); err == nil {
			addrs := make([]*mail.Address, len(list))
			for i, a := range list {
				addrs[i] = (*mail.Address)(a)
			}
			h.SetAddressList(f.key, addrs)
		} else {
			h.SetText(f.key, f.value)
		}
	}
	if inReplyTo != "" {
		h.Set("In-Reply-To", inReplyTo)
	}
	if len(references) > 0 {
		h.Set("References", strings.Join(references, " "))
	}
	h.SetContentType("text/plain", map[string]string{"charset": "utf-8"})
	h.Set("Content-Transfer-Encoding", "quoted-printable")
	var buf bytes.Buffer
	w, err := mail.CreateSingleInlineWriter(&buf, h)
	if err != nil {
		return nil, "", err
	}
	if _, err := io.WriteString(w, body); err != nil {
		return nil, "", err
	}
	if err := w.Close(); err != nil {
		return nil, "", err
	}
	return buf.Bytes(), "<" + msgID + ">", nil
}

func recipients(fields ...string) []string {
	var out []string
	for _, f := range fields {
		if f == "" {
			continue
		}
		if list, err := netmail.ParseAddressList(f); err == nil {
			for _, a := range list {
				out = append(out, a.Address)
			}
			continue
		}
		for _, part := range strings.Split(f, ",") {
			if p := strings.TrimSpace(part); p != "" {
				out = append(out, p)
			}
		}
	}
	return out
}

// loginAuth is SMTP AUTH LOGIN for servers that do not offer PLAIN.
type loginAuth struct{ user, pass string }

func (a loginAuth) Start(*smtp.ServerInfo) (string, []byte, error) { return "LOGIN", nil, nil }

func (a loginAuth) Next(from []byte, more bool) ([]byte, error) {
	if !more {
		return nil, nil
	}
	if strings.Contains(strings.ToLower(string(from)), "user") {
		return []byte(a.user), nil
	}
	return []byte(a.pass), nil
}

// SendSMTP delivers a message; tests replace it.
var SendSMTP = func(ctx context.Context, a account, from string, to []string, raw []byte) error {
	conn, err := Dial(ctx, a.SMTP)
	if err != nil {
		return err
	}
	stop := context.AfterFunc(ctx, func() { conn.Close() })
	defer stop()
	c, err := smtp.NewClient(conn, a.SMTP.Host)
	if err != nil {
		conn.Close()
		return err
	}
	defer c.Close()
	if !a.SMTP.Secure {
		if ok, _ := c.Extension("STARTTLS"); !ok {
			return errors.New("The mail server does not offer STARTTLS.")
		}
		if err := c.StartTLS(&tls.Config{ServerName: a.SMTP.Host}); err != nil {
			return err
		}
	}
	var auth smtp.Auth = smtp.PlainAuth("", a.Username, a.Password, a.SMTP.Host)
	if _, mechs := c.Extension("AUTH"); !strings.Contains(strings.ToUpper(mechs), "PLAIN") && strings.Contains(strings.ToUpper(mechs), "LOGIN") {
		auth = loginAuth{a.Username, a.Password}
	}
	if err := c.Auth(auth); err != nil {
		return err
	}
	if err := c.Mail(from); err != nil {
		return err
	}
	for _, r := range to {
		if err := c.Rcpt(r); err != nil {
			return err
		}
	}
	w, err := c.Data()
	if err != nil {
		return err
	}
	if _, err := w.Write(raw); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	return c.Quit()
}

var reSubject = regexp.MustCompile(`(?i)^re:`)

func sendMail(ctx context.Context, a account, args map[string]any) (any, error) {
	to, err := integrations.RequireText(args["to"], "to")
	if err != nil {
		return nil, err
	}
	body, err := integrations.RequireText(args["body"], "body")
	if err != nil {
		return nil, err
	}
	cc, bcc, subject := text(args["cc"]), text(args["bcc"]), text(args["subject"])
	return withIMAP(ctx, a, func(c *imapclient.Client) (any, error) {
		inReplyTo := ""
		var refs []string
		if dyn.Truthy(args["reply_to_uid"]) {
			if err := selectFolder(c, args["reply_folder"]); err != nil {
				return nil, err
			}
			raw, err := fetchRaw(c, args["reply_to_uid"])
			if err != nil {
				return nil, err
			}
			original, err := parseMessage(raw)
			if err != nil {
				return nil, err
			}
			inReplyTo = original.messageID
			refs = append(append(refs, original.references...), nonEmpty(original.messageID)...)
			if subject == "" {
				if reSubject.MatchString(original.subject) {
					subject = original.subject
				} else {
					subject = "Re: " + original.subject
				}
			}
		}
		raw, messageID, err := compose(a.Email, to, cc, subject, body, inReplyTo, refs)
		if err != nil {
			return nil, err
		}
		if err := SendSMTP(ctx, a, a.Email, recipients(to, cc, bcc), raw); err != nil {
			return nil, err
		}
		// Most servers keep no copy of mail sent over SMTP; Gmail does it itself.
		if !a.SavesSentMail {
			if sent, err := specialFolder(c, "sent"); err == nil {
				cmd := c.Append(sent, int64(len(raw)), &imap.AppendOptions{Flags: []imap.Flag{imap.FlagSeen}})
				if _, err := cmd.Write(raw); err == nil && cmd.Close() == nil {
					_, _ = cmd.Wait()
				}
			}
		}
		return dyn.Ordered{{Key: "sent", Value: true}, {Key: "messageId", Value: messageID}, {Key: "to", Value: to}, {Key: "subject", Value: subject}}, nil
	})
}

func nonEmpty(s string) []string {
	if s == "" {
		return nil
	}
	return []string{s}
}

// mailTool runs a mail tool; ok is false for other tools.
func mailTool(ctx context.Context, name string, args map[string]any, a account) (any, bool, error) {
	switch name {
	case "email_list_folders":
		out, err := withIMAP(ctx, a, func(c *imapclient.Client) (any, error) {
			folders, err := listFolders(c)
			if err != nil {
				return nil, err
			}
			list := make([]dyn.Ordered, 0, len(folders))
			for _, f := range folders {
				list = append(list, dyn.Ordered{{Key: "path", Value: f.Mailbox}, {Key: "name", Value: leafName(f)}, {Key: "specialUse", Value: specialUse(f)}})
			}
			return list, nil
		})
		return out, true, err
	case "email_search":
		n, ok := integrations.JSNumber(args["limit"])
		if !ok || n == 0 {
			n = 20
		}
		limit := int(math.Trunc(math.Max(1, math.Min(n, 50))))
		criteria, err := searchCriteria(args)
		if err != nil {
			return nil, true, err
		}
		out, err := withIMAP(ctx, a, func(c *imapclient.Client) (any, error) {
			if err := selectFolder(c, args["folder"]); err != nil {
				return nil, err
			}
			data, err := c.UIDSearch(criteria, nil).Wait()
			if err != nil {
				return nil, err
			}
			uids := data.AllUIDs()
			sort.Slice(uids, func(i, j int) bool { return uids[i] < uids[j] })
			if len(uids) > limit {
				uids = uids[len(uids)-limit:]
			}
			if len(uids) == 0 {
				return []dyn.Ordered{}, nil
			}
			msgs, err := c.Fetch(imap.UIDSetNum(uids...), &imap.FetchOptions{UID: true, Envelope: true, Flags: true, InternalDate: true}).Collect()
			if err != nil {
				return nil, err
			}
			sort.Slice(msgs, func(i, j int) bool { return msgs[i].UID > msgs[j].UID })
			out := make([]dyn.Ordered, 0, len(msgs))
			for _, m := range msgs {
				out = append(out, summarize(m))
			}
			return out, nil
		})
		return out, true, err
	case "email_read":
		out, err := withIMAP(ctx, a, func(c *imapclient.Client) (any, error) {
			if err := selectFolder(c, args["folder"]); err != nil {
				return nil, err
			}
			raw, err := fetchRaw(c, args["uid"])
			if err != nil {
				return nil, err
			}
			p, err := parseMessage(raw)
			if err != nil {
				return nil, err
			}
			body, truncated := sliceUTF16(p.body, maxBodyChars)
			uid, _ := integrations.JSNumber(args["uid"])
			attachments := p.attachments
			if attachments == nil {
				attachments = []dyn.Ordered{}
			}
			return dyn.Ordered{{Key: "uid", Value: uid}, {Key: "from", Value: p.from}, {Key: "to", Value: p.to}, {Key: "cc", Value: p.cc},
				{Key: "subject", Value: p.subject}, {Key: "date", Value: isoMillis(p.date)}, {Key: "body", Value: body},
				{Key: "truncated", Value: truncated}, {Key: "attachments", Value: attachments}}, nil
		})
		return out, true, err
	case "email_send":
		out, err := sendMail(ctx, a, args)
		return out, true, err
	case "email_update":
		list, _ := args["uids"].([]any)
		var uids []imap.UID
		for _, v := range list {
			if uid, ok := uidArg(v); ok {
				uids = append(uids, uid)
			}
		}
		if len(uids) == 0 {
			return nil, true, errors.New("uids must list at least one message uid.")
		}
		set := imap.UIDSetNum(uids...)
		out, err := withIMAP(ctx, a, func(c *imapclient.Client) (any, error) {
			if err := selectFolder(c, args["folder"]); err != nil {
				return nil, err
			}
			for _, f := range []struct {
				arg  string
				flag imap.Flag
			}{{"read", imap.FlagSeen}, {"flagged", imap.FlagFlagged}} {
				on, isBool := args[f.arg].(bool)
				if !isBool {
					continue
				}
				op := imap.StoreFlagsDel
				if on {
					op = imap.StoreFlagsAdd
				}
				if err := c.Store(set, &imap.StoreFlags{Op: op, Silent: true, Flags: []imap.Flag{f.flag}}, nil).Close(); err != nil {
					return nil, err
				}
			}
			var movedTo any
			if target := text(args["move_to"]); target != "" {
				dest := target
				if _, isSpecial := special[strings.ToLower(target)]; isSpecial {
					found, err := specialFolder(c, strings.ToLower(target))
					if err != nil {
						return nil, err
					}
					dest = found
				}
				if _, err := c.Move(set, dest).Wait(); err != nil {
					return nil, err
				}
				movedTo = dest
			}
			return dyn.Ordered{{Key: "updated", Value: len(uids)}, {Key: "movedTo", Value: movedTo}}, nil
		})
		return out, true, err
	}
	return nil, false, nil
}

// verifyMailbox signs in once, so a wrong password fails at setup.
func verifyMailbox(ctx context.Context, a account) error {
	_, err := withIMAP(ctx, a, func(c *imapclient.Client) (struct{}, error) { return struct{}{}, c.Noop().Wait() })
	return err
}
