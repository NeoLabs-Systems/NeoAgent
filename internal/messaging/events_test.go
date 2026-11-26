package messaging

import (
	"context"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
)

// TestPlatformEventsReachTriggersAndAccessScreen checks what a connection's
// events leave behind: trigger events, the recorded reaction and the access
// screen's two target lists.
func TestPlatformEventsReachTriggersAndAccessScreen(t *testing.T) {
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
	for _, q := range []string{
		`INSERT INTO users (id, username, password) VALUES (1, 'neo', 'x')`,
		`INSERT INTO agents (id, user_id, slug, display_name) VALUES ('a1', 1, 'main', 'Main')`,
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	box, err := secretbox.New("enc:v1:", "x")
	if err != nil {
		t.Fatal(err)
	}
	var published []string
	var events Events
	m := NewManager(ManagerConfig{DB: db, Box: box, Agents: oneAgent{}, Emitter: &eventLog{}, DataDir: dir,
		OnEvent: func(name string, event map[string]any) {
			if event["userId"] != int64(1) || event["agentId"] != "a1" || event["platform"] != "telegram" {
				t.Errorf("%s published without its connection: %v", name, event)
			}
			published = append(published, name)
		},
		Factories: map[string]Factory{"telegram": func(_ Config, ev Events) (Platform, error) {
			events = ev
			return &offlinePlatform{status: StatusDisconnected, ev: ev}, nil
		}}})
	defer m.Stop()
	if _, err := m.ConnectPlatform(ctx, 1, "a1", "telegram", map[string]any{"token": "t"}, true); err != nil {
		t.Fatal(err)
	}

	events.Membership(Membership{Kind: "member_joined", SpaceID: "g1", MemberID: "7"})
	events.Membership(Membership{Kind: "member_left", SpaceID: "g1", MemberID: "7"})
	events.Reaction(Reaction{ChatID: "42", Sender: "42", TargetMessageID: "9", Emoji: "+1"})
	events.BlockedSender(BlockedSender{Suggestions: []Suggestion{{Label: "Mia", Bucket: "directRules", Rule: SuggestionRule{Scope: "user", Value: "7"}}}})
	catalog, err := m.GetAccessCatalog(ctx, 1, "a1", "telegram")
	if err != nil {
		t.Fatal(err)
	}
	if got := catalog["suggestedTargets"].([]Suggestion); len(got) != 1 || got[0].Rule.Value != "7" {
		t.Errorf("suggestedTargets = %v", got)
	}
	// The reaction is a recent chat of this connection.
	if got := catalog["discoveredTargets"].([]AccessTarget); len(got) != 1 || got[0].Value != "42" {
		t.Errorf("discoveredTargets = %v", got)
	}
	events.LoggedOut()

	want := []string{"member_joined", "member_left", "reaction_added", "platform_disconnected"}
	if !reflect.DeepEqual(published, want) {
		t.Errorf("published %v, want %v", published, want)
	}
}
