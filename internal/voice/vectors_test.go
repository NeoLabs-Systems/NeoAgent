package voice

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"reflect"
	"regexp"
	"strings"
	"testing"
)

// vectors.json holds what the Node server's voice code answered for the same
// inputs (gen/vectors.js).
type vectors struct {
	CatalogCases []struct {
		Env                map[string]string `json:"env"`
		Value              string            `json:"value"`
		Provider           string            `json:"provider"`
		ServerDefault      string            `json:"serverDefault"`
		NormalizedProvider string            `json:"normalizedProvider"`
		ConfiguredModel    string            `json:"configuredModel"`
		Voice              string            `json:"voice"`
		InputMode          string            `json:"inputMode"`
	} `json:"catalogCases"`
	Rank []struct {
		IDs    []string `json:"ids"`
		Ranked []string `json:"ranked"`
	} `json:"rank"`
	STT []struct {
		Provider, Model, Normalized, Resolved string
	} `json:"stt"`
	VAD []struct {
		Name      string `json:"name"`
		PCMBase64 string `json:"pcmBase64"`
		Result    struct {
			Speech         *bool   `json:"speech"`
			DurationSec    float64 `json:"durationSec"`
			ActiveRatio    float64 `json:"activeRatio"`
			VoicedRatio    float64 `json:"voicedRatio"`
			LowEnergyRatio float64 `json:"lowEnergyRatio"`
		} `json:"result"`
	} `json:"vad"`
	Classify []struct {
		Source      string  `json:"source"`
		VAD         any     `json:"vad"`
		Caption     string  `json:"caption"`
		Forwarded   bool    `json:"forwarded"`
		DurationSec float64 `json:"durationSec"`
		Intent      string  `json:"intent"`
	} `json:"classify"`
	HistoryText []struct {
		Msg struct {
			Content        string `json:"content"`
			LocalMediaPath string `json:"localMediaPath"`
			VoiceNote      struct {
				Intent string `json:"intent"`
			} `json:"voiceNote"`
		} `json:"msg"`
		Text string `json:"text"`
	} `json:"historyText"`
	Messages []struct {
		Msg struct {
			Platform       string `json:"platform"`
			ChatID         string `json:"chatId"`
			Content        string `json:"content"`
			LocalMediaPath string `json:"localMediaPath"`
			MediaType      string `json:"mediaType"`
			VoiceNote      struct {
				Intent   string `json:"intent"`
				STTError string `json:"sttError"`
			} `json:"voiceNote"`
		} `json:"msg"`
		Parts struct {
			SenderIdentity     string `json:"senderIdentity"`
			SenderIdentityNote string `json:"senderIdentityNote"`
			FormattingGuide    string `json:"formattingGuide"`
			ReplyContext       string `json:"replyContext"`
		} `json:"parts"`
		Prompt string `json:"prompt"`
	} `json:"messages"`
	Fragments    map[string]string `json:"fragments"`
	PromptPieces struct {
		RulesWithTools string `json:"rulesWithTools"`
		RulesHandoff   string `json:"rulesHandoff"`
		Clamp          []struct {
			Text string `json:"text"`
			Max  int    `json:"max"`
			Out  string `json:"out"`
		} `json:"clamp"`
		Running      string `json:"running"`
		RunningEmpty string `json:"runningEmpty"`
	} `json:"promptPieces"`
	ProviderTable []struct {
		ID               string   `json:"id"`
		Label            string   `json:"label"`
		RuntimeProvider  string   `json:"runtimeProvider"`
		APIKeyEnv        string   `json:"apiKeyEnv"`
		DefaultVoice     string   `json:"defaultVoice"`
		Voices           []string `json:"voices"`
		InputSampleRate  int      `json:"inputSampleRate"`
		OutputSampleRate int      `json:"outputSampleRate"`
		TaskTools        bool     `json:"taskTools"`
		Adapter          string   `json:"adapter"`
		Protocol         string   `json:"protocol"`
	} `json:"providerTable"`
}

func loadVectors(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestCatalogMatchesNode(t *testing.T) {
	v := loadVectors(t)
	for _, c := range v.CatalogCases {
		d := Defaults{Getenv: func(k string) string { return c.Env[k] }}
		if got := d.ServerDefaultProvider(); got != c.ServerDefault {
			t.Errorf("%v: ServerDefaultProvider = %q, Node %q", c.Env, got, c.ServerDefault)
		}
		if got := d.NormalizeProvider(c.Value); got != c.NormalizedProvider {
			t.Errorf("%v: NormalizeProvider(%q) = %q, Node %q", c.Env, c.Value, got, c.NormalizedProvider)
		}
		if got := d.ConfiguredModel(c.Provider, c.Value); got != c.ConfiguredModel {
			t.Errorf("%v: ConfiguredModel(%q, %q) = %q, Node %q", c.Env, c.Provider, c.Value, got, c.ConfiguredModel)
		}
		if got := d.ResolveVoice(c.Provider, c.Value); got != c.Voice {
			t.Errorf("%v: ResolveVoice(%q, %q) = %q, Node %q", c.Env, c.Provider, c.Value, got, c.Voice)
		}
		if got := NormalizeInputMode(c.Value); got != c.InputMode {
			t.Errorf("NormalizeInputMode(%q) = %q, Node %q", c.Value, got, c.InputMode)
		}
	}
}

func TestProviderTableMatchesNode(t *testing.T) {
	v := loadVectors(t)
	if len(v.ProviderTable) != len(liveProviders) {
		t.Fatalf("%d providers, Node has %d", len(liveProviders), len(v.ProviderTable))
	}
	for i, want := range v.ProviderTable {
		got := liveProviders[i]
		if got.ID != want.ID || got.Label != want.Label || got.RuntimeProvider != want.RuntimeProvider || got.APIKeyEnv != want.APIKeyEnv ||
			got.DefaultVoice != want.DefaultVoice || !reflect.DeepEqual(got.Voices, want.Voices) || got.InputSampleRate != want.InputSampleRate ||
			got.OutputSampleRate != want.OutputSampleRate || got.TaskTools != want.TaskTools || got.Adapter != want.Adapter || got.Protocol != want.Protocol {
			t.Errorf("provider %d differs:\n go   %+v\n node %+v", i, got, want)
		}
	}
}

func TestRankLiveModelsMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Rank {
		models := make([]LiveModel, len(c.IDs))
		for i, id := range c.IDs {
			models[i] = LiveModel{ID: id}
		}
		var got []string
		for _, m := range RankLiveModels(models) {
			got = append(got, m.ID)
		}
		if len(got) != 0 || len(c.Ranked) != 0 {
			if !reflect.DeepEqual(got, c.Ranked) {
				t.Errorf("RankLiveModels(%v) = %v, Node %v", c.IDs, got, c.Ranked)
			}
		}
	}
}

func TestSTTDefaultsMatchNode(t *testing.T) {
	for _, c := range loadVectors(t).STT {
		if got := NormalizeSTTProvider(c.Provider); got != c.Normalized {
			t.Errorf("NormalizeSTTProvider(%q) = %q, Node %q", c.Provider, got, c.Normalized)
		}
		if got := ResolveSTTModel(c.Provider, c.Model); got != c.Resolved {
			t.Errorf("ResolveSTTModel(%q, %q) = %q, Node %q", c.Provider, c.Model, got, c.Resolved)
		}
	}
}

func TestSpeechActivityMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).VAD {
		pcm, err := base64.StdEncoding.DecodeString(c.PCMBase64)
		if err != nil {
			t.Fatal(err)
		}
		got := AnalyzeSpeechActivity(pcm)
		want := c.Result
		if (got.Speech == nil) != (want.Speech == nil) || (got.Speech != nil && *got.Speech != *want.Speech) ||
			got.DurationSec != want.DurationSec || got.ActiveRatio != want.ActiveRatio ||
			got.VoicedRatio != want.VoicedRatio || got.LowEnergyRatio != want.LowEnergyRatio {
			t.Errorf("%s: %+v, Node %+v", c.Name, got, want)
		}
	}
}

func TestClassifyVoiceNoteMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Classify {
		var vad *SpeechActivity
		if c.VAD != "unavailable" {
			vad = &SpeechActivity{}
			if b, ok := c.VAD.(bool); ok {
				vad.Speech = &b
			}
		}
		if got := ClassifyVoiceNote(vad, c.Source, c.DurationSec, c.Caption, c.Forwarded); got != c.Intent {
			t.Errorf("%+v: %q", c, got)
		}
	}
}

func TestVoiceNoteHistoryTextMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).HistoryText {
		msg := Message{Content: c.Msg.Content, LocalMediaPath: c.Msg.LocalMediaPath, VoiceNote: &VoiceNote{Intent: c.Msg.VoiceNote.Intent}}
		if got := VoiceNoteHistoryText(msg); got != c.Text {
			t.Errorf("%+v: %q, Node %q", c.Msg, got, c.Text)
		}
	}
}

func TestSpokenRequestPromptMatchesNode(t *testing.T) {
	// fenceUntrusted belongs to the untrusted-text helpers of another domain;
	// the test applies the same fence-tag neutralising so the prompt can be
	// compared whole.
	fenceTag := regexp.MustCompile(`(?i)<(/?)(external_[a-z_]+|sender_identity)\b`)
	fence := func(tag, text string) string {
		return "<" + tag + ">\n" + fenceTag.ReplaceAllString(text, "&lt;${1}${2}") + "\n</" + tag + ">"
	}
	for _, c := range loadVectors(t).Messages {
		msg := SpokenMessage{
			Platform: c.Msg.Platform, ChatID: c.Msg.ChatID, Content: c.Msg.Content, LocalMediaPath: c.Msg.LocalMediaPath,
			STTError: c.Msg.VoiceNote.STTError, SenderIdentity: c.Parts.SenderIdentity, SenderIdentityNote: c.Parts.SenderIdentityNote,
			FormattingGuide: c.Parts.FormattingGuide, ReplyContext: c.Parts.ReplyContext,
		}
		if got := BuildVoiceMessagingPrompt(msg, fence); got != c.Prompt {
			t.Errorf("prompt for %+v differs:\n go:\n%s\n node:\n%s", c.Msg, got, c.Prompt)
		}
	}
}

func TestPromptPiecesMatchNode(t *testing.T) {
	v := loadVectors(t)
	render := func(file string, _ map[string]string) string { return v.Fragments[file] }
	if got := callRules(render, true); got != v.PromptPieces.RulesWithTools {
		t.Errorf("callRules(true):\n%s\nNode:\n%s", got, v.PromptPieces.RulesWithTools)
	}
	if got := callRules(render, false); got != v.PromptPieces.RulesHandoff {
		t.Errorf("callRules(false):\n%s\nNode:\n%s", got, v.PromptPieces.RulesHandoff)
	}
	for _, c := range v.PromptPieces.Clamp {
		if got := clampText(c.Text, c.Max); got != c.Out {
			t.Errorf("clampText(%q, %d) = %q, Node %q", c.Text, c.Max, got, c.Out)
		}
	}
	got := describeRunningTasks([]map[string]any{
		{"task_id": "1", "request": "Check the weather in Berlin", "started_in": "this call", "running_for_seconds": 95},
		{"task_id": "2", "request": strings.Repeat("x", 400), "started_in": "the chat", "running_for_seconds": nil},
	})
	if got != v.PromptPieces.Running || describeRunningTasks(nil) != v.PromptPieces.RunningEmpty {
		t.Errorf("describeRunningTasks:\n%s\nNode:\n%s", got, v.PromptPieces.Running)
	}
}
