package wearable

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
	"github.com/NeoLabs-Systems/neolabs-go/wsclient"
)

const testUser = 7

// stubVoice behaves like the stub runtime gen/gateway.js gives the Node
// gateway, and records the calls the gateway makes on it.
type stubVoice struct {
	mu    sync.Mutex
	calls [][]any
	sinks map[string]livevoice.Sink
}

func (v *stubVoice) record(kind string, args map[string]any) {
	v.mu.Lock()
	v.calls = append(v.calls, []any{kind, args})
	v.mu.Unlock()
}

func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func (v *stubVoice) OpenWearableCall(_ context.Context, userID int64, agentID, sessionID, devicePlatform string, sink livevoice.Sink) (string, error) {
	v.record("open", map[string]any{"userId": userID, "agentId": nilIfEmpty(agentID), "sessionId": nilIfEmpty(sessionID), "devicePlatform": devicePlatform})
	if sessionID == "boom" {
		return "", errors.New("Gemini Live closed before setup completed (go_away).")
	}
	id := sessionID
	if id == "" {
		id = "session-1"
	}
	v.mu.Lock()
	if v.sinks == nil {
		v.sinks = map[string]livevoice.Sink{}
	}
	v.sinks[id] = sink
	v.mu.Unlock()
	sink.Send("session_ready", map[string]any{"sessionId": id, "provider": "google", "inputSampleRate": 16000, "outputSampleRate": 24000})
	sink.Send("audio", map[string]any{"sessionId": id, "audioBase64": "AQID"})
	sink.Send("transcript", map[string]any{"sessionId": id, "role": "assistant", "content": "Hi", "final": true})
	return id, nil
}

func (v *stubVoice) AppendAudio(sessionID string, pcm []byte, userID int64) error {
	bytes := make([]any, len(pcm))
	for i, b := range pcm {
		bytes[i] = float64(b)
	}
	v.record("audio", map[string]any{"sessionId": sessionID, "bytes": bytes, "userId": userID})
	if sessionID == "nope" {
		return errors.New("Voice session was not found.")
	}
	return nil
}
func (v *stubVoice) StartInput(id string, userID int64) error {
	v.record("start", map[string]any{"sessionId": id, "userId": userID})
	return nil
}
func (v *stubVoice) EndInput(id string, userID int64) error {
	v.record("end", map[string]any{"sessionId": id, "userId": userID})
	return nil
}
func (v *stubVoice) InterruptOutput(id string, userID int64) error {
	v.record("interrupt", map[string]any{"sessionId": id, "userId": userID})
	return nil
}
func (v *stubVoice) CloseSession(id, reason string, userID int64, _ bool) error {
	v.record("close", map[string]any{"sessionId": id, "reason": reason, "userId": userID})
	return nil
}

type gatewayScenario struct {
	Name      string `json:"name"`
	Anonymous bool   `json:"anonymous"`
	Steps     []struct {
		JSON any     `json:"json"`
		Text *string `json:"text"`
		Emit *struct {
			SessionID string         `json:"sessionId"`
			Kind      string         `json:"kind"`
			Payload   map[string]any `json:"payload"`
		} `json:"emit"`
		ListConnections bool `json:"listConnections"`
	} `json:"steps"`
	WaitForClose      int              `json:"waitForClose"`
	Rejected          *int             `json:"rejected"`
	Received          []map[string]any `json:"received"`
	Calls             [][]any          `json:"calls"`
	Changes           []map[string]any `json:"changes"`
	ConnectionsDuring []map[string]any `json:"connectionsDuring"`
	FinalConnections  int              `json:"finalConnections"`
	CloseInfo         *struct {
		Code   int    `json:"code"`
		Reason string `json:"reason"`
	} `json:"closeInfo"`
}

func normalizeJSON(t *testing.T, v any) any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

// gateway.json holds what the Node gateway did for the same conversations
// (gen/gateway.js): what the device was sent, the calls made on the voice
// runtime, the connection registry and the connect/disconnect events.
func TestGatewayMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/gateway.json")
	if err != nil {
		t.Fatal(err)
	}
	var scenarios []gatewayScenario
	if err := json.Unmarshal(raw, &scenarios); err != nil {
		t.Fatal(err)
	}
	for _, sc := range scenarios {
		t.Run(sc.Name, func(t *testing.T) { replayGateway(t, sc) })
	}
}

func replayGateway(t *testing.T, sc gatewayScenario) {
	voice := &stubVoice{}
	service := NewService(ServiceConfig{Voice: voice, Version: func() VersionInfo { return VersionInfo{} }})
	var changeMu sync.Mutex
	var changes []map[string]any
	service.OnConnectionChanged(func(c ConnectionChange) {
		changeMu.Lock()
		defer changeMu.Unlock()
		var label any
		if c.DeviceLabel != "" {
			label = c.DeviceLabel
		}
		changes = append(changes, map[string]any{"userId": float64(c.UserID), "deviceId": c.DeviceID, "deviceLabel": label, "transition": c.Transition, "occurredAt": "T"})
	})
	gw := NewGateway(GatewayConfig{
		Service: service, Voice: voice, HelloTimeout: 400 * time.Millisecond,
		UserID: func(*http.Request) (int64, bool) { return testUser, !sc.Anonymous },
	})
	mux := http.NewServeMux()
	gw.Routes(mux)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := wsclient.Dial(ctx, srv.URL+WSPath, wsclient.Options{Header: http.Header{"User-Agent": {"esp32-test/1.0"}}})
	if sc.Anonymous {
		if err == nil || sc.Rejected == nil || !strings.Contains(err.Error(), "(401)") {
			t.Fatalf("anonymous upgrade: err=%v, Node rejected with %v", err, sc.Rejected)
		}
		return
	}
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()

	var received []any
	var recvMu sync.Mutex
	var closeErr error
	done := make(chan struct{})
	go func() {
		defer close(done)
		for {
			_, data, err := conn.Read(ctx)
			if err != nil {
				closeErr = err
				return
			}
			var m any
			_ = json.Unmarshal(data, &m)
			if obj, ok := m.(map[string]any); ok && obj["serverTime"] != nil {
				obj["serverTime"] = "T"
			}
			recvMu.Lock()
			received = append(received, m)
			recvMu.Unlock()
		}
	}()

	var during []any
	for _, step := range sc.Steps {
		switch {
		case step.Text != nil:
			_ = conn.WriteText(ctx, []byte(*step.Text))
		case step.JSON != nil:
			_ = conn.WriteJSON(ctx, step.JSON)
		}
		if step.Emit != nil {
			voice.mu.Lock()
			sink := voice.sinks[step.Emit.SessionID]
			voice.mu.Unlock()
			sink.Send(step.Emit.Kind, step.Emit.Payload)
		}
		time.Sleep(60 * time.Millisecond)
		if step.ListConnections {
			for _, c := range service.Connections(testUser) {
				during = append(during, normalizeJSON(t, connectionJSON(c)))
			}
		}
	}
	if sc.WaitForClose > 0 {
		<-done
	} else {
		_ = conn.Close(wsclient.CloseNormal, "")
		select {
		case <-done:
		case <-time.After(2 * time.Second):
		}
		time.Sleep(150 * time.Millisecond)
	}

	recvMu.Lock()
	gotReceived := received
	recvMu.Unlock()
	want := make([]any, len(sc.Received))
	for i, m := range sc.Received {
		want[i] = m
	}
	if len(gotReceived) == 0 && len(want) == 0 {
		gotReceived = want
	}
	if !reflect.DeepEqual(normalizeJSON(t, gotReceived), normalizeJSON(t, want)) {
		t.Errorf("device messages differ\n go:   %s\n node: %s", mustJSON(gotReceived), mustJSON(want))
	}
	voice.mu.Lock()
	gotCalls := normalizeJSON(t, voice.calls)
	voice.mu.Unlock()
	wantCalls := normalizeJSON(t, orEmptyCalls(sc.Calls))
	if gotCalls == nil {
		gotCalls = []any{}
	}
	if !reflect.DeepEqual(gotCalls, wantCalls) {
		t.Errorf("voice runtime calls differ\n go:   %s\n node: %s", mustJSON(gotCalls), mustJSON(wantCalls))
	}
	changeMu.Lock()
	gotChanges := normalizeJSON(t, changes)
	changeMu.Unlock()
	if gotChanges == nil {
		gotChanges = []any{}
	}
	if !reflect.DeepEqual(gotChanges, normalizeJSON(t, orEmptyMaps(sc.Changes))) {
		t.Errorf("connection events differ\n go:   %s\n node: %s", mustJSON(gotChanges), mustJSON(sc.Changes))
	}
	if sc.ConnectionsDuring != nil {
		wantDuring := make([]any, len(sc.ConnectionsDuring))
		for i, c := range sc.ConnectionsDuring {
			wantDuring[i] = c
		}
		// connectedAt and lastSeenAt are times; Node's run replaced them.
		for _, c := range during {
			c.(map[string]any)["connectedAt"], c.(map[string]any)["lastSeenAt"] = "T", "T"
		}
		if !reflect.DeepEqual(during[len(during)-1:], wantDuring[len(wantDuring)-1:]) {
			t.Errorf("connection list differs\n go:   %s\n node: %s", mustJSON(during), mustJSON(wantDuring))
		}
	}
	if left := len(service.Connections(testUser)); left != sc.FinalConnections {
		t.Errorf("%d connections left, Node %d", left, sc.FinalConnections)
	}
	if sc.CloseInfo != nil && sc.CloseInfo.Code != 1000 {
		if wsclient.CloseStatus(closeErr) != sc.CloseInfo.Code || wsclient.CloseReason(closeErr) != sc.CloseInfo.Reason {
			t.Errorf("closed with %d %q, Node %d %q", wsclient.CloseStatus(closeErr), wsclient.CloseReason(closeErr), sc.CloseInfo.Code, sc.CloseInfo.Reason)
		}
	}
}

func orEmptyCalls(c [][]any) [][]any {
	if c == nil {
		return [][]any{}
	}
	return c
}

func orEmptyMaps(c []map[string]any) []map[string]any {
	if c == nil {
		return []map[string]any{}
	}
	return c
}

func mustJSON(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}
