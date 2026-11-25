package weather

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
)

// TestConnectStoresThePublicConnection connects through the routes: the
// connection is stored at once and the session reports it.
func TestConnectStoresThePublicConnection(t *testing.T) {
	s, _ := replaytest.Stack(t, func(svc *integrations.Services) []integrations.Provider {
		return []integrations.Provider{New(svc)}
	})
	if r := s.Call(t, "POST", "/api/integrations/weather/connect", 1, `{"appId":"nope"}`, nil); r.Status != 400 || r.Raw != `{"error":"Unknown Weather app: nope"}` {
		t.Fatalf("bad app: %d %s", r.Status, r.Raw)
	}
	r := s.Call(t, "POST", "/api/integrations/weather/connect", 1, `{"appId":"forecast"}`, nil)
	var start map[string]string
	_ = json.Unmarshal([]byte(r.Raw), &start)
	if r.Status != 200 || start["provider"] != "weather" || start["appId"] != "forecast" || start["status"] != "interactive_connect" ||
		start["url"] != "https://neo.example/api/integrations/weather/connect/"+start["sessionId"]+"?agentId="+s.MainAgent(t, 1) {
		t.Fatalf("connect: %d %s", r.Status, r.Raw)
	}
	status := s.Call(t, "GET", "/api/integrations/weather/connect/"+start["sessionId"]+"/status", 1, "", nil)
	if status.Status != 200 || !strings.HasPrefix(status.Raw, `{"id":"`+start["sessionId"]+`","provider":"weather","appId":"forecast","status":"connected","connectionId":`) ||
		!strings.HasSuffix(status.Raw, `"accountEmail":"public@open-meteo","error":null,"qr":null}`) {
		t.Fatalf("status: %s", status.Raw)
	}
	if r := s.Call(t, "DELETE", "/api/integrations/weather/connect/"+start["sessionId"], 1, "", nil); r.Status != 404 || r.Raw != `{"error":"Connection cancellation is not supported."}` {
		t.Fatalf("cancel: %d %s", r.Status, r.Raw)
	}
	if r := s.Call(t, "GET", "/api/integrations/weather/config", 1, "", nil); r.Status != 404 || r.Raw != `{"error":"Weather does not support per-user configuration."}` {
		t.Fatalf("config: %d %s", r.Status, r.Raw)
	}
	list := s.Call(t, "GET", "/api/integrations", 1, "", nil)
	if !strings.Contains(list.Raw, `"accountEmail":"public@open-meteo"`) || strings.Contains(list.Raw, `"connectionMethod"`) {
		t.Fatalf("list: %s", list.Raw)
	}
}
