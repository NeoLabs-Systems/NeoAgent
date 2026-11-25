package sockets

import (
	"encoding/base64"
	"strings"
	"testing"
	"time"
)

func TestMessagingEvents(t *testing.T) {
	st := newStack(t)
	st.fake.admins[1] = true
	c := st.connect(1)

	c.emit("messaging:connect", map[string]any{"platform": "  WhatsApp ", "agentId": "other", "config": map[string]any{"a": 1}, "x": "y"})
	if got := obj(c.expect("messaging:connect_result")[0]); got["platform"] != "whatsapp" {
		t.Fatalf("%v", got)
	}
	st.fake.waitFor(t, "connect whatsapp agent=agent-other config=map[a:1]")

	c.emit("messaging:connect", map[string]any{"config": "not an object"})
	if got := obj(c.expect("messaging:error")[0])["error"]; got != "platform is required" {
		t.Fatal(got)
	}
	c.emit("messaging:disconnect", map[string]any{})
	if got := obj(c.expect("messaging:error")[0])["error"]; got != "platform is required" {
		t.Fatal(got)
	}
	c.emit("messaging:disconnect", map[string]any{"platform": "telegram"})
	c.expect("messaging:disconnect_result")

	for _, tc := range []struct {
		payload map[string]any
		want    string
	}{
		{map[string]any{"to": "x", "content": "y"}, "platform is required"},
		{map[string]any{"platform": "telegram", "content": "y"}, "recipient is required"},
		{map[string]any{"platform": "telegram", "to": "x"}, "content must be 1-12000 characters"},
		{map[string]any{"platform": "telegram", "to": "x", "content": 5}, "content must be 1-12000 characters"},
		{map[string]any{"platform": "telegram", "to": "x", "content": strings.Repeat("a", 12001)}, "content must be 1-12000 characters"},
	} {
		c.emit("messaging:send", tc.payload)
		if got := obj(c.expect("messaging:error")[0])["error"]; got != tc.want {
			t.Errorf("%v: got %q want %q", tc.payload, got, tc.want)
		}
	}
	c.emit("messaging:send", map[string]any{"platform": "Telegram", "to": " 42 ", "content": strings.Repeat("a", 12000), "mediaPath": " /m.png ", "agentId": "other"})
	if got := obj(c.expect("messaging:sent")[0]); got["to"] != "42" {
		t.Fatalf("%v", got)
	}
	st.fake.waitFor(t, "send telegram to=42 content=aaaa")
	if !st.fake.has("send telegram to=42") || !strings.Contains(strings.Join(st.fake.seen(), "\n"), "media=/m.png") {
		t.Fatal(st.fake.seen())
	}

	c.emit("messaging:send", map[string]any{"platform": "broken", "to": "x", "content": "y"})
	if got := obj(c.expect("messaging:error")[0])["error"]; got != "boom" { // admin sees the text
		t.Fatal(got)
	}

	c.emit("messaging:status")
	if got := obj(c.expect("messaging:status")[0]); got["agent"] != "agent-main" || got["whatsapp"] != "connected" {
		t.Fatalf("%v", got)
	}
}

func TestVoiceCallEvents(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)

	c.emit("voice:call_accept", map[string]any{})
	if got := obj(c.expect("voice:error")[0])["error"]; got != "callId is required" {
		t.Fatal(got)
	}
	st.fake.mu.Lock()
	st.fake.acceptResult = AcceptResult{Accepted: true}
	st.fake.mu.Unlock()
	c.emit("voice:call_accept", map[string]any{"callId": "call-1"})
	c.expectSilence(150 * time.Millisecond)
	st.fake.waitFor(t, "accept call-1")

	st.fake.mu.Lock()
	st.fake.acceptResult = AcceptResult{Status: "expired"}
	st.fake.mu.Unlock()
	c.emit("voice:call_accept", map[string]any{"callId": "call-2"})
	if got := obj(c.expect("voice:call_ended")[0]); got["callId"] != "call-2" || got["reason"] != "expired" {
		t.Fatalf("%v", got)
	}

	c.emit("voice:call_decline", map[string]any{"callId": "call-3", "later": true})
	st.fake.waitFor(t, "decline call-3 later=true")
	c.emit("voice:call_decline", map[string]any{"callId": "call-4", "later": "yes"})
	st.fake.waitFor(t, "decline call-4 later=false") // only boolean true counts
	c.emit("voice:call_decline", map[string]any{})
	c.expect("voice:error")
}

func TestVoiceCallsAreUnavailableWithoutACoordinator(t *testing.T) {
	st := newStack(t, func(o *stackOpts) {
		o.mod = func(c *Config) { c.Services.Calls, c.Services.Approvals = nil, nil }
	})
	c := st.connect(1)
	for _, ev := range []string{"voice:call_accept", "voice:call_decline"} {
		c.emit(ev, map[string]any{"callId": "x"})
		if got := obj(c.expect("voice:error")[0])["error"]; got != "Agent calls are unavailable." {
			t.Fatalf("%s: %v", ev, got)
		}
	}
}

func TestVoiceSessionEvents(t *testing.T) {
	st := newStack(t)
	st.fake.admins[1] = true // admins read the error text itself
	c := st.connect(1)

	c.emit("voice:session_open", map[string]any{"agentId": "other"})
	st.fake.waitFor(t, `voice-open user=1 agent=agent-other session="" peer=true`)
	c.emit("voice:session_open", map[string]any{"sessionId": " resume-me "})
	st.fake.waitFor(t, `voice-open user=1 agent=agent-main session="resume-me"`)

	chunk := []byte{1, 2, 3, 250, 255}
	c.emit("voice:audio", map[string]any{"sessionId": "s1", "audioBase64": base64.StdEncoding.EncodeToString(chunk)})
	st.fake.waitFor(t, "audio s1 010203faff")
	c.emit("voice:audio", map[string]any{"sessionId": "s1", "audioBase64": "AQID-_8"}) // URL-safe, unpadded
	st.fake.waitFor(t, "audio s1 010203fbff")
	c.emit("voice:audio", map[string]any{"sessionId": "s1"})
	if got := obj(c.expect("voice:error")[0]); got["error"] != "audioBase64 is required" || got["sessionId"] != "s1" || got["recoverable"] != true {
		t.Fatalf("%v", got)
	}
	c.emit("voice:audio", map[string]any{"audioBase64": "AAAA"})
	if got := obj(c.expect("voice:error")[0]); got["error"] != "sessionId is required" || got["recoverable"] != true {
		t.Fatalf("%v", got)
	}

	c.emit("voice:input_start", map[string]any{"sessionId": "s1"})
	c.emit("voice:interrupt", map[string]any{"sessionId": "s1"})
	c.emit("voice:cancel_task", map[string]any{"sessionId": "s1", "runId": " r9 "})
	st.fake.waitFor(t, "input-start s1")
	st.fake.waitFor(t, "interrupt s1")
	st.fake.waitFor(t, "cancel-task s1 run=r9")
	// the runtime's failure reaches the client as a recoverable voice:error
	c.emit("voice:input_end", map[string]any{"sessionId": "s1"})
	if got := obj(c.expect("voice:error")[0]); got["sessionId"] != "s1" || got["recoverable"] != true {
		t.Fatalf("%v", got)
	}

	c.emit("voice:session_close", map[string]any{"sessionId": "sess-new", "cancelTask": true})
	st.fake.waitFor(t, "close sess-new reason=client_closed cancel=true")
}

func TestVoiceEventsKeepTheirOrder(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	for i := 0; i < 40; i++ {
		c.emit("voice:audio", map[string]any{"sessionId": "s", "audioBase64": base64.StdEncoding.EncodeToString([]byte{byte(i)})})
	}
	c.emit("voice:input_start", map[string]any{"sessionId": "s"})
	st.fake.waitFor(t, "input-start s")
	var got []string
	for _, call := range st.fake.seen() {
		if strings.HasPrefix(call, "audio s ") {
			got = append(got, strings.TrimPrefix(call, "audio s "))
		}
	}
	if len(got) != 40 {
		t.Fatalf("%d chunks", len(got))
	}
	for i, g := range got {
		if g != strings.ToLower(string("0123456789abcdef"[i>>4])+string("0123456789abcdef"[i&15])) {
			t.Fatalf("chunk %d out of order: %v", i, got)
		}
	}
}

func TestVoiceSessionOpenFailureIsNotRecoverable(t *testing.T) {
	st := newStack(t)
	st.fake.voiceOpenErr = codedErr{"X"}
	st.fake.admins[1] = true
	c := st.connect(1)
	c.emit("voice:session_open", map[string]any{})
	if got := obj(c.expect("voice:error")[0]); got["error"] != "denied" || got["recoverable"] != false {
		t.Fatalf("%v", got)
	}
}

func TestMCPEvents(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	c.emit("mcp:status", map[string]any{"agentId": "other"})
	if got := obj(c.expect("mcp:status")[0]); got["agent"] != "agent-other" {
		t.Fatalf("%v", got)
	}
	c.emit("mcp:tools", map[string]any{"serverId": " srv-1 "})
	if got := obj(c.expect("mcp:tools")[0].([]any)[0]); got["server"] != "srv-1" {
		t.Fatalf("%v", got)
	}
	c.emit("mcp:tools", map[string]any{})
	if got := obj(c.expect("mcp:tools")[0].([]any)[0]); got["all"] != true || got["agent"] != "agent-main" {
		t.Fatalf("%v", got)
	}
}

func TestIntegrationsStatus(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	c.emit("integrations:status")
	if got := obj(c.expect("integrations:status")[0].([]any)[0]); got["id"] != "google" {
		t.Fatalf("%v", got)
	}

	st = newStack(t, func(o *stackOpts) { o.mod = func(c *Config) { c.Services.Integrations = nil } })
	st.fake.admins[1] = true
	c = st.connect(1)
	c.emit("integrations:status", map[string]any{})
	if got := obj(c.expect("error")[0])["message"]; got != "Official integration manager is not available." {
		t.Fatal(got)
	}
}

func TestMemoryEvents(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	c.emit("memory:read", map[string]any{"agentId": "other"})
	got := obj(c.expect("memory:data")[0])
	logs := got["dailyLogs"].([]any)
	if got["agentId"] != "agent-other" || got["memory"] != "memory text" || obj(logs[0])["days"] != float64(3) ||
		got["assistantBehaviorNotes"].([]any)[0] != "note for agent-other" {
		t.Fatalf("%v", got)
	}

	c.emit("memory:search", map[string]any{"query": "  tea  "})
	if got := obj(c.expect("memory:search_results")[0]); got["query"] != "tea" {
		t.Fatalf("%v", got)
	}
	for _, q := range []any{"", "   ", nil, 5, strings.Repeat("q", 2001)} {
		c.emit("memory:search", map[string]any{"query": q})
		if got := obj(c.expect("error")[0])["message"]; got != "query must be 1-2000 characters" {
			t.Fatalf("%v: %v", q, got)
		}
	}
	c.emit("memory:search", map[string]any{"query": strings.Repeat("q", 2000)})
	c.expect("memory:search_results")
}

func TestPayloadsThatAreNotObjectsAreTreatedAsEmpty(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	c.emit("memory:read", "garbage")
	c.expect("memory:data")
	c.emit("agent:history", []any{1, 2})
	c.expect("agent:history")
	c.emit("messaging:status", 42)
	c.expect("messaging:status")
}
