package timeline

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type op struct {
	Kind          string          `json:"kind"`
	UserID        int64           `json:"userId"`
	AgentID       *string         `json:"agentId"`
	TaskID        int64           `json:"taskId"`
	TaskName      string          `json:"taskName"`
	EventKind     string          `json:"eventKind"`
	OccurredAt    string          `json:"occurredAt"`
	RunID         *string         `json:"runId"`
	Reason        string          `json:"reason"`
	Error         string          `json:"error"`
	TriggerType   string          `json:"triggerType"`
	TriggerSource string          `json:"triggerSource"`
	Title         string          `json:"title"`
	Status        string          `json:"status"`
	SourceKind    string          `json:"sourceKind"`
	Summary       string          `json:"summary"`
	Metadata      json.RawMessage `json:"metadata"`
}

type query struct {
	Name    string `json:"name"`
	Call    string `json:"call"`
	UserID  int64  `json:"userId"`
	Options struct {
		Limit   any      `json:"limit"`
		Sources []string `json:"sources"`
		Query   string   `json:"query"`
		AgentID string   `json:"agentId"`
	} `json:"options"`
	Out string `json:"out"`
}

func str(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func limitOf(v any) int {
	if v == nil {
		return 0
	}
	n, _ := jsv.ParseInt(v)
	return n
}

// TestMatchesNodeTimelineService runs the operations recorded from the Node
// service and requires the same stored items and the same answers.
func TestMatchesNodeTimelineService(t *testing.T) {
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v struct {
		Ops     []op     `json:"ops"`
		Stored  []string `json:"stored"`
		Queries []query  `json:"queries"`
	}
	if err := json.Unmarshal(raw, &v); err != nil {
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
	for _, q := range []string{
		`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`,
		`INSERT INTO agents (id, user_id, slug, display_name) VALUES ('agent-a', 1, 'main', 'Main'), ('agent-b', 1, 'other', 'Other')`,
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	s := &Service{DB: db}
	for i, o := range v.Ops {
		var item *Item
		occurred, _ := jsv.ParseDate(o.OccurredAt)
		switch o.Kind {
		case "task":
			item, err = s.RecordTaskLifecycle(ctx, TaskLifecycle{
				UserID: o.UserID, AgentID: str(o.AgentID), TaskID: o.TaskID, TaskName: o.TaskName, EventKind: o.EventKind,
				OccurredAt: occurred, RunID: str(o.RunID), Reason: o.Reason, Error: o.Error, TriggerType: o.TriggerType, TriggerSource: o.TriggerSource,
			})
		case "run":
			item, err = s.RecordRunLifecycle(ctx, RunLifecycle{
				UserID: o.UserID, AgentID: str(o.AgentID), RunID: str(o.RunID), Title: o.Title, EventKind: o.EventKind,
				OccurredAt: occurred, Status: o.Status, TriggerSource: o.TriggerSource, Error: o.Error,
			})
		default:
			meta, _ := jsv.Decode(o.Metadata)
			item, err = s.insert(ctx, event{
				userID: o.UserID, agentID: str(o.AgentID), sourceKind: o.SourceKind, eventKind: o.EventKind,
				occurredAt: normalizeTimestamp(o.OccurredAt, time.Now()), title: o.Title, summary: o.Summary, metadata: meta.(*jsv.Object),
			})
		}
		if err != nil {
			t.Fatal(err)
		}
		if got, _ := json.Marshal(item); string(got) != v.Stored[i] {
			t.Errorf("op %d stored\n got  %s\n want %s", i, got, v.Stored[i])
		}
	}
	for _, q := range v.Queries {
		switch q.Call {
		case "list":
			items, err := s.List(ctx, q.UserID, ListOptions{Limit: limitOf(q.Options.Limit), Sources: q.Options.Sources})
			if err != nil {
				t.Fatal(err)
			}
			if got, _ := json.Marshal(items); string(got) != q.Out {
				t.Errorf("%s\n got  %s\n want %s", q.Name, got, q.Out)
			}
		default:
			got, err := s.BuildPromptContext(ctx, q.UserID, PromptOptions{
				Limit: limitOf(q.Options.Limit), Sources: q.Options.Sources, Query: q.Options.Query, AgentID: q.Options.AgentID,
			})
			if err != nil {
				t.Fatal(err)
			}
			if got != q.Out {
				t.Errorf("%s\n got  %q\n want %q", q.Name, got, q.Out)
			}
		}
	}
}
