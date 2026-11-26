package taskwebhooks_test

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/taskwebhooks"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type agentStub struct{}

func (agentStub) Resolve(context.Context, int64, string) (string, error) { return "main", nil }
func (agentStub) IsMain(context.Context, int64, string) (bool, error)    { return true, nil }

type engineStub struct{ runs []tasks.RunRequest }

func (e *engineStub) RunTask(_ context.Context, req tasks.RunRequest) (tasks.RunResult, error) {
	e.runs = append(e.runs, req)
	return tasks.RunResult{RunID: "run-1", Result: jsv.NewObject().Set("content", "done")}, nil
}

type fixture struct {
	t      *testing.T
	db     *dbx.DB
	mux    *http.ServeMux
	engine *engineStub
	box    *secretbox.Box
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, t.TempDir()+"/hooks.db", dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, statement := range []string{
		`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x')`,
		`INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('main', 1, 'main', 'Main', 1)`,
		`INSERT INTO scheduled_tasks (id, user_id, agent_id, name, trigger_type, trigger_config, task_type, task_config, enabled)
			VALUES (5, 1, 'main', 'Hook', 'webhook', '{}', 'agent_prompt', '{"prompt":"handle it"}', 1)`,
	} {
		if _, err := db.W.ExecContext(ctx, statement); err != nil {
			t.Fatal(err)
		}
	}
	box, err := secretbox.New("test-secret-key-for-webhooks-32by!", "fallback-secret-key-32bytes!")
	if err != nil {
		t.Fatal(err)
	}
	engine := &engineStub{}
	user := func(*http.Request) (int64, bool) { return 1, true }
	rt := tasks.New(tasks.Config{DB: db, Box: box, Agents: agentStub{}, Engine: engine, UserID: user})
	t.Cleanup(rt.Stop)
	mux := http.NewServeMux()
	taskwebhooks.New(taskwebhooks.Config{DB: db, Box: box, Dispatcher: rt, UserID: user}).Routes(mux)
	return &fixture{t: t, db: db, mux: mux, engine: engine, box: box}
}

func (f *fixture) call(method, path, body string, headers map[string]string) (int, string) {
	req := httptest.NewRequest(method, "/api/task-webhooks/"+path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	f.mux.ServeHTTP(rec, req)
	return rec.Code, strings.TrimSpace(rec.Body.String())
}

// signed builds the headers a 3.9.0 sender sends.
func signed(secret, requestID, body string, skew time.Duration) map[string]string {
	ts := strconv.FormatInt(time.Now().Add(skew).UnixMilli(), 10)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(ts + "." + body))
	return map[string]string{
		"X-NeoAgent-Timestamp": ts, "X-NeoAgent-Request-Id": requestID,
		"X-NeoAgent-Signature": "sha256=" + hex.EncodeToString(mac.Sum(nil)),
	}
}

// A secret stored by the Node server keeps working and its delivery runs the task.
func TestSignedDeliveryRunsTaskOnce(t *testing.T) {
	f := newFixture(t)
	sealed, err := f.box.Seal("node-era-secret")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.db.W.Exec(`INSERT INTO task_webhook_secrets (task_id, user_id, secret_encrypted, secret_fingerprint) VALUES (5, 1, ?, 'abc')`, sealed); err != nil {
		t.Fatal(err)
	}
	body := `{"event":"deploy_finished"}`
	headers := signed("node-era-secret", "req-1", body, 0)
	code, answer := f.call("POST", "5/deliver", body, headers)
	if code != http.StatusAccepted || !strings.Contains(answer, `"accepted":true`) || !strings.Contains(answer, `"content":"done"`) {
		t.Fatalf("deliver: %d %s", code, answer)
	}
	if len(f.engine.runs) != 1 || !strings.Contains(f.engine.runs[0].Prompt, "deploy_finished") {
		t.Fatalf("runs = %+v", f.engine.runs)
	}
	if code, answer = f.call("POST", "5/deliver", body, headers); code != http.StatusConflict || answer != `{"error":"Webhook request ID was already used."}` {
		t.Fatalf("replay: %d %s", code, answer)
	}
	_, answer = f.call("GET", "5/deliveries", "", nil)
	var deliveries []map[string]any
	if err := json.Unmarshal([]byte(answer), &deliveries); err != nil || len(deliveries) != 1 ||
		deliveries[0]["status"] != "completed" || deliveries[0]["completedAt"] == nil {
		t.Fatalf("deliveries: %v %s", err, answer)
	}
	if len(f.engine.runs) != 1 {
		t.Fatalf("replay ran the task again: %d runs", len(f.engine.runs))
	}
}

func TestDeliveryRefusals(t *testing.T) {
	f := newFixture(t)
	code, answer := f.call("POST", "5/rotate", "", nil)
	var rotated struct{ Secret, Fingerprint string }
	if err := json.Unmarshal([]byte(answer), &rotated); err != nil || code != 200 || len(rotated.Secret) != 43 || len(rotated.Fingerprint) != 16 {
		t.Fatalf("rotate: %d %s", code, answer)
	}
	code, answer = f.call("GET", "5", "", nil)
	if code != 200 || strings.Contains(answer, rotated.Secret) || !strings.Contains(answer, `"configured":true`) {
		t.Fatalf("configuration: %d %s", code, answer)
	}

	body := `{}`
	bodyOnly := signed(rotated.Secret, "a", body, 0)
	mac := hmac.New(sha256.New, []byte(rotated.Secret))
	mac.Write([]byte(body))
	bodyOnly["X-NeoAgent-Signature"] = "sha256=" + hex.EncodeToString(mac.Sum(nil))
	noID := signed(rotated.Secret, "", body, 0)
	for _, c := range []struct {
		name    string
		headers map[string]string
		body    string
		status  int
		message string
	}{
		{"no request id", noID, body, 401, "Missing webhook authentication headers."},
		{"old", signed(rotated.Secret, "b", body, -6*time.Minute), body, 401, "Webhook timestamp is outside the allowed window."},
		{"future", signed(rotated.Secret, "c", body, 6*time.Minute), body, 401, "Webhook timestamp is outside the allowed window."},
		{"body-only signature", bodyOnly, body, 401, "Invalid webhook signature."},
		{"too large", signed(rotated.Secret, "d", body, 0), `{"a":"` + strings.Repeat("x", 256<<10) + `"}`, 413, "Webhook payload exceeds 256 KiB."},
	} {
		code, answer := f.call("POST", "5/deliver", c.body, c.headers)
		if code != c.status || answer != `{"error":"`+c.message+`"}` {
			t.Errorf("%s: %d %s", c.name, code, answer)
		}
	}

	if _, err := f.db.W.Exec(`UPDATE scheduled_tasks SET enabled = 0 WHERE id = 5`); err != nil {
		t.Fatal(err)
	}
	if code, answer := f.call("POST", "5/deliver", body, signed(rotated.Secret, "e", body, 0)); code != 404 || answer != `{"error":"Webhook task is unavailable."}` {
		t.Errorf("disabled: %d %s", code, answer)
	}
	if len(f.engine.runs) != 0 {
		t.Fatalf("a refused delivery ran the task")
	}
}
