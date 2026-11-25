package wiring

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// TestIncomingPromptMatchesNode compares the prompt of a direct message with
// buildIncomingPrompt of the Node server.
func TestIncomingPromptMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/incoming_prompt.json")
	if err != nil {
		t.Fatal(err)
	}
	var vector struct {
		Msg    messaging.Message `json:"msg"`
		Prompt string            `json:"prompt"`
	}
	if err := json.Unmarshal(raw, &vector); err != nil {
		t.Fatal(err)
	}
	if got := incomingPrompt(vector.Msg); got != vector.Prompt {
		t.Fatalf("prompt differs:\n got: %q\nwant: %q", got, vector.Prompt)
	}
}
