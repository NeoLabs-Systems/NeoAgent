package sockets

import (
	"context"
	"errors"

	"github.com/NeoLabs-Systems/neolabs-go/realtime"
)

const (
	maxVoiceAudioChunkBytes  = 256 * 1024
	maxVoiceAudioBase64Chars = (maxVoiceAudioChunkBytes*4+2)/3 + 8 // Math.ceil(bytes * 4 / 3) + 8
)

func (c *client) voiceError(err error, extra ...any) {
	c.failWith("voice:error", "error", err, extra...)
}

func (c *client) voiceCallAccept(ev *realtime.Event) {
	calls := c.srv.cfg.Services.Calls
	callID := optionalString(ev.Object(0)["callId"], 128)
	switch {
	case callID == "":
		_ = c.sock.Emit("voice:error", map[string]any{"error": "callId is required"})
		return
	case calls == nil:
		_ = c.sock.Emit("voice:error", map[string]any{"error": "Agent calls are unavailable."})
		return
	}
	result, err := calls.Accept(context.Background(), callID, c.userID, c.sock)
	if err != nil {
		c.voiceError(err)
		return
	}
	if !result.Accepted {
		_ = c.sock.Emit("voice:call_ended", map[string]any{"callId": callID, "reason": result.Status})
		return
	}
	// A disconnect detaches the call like one the socket opened itself.
	if result.SessionID != "" {
		c.trackVoiceSession(result.SessionID, true)
	}
}

func (c *client) voiceCallDecline(ev *realtime.Event) {
	calls := c.srv.cfg.Services.Calls
	data := ev.Object(0)
	callID := optionalString(data["callId"], 128)
	switch {
	case callID == "":
		_ = c.sock.Emit("voice:error", map[string]any{"error": "callId is required"})
		return
	case calls == nil:
		_ = c.sock.Emit("voice:error", map[string]any{"error": "Agent calls are unavailable."})
		return
	}
	later, _ := data["later"].(bool)
	if err := calls.Decline(callID, c.userID, c.sock, later); err != nil {
		c.voiceError(err)
	}
}

func (c *client) voiceSessionOpen(ev *realtime.Event) {
	data := ev.Object(0)
	agentID, err := c.agentFor(agentCandidate(data))
	var sessionID string
	if err == nil {
		sessionID, err = c.srv.cfg.Services.Voice.OpenFlutterSession(context.Background(), OpenVoiceSession{
			UserID: c.userID, AgentID: agentID, Peer: c.sock, SessionID: optionalString(data["sessionId"], 128),
		})
	}
	if err != nil {
		c.voiceError(err, "recoverable", false)
		return
	}
	c.trackVoiceSession(sessionID, true)
}

// voiceSessionEvents are the events of an open voice session. They share
// validation: a sessionId, ownership is checked by the runtime.
func (c *client) voiceSessionEvents() map[string]handler {
	voice := c.srv.cfg.Services.Voice
	events := map[string]struct {
		run   func(sessionID string, data map[string]any) error
		async bool
	}{
		"voice:audio": {run: func(id string, data map[string]any) error {
			audio := optionalString(data["audioBase64"], maxVoiceAudioBase64Chars)
			if audio == "" {
				return errors.New("audioBase64 is required")
			}
			return voice.AppendAudio(id, decodeBase64(audio), c.userID)
		}},
		"voice:input_start": {run: func(id string, _ map[string]any) error { return voice.StartInput(id, c.userID) }},
		"voice:input_end":   {run: func(id string, _ map[string]any) error { return voice.EndInput(id, c.userID) }},
		"voice:interrupt":   {run: func(id string, _ map[string]any) error { return voice.InterruptOutput(id, c.userID) }},
		"voice:cancel_task": {run: func(id string, data map[string]any) error {
			return voice.CancelTask(id, c.userID, optionalString(data["runId"], 128))
		}},
		"voice:session_close": {async: true, run: func(id string, data map[string]any) error {
			cancel, _ := data["cancelTask"].(bool)
			if err := voice.CloseSession(context.Background(), id, "client_closed", c.userID, cancel); err != nil {
				return err
			}
			c.trackVoiceSession(id, false)
			return nil
		}},
	}
	out := make(map[string]handler, len(events))
	for name, e := range events {
		out[name] = handler{async: e.async, run: func(ev *realtime.Event) {
			data := ev.Object(0)
			sessionID := optionalString(data["sessionId"], 128)
			if sessionID == "" {
				_ = c.sock.Emit("voice:error", map[string]any{"error": "sessionId is required", "recoverable": true})
				return
			}
			if err := e.run(sessionID, data); err != nil {
				c.voiceError(err, "sessionId", sessionID, "recoverable", true)
			}
		}}
	}
	return out
}
