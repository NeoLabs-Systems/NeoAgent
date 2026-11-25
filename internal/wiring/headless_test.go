package wiring

import "testing"

func TestSelectionFor(t *testing.T) {
	for _, c := range []struct{ provider, model, want string }{
		{"", "", ""},
		{"", "openai/gpt-5.5", "openai::gpt-5.5"},
		{"", "openai::gpt-5.5", "openai::gpt-5.5"},
		{"OpenRouter", "inclusionai/ling-3.0-flash-vl:free", "openrouter::inclusionai/ling-3.0-flash-vl:free"},
		{"", "auto", "auto"},
	} {
		if got, err := selectionFor(c.provider, c.model); err != nil || got != c.want {
			t.Errorf("selectionFor(%q, %q) = %q, %v", c.provider, c.model, got, err)
		}
	}
	if _, err := selectionFor("openai", ""); err == nil {
		t.Fatal("provider without model accepted")
	}
}
