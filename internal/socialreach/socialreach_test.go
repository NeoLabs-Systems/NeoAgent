package socialreach

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/socialvideo"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type recorded struct {
	URL     string            `json:"url"`
	Headers map[string]string `json:"headers"`
}

type scenario struct {
	Responses map[string]struct {
		Status int
		Body   string
	}
	Browsers    map[string][]map[string]any
	VideoResult socialvideo.Result
	Healths     map[string]socialvideo.Health
	Steps       []struct {
		Name      string
		Method    string
		Path      string
		User      *int
		Body      *string
		Video     string
		Browser   string
		NoService bool
		Expect    struct {
			Status int
			Body   json.RawMessage
		}
		ExpectRequests   []recorded
		ExpectVideoCalls []map[string]any
	}
	Snapshot []struct {
		User   int
		Key    string
		Value  map[string]any
		Sealed bool
	}
}

type world struct {
	t        *testing.T
	s        scenario
	db       *dbx.DB
	box      *secretbox.Box
	requests []recorded
	calls    []map[string]any
}

// RoundTrip answers outbound requests from the recorded table and logs them.
func (w *world) RoundTrip(req *http.Request) (*http.Response, error) {
	headers := map[string]string{}
	for _, k := range []string{"User-Agent", "Accept", "Cookie", "Referer"} {
		if v := req.Header.Get(k); v != "" {
			headers[strings.ToLower(k)] = v
		}
	}
	w.requests = append(w.requests, recorded{req.URL.String(), headers})
	hit, ok := w.s.Responses[req.URL.String()]
	if !ok {
		hit.Status, hit.Body = 404, "unknown"
	}
	if hit.Status == 0 {
		hit.Status = 200
	}
	return &http.Response{StatusCode: hit.Status, Body: io.NopCloser(strings.NewReader(hit.Body)), Header: http.Header{}, Request: req}, nil
}

type fakeVideo struct {
	w    *world
	mode string
}

func (f fakeVideo) HealthStatus(context.Context, bool) (socialvideo.Health, error) {
	if f.mode == "error" {
		return socialvideo.Health{}, errors.New("probe exploded")
	}
	return f.w.s.Healths[f.mode], nil
}

func (f fakeVideo) Extract(_ context.Context, userID int64, url string, o socialvideo.Options) (socialvideo.Result, error) {
	var agent any
	if o.AgentID != "" {
		agent = o.AgentID
	}
	f.w.calls = append(f.w.calls, map[string]any{"userId": float64(userID), "url": url, "includeFrame": o.IncludeFrame, "forceStt": o.ForceSTT, "agentId": agent})
	return f.w.s.VideoResult, nil
}

type fakeRuntime struct {
	w    *world
	mode string
}

func (r fakeRuntime) BrowserForUser(context.Context, int64) (CloudBrowser, error) {
	if r.mode == "throws" {
		return nil, errors.New("computer is off")
	}
	return browserFake(r.w.s.Browsers[r.mode]), nil
}

type browserFake []map[string]any

func (b browserFake) GetCookies(context.Context) ([]map[string]any, error) { return b, nil }

var stamp = regexp.MustCompile(`\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z`)

func normalize(raw string) string {
	return stamp.ReplaceAllStringFunc(raw, func(m string) string {
		if m == "2026-11-24T10:00:00.000Z" || strings.HasPrefix(m, "2026-01") {
			return m
		}
		return "<ts>"
	})
}

func newWorld(t *testing.T) *world {
	t.Helper()
	raw, err := os.ReadFile("testdata/scenario.json")
	if err != nil {
		t.Fatal(err)
	}
	w := &world{t: t}
	if err := json.Unmarshal(raw, &w.s); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	w.db, err = dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { w.db.Close() })
	if err := schema.Ensure(ctx, w.db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := w.db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`); err != nil {
		t.Fatal(err)
	}
	// The scenario was recorded with SESSION_SECRET=x as the key material.
	w.box, err = secretbox.New(config.SecretPrefix, "x")
	if err != nil {
		t.Fatal(err)
	}
	return w
}

// serviceFor builds what Node built per request: the service with the video
// and browser the step asks for.
func (w *world) serviceFor(video, browser string) *Service {
	cfg := Config{DB: w.db, Box: w.box, HTTP: &http.Client{Transport: w}}
	if video == "" {
		video = "ready"
	}
	if video != "none" {
		cfg.Video = fakeVideo{w, video}
	}
	if browser != "" && browser != "none" {
		cfg.Runtime = fakeRuntime{w, browser}
	}
	return New(cfg)
}

func TestRoutesReplayNode(t *testing.T) {
	w := newWorld(t)
	srv := httptest.NewServer(http.HandlerFunc(func(rw http.ResponseWriter, r *http.Request) {
		var backend Backend
		if r.Header.Get("X-No-Service") == "" {
			backend = w.serviceFor(r.Header.Get("X-Video"), r.Header.Get("X-Browser"))
		}
		mux := http.NewServeMux()
		NewAPI(APIConfig{
			Backend: backend,
			UserID: func(r *http.Request) (int64, bool) {
				id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
				return id, err == nil
			},
		}).Routes(mux)
		mux.ServeHTTP(rw, r)
	}))
	defer srv.Close()

	for _, step := range w.s.Steps {
		var body io.Reader
		if step.Body != nil {
			body = strings.NewReader(*step.Body)
		}
		req, _ := http.NewRequest(step.Method, srv.URL+step.Path, body)
		if step.User != nil {
			req.Header.Set("X-Test-User", strconv.Itoa(*step.User))
		}
		if step.NoService {
			req.Header.Set("X-No-Service", "1")
		}
		req.Header.Set("X-Video", step.Video)
		req.Header.Set("X-Browser", step.Browser)
		if step.Body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		w.requests, w.calls = nil, nil
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		raw, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != step.Expect.Status {
			t.Errorf("%s: status %d, want %d (%s)", step.Name, resp.StatusCode, step.Expect.Status, raw)
			continue
		}
		var got, want any
		_ = json.Unmarshal([]byte(normalize(string(raw))), &got)
		_ = json.Unmarshal(step.Expect.Body, &want)
		if !reflect.DeepEqual(got, want) {
			t.Errorf("%s:\n got %s\nwant %s", step.Name, normalize(string(raw)), step.Expect.Body)
		}
		if len(w.requests)+len(step.ExpectRequests) > 0 && !reflect.DeepEqual(w.requests, step.ExpectRequests) {
			t.Errorf("%s: outbound requests\n got %v\nwant %v", step.Name, w.requests, step.ExpectRequests)
		}
		if len(w.calls)+len(step.ExpectVideoCalls) > 0 && !reflect.DeepEqual(w.calls, step.ExpectVideoCalls) {
			t.Errorf("%s: video calls\n got %v\nwant %v", step.Name, w.calls, step.ExpectVideoCalls)
		}
	}

	rows, err := w.db.R.Query(`SELECT user_id, key, value FROM user_settings ORDER BY user_id, key`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	type row struct {
		User   int
		Key    string
		Value  map[string]any
		Sealed bool
	}
	var got []row
	for rows.Next() {
		var r row
		var value string
		if err := rows.Scan(&r.User, &r.Key, &value); err != nil {
			t.Fatal(err)
		}
		r.Sealed = w.box.IsSealed(value)
		plain, err := w.box.Open(value)
		if err != nil {
			t.Fatal(err)
		}
		_ = json.Unmarshal([]byte(plain), &r.Value)
		r.Value["importedAt"] = "<ts>"
		got = append(got, r)
	}
	sort.Slice(got, func(i, j int) bool { return got[i].User < got[j].User })
	var want []row
	for _, s := range w.s.Snapshot {
		want = append(want, row{s.User, s.Key, s.Value, s.Sealed})
	}
	if !reflect.DeepEqual(got, want) {
		g, _ := json.Marshal(got)
		x, _ := json.Marshal(want)
		t.Errorf("stored cookies:\n got %s\nwant %s", g, x)
	}
}

func TestHelpers(t *testing.T) {
	for _, c := range []struct {
		in   any
		want int
	}{{nil, 10}, {"abc", 10}, {json.Number("0"), 10}, {json.Number("-3"), 10}, {json.Number("2.9"), 2}, {"7", 7}, {json.Number("999"), 30}, {true, 1}} {
		if got := normalizeLimit(c.in, 10, 30); got != c.want {
			t.Errorf("normalizeLimit(%v) = %d, want %d", c.in, got, c.want)
		}
	}
	if got := encodeURIComponent("a b&c/é!'()*~"); got != "a%20b%26c%2F%C3%A9!'()*~" {
		t.Errorf("encodeURIComponent: %s", got)
	}
	if got := compactText("  a \n b  ", 3); got != "a b" {
		t.Errorf("compactText: %q", got)
	}
	if got := compactText("abcdefgh", 4); got != "abcd..." {
		t.Errorf("compactText cut: %q", got)
	}
}
