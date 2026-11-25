package phone

import (
	"context"
	"encoding/json"
	"reflect"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

type vectors struct {
	Now      int64           `json:"now"`
	Device   json.RawMessage `json:"device"`
	SyncBody json.RawMessage `json:"syncBody"`
	Steps    []struct {
		replaytest.Step
		Tool        string         `json:"tool"`
		Args        map[string]any `json:"args"`
		App         string         `json:"app"`
		Op          string         `json:"op"`
		PhoneAnswer map[string]any `json:"phoneAnswer"`
	} `json:"steps"`
}

func object(t *testing.T, raw []byte) *jsv.Object {
	t.Helper()
	v, err := jsv.Decode(raw)
	if err != nil {
		t.Fatal(err)
	}
	return v.(*jsv.Object)
}

// TestMatchesNode replays the Node provider's recorded calls over a phone that
// shared the same calendars, contacts and alarm.
func TestMatchesNode(t *testing.T) {
	var v vectors
	replaytest.Load(t, &v)
	now := time.UnixMilli(v.Now).UTC()
	var mu sync.Mutex
	var wakes []any
	var store *mobilesync.Phone
	var p integrations.Provider
	st := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		store = &mobilesync.Phone{DB: svc.DB, Box: svc.Box}
		p = New(svc, Options{Store: store, Now: func() time.Time { return now }, Wake: func(userID int64, deviceID string) {
			mu.Lock()
			wakes = append(wakes, map[string]any{"room": "user:1", "event": "device_sync:wake", "payload": map[string]any{"deviceId": deviceID}})
			mu.Unlock()
		}})
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	ctx := context.Background()
	agent, err := st.Svc.ResolveAgent(ctx, 1, "")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Register(ctx, 1, agent, object(t, v.Device), []any{"calendar", "contacts", "alarms"}); err != nil {
		t.Fatal(err)
	}
	body := object(t, v.SyncBody)
	if _, err := store.Sync(ctx, 1, agent, body); err != nil {
		t.Fatal(err)
	}
	// The store reads the wall clock; pin what Node recorded at its fixed time.
	syncedAt := jsv.ISO(now)
	if _, err := st.DB.W.Exec(`UPDATE integration_connections SET metadata_json = json_set(metadata_json, '$.syncedAt', ?) WHERE provider_key = 'phone'`, syncedAt); err != nil {
		t.Fatal(err)
	}
	// The alarm lies in the past of the wall clock, so the store skips it.
	sealedAlarm := mustSeal(t, st, `{"time":"2026-01-02T06:30:00.000Z"}`)
	if _, err := st.DB.W.Exec(`INSERT OR IGNORE INTO device_sync_items (user_id, agent_id, device_id, kind, item_key, starts_at, payload_json) VALUES (1, ?, 'device-1234', 'alarm', '2026-01-02T06:30:00.000Z', '2026-01-02T06:30:00.000Z', ?)`, agent, sealedAlarm); err != nil {
		t.Fatal(err)
	}
	rows, err := st.Svc.ListConnections(ctx, 1, "phone", agent)
	if err != nil {
		t.Fatal(err)
	}
	byApp := map[string]integrations.Connection{}
	for _, r := range rows {
		byApp[r.AppKey] = r
	}
	var commands []any
	for _, step := range v.Steps {
		var got any
		var err error
		switch {
		case step.Tool != "":
			if step.PhoneAnswer != nil {
				answer := step.PhoneAnswer
				go func() {
					time.Sleep(100 * time.Millisecond)
					synced, err := store.Sync(ctx, 1, agent, jsv.NewObject().Set("deviceId", "device-1234"))
					if err != nil {
						t.Error(err)
						return
					}
					list, _ := synced.Val("commands").([]any)
					mu.Lock()
					commands = append(commands, list)
					mu.Unlock()
					last := list[len(list)-1].(*jsv.Object)
					result := jsv.NewObject().Set("id", last.Val("id"))
					for k, v := range answer {
						result.Set(k, toJSV(v))
					}
					if _, err := store.Sync(ctx, 1, agent, jsv.NewObject().Set("deviceId", "device-1234").Set("results", []any{result})); err != nil {
						t.Error(err)
					}
				}()
			}
			var ex *integrations.Execution
			ex, err = p.ExecuteTool(ctx, step.Tool, step.Args, byApp[step.App])
			if ex != nil {
				got = ex.Result
			}
		case step.Name == "commands the phone received":
			mu.Lock()
			got = commands
			mu.Unlock()
		case step.Name == "wakes":
			mu.Lock()
			got = wakes
			mu.Unlock()
		case step.Op == "test":
			_, err = p.(integrations.Tester).TestConnection(ctx, byApp[step.App])
			got = map[string]any{}
		}
		replaytest.Check(t, step.Step, got, err)
	}
}

func toJSV(v any) any {
	if m, ok := v.(map[string]any); ok {
		o := jsv.NewObject()
		for k, val := range m {
			o.Set(k, toJSV(val))
		}
		return o
	}
	return v
}

func mustSeal(t *testing.T, st *integrationstest.Stack, plain string) string {
	t.Helper()
	s, err := st.Box.Seal(plain)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

// TestQueuedWhenThePhoneIsOffline: a change the phone does not pick up in
// time is reported as pending.
func TestQueuedWhenThePhoneIsOffline(t *testing.T) {
	var p integrations.Provider
	var store *mobilesync.Phone
	st := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		store = &mobilesync.Phone{DB: svc.DB, Box: svc.Box}
		p = New(svc, Options{Store: store, CommandWait: 10 * time.Millisecond})
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	ctx := context.Background()
	agent, _ := st.Svc.ResolveAgent(ctx, 1, "")
	device := jsv.NewObject().Set("id", "device-5678").Set("platform", "ios").Set("name", "iPhone")
	if _, err := store.Register(ctx, 1, agent, device, []any{"contacts"}); err != nil {
		t.Fatal(err)
	}
	rows, _ := st.Svc.ListConnections(ctx, 1, "phone", agent)
	ex, err := p.ExecuteTool(ctx, "phone_create_contact", map[string]any{"name": "Zed"}, rows[0])
	if err != nil {
		t.Fatal(err)
	}
	got := replaytest.Normalize(t, ex.Result)
	want := map[string]any{"status": "queued", "device": "iPhone", "syncedAt": nil,
		"note": "The phone has not picked this up yet. It will make the change the next time it syncs; tell the user it is pending, not done."}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v", got)
	}
	raw, _ := json.Marshal(ex.Result)
	if string(raw) != `{"status":"queued","device":"iPhone","syncedAt":null,"note":"The phone has not picked this up yet. It will make the change the next time it syncs; tell the user it is pending, not done."}` {
		t.Fatalf("member order: %s", raw)
	}
}
