package handlers

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

type nodeVectors struct {
	Proactive []struct {
		Purpose any             `json:"purpose"`
		Message string          `json:"message"`
		Result  json.RawMessage `json:"result"`
	} `json:"proactive"`
	Addresses []struct {
		Platform, Value, Result string
	} `json:"addresses"`
	Origin []struct {
		Input  map[string]any `json:"input"`
		Result bool           `json:"result"`
	} `json:"origin"`
	Targets []struct {
		Input  map[string]any  `json:"input"`
		Result json.RawMessage `json:"result"`
	} `json:"targets"`
	Triggers []struct {
		Args     dyn.Map         `json:"args"`
		Fallback *string         `json:"fallback"`
		Result   json.RawMessage `json:"result"`
	} `json:"triggers"`
	ReadArgs []struct {
		Args   dyn.Map         `json:"args"`
		Result json.RawMessage `json:"result"`
	} `json:"readArgs"`
	Bounded []struct {
		Input     dyn.Map         `json:"input"`
		HasRange  bool            `json:"hasRange"`
		CharLimit int             `json:"charLimit"`
		Result    json.RawMessage `json:"result"`
	} `json:"bounded"`
	Provenance []struct {
		Source  any             `json:"source"`
		Content string          `json:"content"`
		Tainted bool            `json:"tainted"`
		Owner   []string        `json:"owner"`
		Result  json.RawMessage `json:"result"`
	} `json:"provenance"`
}

func loadVectors(t *testing.T) nodeVectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/node_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v nodeVectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func same(t *testing.T, label string, got any, want json.RawMessage) {
	t.Helper()
	g, err := normalize(got)
	if err != nil {
		t.Fatal(err)
	}
	var w any
	if err := json.Unmarshal(want, &w); err != nil {
		t.Fatal(err)
	}
	if dyn.Stringify(g) != dyn.Stringify(w) {
		t.Errorf("%s:\n got: %.800s\nwant: %.800s", label, dyn.Stringify(g), dyn.Stringify(w))
	}
}

func s(m map[string]any, k string) string { v, _ := m[k].(string); return v }

func TestMessagingLogicMatchesNode(t *testing.T) {
	v := loadVectors(t)
	for i, c := range v.Proactive {
		r := validateProactiveSend(c.Purpose, c.Message)
		got := dyn.Map{"ok": r.ok}
		if r.ok {
			got["purpose"] = r.purpose
		}
		if r.err != "" {
			got["error"] = r.err
		}
		if r.reason != "" {
			got["reason"] = r.reason
		}
		if r.skipped {
			got["skipped"], got["suppressed"] = true, true
		}
		same(t, "proactive #"+itoa(i), got, c.Result)
	}
	for _, c := range v.Addresses {
		if got := canonicalAddress(c.Platform, c.Value); got != c.Result {
			t.Errorf("canonicalAddress(%q, %q) = %q, want %q", c.Platform, c.Value, got, c.Result)
		}
	}
	for i, c := range v.Origin {
		in := c.Input
		if got := isOriginDelivery(s(in, "triggerSource"), s(in, "source"), s(in, "chatId"), s(in, "platform"), s(in, "to")); got != c.Result {
			t.Errorf("origin #%d = %v, want %v", i, got, c.Result)
		}
	}
	for i, c := range v.Targets {
		in := c.Input
		r := resolveSendTarget(s(in, "triggerSource"), s(in, "source"), s(in, "chatId"), s(in, "platform"), s(in, "to"), in["isGroup"] == true, s(in, "senderId"))
		same(t, "target #"+itoa(i), dyn.Map{"platform": r.platform, "to": r.to, "redirectedFromDirect": r.redirected}, c.Result)
	}
}

func TestTriggerArgsMatchNode(t *testing.T) {
	for i, c := range loadVectors(t).Triggers {
		fallback := ""
		if c.Fallback != nil {
			fallback = *c.Fallback
		}
		r := resolveTriggerArgs(c.Args, fallback)
		got := dyn.Map{"triggerType": nilIfEmpty(r.triggerType), "hasType": r.hasType, "hasConfig": r.hasConfig, "configDefined": r.configDefined}
		if r.configDefined {
			got["triggerConfig"] = r.config
		}
		same(t, "trigger #"+itoa(i), got, c.Result)
	}
}

func TestFileReadLogicMatchesNode(t *testing.T) {
	v := loadVectors(t)
	for i, c := range v.ReadArgs {
		same(t, "readArgs #"+itoa(i), normalizeReadFileArgs(c.Args), c.Result)
	}
	for i, c := range v.Bounded {
		same(t, "bounded #"+itoa(i), boundedRead(c.Input, c.HasRange, c.CharLimit), c.Result)
	}
}

func TestSaveProvenanceMatchesNode(t *testing.T) {
	for i, c := range loadVectors(t).Provenance {
		p := saveProvenance(c.Source, c.Content, &Run{Tainted: c.Tainted, OwnerStatements: c.Owner})
		got := dyn.Map{"metadata": p.Metadata}
		if p.Confidence != 0 {
			got["confidence"] = p.Confidence
		}
		if p.StaleAfterDays != nil {
			got["staleAfterDays"] = *p.StaleAfterDays
		}
		same(t, "provenance #"+itoa(i), got, c.Result)
	}
}

func itoa(i int) string { return dyn.Number(float64(i)) }
