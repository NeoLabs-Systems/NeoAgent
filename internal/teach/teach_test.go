package teach

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
)

type vectors struct {
	Timelines []struct {
		Events   []*Event
		Timeline []map[string]any
	}
	Encrypted struct {
		Key   string
		Blob  string
		Plain map[string]any
	}
	Normalize []struct {
		Value any
		Max   int
		Out   string
	}
	Evaluations []struct {
		Value any
		Out   any
	}
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

func asJSON(t *testing.T, v any) any {
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

func TestTimelineMatchesNode(t *testing.T) {
	for i, c := range loadVectors(t).Timelines {
		got := asJSON(t, BuildTimeline(c.Events))
		want := asJSON(t, c.Timeline)
		if gl, wl := got.([]any), want.([]any); len(gl) != len(wl) {
			t.Fatalf("case %d: %d entries, want %d", i, len(gl), len(wl))
		}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("case %d differs", i)
		}
	}
}

func TestTimelineKeyOrder(t *testing.T) {
	raw, _ := json.Marshal(BuildTimeline([]*Event{{Sequence: 1, Type: "key", Key: "a"}}))
	want := `[{"sequence":1,"type":"key","atMs":0,"key":"a","modifiers":{},"context":{"activeWindow":null,"accessibility":[],"shellEvents":[],"files":[],"browser":null}}]`
	if string(raw) != want {
		t.Fatalf("%s", raw)
	}
}

func TestNormalizeMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Normalize {
		if got := normalize(c.Value, c.Max); got != c.Out {
			t.Errorf("normalize(%#v, %d) = %q, want %q", c.Value, c.Max, got, c.Out)
		}
	}
}

func TestParseEvaluationResultMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Evaluations {
		got := ParseEvaluationResult(c.Value)
		if s, ok := c.Out.(string); ok && s == "__undefined__" {
			if got != nil {
				t.Errorf("%#v: got %#v, want undefined", c.Value, got)
			}
			continue
		}
		if !reflect.DeepEqual(got, c.Out) {
			t.Errorf("%#v: got %#v, want %#v", c.Value, got, c.Out)
		}
	}
}

func TestDecryptsNodeBlobAndRoundTrips(t *testing.T) {
	v := loadVectors(t).Encrypted
	key, _ := hex.DecodeString(v.Key)
	blob, _ := base64.StdEncoding.DecodeString(v.Blob)
	var got map[string]any
	if err := decryptJSON(key, blob, &got); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, v.Plain) {
		t.Fatalf("%v != %v", got, v.Plain)
	}
	sealed, err := encryptJSON(key, v.Plain)
	if err != nil {
		t.Fatal(err)
	}
	var back map[string]any
	if err := decryptJSON(key, sealed, &back); err != nil || !reflect.DeepEqual(back, v.Plain) {
		t.Fatalf("%v %v", back, err)
	}
	sealed[len(sealed)-1] ^= 1
	if decryptJSON(key, sealed, &back) == nil {
		t.Fatal("tampered blob accepted")
	}
}

type fakeRuntime struct {
	mu        sync.Mutex
	acquired  map[string]bool
	sensitive bool
	shots     int
	status    map[string]any
}

func (r *fakeRuntime) AcquireControl(_, _, id string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.acquired[id] = true
}
func (r *fakeRuntime) ReleaseControl(_, id string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.acquired, id)
}
func (r *fakeRuntime) RequestComputer(_ context.Context, _, method, path string, _ any, _ RequestOptions) (map[string]any, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	switch path {
	case "/teach/context":
		if r.sensitive {
			return map[string]any{"sensitiveInputActive": true}, nil
		}
		return r.status, nil
	case "/desktop/screenshot":
		r.shots++
		return map[string]any{"path": "/tmp/s.png"}, nil
	case "/files/read":
		return map[string]any{"content": "PNGDATA"}, nil
	}
	return nil, errors.New("unexpected " + method + " " + path)
}
func (r *fakeRuntime) Browser(context.Context, string) (Browser, error) {
	return nil, errors.New("no browser")
}

type fakeLearner struct {
	got Demonstration
	out Learned
}

func (l *fakeLearner) LearnFromComputerDemonstration(_ context.Context, d Demonstration) (Learned, error) {
	l.got = d
	return l.out, nil
}

type fakeEmitter struct {
	mu     sync.Mutex
	events []map[string]any
}

func (e *fakeEmitter) EmitToRoom(room, event string, payload any) {
	e.mu.Lock()
	defer e.mu.Unlock()
	m := map[string]any{"room": room, "event": event}
	raw, _ := json.Marshal(payload)
	var fields map[string]any
	_ = json.Unmarshal(raw, &fields)
	for k, v := range fields {
		m[k] = v
	}
	e.events = append(e.events, m)
}

func newService(t *testing.T) (*Service, *fakeRuntime, *fakeLearner, *fakeEmitter) {
	t.Helper()
	dir := filepath.Join(t.TempDir(), "teach")
	os.MkdirAll(dir, 0o755)
	os.WriteFile(filepath.Join(dir, "stale.teach"), []byte("x"), 0o600)
	rt := &fakeRuntime{acquired: map[string]bool{}, status: map[string]any{
		"activeWindow": " Terminal ",
		"files":        []any{map[string]any{"path": "/a", "size": 1.0, "modifiedAt": "t1"}},
		"shellEvents":  []any{map[string]any{"at": 5.0, "command": "ls"}},
	}}
	l := &fakeLearner{out: Learned{Success: true, Name: "deploy", Description: "Deploys"}}
	em := &fakeEmitter{}
	s := New(Config{Dir: dir, Runtime: rt, Learner: l, Emitter: em})
	if err := s.Start(context.Background()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(s.Stop)
	if _, err := os.Stat(filepath.Join(dir, "stale.teach")); !os.IsNotExist(err) {
		t.Fatal("stale recording kept across Start")
	}
	return s, rt, l, em
}

func TestSessionLifecycle(t *testing.T) {
	s, rt, learner, em := newService(t)
	ctx := context.Background()

	if _, err := s.StartSession(ctx, "1", StartInput{Goal: "  "}); err == nil || err.Error() != "A short Teach Mode goal is required." {
		t.Fatal(err)
	}
	sum, err := s.StartSession(ctx, "1", StartInput{Goal: "deploy the app", AgentID: "main"})
	if err != nil {
		t.Fatal(err)
	}
	if sum.Status != "recording" || sum.EventCount != 1 || sum.ScreenshotCount != 1 {
		t.Fatalf("%+v", sum)
	}
	_, err = s.StartSession(ctx, "1", StartInput{Goal: "again"})
	if e, ok := apperr.As(err); !ok || e.Status != 409 || e.Code != "TEACH_ALREADY_RECORDING" {
		t.Fatalf("%v", err)
	}
	if info, err := os.Stat(filepath.Join(s.cfg.Dir, sum.ID+".teach")); err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("session file: %v %v", info, err)
	}

	res, err := s.Record(ctx, "1", map[string]any{"type": "key", "key": "Enter", "modifiers": map[string]any{"ctrl": true}})
	if err != nil || !res.Recording || *res.EventCount != 2 {
		t.Fatalf("%+v %v", res, err)
	}
	if res, _ := s.Record(ctx, "1", map[string]any{"type": "bogus"}); !res.Ignored {
		t.Fatalf("%+v", res)
	}
	if res, _ := s.Record(ctx, "2", map[string]any{"type": "key"}); res.Recording {
		t.Fatal("recorded into another user's session")
	}
	rt.mu.Lock()
	rt.sensitive = true
	rt.mu.Unlock()
	before := rt.shots
	if _, err := s.Record(ctx, "1", map[string]any{"type": "text-input", "value": "hunter2"}); err != nil {
		t.Fatal(err)
	}
	if rt.shots != before {
		t.Fatal("screenshot taken while a password field was active")
	}

	if _, err := s.StopSession(ctx, "2", sum.ID); err == nil {
		t.Fatal("another user stopped the session")
	}
	out, err := s.StopSession(ctx, "1", sum.ID)
	if err != nil || out.Skill != "deploy" || !out.Success {
		t.Fatalf("%+v %v", out, err)
	}
	if learner.got.Goal != "deploy the app" || learner.got.Evidence.Recorder != "semantic-v1" || learner.got.Evidence.SourceEventCount != 4 {
		t.Fatalf("%+v", learner.got)
	}
	for _, e := range learner.got.Evidence.Timeline {
		if e.Type == "text-input" {
			raw, _ := json.Marshal(e)
			if strings.Contains(string(raw), "hunter2") {
				t.Fatal("typed text reached the learner")
			}
		}
	}
	if s.active("1") != nil || len(rt.acquired) != 0 {
		t.Fatal("session not purged")
	}
	entries, _ := os.ReadDir(s.cfg.Dir)
	if len(entries) != 0 {
		t.Fatalf("recording left on disk: %v", entries)
	}
	last := em.events[len(em.events)-1]
	if last["event"] != "teach:status" || last["room"] != "user:1" || last["status"] != "completed" || last["skill"] != "deploy" {
		t.Fatalf("%v", last)
	}
}

func TestIgnoredDemonstrationAndCancel(t *testing.T) {
	s, _, learner, _ := newService(t)
	ctx := context.Background()
	learner.out = Learned{Ignored: true, Error: "too short"}
	sum, _ := s.StartSession(ctx, "1", StartInput{Goal: "x"})
	_, err := s.StopSession(ctx, "1", sum.ID)
	if e, ok := apperr.As(err); !ok || e.Status != 422 || e.Code != "TEACH_SKILL_NOT_CREATED" || e.Message != "too short" {
		t.Fatalf("%v", err)
	}
	sum, _ = s.StartSession(ctx, "1", StartInput{Goal: "y"})
	if s.Cancel("2", sum.ID) {
		t.Fatal("another user cancelled")
	}
	if !s.Cancel("1", sum.ID) || s.active("1") != nil {
		t.Fatal("cancel failed")
	}
}

func TestExpire(t *testing.T) {
	s, rt, _, _ := newService(t)
	sum, _ := s.StartSession(context.Background(), "1", StartInput{Goal: "x"})
	s.expire(time.Now().Add(sessionTTL + time.Minute))
	if s.active("1") != nil || len(rt.acquired) != 0 {
		t.Fatalf("session %s outlived its TTL", sum.ID)
	}
}

func TestCompactReportsChanges(t *testing.T) {
	s := &Service{}
	sess := &session{lastFileState: map[string]string{}}
	files := func(items ...map[string]any) rawContext {
		raw := rawContext{Accessibility: []any{}}
		for _, i := range items {
			raw.Files = append(raw.Files, i)
		}
		return raw
	}
	a := map[string]any{"path": "/a", "size": 1.0, "modifiedAt": "t1"}
	b := map[string]any{"path": "/b", "size": 2.0}
	if c := s.compact(sess, files(a, b), true); len(c.Files) != 0 {
		t.Fatal("initial state reports changes")
	}
	a2 := map[string]any{"path": "/a", "size": 5.0, "modifiedAt": "t2"}
	c := s.compact(sess, files(a2), false)
	raw, _ := json.Marshal(c.Files)
	if string(raw) != `[{"path":"/a","size":5,"modifiedAt":"t2"},{"path":"/b","deleted":true}]` {
		t.Fatalf("%s", raw)
	}
}
