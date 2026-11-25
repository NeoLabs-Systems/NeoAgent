// Package voice is the voice side of NeoAgent: live voice calls (the live
// model fronts parallel background runs with task tools and quiet-line
// progress), speech-to-text for voice notes and dictation, voice note
// classification, agent-initiated calls, and the /api/voice-assistant routes.
//
// The call mechanics (provider protocols, who has the line, reconnects) live in
// the shared livevoice package; this package supplies NeoAgent's settings,
// prompts, task runtime and storage around them. The AI engine, the provider
// catalog and the realtime hub belong to other domains and are consumed through
// the small interfaces in interfaces.go.
package voice
