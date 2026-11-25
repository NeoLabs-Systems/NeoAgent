package delegation

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
)

type harness struct {
	t       *testing.T
	app     http.Handler
	cookies map[int64]string
}

func newHarness(t *testing.T) (*harness, *dbx.DB) {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "test.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"ana", "ben", "cai"} {
		if _, err := db.W.Exec(`INSERT INTO users (username, password) VALUES (?, 'x')`, name); err != nil {
			t.Fatal(err)
		}
	}
	sdb, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "sessions.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sdb.Close() })
	store, err := sessionx.NewStore(ctx, sdb.W)
	if err != nil {
		t.Fatal(err)
	}
	mgr, err := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"test-secret"}})
	if err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	New(Config{DB: db, IsAdmin: func(_ context.Context, uid int64) bool { return uid == 1 }, PublicURL: "https://agent.example"}).Routes(mux)
	mux.HandleFunc("/test-login", func(w http.ResponseWriter, r *http.Request) {
		id, _ := strconv.ParseInt(r.URL.Query().Get("user"), 10, 64)
		sessionx.FromContext(r.Context()).Set("userId", id)
	})
	return &harness{t: t, app: mgr.Middleware(mux), cookies: map[int64]string{}}, db
}

func (h *harness) cookie(uid int64) string {
	if c, ok := h.cookies[uid]; ok {
		return c
	}
	rec := httptest.NewRecorder()
	h.app.ServeHTTP(rec, httptest.NewRequest("GET", "/test-login?user="+strconv.FormatInt(uid, 10), nil))
	c := strings.SplitN(rec.Header().Get("Set-Cookie"), ";", 2)[0]
	h.cookies[uid] = c
	return c
}

func (h *harness) call(uid int64, method, path, body string) (int, map[string]any, string) {
	h.t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Cookie", h.cookie(uid))
	rec := httptest.NewRecorder()
	h.app.ServeHTTP(rec, req)
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out, rec.Body.String()
}

func TestInviteRedeemAndManagedPermissions(t *testing.T) {
	h, db := newHarness(t)
	// An unmanaged account holds everything; the summary keeps Node's key order.
	code, _, raw := h.call(1, "GET", "/api/delegation", "")
	if code != 200 || !strings.HasPrefix(raw, `{"isAdmin":true,"catalog":["shell","file_write",`) || !strings.HasSuffix(raw, `"managedBy":null,"managing":[],"invites":[]}`) {
		t.Fatalf("summary: %d %s", code, raw)
	}
	code, created, raw := h.call(1, "POST", "/api/delegation/invites", `{"label":"team","permissions":["shell","network_write"],"maxUses":1}`)
	if code != 201 || !strings.HasPrefix(created["link"].(string), "https://agent.example/app/?invite=") {
		t.Fatalf("create: %d %s", code, raw)
	}
	link := created["link"].(string)
	if code, out, _ := h.call(1, "POST", "/api/delegation/invites/preview", `{"link":"`+link+`"}`); code != 400 || out["code"] != "INVITE_SELF" {
		t.Fatalf("self preview: %d %v", code, out)
	}
	if code, out, raw := h.call(2, "POST", "/api/delegation/invites/preview", `{"link":"`+link+`"}`); code != 200 || out["singleUse"] != true {
		t.Fatalf("preview: %d %s", code, raw)
	}
	if code, out, raw := h.call(2, "POST", "/api/delegation/invites/redeem", `{"link":"`+link+`"}`); code != 200 || out["managedBy"] == nil {
		t.Fatalf("redeem: %d %s", code, raw)
	}
	// Single use: a second account cannot redeem it.
	if code, out, _ := h.call(3, "POST", "/api/delegation/invites/redeem", `{"link":"`+link+`"}`); code != 410 || out["code"] != "INVITE_USED" {
		t.Fatalf("reuse: %d %v", code, out)
	}
	svc := NewService(db)
	ok, _ := svc.IsPermitted(context.Background(), 2, "shell")
	denied, _ := svc.IsPermitted(context.Background(), 2, "file_write")
	if !ok || denied {
		t.Fatalf("permitted shell=%v file_write=%v", ok, denied)
	}
	// The manager adds and removes one; an unknown key and a non-boolean fail.
	if code, _, raw := h.call(1, "PUT", "/api/delegation/managing/2/permissions", `{"permission":"file_write","allowed":true}`); code != 200 {
		t.Fatalf("grant: %d %s", code, raw)
	}
	if ok, _ := svc.IsPermitted(context.Background(), 2, "file_write"); !ok {
		t.Fatal("file_write must be granted")
	}
	if code, out, _ := h.call(1, "PUT", "/api/delegation/managing/2/permissions", `{"permission":"nope","allowed":true}`); code != 400 || out["error"] != "Unknown permission: nope" {
		t.Fatalf("unknown: %d %v", code, out)
	}
	if code, out, _ := h.call(1, "PUT", "/api/delegation/managing/2/permissions", `{"permission":"shell","allowed":"yes"}`); code != 400 || out["code"] != "INVALID_PERMISSION_VALUE" {
		t.Fatalf("non-boolean: %d %v", code, out)
	}
	// A managed account cannot hand out what its manager took away.
	code, created, _ = h.call(2, "POST", "/api/delegation/invites", `{"permissions":["desktop_control"]}`)
	if code != 403 || created["code"] != "INVITE_SCOPE" {
		t.Fatalf("scope: %d %v", code, created)
	}
	// Leaving restores everything and is audited.
	if code, out, _ := h.call(2, "POST", "/api/delegation/leave", ""); code != 200 || out["managedBy"] != nil {
		t.Fatalf("leave: %d %v", code, out)
	}
	if code, _, _ := h.call(2, "GET", "/api/delegation/audit", ""); code != 403 {
		t.Fatalf("audit non-admin: %d", code)
	}
	code, audit, raw := h.call(1, "GET", "/api/delegation/audit?limit=10", "")
	if code != 200 || len(audit["entries"].([]any)) != 4 || !strings.Contains(raw, `"usernames":{"1":"ana"}`) {
		t.Fatalf("audit: %d %s", code, raw)
	}
}
