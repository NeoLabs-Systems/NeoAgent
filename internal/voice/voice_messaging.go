package voice

import (
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

// Dictated voice notes run as spoken turns at low latency. An audio clip shared
// as context is a normal message with media attached. Live calls never come
// through here: they run on the live voice model.
const (
	VoiceLatencyProfile  = "voice"
	VoiceReasoningEffort = "low"
)

// IsVoiceLikeMessage: a dictated voice note.
func IsVoiceLikeMessage(mediaType string, note *VoiceNote) bool {
	return strings.ToLower(livevoice.TrimJS(mediaType)) == "audio" && note != nil && note.Intent == IntentDictation
}

// SpokenMessage is an inbound voice note as the prompt describes it.
type SpokenMessage struct {
	Platform       string
	ChatID         string
	Content        string
	LocalMediaPath string
	STTError       string
	// The blocks other domains build for a message: who sent it, how the
	// platform renders text, what it replies to.
	SenderIdentity     string
	SenderIdentityNote string
	FormattingGuide    string
	ReplyContext       string
}

// Fence wraps untrusted text in its tag (utils/untrusted_text fenceUntrusted).
type Fence func(tag, text string) string

// BuildVoiceMessagingPrompt is the prompt of a spoken request that arrived as a
// voice note.
func BuildVoiceMessagingPrompt(msg SpokenMessage, fence Fence) string {
	channel := msg.Platform
	if channel == "" {
		channel = "voice"
	}
	channel = livevoice.TrimJS(channel)
	if msg.STTError != "" {
		return strings.Join([]string{
			"You received a voice note on " + channel + ", but transcribing it failed (" + msg.STTError + ").",
			msg.SenderIdentity,
			"",
			msg.SenderIdentityNote,
			"The original audio is kept at: " + msg.LocalMediaPath,
			"",
			msg.FormattingGuide,
			"",
			"Do not guess what was said. You may retry once with transcribe_audio on that path.",
			`If that does not work, reply with send_message platform="` + msg.Platform + `" to="` + msg.ChatID + `" asking one short question so the sender can repeat or type the request.`,
		}, "\n")
	}
	lines := []string{
		"You received a spoken request on " + channel + ".",
		msg.SenderIdentity,
		"",
		"Transcribed speech content:",
		fence("external_spoken_request", livevoice.TrimJS(msg.Content)),
	}
	if msg.ReplyContext != "" {
		lines = append(lines, "", msg.ReplyContext)
	}
	original := ""
	if msg.LocalMediaPath != "" {
		original = "The original voice note is kept at: " + msg.LocalMediaPath + ". If the sender says it was not meant as a request, treat that clip as shared audio instead."
	}
	lines = append(lines,
		"",
		msg.SenderIdentityNote,
		original,
		"",
		msg.FormattingGuide,
		"",
		"Latency matters. Use full tool autonomy but move without delay.",
		`Reply with send_message platform="`+msg.Platform+`" to="`+msg.ChatID+`" when complete.`,
		"Match the spoken register: direct, natural sentences. Avoid bullet-heavy or markdown-heavy replies unless the platform clearly renders them.",
		"Use send_interim_update only when a real progress update or a blocking question would genuinely help.",
	)
	return strings.Join(lines, "\n")
}

// VoiceRunOptions start the agent run for a dictated voice note.
type VoiceRunOptions struct {
	RunID          string
	AgentID        string
	Model          string // empty for the default model
	TriggerSource  string
	ConversationID string
	Source         string
	ChatID         string
	RawUserMessage string
	// VoiceMode marks the run as a spoken turn.
	VoiceMode       bool
	LatencyProfile  string
	LatencyPriority string
	ReasoningEffort string
}

// BuildVoiceMessagingRunOptions are the run options of a dictated voice note.
// speechModel is the agent's default_speech_model setting; "auto" or empty
// leaves the model to the engine.
func BuildVoiceMessagingRunOptions(runID, agentID, conversationID, speechModel string, msg SpokenMessage) VoiceRunOptions {
	model := livevoice.TrimJS(speechModel)
	if model == "" || model == "auto" {
		model = ""
	}
	return VoiceRunOptions{
		RunID: runID, AgentID: agentID, Model: model, TriggerSource: "messaging", ConversationID: conversationID,
		Source: msg.Platform, ChatID: msg.ChatID, RawUserMessage: msg.Content, VoiceMode: true,
		LatencyProfile: VoiceLatencyProfile, LatencyPriority: "interactive", ReasoningEffort: VoiceReasoningEffort,
	}
}
