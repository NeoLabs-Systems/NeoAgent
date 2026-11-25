package models

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
)

type vectors struct {
	Catalog  []Model `json:"catalog"`
	Identity struct {
		Create []string `json:"create"`
		Parse  []struct {
			V   any            `json:"v"`
			Out map[string]any `json:"out"`
		} `json:"parse"`
		Resolve []struct {
			V   string  `json:"v"`
			P   *string `json:"p"`
			Out *string `json:"out"`
		} `json:"resolve"`
		Normalize []string `json:"normalize"`
		Matches   []struct {
			ID  string   `json:"id"`
			Set []string `json:"set"`
			Out bool     `json:"out"`
		} `json:"matches"`
		Selectable Model `json:"selectable"`
	} `json:"identity"`
	Dispositions []struct {
		Error    *errorShape `json:"error"`
		Provider string      `json:"provider"`
		Out      *struct {
			Scope        string `json:"scope"`
			FailureClass string `json:"failureClass"`
			CooldownMs   int64  `json:"cooldownMs"`
			Status       *int   `json:"status"`
		} `json:"out"`
	} `json:"dispositions"`
	ErrorHelpers []struct {
		Error       *errorShape `json:"error"`
		Permanent   bool        `json:"permanent"`
		Recoverable bool        `json:"recoverable"`
		Switch      bool        `json:"switch"`
	} `json:"errorHelpers"`
	Routing []struct {
		Name     string `json:"name"`
		Scenario struct {
			Models   []Model        `json:"models"`
			Settings map[string]any `json:"settings"`
			Request  struct {
				IsSubagent    bool   `json:"isSubagent"`
				ModelOverride string `json:"modelOverride"`
				SelectionHint struct {
					Complexity         string `json:"complexity"`
					RequiredConfidence string `json:"requiredConfidence"`
					CostMode           string `json:"costMode"`
				} `json:"selectionHint"`
			} `json:"request"`
			Ops []struct {
				Failure *struct {
					SelectionID string      `json:"selectionId"`
					Error       *errorShape `json:"error"`
				} `json:"failure"`
				Success string `json:"success"`
			} `json:"ops"`
		} `json:"scenario"`
		Route *struct {
			ID     string  `json:"id"`
			Reason *string `json:"reason"`
		} `json:"route"`
		Error *struct {
			Message string `json:"message"`
			Code    string `json:"code"`
		} `json:"error"`
		Fallback      *string  `json:"fallback"`
		FallbackPlain *string  `json:"fallbackPlain"`
		Ranked        []string `json:"ranked"`
	} `json:"routing"`
	NeoRouterTask []struct {
		Kind *string `json:"kind"`
		Out  *string `json:"out"`
	} `json:"neoRouterTask"`
	Health struct {
		Main, Agent, Other snapshotShape
		Blocked            []bool   `json:"blocked"`
		Cooling            []bool   `json:"cooling"`
		Describe           []string `json:"describe"`
		Rows               []struct {
			UserID           int64  `json:"user_id"`
			AgentID          string `json:"agent_id"`
			ProviderID       string `json:"provider_id"`
			ModelSelectionID string `json:"model_selection_id"`
			FailureScope     string `json:"failure_scope"`
			FailureClass     string `json:"failure_class"`
			FailureCount     int    `json:"failure_count"`
			LastStatus       int    `json:"last_status"`
		} `json:"rows"`
		CountAfterRepeat int `json:"countAfterRepeat"`
		AfterSuccess     int `json:"afterSuccess"`
	} `json:"health"`
	TaskModels struct {
		Normalize []struct {
			Raw any               `json:"raw"`
			Out map[string]string `json:"out"`
		} `json:"normalize"`
		Infer []struct {
			Names []string `json:"names"`
			Out   *string  `json:"out"`
		} `json:"infer"`
		Kinds []string `json:"kinds"`
	} `json:"taskModels"`
	Usage []struct {
		Value map[string]any `json:"value"`
		Out   *Usage         `json:"out"`
	} `json:"usage"`
	UsageMerge []struct {
		A, B *map[string]any
		Out  Usage `json:"out"`
	} `json:"usageMerge"`
	Grants []struct {
		Raw *string  `json:"raw"`
		Out []string `json:"out"`
	} `json:"grants"`
	Access []struct {
		Disabled []string `json:"disabled"`
		Granted  []string `json:"granted"`
		Out      []struct {
			Blocked      bool `json:"blocked"`
			AdminGranted bool `json:"adminGranted"`
		} `json:"out"`
	} `json:"access"`
	Visibility struct {
		Steps []any             `json:"steps"`
		Env   map[string]string `json:"env"`
	} `json:"visibility"`
}

type snapshotShape struct {
	Models    []string `json:"models"`
	Providers []string `json:"providers"`
	Paid      []string `json:"paid"`
}

type errorShape struct {
	Status  int            `json:"status"`
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Headers map[string]any `json:"headers"`
}

func (e *errorShape) toError() error {
	if e == nil {
		return nil
	}
	out := &llm.Error{Status: e.Status, Code: e.Code, Message: e.Message}
	if out.Message == "" {
		out.Message = "failure"
	}
	if v, ok := e.Headers["retry-after"]; ok {
		var seconds int
		fmt.Sscan(fmt.Sprint(v), &seconds)
		out.RetryAfter = time.Duration(seconds) * time.Second
	}
	if v, ok := e.Headers["retry-after-ms"]; ok {
		var ms int
		fmt.Sscan(fmt.Sprint(v), &ms)
		out.RetryAfter = time.Duration(ms) * time.Millisecond
	}
	if e.Status == 0 && e.Code == "ECONNRESET" {
		out.Retryable = true
	}
	return out
}

func load(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/models.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

// The catalog vectors use a null availability for "available" models of the
// catalog; JSON decoding has already given every entry its flag.

type aggregators struct{}

func (aggregators) IsAggregator(id string) bool { return id == "openrouter" || id == "nous" }

func openDB(t *testing.T) *dbx.DB {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'a', 'x'), (2, 'b', 'x')`); err != nil {
		t.Fatal(err)
	}
	return db
}

func newFailures(db *dbx.DB) *Failures {
	return &Failures{Store: &HealthStore{DB: db}, Providers: aggregators{}, Cooldowns: DefaultCooldowns()}
}

func settingsFrom(raw map[string]any) Settings {
	s := Settings{}
	s.DefaultChatModel, _ = raw["default_chat_model"].(string)
	s.DefaultSubagentModel, _ = raw["default_subagent_model"].(string)
	s.CostMode, _ = raw["cost_mode"].(string)
	if list, ok := raw["enabled_models"].([]any); ok {
		for _, id := range list {
			s.EnabledModels = append(s.EnabledModels, fmt.Sprint(id))
		}
	}
	return s
}

func TestIdentityMatchesNode(t *testing.T) {
	v := load(t)
	if got := []string{CreateSelectionID("OpenAI ", " gpt-5 "), CreateSelectionID("x", "y")}; !slices.Equal(got, v.Identity.Create) {
		t.Errorf("create: %v", got)
	}
	for _, c := range v.Identity.Parse {
		s, ok := ParseSelectionID(fmt.Sprint(orEmpty(c.V)))
		if ok != (c.Out != nil) || ok && (s.Provider != c.Out["provider"] || s.ModelID != c.Out["modelId"]) {
			t.Errorf("parse %v: %v %v, want %v", c.V, s, ok, c.Out)
		}
	}
	for _, c := range v.Identity.Resolve {
		preferred := ""
		if c.P != nil {
			preferred = *c.P
		}
		got := ResolveSelection(v.Catalog, c.V, preferred)
		if (got == nil) != (c.Out == nil) || got != nil && got.ID != *c.Out {
			t.Errorf("resolve %q/%q: %v, want %v", c.V, preferred, got, c.Out)
		}
	}
	if got := NormalizeSelections(v.Catalog, []string{"gpt-5", "openai::gpt-5", "claude-x", "zzz", "nous::gpt-5", "claude-x"}); !slices.Equal(got, v.Identity.Normalize) {
		t.Errorf("normalize: %v, want %v", got, v.Identity.Normalize)
	}
	for _, c := range v.Identity.Matches {
		var set map[string]bool
		if c.Set != nil {
			set = map[string]bool{}
			for _, id := range c.Set {
				set[id] = true
			}
		}
		var model Model
		for _, m := range v.Catalog {
			if m.ID == c.ID {
				model = m
			}
		}
		if MatchesConfiguredID(model, set) != c.Out {
			t.Errorf("matches %s %v", c.ID, c.Set)
		}
	}
	if got := ToSelectable(Model{ID: " X ", Provider: "OpenAI"}); got.ID != v.Identity.Selectable.ID || got.ModelID != v.Identity.Selectable.ModelID || got.Provider != v.Identity.Selectable.Provider {
		t.Errorf("selectable: %+v want %+v", got, v.Identity.Selectable)
	}
}

func orEmpty(v any) any {
	if v == nil {
		return ""
	}
	return v
}

func TestDispositionsMatchNode(t *testing.T) {
	v := load(t)
	f := &Failures{Providers: aggregators{}, Cooldowns: DefaultCooldowns()}
	for _, c := range v.Dispositions {
		var err error
		if c.Error != nil {
			err = c.Error.toError()
		}
		got := f.Disposition(err, c.Provider)
		if c.Out == nil {
			if got != nil {
				t.Errorf("%+v/%s: %+v, want none", c.Error, c.Provider, got)
			}
			continue
		}
		wantStatus := 0
		if c.Out.Status != nil {
			wantStatus = *c.Out.Status
		}
		if got == nil || got.Scope != c.Out.Scope || got.FailureClass != c.Out.FailureClass || got.Cooldown.Milliseconds() != c.Out.CooldownMs || got.Status != wantStatus {
			t.Errorf("%+v/%s: %+v, want %+v", c.Error, c.Provider, got, c.Out)
		}
	}
	for _, c := range v.ErrorHelpers {
		var err error
		if c.Error != nil {
			err = c.Error.toError()
		}
		if f.IsPermanentModelFailure(err) != c.Permanent || f.IsRecoverableModelFailure(err) != c.Recoverable || f.ShouldSwitchModel(err) != c.Switch {
			t.Errorf("helpers for %+v differ", c.Error)
		}
	}
	if f.Disposition(context.Canceled, "") != nil || f.Disposition(errors.New("x"), "") != nil {
		t.Error("aborts and plain errors say nothing about health")
	}
}

func TestRoutingMatchesNode(t *testing.T) {
	v := load(t)
	ctx := context.Background()
	for _, c := range v.Routing {
		db := openDB(t)
		failures := newFailures(db)
		sc := c.Scenario
		for _, op := range sc.Ops {
			if op.Failure != nil {
				failures.RecordFailure(ctx, 1, "", op.Failure.SelectionID, op.Failure.Error.toError())
			}
			if op.Success != "" {
				failures.RecordSuccess(ctx, 1, "", op.Success)
			}
		}
		settings := settingsFrom(sc.Settings)
		health := failures.Snapshot(ctx, 1, "")
		hint := Hint{Complexity: sc.Request.SelectionHint.Complexity, RequiredConfidence: sc.Request.SelectionHint.RequiredConfidence, CostMode: sc.Request.SelectionHint.CostMode}
		route, err := SelectInitialModel(InitialRequest{Models: sc.Models, Settings: settings, Health: health, IsSubagent: sc.Request.IsSubagent, ModelOverride: sc.Request.ModelOverride, Hint: hint})
		switch {
		case c.Error != nil:
			var unavailable *Unavailable
			if !errors.As(err, &unavailable) || unavailable.Message != c.Error.Message || unavailable.Code() != c.Error.Code {
				t.Errorf("%s: error %v, want %+v", c.Name, err, c.Error)
			}
		case err != nil:
			t.Errorf("%s: unexpected error %v", c.Name, err)
		default:
			wantReason := ""
			if c.Route.Reason != nil {
				wantReason = *c.Route.Reason
			}
			if route.Model.ID != c.Route.ID || route.Reason != wantReason {
				t.Errorf("%s: %s (%s), want %s (%s)", c.Name, route.Model.ID, route.Reason, c.Route.ID, wantReason)
			}
		}
		fallbackID := func(m *Model) *string {
			if m == nil {
				return nil
			}
			return &m.ID
		}
		fb := SelectFallbackModel(FallbackRequest{Models: sc.Models, Settings: settings, Health: health, CurrentModelID: "openai::gpt-5", ExcludedModelIDs: []string{"anthropic::claude-x"}, ExcludedProviderIDs: []string{"Google"}})
		if !reflect.DeepEqual(fallbackID(fb), c.Fallback) {
			t.Errorf("%s: fallback %v, want %v", c.Name, fallbackID(fb), c.Fallback)
		}
		fp := SelectFallbackModel(FallbackRequest{Models: sc.Models, Settings: settings, Health: health, CurrentModelID: "openrouter::cheap/one"})
		if !reflect.DeepEqual(fallbackID(fp), c.FallbackPlain) {
			t.Errorf("%s: plain fallback %v, want %v", c.Name, fallbackID(fp), c.FallbackPlain)
		}
		ranked := RankModels(sc.Models, sc.Request.IsSubagent, hint, settings)
		var ids []string
		for _, m := range ranked {
			ids = append(ids, m.ID)
		}
		if !slices.Equal(ids, c.Ranked) {
			t.Errorf("%s: ranked %v, want %v", c.Name, ids, c.Ranked)
		}
	}
	for _, c := range v.NeoRouterTask {
		kind := ""
		if c.Kind != nil {
			kind = *c.Kind
		}
		want := ""
		if c.Out != nil {
			want = *c.Out
		}
		if got := NeoRouterTaskSelection(kind); got != want {
			t.Errorf("neorouter task %q: %q, want %q", kind, got, want)
		}
	}
}

func TestHealthPersistsAcrossRestartMatchesNode(t *testing.T) {
	v := load(t)
	ctx := context.Background()
	db := openDB(t)
	first := newFailures(db)
	first.RecordFailure(ctx, 1, "", "openai::gpt-5", &llm.Error{Status: 401, Message: "x"})
	first.RecordFailure(ctx, 1, "agent-7", "openrouter::vendor/model", &llm.Error{Status: 402, Message: "x"})
	first.RecordFailure(ctx, 1, "", "google::gemini-y", &llm.Error{Status: 404, Message: "x"})
	first.RecordFailure(ctx, 2, "", "google::gemini-y", &llm.Error{Status: 404, Message: "x"})
	// A restart: the in-memory cache is gone, the store remains.
	failures := newFailures(db)
	shape := func(agent string) snapshotShape {
		s := failures.Snapshot(ctx, 1, agent)
		keys := func(m map[string]bool) []string {
			out := []string{}
			for k := range m {
				out = append(out, k)
			}
			slices.Sort(out)
			return out
		}
		return snapshotShape{Models: keys(s.ModelIDs), Providers: keys(s.ProviderIDs), Paid: keys(s.PaidProviderIDs)}
	}
	norm := func(s snapshotShape) snapshotShape {
		if s.Models == nil {
			s.Models = []string{}
		}
		if s.Providers == nil {
			s.Providers = []string{}
		}
		if s.Paid == nil {
			s.Paid = []string{}
		}
		return s
	}
	for name, got := range map[string]snapshotShape{"main": shape(""), "agent": shape("agent-7"), "other": shape("nobody")} {
		want := map[string]snapshotShape{"main": v.Health.Main, "agent": v.Health.Agent, "other": v.Health.Other}[name]
		if !reflect.DeepEqual(norm(got), norm(want)) {
			t.Errorf("snapshot %s: %+v, want %+v", name, got, want)
		}
	}
	agentSnap := failures.Snapshot(ctx, 1, "agent-7")
	for i, m := range v.Catalog {
		if got := agentSnap.IsBlocked(m); got != v.Health.Blocked[i] {
			t.Errorf("blocked %s: %v, want %v", m.ID, got, v.Health.Blocked[i])
		}
	}
	for i, id := range []string{"google::gemini-y", "openai::gpt-5", "nous::x", ""} {
		if got := failures.IsCoolingDown(ctx, 1, "", id); got != v.Health.Cooling[i] {
			t.Errorf("cooling %q: %v, want %v", id, got, v.Health.Cooling[i])
		}
	}
	var described []string
	for _, line := range failures.DescribeCooldowns(ctx, 1, "", "openai::gpt-5") {
		described = append(described, line[:strings.Index(line, "until ")]+"until X")
	}
	if !slices.Equal(described, v.Health.Describe) {
		t.Errorf("describe: %v, want %v", described, v.Health.Describe)
	}
	rows, err := db.R.Query(`SELECT user_id, agent_id, provider_id, model_selection_id, failure_scope, failure_class, failure_count, last_status FROM ai_model_health ORDER BY user_id, agent_id, model_selection_id`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	i := 0
	for rows.Next() {
		var got struct {
			User                                 int64
			Agent, Provider, Model, Scope, Class string
			Count, Status                        int
		}
		rows.Scan(&got.User, &got.Agent, &got.Provider, &got.Model, &got.Scope, &got.Class, &got.Count, &got.Status)
		want := v.Health.Rows[i]
		if got.User != want.UserID || got.Agent != want.AgentID || got.Provider != want.ProviderID || got.Model != want.ModelSelectionID || got.Scope != want.FailureScope || got.Class != want.FailureClass || got.Count != want.FailureCount || got.Status != want.LastStatus {
			t.Errorf("row %d: %+v, want %+v", i, got, want)
		}
		i++
	}
	if i != len(v.Health.Rows) {
		t.Errorf("%d rows, Node has %d", i, len(v.Health.Rows))
	}
	failures.RecordFailure(ctx, 1, "", "openai::gpt-5", &llm.Error{Status: 401, Message: "x"})
	var count int
	db.R.QueryRow(`SELECT failure_count FROM ai_model_health WHERE user_id = 1 AND agent_id = 'main' AND provider_id = 'openai'`).Scan(&count)
	if count != v.Health.CountAfterRepeat {
		t.Errorf("failure count %d, want %d", count, v.Health.CountAfterRepeat)
	}
	failures.RecordSuccess(ctx, 1, "", "openai::other")
	db.R.QueryRow(`SELECT COUNT(*) FROM ai_model_health WHERE user_id = 1 AND agent_id = 'main' AND provider_id = 'openai'`).Scan(&count)
	if count != v.Health.AfterSuccess {
		t.Errorf("rows after success %d, want %d", count, v.Health.AfterSuccess)
	}
}

func TestCooldownExpiresWithTheClock(t *testing.T) {
	ctx := context.Background()
	now := time.Now()
	f := &Failures{Providers: aggregators{}, Cooldowns: DefaultCooldowns(), Now: func() time.Time { return now }}
	f.RecordFailure(ctx, 1, "", "openai::gpt-5", &llm.Error{Status: 429, Message: "slow down"})
	if !f.Snapshot(ctx, 1, "").ProviderIDs["openai"] {
		t.Fatal("a rate-limited provider should cool down")
	}
	now = now.Add(2 * time.Minute)
	if f.Snapshot(ctx, 1, "").ProviderIDs["openai"] {
		t.Error("the cooldown should have passed")
	}
}

func TestTaskModelsUsageGrantsMatchNode(t *testing.T) {
	v := load(t)
	for _, c := range v.TaskModels.Normalize {
		raw, _ := c.Raw.(map[string]any)
		got := NormalizeTaskModels(raw)
		if !reflect.DeepEqual(got, c.Out) && !(len(got) == 0 && len(c.Out) == 0) {
			t.Errorf("normalize %v: %v, want %v", c.Raw, got, c.Out)
		}
	}
	for _, c := range v.TaskModels.Infer {
		want := ""
		if c.Out != nil {
			want = *c.Out
		}
		if got := InferTaskKind(c.Names); got != want {
			t.Errorf("infer %v: %q, want %q", c.Names, got, want)
		}
	}
	if !slices.Equal(TaskModelKinds(), v.TaskModels.Kinds) {
		t.Errorf("kinds %v", TaskModelKinds())
	}
	for _, c := range v.Usage {
		got := NormalizeUsage(c.Value)
		if !reflect.DeepEqual(got, c.Out) {
			t.Errorf("usage %v: %+v, want %+v", c.Value, got, c.Out)
		}
	}
	for _, c := range v.UsageMerge {
		var a, b *Usage
		if c.A != nil {
			a = NormalizeUsage(*c.A)
		}
		if c.B != nil {
			b = NormalizeUsage(*c.B)
		}
		if got := Merge(a, b); got != c.Out {
			t.Errorf("merge: %+v, want %+v", got, c.Out)
		}
	}
	for _, c := range v.Grants {
		raw := ""
		if c.Raw != nil {
			raw = *c.Raw
		}
		got := ParseGrantedIDs(raw)
		if !slices.Equal(got, c.Out) {
			t.Errorf("grants %q: %v, want %v", raw, got, c.Out)
		}
	}
	for i, c := range v.Access {
		disabled := map[string]bool{}
		for _, id := range c.Disabled {
			disabled[id] = true
		}
		if len(c.Disabled) > 0 {
			disabled["openai::gpt-5"] = true
		}
		granted := map[string]bool{}
		for _, id := range c.Granted {
			granted[id] = true
		}
		for j, m := range []Model{v.Catalog[0], v.Catalog[2]} {
			if m.ID == "a" {
				m.ID = "a"
			}
			blocked, adminGranted := Access(m, disabled, granted)
			if blocked != c.Out[j].Blocked || adminGranted != c.Out[j].AdminGranted {
				t.Errorf("access case %d model %d: %v/%v, want %+v", i, j, blocked, adminGranted, c.Out[j])
			}
		}
	}
}

type memoryEnv map[string]string

func (m memoryEnv) Lookup(key string) (string, bool) { v, ok := m[key]; return v, ok }
func (m memoryEnv) Set(key, value string) error      { m[key] = value; return nil }

func TestVisibilityMatchesNode(t *testing.T) {
	v := load(t)
	env := memoryEnv{}
	vis := Visibility{Env: env}
	must := func(ids []string, err error) []string {
		if err != nil {
			t.Fatal(err)
		}
		if ids == nil {
			ids = []string{}
		}
		return ids
	}
	got := []any{
		vis.DisabledIDs(), must(vis.SetDisabledIDs([]string{" a ", "b", "a", ""})), vis.DisabledIDs(), vis.AutoEnableNew(),
		must(vis.Reconcile([]string{"m1", "m2"}, CatalogLLM)), must(vis.Reconcile([]string{"m1", "m2", "m3"}, CatalogLLM)),
		vis.SetAutoEnableNew(false), vis.AutoEnableNew(),
		must(vis.Reconcile([]string{"m1", "m4", " m5 ", "m4"}, CatalogLLM)), must(vis.Reconcile(nil, CatalogLLM)),
		must(vis.Reconcile([]string{"d1"}, CatalogDecisions)), must(vis.Reconcile([]string{"d1", "d2"}, CatalogDecisions)),
		vis.SetAutoEnableNew(true), must(vis.Reconcile([]string{"m1", "m6"}, CatalogLLM)),
	}
	// Setters return nothing in Node's list (true/true or the set value); compare the
	// list-valued steps and the stored environment.
	for i, want := range v.Visibility.Steps {
		list, isList := want.([]any)
		if !isList {
			continue
		}
		gotList, ok := got[i].([]string)
		if !ok && got[i] == nil {
			gotList = []string{}
		}
		wantList := make([]string, len(list))
		for j, id := range list {
			wantList[j] = fmt.Sprint(id)
		}
		if !slices.Equal(gotList, wantList) {
			t.Errorf("step %d: %v, want %v", i, gotList, wantList)
		}
	}
	for key, want := range v.Visibility.Env {
		if env[key] != want {
			t.Errorf("env %s = %q, want %q", key, env[key], want)
		}
	}
}
