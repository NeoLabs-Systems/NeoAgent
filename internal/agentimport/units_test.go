package agentimport

import (
	"encoding/json"
	"reflect"
	"testing"
)

type unitVectors struct {
	Units struct {
		Facts []struct {
			Input string
			Out   []string
		}
		JSON5 []struct {
			Input string
			Out   struct {
				Value json.RawMessage
				Error bool
			}
		}
		Entries []struct {
			Input string
			Out   []struct{ Text, Heading string }
		}
		Intervals []struct {
			Ms  float64
			Out struct {
				Cron  string
				Exact bool
			}
		}
		Crons []struct {
			Expr string
			Out  *struct {
				Cron  string
				Exact bool
			}
		}
	}
}

func loadUnits(t *testing.T) unitVectors {
	t.Helper()
	var v unitVectors
	raw := mustRead(t, "testdata/scan.json")
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestShortFactsMatchNode(t *testing.T) {
	for _, c := range loadUnits(t).Units.Facts {
		got := toShortFacts(c.Input)
		if len(got) == 0 && len(c.Out) == 0 {
			continue
		}
		if !reflect.DeepEqual(got, c.Out) {
			t.Errorf("toShortFacts(%q)\n got  %q\n want %q", c.Input, got, c.Out)
		}
	}
}

func TestMemoryEntriesMatchNode(t *testing.T) {
	for _, c := range loadUnits(t).Units.Entries {
		var got []struct{ Text, Heading string }
		for _, e := range splitMemoryEntries(c.Input) {
			got = append(got, struct{ Text, Heading string }(e))
		}
		if len(got) == 0 && len(c.Out) == 0 {
			continue
		}
		if !reflect.DeepEqual(got, c.Out) {
			t.Errorf("splitMemoryEntries(%q)\n got  %v\n want %v", c.Input, got, c.Out)
		}
	}
}

func TestJSON5MatchesNode(t *testing.T) {
	for _, c := range loadUnits(t).Units.JSON5 {
		v, err := parseJSON5(c.Input)
		if c.Out.Error {
			if err == nil {
				t.Errorf("parseJSON5(%q) should fail", c.Input)
			}
			continue
		}
		if err != nil {
			t.Errorf("parseJSON5(%q): %v", c.Input, err)
			continue
		}
		raw, _ := json.Marshal(jsonValue(v))
		var g, w any
		json.Unmarshal(raw, &g)
		if err := json.Unmarshal(c.Out.Value, &w); err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(g, w) {
			t.Errorf("parseJSON5(%q) = %s want %s", c.Input, raw, c.Out.Value)
		}
	}
	// JavaScript orders integer keys first.
	v, _ := parseJSON5(`{"2":1,"1":2,b:3,a:4}`)
	if got := asObj(v).Keys(); !reflect.DeepEqual(got, []string{"1", "2", "b", "a"}) {
		t.Errorf("key order %v", got)
	}
}

func TestSchedulesMatchNode(t *testing.T) {
	u := loadUnits(t).Units
	for _, c := range u.Intervals {
		if got := intervalToCron(c.Ms); got.Expr != c.Out.Cron || got.Exact != c.Out.Exact {
			t.Errorf("intervalToCron(%v) = %v want %v", c.Ms, got, c.Out)
		}
	}
	for _, c := range u.Crons {
		got, ok := toFiveFieldCron(c.Expr)
		switch {
		case c.Out == nil && ok:
			t.Errorf("toFiveFieldCron(%q) should fail", c.Expr)
		case c.Out != nil && (!ok || got.Expr != c.Out.Cron || got.Exact != c.Out.Exact):
			t.Errorf("toFiveFieldCron(%q) = %v want %v", c.Expr, got, c.Out)
		}
	}
}
