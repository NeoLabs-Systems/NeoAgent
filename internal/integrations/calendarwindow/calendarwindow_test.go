package calendarwindow

import (
	"bytes"
	"encoding/json"
	"os"
	"testing"
)

type testEvent struct {
	ID     string  `json:"id"`
	AllDay bool    `json:"allDay"`
	Start  *string `json:"start"`
	End    *string `json:"end"`
}

func (e testEvent) IsAllDay() bool { return e.AllDay }
func (e testEvent) StartText() string {
	if e.Start == nil {
		return ""
	}
	return *e.Start
}
func (e testEvent) EndText() string {
	if e.End == nil {
		return ""
	}
	return *e.End
}

type vector struct {
	Name    string      `json:"name"`
	Events  []testEvent `json:"events"`
	Options struct {
		TimeMin string `json:"timeMin"`
		TimeMax string `json:"timeMax"`
		Args    struct {
			IncludeOngoing bool `json:"include_ongoing"`
			IncludeAllDay  bool `json:"include_all_day"`
		} `json:"args"`
		ExecutionOptions struct {
			TriggerSource string `json:"triggerSource"`
			TaskID        any    `json:"taskId"`
			ScheduledAt   string `json:"scheduledAt"`
		} `json:"executionOptions"`
	} `json:"options"`
	Result json.RawMessage `json:"result"`
}

// TestMatchesNode compares the answers byte for byte, member order included.
func TestMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []vector
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	for _, v := range vectors {
		t.Run(v.Name, func(t *testing.T) {
			o := v.Options
			got := Finalize(v.Events, Options{
				TimeMin: o.TimeMin, TimeMax: o.TimeMax,
				IncludeOngoing: o.Args.IncludeOngoing, IncludeAllDay: o.Args.IncludeAllDay,
				AutomaticReminder: (o.ExecutionOptions.TriggerSource == "schedule" || o.ExecutionOptions.TriggerSource == "tasks") &&
					o.ExecutionOptions.TaskID != nil && !o.Args.IncludeOngoing,
				ScheduledAt: o.ExecutionOptions.ScheduledAt,
			})
			var buf bytes.Buffer
			enc := json.NewEncoder(&buf)
			enc.SetEscapeHTML(false)
			if err := enc.Encode(got); err != nil {
				t.Fatal(err)
			}
			var want bytes.Buffer
			if err := json.Compact(&want, v.Result); err != nil {
				t.Fatal(err)
			}
			if gotText := bytes.TrimSpace(buf.Bytes()); !bytes.Equal(gotText, want.Bytes()) {
				t.Fatalf("\n go: %s\nnode: %s", gotText, want.Bytes())
			}
		})
	}
}
