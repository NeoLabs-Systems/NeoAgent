package handlers

import (
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

type noEnv struct{}

func (noEnv) HostTerminal() bool           { return false }
func (noEnv) WebSharingEnabled(int64) bool { return true }

// Every built-in tool of the registry has a handler, and the integrated
// tools dispatched in integrated.go are the registry's integrated tools.
func TestEveryRegistryToolIsHandled(t *testing.T) {
	reg, err := tools.NewRegistry(noEnv{})
	if err != nil {
		t.Fatal(err)
	}
	b := New(Deps{})
	for _, def := range reg.Definitions() {
		if !b.Handles(def.Name) {
			t.Errorf("no handler for %s", def.Name)
		}
	}
	for _, name := range []string{"settings_read", "settings_update", "settings_link", "detect_synthid_watermark"} {
		if !reg.Meta(name, nil).Known {
			t.Errorf("%s is not an integrated tool of the registry", name)
		}
	}
	if n := len(reg.Definitions()); n != len(b.handlers) {
		t.Errorf("registry has %d built-ins, backend %d handlers", n, len(b.handlers))
	}
}
