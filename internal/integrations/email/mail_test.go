package email

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
	"github.com/emersion/go-imap/v2"
	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/emersion/go-imap/v2/imapserver"
	"github.com/emersion/go-imap/v2/imapserver/imapmemserver"
)

// imapServer runs an in-memory IMAP server with one account, the folders
// INBOX, Sent and Trash, and two messages in INBOX.
func imapServer(t *testing.T) string {
	t.Helper()
	mem := imapmemserver.New()
	user := imapmemserver.NewUser("neo@example.com", "app pw")
	for _, name := range []string{"INBOX", "Sent", "Trash"} {
		if err := user.Create(name, nil); err != nil {
			t.Fatal(err)
		}
	}
	mem.AddUser(user)
	srv := imapserver.New(&imapserver.Options{
		NewSession: func(*imapserver.Conn) (imapserver.Session, *imapserver.GreetingData, error) {
			return mem.NewSession(), nil, nil
		},
		Caps:         imap.CapSet{imap.CapIMAP4rev1: {}, imap.CapIMAP4rev2: {}},
		InsecureAuth: true,
		Logger:       log.New(io.Discard, "", 0),
	})
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() { _ = srv.Serve(ln) }()
	t.Cleanup(func() { srv.Close() })
	addr := ln.Addr().String()

	c, err := imapclient.DialInsecure(addr, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	if err := c.Login("neo@example.com", "app pw").Wait(); err != nil {
		t.Fatal(err)
	}
	for _, raw := range []string{
		"From: Ada Lovelace <ada@example.com>\r\nTo: neo@example.com\r\nSubject: Engines\r\nMessage-ID: <m1@example.com>\r\nDate: Thu, 01 Jan 2026 10:00:00 +0000\r\n\r\nThe analytical engine.\r\n",
		"From: \"Hopper, Grace\" <grace@example.com>\r\nTo: neo@example.com\r\nCc: bob@example.com\r\nSubject: Re: Compilers\r\nMessage-ID: <m2@example.com>\r\nReferences: <m0@example.com>\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=b\r\n\r\n--b\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nSee the attachment.\r\n--b\r\nContent-Type: application/pdf\r\nContent-Disposition: attachment; filename=\"spec.pdf\"\r\n\r\nPDFDATA\r\n--b--\r\n",
	} {
		cmd := c.Append("INBOX", int64(len(raw)), nil)
		if _, err := cmd.Write([]byte(raw)); err != nil {
			t.Fatal(err)
		}
		if err := cmd.Close(); err != nil {
			t.Fatal(err)
		}
		if _, err := cmd.Wait(); err != nil {
			t.Fatal(err)
		}
	}
	return addr
}

type sent struct {
	from string
	to   []string
	raw  string
}

func setupMail(t *testing.T) (*Provider, integrations.Connection, *[]sent) {
	t.Helper()
	addr := imapServer(t)
	insecureForTests = true
	oldDial, oldSend := Dial, SendSMTP
	Dial = func(ctx context.Context, s server) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "tcp", addr)
	}
	var outbox []sent
	SendSMTP = func(_ context.Context, _ account, from string, to []string, raw []byte) error {
		outbox = append(outbox, sent{from, to, string(raw)})
		return nil
	}
	t.Cleanup(func() { Dial, SendSMTP, insecureForTests = oldDial, oldSend, false })
	var p *Provider
	s, _ := replaytest.Stack(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc)
		return []integrations.Provider{p}
	})
	creds := `{"email":"neo@example.com","username":"neo@example.com","password":"app pw","imap":{"host":"imap.example.com","port":993,"secure":true},"smtp":{"host":"smtp.example.com","port":465,"secure":true},"savesSentMail":false,"caldav":null,"carddav":null}`
	id := s.Connect(t, 1, "email", "mail", "neo@example.com", creds)
	conn, err := s.Svc.ConnectionByID(context.Background(), 1, id, s.MainAgent(t, 1))
	if err != nil || conn == nil {
		t.Fatal(err)
	}
	return p, *conn, &outbox
}

func run(t *testing.T, p *Provider, conn integrations.Connection, tool string, args map[string]any) any {
	t.Helper()
	ex, err := p.ExecuteTool(context.Background(), tool, args, conn)
	if err != nil {
		t.Fatalf("%s: %v", tool, err)
	}
	raw, _ := json.Marshal(ex.Result)
	var out any
	_ = json.Unmarshal(raw, &out)
	return out
}

func TestMailToolsAgainstIMAPServer(t *testing.T) {
	p, conn, outbox := setupMail(t)

	folders := run(t, p, conn, "email_list_folders", map[string]any{}).([]any)
	byPath := map[string]any{}
	for _, f := range folders {
		m := f.(map[string]any)
		byPath[m["path"].(string)] = m["specialUse"]
	}
	if byPath["INBOX"] != `\Inbox` || byPath["Sent"] != `\Sent` || byPath["Trash"] != `\Trash` {
		t.Fatalf("folders %v", folders)
	}

	found := run(t, p, conn, "email_search", map[string]any{"limit": 5.0}).([]any)
	if len(found) != 2 || found[0].(map[string]any)["uid"] != 2.0 || found[0].(map[string]any)["from"] != "Hopper, Grace <grace@example.com>" {
		t.Fatalf("search newest first: %v", found)
	}
	if found[1].(map[string]any)["unread"] != true {
		t.Fatalf("unread flag: %v", found[1])
	}
	only := run(t, p, conn, "email_search", map[string]any{"subject": "Engines"}).([]any)
	if len(only) != 1 || only[0].(map[string]any)["subject"] != "Engines" {
		t.Fatalf("subject search: %v", only)
	}
	if _, err := p.ExecuteTool(context.Background(), "email_search", map[string]any{"since": "someday"}, conn); err == nil || err.Error() != "since must be an ISO date." {
		t.Fatalf("bad date: %v", err)
	}

	msg := run(t, p, conn, "email_read", map[string]any{"uid": 2.0}).(map[string]any)
	if msg["from"] != `"Hopper, Grace" <grace@example.com>` || msg["cc"] != "bob@example.com" || !strings.Contains(msg["body"].(string), "See the attachment.") || msg["truncated"] != false {
		t.Fatalf("read: %v", msg)
	}
	att := msg["attachments"].([]any)
	if len(att) != 1 || att[0].(map[string]any)["filename"] != "spec.pdf" || att[0].(map[string]any)["contentType"] != "application/pdf" {
		t.Fatalf("attachments: %v", att)
	}
	if _, err := p.ExecuteTool(context.Background(), "email_read", map[string]any{"uid": 99.0}, conn); err == nil || err.Error() != "Message 99 was not found." {
		t.Fatalf("missing message: %v", err)
	}

	reply := run(t, p, conn, "email_send", map[string]any{"to": "Grace <grace@example.com>", "bcc": "boss@example.com", "body": "Thanks!", "reply_to_uid": 2.0}).(map[string]any)
	if reply["sent"] != true || reply["subject"] != "Re: Compilers" || !strings.HasPrefix(reply["messageId"].(string), "<") {
		t.Fatalf("reply: %v", reply)
	}
	if len(*outbox) != 1 {
		t.Fatalf("outbox %v", *outbox)
	}
	out := (*outbox)[0]
	if out.from != "neo@example.com" || strings.Join(out.to, ",") != "grace@example.com,boss@example.com" ||
		!strings.Contains(out.raw, "In-Reply-To: <m2@example.com>") || !strings.Contains(out.raw, "References: <m0@example.com> <m2@example.com>") ||
		strings.Contains(out.raw, "boss@example.com") || !strings.Contains(out.raw, "Thanks!") {
		t.Fatalf("raw message:\n%s", out.raw)
	}
	sentCopy := run(t, p, conn, "email_search", map[string]any{"folder": "Sent"}).([]any)
	if len(sentCopy) != 1 || sentCopy[0].(map[string]any)["unread"] != false {
		t.Fatalf("copy in Sent: %v", sentCopy)
	}

	updated := run(t, p, conn, "email_update", map[string]any{"uids": []any{1.0, "x", -3.0}, "read": true, "move_to": "trash"}).(map[string]any)
	if updated["updated"] != 1.0 || updated["movedTo"] != "Trash" {
		t.Fatalf("update: %v", updated)
	}
	inTrash := run(t, p, conn, "email_search", map[string]any{"folder": "Trash"}).([]any)
	if len(inTrash) != 1 || inTrash[0].(map[string]any)["unread"] != false {
		t.Fatalf("trash: %v", inTrash)
	}
	if _, err := p.ExecuteTool(context.Background(), "email_update", map[string]any{"uids": []any{}}, conn); err == nil || err.Error() != "uids must list at least one message uid." {
		t.Fatalf("empty uids: %v", err)
	}
}

func TestMailSignInFailureAndSetup(t *testing.T) {
	p, conn, _ := setupMail(t)
	scope := integrations.Scope{UserID: 1, AgentID: conn.AgentID}
	ctx := context.Background()
	if _, err := p.SaveSetup(ctx, scope, map[string]any{"preset": "fastmail", "email": "neo@example.com", "password": "wrong", "calendar": false, "contacts": false}); err == nil ||
		err.Error() != "The mail server rejected the email address or app password." {
		t.Fatalf("wrong password: %v", err)
	}
	// Preset passwords lose their grouping spaces; this account's password has one, so it fails too.
	if _, err := p.SaveSetup(ctx, scope, map[string]any{"preset": "fastmail", "email": "neo@example.com", "password": "app pw", "calendar": false, "contacts": false}); err == nil {
		t.Fatal("spaces were kept for a preset")
	}
	if _, err := p.SaveSetup(ctx, scope, map[string]any{"preset": "custom", "email": "Neo@Example.com", "password": "app pw",
		"imap": map[string]any{"host": "IMAP.example.com", "port": 993.0}, "smtp": map[string]any{"host": "smtp.example.com", "port": "587"}}); err != nil {
		t.Fatalf("custom setup: %v", err)
	}
	cfg, err := p.SetupConfig(ctx, scope)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(cfg)
	if !strings.Contains(string(raw), `"accounts":[{"email":"neo@example.com","preset":"custom","apps":["Mail"]}]`) {
		t.Fatalf("setup config: %s", raw)
	}
}
