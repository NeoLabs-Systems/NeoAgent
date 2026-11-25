package agents

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// TestCreateForRunMatchesNode replays createAgentForRun recorded on the same
// seeded database (testdata/gen_vectors.js).
func TestCreateForRunMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/node_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var cases []struct {
		Run struct {
			UserID              int64  `json:"userId"`
			AgentID             string `json:"agentId"`
			RunID               string `json:"runId"`
			AlreadyCreatedInRun bool   `json:"alreadyCreatedInRun"`
		}
		Args   map[string]any
		Result map[string]any
		Row    map[string]any
	}
	if err := json.Unmarshal(raw, &cases); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	seed := []string{
		"INSERT INTO users (id, username, password) VALUES (1, 'u', 'x'), (2, 'v', 'x')",
		`INSERT INTO agents (id, user_id, slug, display_name, is_default, tool_restrictions_json) VALUES ('a1', 1, 'main', 'Main', 1, '{"network_write":"require_approval","bogus":"deny"}')`,
		"INSERT INTO agent_delegations (id, user_id, parent_agent_id, target_agent_id, task, status, child_run_id) VALUES ('d1', 1, 'a1', 'a1', 't', 'running', 'run-task')",
	}
	for i := 0; i < 12; i++ {
		seed = append(seed, "INSERT INTO agents (id, user_id, slug, display_name) VALUES ('b"+itoa(i)+"', 2, 's"+itoa(i)+"', 'S"+itoa(i)+"')")
	}
	for _, q := range seed {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	c := &Creator{DB: db}
	for i, tc := range cases {
		got, err := c.CreateForRun(ctx, Run{UserID: tc.Run.UserID, AgentID: tc.Run.AgentID, RunID: tc.Run.RunID, AlreadyCreated: tc.Run.AlreadyCreatedInRun}, tc.Args)
		var refusal *Refusal
		var result map[string]any
		switch {
		case errors.As(err, &refusal):
			result = map[string]any{"error": refusal.Msg}
		case err != nil:
			result = map[string]any{"thrown": err.Error()}
		default:
			result = map[string]any{"id": true, "slug": got.Slug, "displayName": got.DisplayName}
		}
		if a, b := js(result), js(tc.Result); a != b {
			t.Errorf("#%d: %s, want %s", i, a, b)
		}
		if tc.Row == nil {
			continue
		}
		var row struct {
			slug, name, desc, resp, instr, status, targets, restrictions, createdBy, reason string
			isDefault, canDelegate, canBe                                                   int
		}
		var createdBy, reason sql.NullString
		if err := db.R.QueryRow(`SELECT slug, display_name, description, responsibilities, instructions, status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json, tool_restrictions_json, created_by_agent_id, creation_reason FROM agents WHERE id = ?`, got.ID).
			Scan(&row.slug, &row.name, &row.desc, &row.resp, &row.instr, &row.status, &row.isDefault, &row.canDelegate, &row.canBe, &row.targets, &row.restrictions, &createdBy, &reason); err != nil {
			t.Fatal(err)
		}
		gotRow := map[string]any{
			"slug": row.slug, "display_name": row.name, "description": row.desc, "responsibilities": row.resp, "instructions": row.instr,
			"status": row.status, "is_default": row.isDefault, "can_delegate": row.canDelegate, "can_be_delegated_to": row.canBe,
			"delegate_targets_json": row.targets, "tool_restrictions_json": row.restrictions, "created_by_agent_id": createdBy.String, "creation_reason": reason.String,
		}
		if a, b := js(gotRow), js(tc.Row); a != b {
			t.Errorf("#%d row: %s, want %s", i, a, b)
		}
	}
}

func itoa(i int) string { b, _ := json.Marshal(i); return string(b) }

func js(v any) string {
	raw, _ := json.Marshal(v)
	var back any
	_ = json.Unmarshal(raw, &back)
	out, _ := json.Marshal(back)
	return string(out)
}
