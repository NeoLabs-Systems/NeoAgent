package integrations_test

import (
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/github"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/google"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/microsoft"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/slack"
)

func TestRoutesMatchNode(t *testing.T) {
	replay(t, func(svc *integrations.Services) []integrations.Provider {
		return []integrations.Provider{github.New(svc), google.New(svc), microsoft.New(svc), slack.New(svc)}
	})
}
