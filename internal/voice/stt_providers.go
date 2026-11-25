package voice

import "strings"

// AutoSTTProvider picks the first provider in STTProviders that has an API
// key. "neorouter" is a connected NeoRouter; its model "auto" lets it choose.
const AutoSTTProvider = "auto"

// STTProviders are the speech-to-text providers, in the order automatic tries
// them.
var STTProviders = []string{"openai", "gemini", "deepgram", "neorouter"}

// DefaultSTTModels are the models used when none is configured.
var DefaultSTTModels = map[string]string{
	"openai":    "gpt-transcribe",
	"gemini":    "gemini-3-flash-preview",
	"deepgram":  "nova-3",
	"neorouter": "auto",
}

// NormalizeSTTProvider maps a stored value to a provider id, or "auto".
func NormalizeSTTProvider(provider string) string {
	value := strings.ToLower(strings.TrimSpace(provider))
	for _, p := range STTProviders {
		if p == value {
			return value
		}
	}
	return AutoSTTProvider
}

// ResolveSTTModel is the configured model or the provider's default. With
// "auto" the model stays empty until a concrete provider is chosen.
func ResolveSTTModel(provider, requestedModel string) string {
	requested := strings.TrimSpace(requestedModel)
	id := NormalizeSTTProvider(provider)
	if id == AutoSTTProvider {
		return requested
	}
	if requested != "" {
		return requested
	}
	return DefaultSTTModels[id]
}
