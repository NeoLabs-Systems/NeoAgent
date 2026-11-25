package neocloud

import (
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/companion/companiontest"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
)

// TestMatchesNode replays the Node provider's recorded calls.
func TestMatchesNode(t *testing.T) {
	companiontest.Replay(t, func(svc *integrations.Services, tr *replaytest.Transport, now func() time.Time) integrations.Provider {
		return New(svc, Options{HTTP: tr.Client(), Now: now})
	})
}
