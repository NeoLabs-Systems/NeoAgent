package integrations_test

import (
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
)

func TestQRImageAndServiceAccessRoutes(t *testing.T) {
	st := integrationstest.New(t, func(*integrations.Services) []integrations.Provider { return nil }, integrations.Hooks{})
	if r := st.Call(t, "GET", "/api/integrations/qr-image?data=hello", 0, "", nil); r.Status != 401 {
		t.Fatalf("anonymous: %d", r.Status)
	}
	if r := st.Call(t, "GET", "/api/integrations/qr-image?data=%20", 1, "", nil); r.Status != 400 || r.Raw != "Missing QR data." {
		t.Fatalf("missing data: %d %s", r.Status, r.Raw)
	}
	r := st.Call(t, "GET", "/api/integrations/qr-image?data=hello", 1, "", nil)
	// Version 1 (21 modules) plus one module of margin, as the Node renderer.
	if r.Status != 200 || !strings.HasPrefix(r.Raw, `<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 23 23" shape-rendering="crispEdges"><path fill="#ffffff" d="M0 0h23v23H0z"/><path stroke="#000000" d="M1 1.5h7`) || !strings.HasSuffix(r.Raw, "\"/></svg>\n") {
		t.Fatalf("qr: %d %s", r.Status, r.Raw)
	}
	if r := st.Call(t, "GET", "/api/integrations/slack/connections/1/services", 1, "", nil); r.Status != 404 || r.Raw != `{"error":"Service access is not supported."}` {
		t.Fatalf("services: %d %s", r.Status, r.Raw)
	}
}
