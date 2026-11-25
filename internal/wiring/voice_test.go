package wiring

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// resolveApiKey (voice/providers/credentials.js): the environment first, then
// API_KEYS.json under the exact name or its lower case, opened when sealed.
func TestResolveAPIKeyMatchesNode(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "API_KEYS.json"), []byte(`{"deepgram_api_key":"enc:sealed","ELEVEN_KEY":"  plain  "}`), 0o600); err != nil {
		t.Fatal(err)
	}
	decrypt := func(v string) string {
		if v == "enc:sealed" {
			return "opened"
		}
		return v
	}
	t.Setenv("NEO_TEST_VOICE_KEY", "from-env")
	cases := []struct {
		names []string
		want  string
	}{
		{[]string{"NEO_TEST_VOICE_KEY", "DEEPGRAM_API_KEY"}, "from-env"},
		{[]string{"DEEPGRAM_API_KEY"}, "opened"},
		{[]string{"ELEVEN_KEY"}, "plain"},
		{[]string{"MISSING_KEY"}, ""},
	}
	for _, c := range cases {
		if got := resolveAPIKey(c.names, dir, decrypt); got != c.want {
			t.Errorf("%v: %q want %q", c.names, got, c.want)
		}
	}
	if got := resolveAPIKey([]string{"DEEPGRAM_API_KEY"}, filepath.Join(dir, "none"), decrypt); got != "" {
		t.Errorf("missing file: %q", got)
	}
}

func TestVoiceNotesInPrompts(t *testing.T) {
	m := messaging.Message{Platform: "telegram", ChatID: "dm_1", Sender: "1", Content: "", MediaType: "audio", LocalMediaPath: "/data/clip.ogg",
		VoiceNote: map[string]any{"source": "telegram_voice", "intent": "audio_context"}}
	prompt := incomingPrompt(m)
	if !strings.Contains(prompt, "The audio clip is something the sender shared, not a spoken request.") ||
		!strings.Contains(prompt, "No text came with it") {
		t.Fatalf("audio context note missing:\n%s", prompt)
	}
	m.VoiceNote["intent"] = "dictation"
	m.Content = "remind me at five"
	if !isVoiceLike(&m) {
		t.Fatal("a dictation is a spoken turn")
	}
	spoken := voicePrompt(m)
	if !strings.HasPrefix(spoken, "You received a spoken request on telegram.") || !strings.Contains(spoken, "remind me at five") {
		t.Fatalf("spoken prompt:\n%s", spoken)
	}
	m.VoiceNote["sttError"] = "timeout"
	if failed := voicePrompt(m); !strings.Contains(failed, "transcribing it failed (timeout)") {
		t.Fatalf("stt failure prompt:\n%s", failed)
	}
}
