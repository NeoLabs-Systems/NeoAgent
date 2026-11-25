package tools

import (
	"encoding/json"
	"os"
	"reflect"
	"slices"
	"testing"
)

type testEnv struct {
	host    bool
	sharing bool
}

func (e testEnv) HostTerminal() bool                  { return e.host }
func (e testEnv) WebSharingEnabled(userID int64) bool { return e.sharing }

func newRegistry(t *testing.T) *Registry {
	t.Helper()
	r, err := NewRegistry(testEnv{})
	if err != nil {
		t.Fatal(err)
	}
	return r
}

type vectors struct {
	Compact []struct {
		Name                string         `json:"name"`
		WithDescriptions    map[string]any `json:"withDescriptions"`
		WithoutDescriptions map[string]any `json:"withoutDescriptions"`
	} `json:"compact"`
	CompactDynamic []struct {
		Def                 Definition     `json:"def"`
		WithDescriptions    map[string]any `json:"withDescriptions"`
		WithoutDescriptions map[string]any `json:"withoutDescriptions"`
	} `json:"compactDynamic"`
	CompactEmpty any `json:"compactEmpty"`
	Shell        []struct {
		Command string `json:"command"`
		Fetches bool   `json:"fetches"`
		Result  bool   `json:"result"`
	} `json:"shell"`
	Coerce []struct {
		Args    map[string]any `json:"args"`
		Coerced map[string]any `json:"coerced"`
		Missing []string       `json:"missing"`
	} `json:"coerce"`
	CoerceSchema map[string]any `json:"coerceSchema"`
	Meta         []struct {
		Name     string      `json:"name"`
		Def      *Definition `json:"def"`
		Meta     Meta        `json:"meta"`
		StepType string      `json:"stepType"`
		Budget   string      `json:"budget"`
		Calls    []struct {
			Args     map[string]any `json:"args"`
			Access   *string        `json:"access"`
			ReadOnly bool           `json:"readOnly"`
			Parallel bool           `json:"parallel"`
			Changes  bool           `json:"changes"`
		} `json:"calls"`
	} `json:"meta"`
	Selection   map[string][]string `json:"selection"`
	StaticNames []string            `json:"staticNames"`
	Refusals    []struct {
		Catalog []Definition `json:"catalog"`
		Options struct {
			Disallowed []string `json:"disallowedToolNames"`
			Allowed    []string `json:"allowedToolNames"`
			ReadOnly   bool     `json:"readOnly"`
		} `json:"options"`
		Name    string         `json:"name"`
		Args    map[string]any `json:"args"`
		Refusal *string        `json:"refusal"`
	} `json:"refusals"`
}

func loadVectors(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

// jsonValue round-trips through JSON so both sides hold plain decoded values.
func jsonValue(t *testing.T, v any) any {
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

func compactMap(t *testing.T, c CompactTool, withDescription bool) map[string]any {
	m := map[string]any{"name": c.Name, "parameters": c.Parameters}
	if withDescription {
		m["description"] = c.Description
	}
	if c.Access != "" {
		m["access"] = c.Access
	}
	if c.Family != "" {
		m["family"] = c.Family
	}
	if c.Integration != nil {
		m["integration"] = c.Integration
	}
	return jsonValue(t, m).(map[string]any)
}

func TestCompactMatchesNode(t *testing.T) {
	v := loadVectors(t)
	r := newRegistry(t)
	if len(v.Compact) != len(r.Definitions()) {
		t.Fatalf("%d definitions, Node has %d", len(r.Definitions()), len(v.Compact))
	}
	for i, def := range r.Definitions() {
		want := v.Compact[i]
		if def.Name != want.Name {
			t.Fatalf("definition %d is %s, Node has %s", i, def.Name, want.Name)
		}
		with, _ := Compact(def, true)
		without, _ := Compact(def, false)
		if got := compactMap(t, with, true); !reflect.DeepEqual(got, want.WithDescriptions) {
			t.Errorf("%s: compact with descriptions differs:\n%v\nwant\n%v", def.Name, got, want.WithDescriptions)
		}
		if got := compactMap(t, without, false); !reflect.DeepEqual(got, want.WithoutDescriptions) {
			t.Errorf("%s: compact without descriptions differs", def.Name)
		}
	}
	for _, want := range v.CompactDynamic {
		with, _ := Compact(want.Def, true)
		without, _ := Compact(want.Def, false)
		if got := compactMap(t, with, true); !reflect.DeepEqual(got, want.WithDescriptions) {
			t.Errorf("%s: dynamic compact with descriptions differs:\n%v\nwant\n%v", want.Def.Name, got, want.WithDescriptions)
		}
		if got := compactMap(t, without, false); !reflect.DeepEqual(got, want.WithoutDescriptions) {
			t.Errorf("%s: dynamic compact without descriptions differs", want.Def.Name)
		}
	}
	if _, ok := Compact(Definition{Name: "  "}, false); ok || v.CompactEmpty != nil {
		t.Error("a nameless definition must not compact")
	}
}

func TestShellClassificationMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Shell {
		if got := IsClearlyReadOnlyShellCommand(c.Command, c.Fetches); got != c.Result {
			t.Errorf("%q (fetches=%v) = %v, Node says %v", c.Command, c.Fetches, got, c.Result)
		}
	}
}

func TestCoerceMatchesNode(t *testing.T) {
	v := loadVectors(t)
	for i, c := range v.Coerce {
		got := CoerceArgs(c.Args, v.CoerceSchema)
		if !reflect.DeepEqual(jsonValue(t, got), jsonValue(t, c.Coerced)) {
			t.Errorf("case %d: coerced %v, Node %v", i, got, c.Coerced)
		}
		if missing := MissingRequiredArgs(got, v.CoerceSchema); !slices.Equal(missing, c.Missing) {
			t.Errorf("case %d: missing %v, Node %v", i, missing, c.Missing)
		}
	}
}

func normalize(m Meta) Meta {
	if m.Capabilities == nil {
		m.Capabilities = []string{}
	}
	if m.Prerequisites == nil {
		m.Prerequisites = []string{}
	}
	if m.WhenToUse == nil {
		m.WhenToUse = []string{}
	}
	if m.WhenNotToUse == nil {
		m.WhenNotToUse = []string{}
	}
	if m.FileArgs == nil {
		m.FileArgs = []string{}
	}
	if m.Policy == nil {
		m.Policy = map[string]any{}
	}
	return m
}

func TestMetadataMatchesNode(t *testing.T) {
	v := loadVectors(t)
	r := newRegistry(t)
	if got := r.StaticNames(); !slices.Equal(got, v.StaticNames) {
		t.Errorf("static names differ:\n%v\n%v", got, v.StaticNames)
	}
	for selection, want := range v.Selection {
		if got := r.NamesWithSelection(selection); !slices.Equal(got, want) {
			t.Errorf("selection %s: %v, want %v", selection, got, want)
		}
	}
	for _, want := range v.Meta {
		meta := r.Meta(want.Name, want.Def)
		if !reflect.DeepEqual(normalize(meta), normalize(want.Meta)) {
			t.Errorf("%s: meta differs:\n%+v\nwant\n%+v", want.Name, meta, want.Meta)
		}
		if got := r.StepType(want.Name, want.Def); got != want.StepType {
			t.Errorf("%s: step type %s, want %s", want.Name, got, want.StepType)
		}
		if got := ResultBudget(meta); got != want.Budget {
			t.Errorf("%s: budget %s, want %s", want.Name, got, want.Budget)
		}
		for _, call := range want.Calls {
			wantAccess := ""
			if call.Access != nil {
				wantAccess = *call.Access
			}
			if got := CallAccess(meta, call.Args); got != wantAccess {
				t.Errorf("%s %v: access %q, want %q", want.Name, call.Args, got, wantAccess)
			}
			if IsReadOnlyCall(meta, call.Args) != call.ReadOnly || IsParallelSafeCall(meta, call.Args) != call.Parallel || ChangesState(meta, call.Args) != call.Changes {
				t.Errorf("%s %v: readOnly/parallel/changes differ from Node", want.Name, call.Args)
			}
		}
	}
}

func TestRunToolRefusalMatchesNode(t *testing.T) {
	v := loadVectors(t)
	r := newRegistry(t)
	for _, c := range v.Refusals {
		options := RunOptions{DisallowedToolNames: c.Options.Disallowed, AllowedToolNames: c.Options.Allowed, ReadOnly: c.Options.ReadOnly}
		want := ""
		if c.Refusal != nil {
			want = *c.Refusal
		}
		if got := r.RunToolRefusal(c.Catalog, options, c.Name, c.Args); got != want {
			t.Errorf("%s %+v: %q, want %q", c.Name, c.Options, got, want)
		}
	}
}

func TestAvailabilityRules(t *testing.T) {
	user := int64(7)
	count := func(r *Registry, o Options) map[string]bool {
		names := map[string]bool{}
		for _, d := range r.Available(o) {
			names[d.Name] = true
		}
		return names
	}
	r := newRegistry(t)
	// Every definition that carries a rule must be one the rules know.
	known := []string{"background_task", "send_interim_update", "react_to_message", "code_navigate", "query_structured_data", "share_web_page"}
	for _, d := range r.Definitions() {
		if d.AvailableWhen && !slices.Contains(known, d.Name) {
			t.Errorf("%s has an availability rule that Go does not implement", d.Name)
		}
	}
	guest := count(r, Options{UserID: &user, TriggerType: "user", TriggerSource: "web"})
	if !guest["background_task"] || !guest["send_interim_update"] || guest["react_to_message"] || guest["code_navigate"] || guest["share_web_page"] {
		t.Errorf("web run on a guest computer: %v", guest)
	}
	sub := count(r, Options{TriggerType: "subagent", TriggerSource: "web"})
	if sub["send_interim_update"] || sub["background_task"] {
		t.Errorf("a subagent must not send updates or manage background tasks: %v", sub)
	}
	chat := count(r, Options{TriggerType: "user", TriggerSource: "messaging"})
	if !chat["react_to_message"] {
		t.Error("messaging runs may react")
	}
	host, _ := NewRegistry(testEnv{host: true, sharing: true})
	if got := count(host, Options{UserID: &user}); !got["code_navigate"] || !got["query_structured_data"] || got["share_web_page"] {
		t.Errorf("host terminal: %v", got)
	}
	shared, _ := NewRegistry(testEnv{sharing: true})
	if !count(shared, Options{UserID: &user})["share_web_page"] || count(shared, Options{})["share_web_page"] {
		t.Error("sharing needs an owner who allows it")
	}
}
