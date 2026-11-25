package email

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/dav"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
)

// The recordings ran with TZ=UTC, a fixed clock and numbered UUIDs that
// continue across providers in the recorder's order.
func TestMain(m *testing.M) {
	time.Local = time.UTC
	dav.Clock = func() time.Time { return replaytest.Now }
	os.Exit(m.Run())
}

func numberedUUIDs(start int) func() string {
	n := start
	return func() string {
		n++
		return fmt.Sprintf("00000000-0000-4000-8000-%012d", n)
	}
}

// TestMatchesNode replays testdata/node.json (gen/batch1_vectors.js).
func TestMatchesNode(t *testing.T) {
	var data struct {
		Steps []replaytest.ProviderStep `json:"steps"`
	}
	replaytest.Load(t, &data)
	dav.NewUUID = numberedUUIDs(3)
	var p *Provider
	s, tr := replaytest.Stack(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc)
		return []integrations.Provider{p}
	})
	var tools, feed []replaytest.ProviderStep
	for _, step := range data.Steps {
		if strings.HasPrefix(step.Tool, "ical_") {
			feed = append(feed, step)
		} else {
			tools = append(tools, step)
		}
	}
	replaytest.RunProvider(t, s, tr, p, "calendar", tools)
	replaytest.RunProvider(t, s, tr, p, "calendar_feed", feed)
}
