package news

import (
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
)

// TestMatchesNode replays testdata/node.json (gen/batch1_vectors.js).
func TestMatchesNode(t *testing.T) {
	var data struct {
		Steps []replaytest.ProviderStep `json:"steps"`
	}
	replaytest.Load(t, &data)
	var p *Provider
	s, tr := replaytest.Stack(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc)
		return []integrations.Provider{p}
	})
	replaytest.RunProvider(t, s, tr, p, "headlines", data.Steps)
}
