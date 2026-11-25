package tasks

import (
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// TestScheduleMatchesNode replays gen/vectors.js: cron parsing, the next-run
// search across zones and DST changes, lead times and one-time datetimes.
func TestScheduleMatchesNode(t *testing.T) {
	saved := time.Local
	time.Local = time.UTC // the zone the vectors were recorded in
	t.Cleanup(func() { time.Local = saved })

	raw, err := os.ReadFile("testdata/schedule_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []struct {
		Fn     string          `json:"fn"`
		Input  json.RawMessage `json:"input"`
		Output json.RawMessage `json:"output"`
	}
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	type result struct {
		Value any    `json:"value,omitempty"`
		Error string `json:"error,omitempty"`
	}
	failures := 0
	for i, v := range vectors {
		var got any
		switch v.Fn {
		case "findNextRun":
			var in struct {
				Expression string  `json:"expression"`
				From       string  `json:"from"`
				Zone       *string `json:"zone"`
			}
			_ = json.Unmarshal(v.Input, &in)
			from, _ := time.Parse(time.RFC3339Nano, in.From)
			var loc *time.Location
			if in.Zone != nil {
				loc = loadZone(*in.Zone)
			}
			next, ok, err := findNextRun(in.Expression, from, loc)
			switch {
			case err != nil:
				got = map[string]any{"error": err.Error()}
			case !ok:
				got = map[string]any{"value": nil}
			default:
				got = map[string]any{"value": jsv.ISO(next)}
			}
		case "normalizeCronExpression":
			in, _ := jsv.Decode(v.Input)
			expr, err := normalizeCronExpression(in)
			if err != nil {
				got = result{Error: err.Error()}
			} else {
				got = result{Value: expr}
			}
		case "normalizeRunAt":
			var in struct {
				Value json.RawMessage `json:"value"`
				Zone  *string         `json:"zone"`
			}
			_ = json.Unmarshal(v.Input, &in)
			value, _ := jsv.Decode(in.Value)
			var loc *time.Location
			if in.Zone != nil {
				loc = loadZone(*in.Zone)
			}
			at, ok, err := normalizeRunAt(value, loc)
			switch {
			case err != nil:
				got = result{Error: err.Error()}
			case !ok:
				got = map[string]any{"value": nil}
			default:
				got = result{Value: at}
			}
		case "resolveLeadTimeMs":
			in, _ := jsv.Decode(v.Input)
			got = float64(leadTime(jsv.Number(in)).Milliseconds())
		default:
			t.Fatalf("unknown vector %s", v.Fn)
		}
		g, _ := json.Marshal(got)
		var want, have any
		_ = json.Unmarshal(v.Output, &want)
		_ = json.Unmarshal(g, &have)
		wb, _ := json.Marshal(want)
		hb, _ := json.Marshal(have)
		if string(wb) != string(hb) {
			failures++
			if failures <= 8 {
				t.Errorf("#%d %s(%s)\n got  %s\n want %s", i, v.Fn, v.Input, hb, wb)
			}
		}
	}
	if failures > 0 {
		t.Logf("%d of %d vectors differ", failures, len(vectors))
	}
}
