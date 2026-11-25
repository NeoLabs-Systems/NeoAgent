package voice

import (
	"strings"
)

// LiveProvider is one live speech-to-speech provider NeoAgent can talk through.
// This table is the single source for the runtime, the settings API, the admin
// console and the setup wizard. Models are not listed here: they come from each
// provider's model list.
type LiveProvider struct {
	ID               string
	Label            string
	RuntimeProvider  string
	APIKeyEnv        string
	DefaultVoice     string
	Voices           []string
	InputSampleRate  int
	OutputSampleRate int
	// TaskTools: the model calls the task tools itself (Gemini). GPT-Live can
	// only hand off, so checking on, changing or stopping a task is handed off
	// like any other request.
	TaskTools bool
	// Adapter names the protocol's session adapter ("openai" or "google").
	Adapter string
	// Protocol is the live protocol a NeoRouter must relay for this entry, ""
	// for a direct provider.
	Protocol string
}

var openAILive = LiveProvider{
	ID: "openai", Label: "OpenAI GPT-Live", RuntimeProvider: "openai", APIKeyEnv: "OPENAI_API_KEY",
	DefaultVoice: "marin",
	Voices: []string{
		"marin", "quartz", "ripple", "vesper", "willow", "stone", "gleam",
		"meridian", "bossa", "tempo", "beacon", "delta", "cinder",
	},
	InputSampleRate: 24000, OutputSampleRate: 24000, TaskTools: false, Adapter: "openai",
}

var googleLive = LiveProvider{
	ID: "google", Label: "Google Gemini Live", RuntimeProvider: "google", APIKeyEnv: "GOOGLE_AI_KEY",
	DefaultVoice: "Kore",
	Voices: []string{
		"Kore", "Puck", "Charon", "Fenrir", "Aoede", "Leda", "Orus", "Zephyr",
		"Callirrhoe", "Autonoe", "Enceladus", "Iapetus", "Umbriel", "Algieba",
		"Despina", "Erinome", "Algenib", "Rasalgethi", "Laomedeia", "Achernar",
		"Alnilam", "Schedar", "Gacrux", "Pulcherrima", "Achird", "Zubenelgenubi",
		"Vindemiatrix", "Sadachbia", "Sadaltager", "Sulafat",
	},
	InputSampleRate: 16000, OutputSampleRate: 24000, TaskTools: true, Adapter: "google",
}

// liveProviders lists the providers in the order the settings show them. A
// connected NeoRouter relays both protocols to whichever of its providers has
// the model, so it appears once per protocol with that protocol's voices and
// audio format.
var liveProviders = []LiveProvider{
	openAILive,
	googleLive,
	withRouter(openAILive, "neorouter_openai", "NeoRouter · GPT-Live", "openai_live"),
	withRouter(googleLive, "neorouter_google", "NeoRouter · Gemini Live", "gemini_live"),
}

func withRouter(base LiveProvider, id, label, protocol string) LiveProvider {
	base.ID, base.Label, base.Protocol = id, label, protocol
	base.RuntimeProvider, base.APIKeyEnv = "neorouter", "NEOROUTER_API_KEY"
	return base
}

// Input modes of a call.
const (
	InputHandsFree = "hands_free"
	InputPTT       = "ptt"
)

var inputModes = []string{InputHandsFree, InputPTT}

// ProviderByID finds a live provider.
func ProviderByID(id string) (LiveProvider, bool) {
	for _, p := range liveProviders {
		if p.ID == id {
			return p, true
		}
	}
	return LiveProvider{}, false
}

// Defaults resolves the settings the server environment decides. The zero
// value reads no environment.
type Defaults struct{ Getenv func(string) string }

func (d Defaults) env(key string) string {
	if d.Getenv == nil {
		return ""
	}
	return strings.TrimSpace(d.Getenv(key))
}

// ServerDefaultProvider is VOICE_LIVE_PROVIDER when it names a provider,
// otherwise OpenAI.
func (d Defaults) ServerDefaultProvider() string {
	configured := strings.ToLower(d.env("VOICE_LIVE_PROVIDER"))
	if _, ok := ProviderByID(configured); ok {
		return configured
	}
	return "openai"
}

// NormalizeProvider maps a stored value to a known provider id.
func (d Defaults) NormalizeProvider(value string) string {
	id := strings.ToLower(strings.TrimSpace(value))
	if _, ok := ProviderByID(id); ok {
		return id
	}
	return d.ServerDefaultProvider()
}

// ConfiguredModel is the stored model; otherwise the server default from the
// environment applies when it belongs to the same provider. Empty means the
// provider's default from its model list.
func (d Defaults) ConfiguredModel(provider, value string) string {
	if requested := strings.TrimSpace(value); requested != "" {
		return requested
	}
	envModel := d.env("VOICE_LIVE_MODEL")
	if envModel != "" && d.NormalizeProvider(provider) == d.ServerDefaultProvider() {
		return envModel
	}
	return ""
}

// ResolveVoice is the stored voice, the server default or the provider's own.
func (d Defaults) ResolveVoice(provider, value string) string {
	if requested := strings.TrimSpace(value); requested != "" {
		return requested
	}
	id := d.NormalizeProvider(provider)
	if envVoice := d.env("VOICE_LIVE_VOICE"); envVoice != "" && id == d.ServerDefaultProvider() {
		return envVoice
	}
	p, _ := ProviderByID(id)
	return p.DefaultVoice
}

// NormalizeInputMode maps a stored value to a known input mode.
func NormalizeInputMode(value string) string {
	mode := strings.ToLower(strings.TrimSpace(value))
	for _, m := range inputModes {
		if mode == m {
			return mode
		}
	}
	return InputHandsFree
}

// LiveProviders lists the live providers in settings order.
func LiveProviders() []LiveProvider { return append([]LiveProvider(nil), liveProviders...) }

// InputModes lists the input modes of a call.
func InputModes() []string { return append([]string(nil), inputModes...) }
