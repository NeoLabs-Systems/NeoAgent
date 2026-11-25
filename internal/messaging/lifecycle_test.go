package messaging

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
)

type eventLog struct{ events []string }

func (e *eventLog) EmitToUser(_ int64, event string, _ any) { e.events = append(e.events, event) }

// TestConnectionRowsFollowNode checks the platform_connections row through a
// connect, a user's disconnect, a restore and a logout, as the Node manager
// kept it, and the events the app listens for.
func TestConnectionRowsFollowNode(t *testing.T) {
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'neo', 'x')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO agents (id, user_id, slug, display_name) VALUES ('a1', 1, 'main', 'Main')`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "x")
	if err != nil {
		t.Fatal(err)
	}
	events := &eventLog{}
	connects := 0
	newManager := func() *Manager {
		return NewManager(ManagerConfig{DB: db, Box: box, Agents: oneAgent{}, Emitter: events, DataDir: dir,
			Factories: map[string]Factory{"telegram": func(_ Config, ev Events) (Platform, error) {
				connects++
				return &offlinePlatform{status: StatusDisconnected, ev: ev}, nil
			}}})
	}
	row := func() (status, last string, config map[string]any) {
		var s, l, c *string
		if err := db.R.QueryRow(`SELECT status, last_connected, config FROM platform_connections WHERE user_id = 1 AND agent_id = 'a1' AND platform = 'telegram'`).Scan(&s, &l, &c); err != nil {
			return "", "", nil
		}
		if l != nil {
			last = *l
		}
		m := &Manager{cfg: ManagerConfig{Box: box}}
		return *s, last, m.decodeConfig(*c)
	}

	m := newManager()
	res, err := m.ConnectPlatform(ctx, 1, "a1", "telegram", map[string]any{"token": "t"}, true)
	if err != nil || res["status"] != StatusConnected {
		t.Fatalf("connect: %v %v", res, err)
	}
	status, last, config := row()
	if status != StatusConnected || last == "" || config["token"] != "t" || config["autoConnect"] != true {
		t.Fatalf("after connect: %s %q %v", status, last, config)
	}
	all := m.AllStatuses(ctx, 1, "a1")
	if v, ok := all.Get("telegram"); !ok || v == nil {
		t.Fatalf("statuses: %v", all)
	}
	if _, err := m.DisconnectPlatform(ctx, 1, "a1", "telegram"); err != nil {
		t.Fatal(err)
	}
	if status, _, config := row(); status != StatusDisconnected || config["autoConnect"] != false {
		t.Fatalf("after disconnect: %s %v", status, config)
	}
	m.Stop()

	// A user's disconnect survives a restart.
	connects = 0
	m = newManager()
	if err := m.Start(ctx); err != nil {
		t.Fatal(err)
	}
	if connects != 0 {
		t.Fatalf("restore reconnected a disconnected platform")
	}
	if _, err := m.ConnectPlatform(ctx, 1, "a1", "telegram", map[string]any{"token": "t"}, true); err != nil {
		t.Fatal(err)
	}
	m.Stop()
	connects = 0
	m = newManager()
	if err := m.Start(ctx); err != nil {
		t.Fatal(err)
	}
	if connects != 1 {
		t.Fatalf("restore connects = %d, want 1", connects)
	}
	if _, err := m.LogoutPlatform(ctx, 1, "a1", "telegram"); err != nil {
		t.Fatal(err)
	}
	if status, _, _ := row(); status != "" {
		t.Fatalf("logout must delete the row, status %q", status)
	}
	if got := m.GetPlatformStatus(ctx, 1, "a1", "telegram")["status"]; got != "not_configured" {
		t.Fatalf("status after logout = %v", got)
	}
	m.Stop()
	want := map[string]bool{"messaging:connected": true}
	for _, e := range events.events {
		if e == "messaging:status" {
			t.Fatalf("messaging:status is not an event the app knows: %v", events.events)
		}
		delete(want, e)
	}
	if len(want) > 0 {
		t.Fatalf("missing events %v in %v", want, events.events)
	}
}
