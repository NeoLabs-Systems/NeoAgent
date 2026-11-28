package wiring

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/behavior"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// mediaChat records the attachment each send hands the platform.
type mediaChat struct {
	messaging.Platform
	media []string
}

func (c *mediaChat) Connect(context.Context) error          { return nil }
func (c *mediaChat) Disconnect(context.Context) error       { return nil }
func (c *mediaChat) Status() string                         { return messaging.StatusConnected }
func (c *mediaChat) AuthInfo() map[string]any               { return nil }
func (c *mediaChat) SetAccessPolicy(messaging.AccessPolicy) {}
func (c *mediaChat) SendMessage(_ context.Context, _, _ string, opts messaging.SendOptions) (messaging.SendResult, error) {
	c.media = append(c.media, opts.MediaPath)
	return messaging.SendResult{Success: true, MessageID: "m1"}, nil
}

type mediaFixture struct {
	mgr                    *messaging.Manager
	chat                   *mediaChat
	ownArtifact            string // artifact id of user 1
	ownArtifactFile        string // its real host path
	otherArtifact          string // artifact id of user 2
	workspaceFile          string // real host path of user 1's workspace file
	workspaceFileUnderRoot string // the same file as the workspace names it
}

func newMediaFixture(t *testing.T) *mediaFixture {
	t.Helper()
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id,username,email,password) VALUES (1,'user','u@example.com','hash'), (2,'other','o@example.com','hash');
		INSERT INTO agents (id,user_id,slug,display_name,is_default) VALUES ('main',1,'main','Main',1), ('other-main',2,'main','Main',1)`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "0123456789012345678901234567890123456789")
	if err != nil {
		t.Fatal(err)
	}
	store := &artifacts.Store{DB: db, Root: filepath.Join(dir, "artifacts")}
	ws, err := workspace.New(filepath.Join(dir, "workspaces"), false)
	if err != nil {
		t.Fatal(err)
	}
	own, err := store.CreateBufferArtifact(ctx, "1", artifacts.File{Kind: "image", Extension: "png", ContentType: "image/png", FilenameBase: "own", Content: []byte("own")})
	if err != nil {
		t.Fatal(err)
	}
	other, err := store.CreateBufferArtifact(ctx, "2", artifacts.File{Kind: "image", Extension: "png", ContentType: "image/png", FilenameBase: "other", Content: []byte("other")})
	if err != nil {
		t.Fatal(err)
	}
	root, err := ws.Root("1")
	if err != nil {
		t.Fatal(err)
	}
	wsFile := filepath.Join(root, "report.txt")
	if err := os.WriteFile(wsFile, []byte("report"), 0o600); err != nil {
		t.Fatal(err)
	}
	f := &mediaFixture{chat: &mediaChat{}, ownArtifact: own.ID, otherArtifact: other.ID, workspaceFileUnderRoot: wsFile}
	if f.ownArtifactFile, err = filepath.EvalSymlinks(own.StoragePath); err != nil {
		t.Fatal(err)
	}
	if f.workspaceFile, err = filepath.EvalSymlinks(wsFile); err != nil {
		t.Fatal(err)
	}
	f.mgr = messaging.NewManager(messaging.ManagerConfig{DB: db, Box: box, Agents: agentScopeAdapter{r: agentscope.Resolver{DB: db}}, DataDir: filepath.Join(dir, "data"),
		Factories:    map[string]messaging.Factory{"discord": func(messaging.Config, messaging.Events) (messaging.Platform, error) { return f.chat, nil }},
		ResolveMedia: messageMedia{artifacts: store, workspaces: ws}.Resolve,
		UserID:       func(*http.Request) (int64, bool) { return 1, true },
	})
	t.Cleanup(f.mgr.Stop)
	if _, err := f.mgr.ConnectPlatform(ctx, 1, "main", "discord", map[string]any{}, true); err != nil {
		t.Fatal(err)
	}
	return f
}

// refused are attachments a user must never get the server to read.
func (f *mediaFixture) refused() map[string]string {
	return map[string]string{
		"host file":        "/etc/passwd",
		"parent traversal": "../../../../../../etc/passwd",
		"other artifact":   f.otherArtifact,
		"other URL":        "/api/artifacts/" + f.otherArtifact + "/content",
		"remote URL":       "file:///etc/passwd",
	}
}

func (f *mediaFixture) expectNothingSent(t *testing.T, name string) {
	t.Helper()
	if len(f.chat.media) != 0 {
		t.Fatalf("%s: platform was handed %q", name, f.chat.media)
	}
}

func (f *mediaFixture) expectSent(t *testing.T, want string) {
	t.Helper()
	if len(f.chat.media) != 1 || f.chat.media[0] != want {
		t.Fatalf("platform got %q, want %q", f.chat.media, want)
	}
	f.chat.media = nil
}

func TestSendRouteResolvesAttachments(t *testing.T) {
	f := newMediaFixture(t)
	mux := http.NewServeMux()
	f.mgr.Routes(mux)
	post := func(media string) *httptest.ResponseRecorder {
		body, _ := json.Marshal(map[string]string{"platform": "discord", "to": "42", "content": "hi", "mediaPath": media})
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/messaging/send", bytes.NewReader(body)))
		return rec
	}
	for name, media := range f.refused() {
		if rec := post(media); rec.Code == http.StatusOK {
			t.Fatalf("%s: accepted %s", name, rec.Body)
		}
		f.expectNothingSent(t, name)
	}
	if rec := post(f.ownArtifact); rec.Code != http.StatusOK {
		t.Fatalf("own artifact: %d %s", rec.Code, rec.Body)
	}
	f.expectSent(t, f.ownArtifactFile)
	if rec := post("report.txt"); rec.Code != http.StatusOK {
		t.Fatalf("workspace file: %d %s", rec.Code, rec.Body)
	}
	f.expectSent(t, f.workspaceFile)
}

func TestSocketSendResolvesAttachments(t *testing.T) {
	f := newMediaFixture(t)
	s := &socketServices{msg: f.mgr}
	ctx := context.Background()
	for name, media := range f.refused() {
		if _, err := s.Send(ctx, 1, "discord", "42", "hi", "main", media); err == nil {
			t.Fatalf("%s: accepted", name)
		}
		f.expectNothingSent(t, name)
	}
	if _, err := s.Send(ctx, 1, "discord", "42", "hi", "main", "/api/artifacts/"+f.ownArtifact+"/content"); err != nil {
		t.Fatal(err)
	}
	f.expectSent(t, f.ownArtifactFile)
}

func TestAgentDeliveriesResolveAttachments(t *testing.T) {
	f := newMediaFixture(t)
	ctx := context.Background()
	sender := behaviorSender{mgr: func() *messaging.Manager { return f.mgr }}
	pipeline := &behavior.Pipeline{Sender: sender}
	deliver := func(media string) (behavior.DeliverResult, error) {
		return pipeline.DeliverReply(ctx, behavior.DeliverRequest{UserID: 1, AgentID: "main", Message: &messaging.Message{Platform: "discord", ChatID: "42"},
			Config: &behavior.Effective{}, Content: "hi", MediaPath: media, RunID: "run-1"})
	}
	tool := toolMessaging{m: f.mgr}
	engine := agentMessaging{mgr: f.mgr}
	for name, media := range f.refused() {
		if out, err := deliver(media); err == nil && out.Delivered {
			t.Fatalf("behavior %s: delivered", name)
		}
		if _, err := tool.Send(ctx, 1, "main", "discord", "42", "hi", media, "run-1", false); err == nil {
			t.Fatalf("tool %s: accepted", name)
		}
		if _, err := engine.Send(ctx, agent.SendRequest{UserID: 1, AgentID: "main", Platform: "discord", ChatID: "42", Content: "hi", MediaPath: media}); err == nil {
			t.Fatalf("engine %s: accepted", name)
		}
		f.expectNothingSent(t, name)
	}
	if out, err := deliver(f.ownArtifact); err != nil || !out.Delivered {
		t.Fatalf("behavior own artifact: %+v %v", out, err)
	}
	f.expectSent(t, f.ownArtifactFile)
	if _, err := tool.Send(ctx, 1, "main", "discord", "42", "hi", "report.txt", "run-1", false); err != nil {
		t.Fatal(err)
	}
	f.expectSent(t, f.workspaceFile)
	// A path the workspace already resolved is still the user's own file.
	if _, err := engine.Send(ctx, agent.SendRequest{UserID: 1, AgentID: "main", Platform: "discord", ChatID: "42", Content: "hi", MediaPath: f.workspaceFileUnderRoot}); err != nil {
		t.Fatal(err)
	}
	f.expectSent(t, f.workspaceFile)
}
