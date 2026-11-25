package nextcloud

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
)

// TestLoginFlowConnectsThroughTheRoutes drives the setup and connect routes:
// the instance URL is checked and saved, the login page opens, the poll
// waits until approval, and every app of the account is stored.
func TestLoginFlowConnectsThroughTheRoutes(t *testing.T) {
	var p *Provider
	s, tr := replaytest.Stack(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc)
		p.pollInterval = time.Millisecond
		return []integrations.Provider{p}
	})
	answer := func(status int, body string) replaytest.Answer {
		raw, _ := json.Marshal(body)
		return replaytest.Answer{Status: status, Body: raw, Headers: map[string]string{"content-type": "application/json"}}
	}

	if r := s.Call(t, "POST", "/api/integrations/nextcloud/connect", 1, `{"appId":"files"}`, nil); r.Status != 400 ||
		!strings.Contains(r.Raw, "Add your Nextcloud instance URL") {
		t.Fatalf("connect before setup: %d %s", r.Status, r.Raw)
	}
	tr.Script([]replaytest.Answer{answer(200, `{"installed":true,"version":"30.0.1"}`)})
	if r := s.Call(t, "PUT", "/api/integrations/nextcloud/config", 1, `{"config":{"baseUrl":"https://cloud.example/"}}`, nil); r.Status != 200 ||
		r.Raw != `{"config":{"baseUrl":"https://cloud.example","configured":true,"accountCount":0,"hasConnectedAccount":false},"provider":"nextcloud","saved":true}` {
		t.Fatalf("save config: %d %s", r.Status, r.Raw)
	}

	tr.Script([]replaytest.Answer{
		answer(200, `{"login":"https://cloud.example/login/v2/flow/abc","poll":{"endpoint":"https://cloud.example/login/v2/poll","token":"tok"}}`),
		answer(404, ``),
		answer(200, `{"server":"https://cloud.example","loginName":"neo","appPassword":"secret"}`),
		answer(200, `{"ocs":{"meta":{"statuscode":200},"data":{"id":"neo","display-name":"Neo","email":""}}}`),
	})
	r := s.Call(t, "POST", "/api/integrations/nextcloud/connect", 1, `{"appId":"files"}`, nil)
	var start struct {
		Status, SessionID, URL string
	}
	if err := json.Unmarshal([]byte(r.Raw), &start); err != nil || r.Status != 200 || start.Status != "interactive_connect" ||
		!strings.HasPrefix(start.URL, "https://neo.example/api/integrations/nextcloud/connect/"+start.SessionID+"?agentId=") {
		t.Fatalf("connect: %d %s", r.Status, r.Raw)
	}
	page := s.Call(t, "GET", "/api/integrations/nextcloud/connect/"+start.SessionID, 1, "", nil)
	if page.Status != 200 || !strings.Contains(page.Raw, "<title>Connect Nextcloud</title>") || !strings.Contains(page.Raw, `const initialLoginUrl = "https://cloud.example/login/v2/flow/abc";`) {
		t.Fatalf("connect page: %d %.300s", page.Status, page.Raw)
	}
	if other := s.Call(t, "GET", "/api/integrations/nextcloud/connect/"+start.SessionID+"/status", 2, "", nil); other.Status != 404 {
		t.Fatalf("another account saw the session: %d %s", other.Status, other.Raw)
	}
	var status map[string]any
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		res := s.Call(t, "GET", "/api/integrations/nextcloud/connect/"+start.SessionID+"/status", 1, "", nil)
		_ = json.Unmarshal([]byte(res.Raw), &status)
		if status["status"] != "connecting" {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}
	if status["status"] != "connected" || status["accountEmail"] != "neo@cloud.example" || status["loginUrl"] != "https://cloud.example/login/v2/flow/abc" {
		t.Fatalf("status: %v", status)
	}
	if poll := tr.Requests()[1]; poll.Method != "POST" || poll.Body == nil || *poll.Body != "token=tok" {
		t.Fatalf("poll request: %+v", poll)
	}
	conns, err := s.Svc.ListConnections(context.Background(), 1, "nextcloud", s.MainAgent(t, 1))
	if err != nil || len(conns) != 3 {
		t.Fatalf("connections: %v %v", conns, err)
	}
	if creds := s.Svc.Credentials(conns[0]); creds.String("appPassword") != "secret" || creds.String("username") != "neo" {
		t.Fatalf("credentials: %v", creds)
	}
	cfg := s.Call(t, "GET", "/api/integrations/nextcloud/config", 1, "", nil)
	if !strings.Contains(cfg.Raw, `"accountCount":1,"hasConnectedAccount":true`) {
		t.Fatalf("config after connect: %s", cfg.Raw)
	}

	// Clearing revokes the app password once and removes every row.
	tr.Script([]replaytest.Answer{answer(200, `{}`)})
	if r := s.Call(t, "DELETE", "/api/integrations/nextcloud/config", 1, "", nil); r.Status != 200 || r.Raw != `{"cleared":true,"provider":"nextcloud"}` {
		t.Fatalf("clear: %d %s", r.Status, r.Raw)
	}
	if reqs := tr.Requests(); len(reqs) != 1 || reqs[0].Method != "DELETE" || !strings.HasSuffix(reqs[0].URL, "/ocs/v2.php/core/apppassword") {
		t.Fatalf("revoke: %+v", reqs)
	}
	if conns, _ := s.Svc.ListConnections(context.Background(), 1, "nextcloud", s.MainAgent(t, 1)); len(conns) != 0 {
		t.Fatalf("rows left: %v", conns)
	}
}
