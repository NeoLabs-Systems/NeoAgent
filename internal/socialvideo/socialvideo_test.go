package socialvideo

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"testing"
)

type scenario struct {
	URLVectors []struct {
		Input string
		OK    *struct{ Platform, NormalizedUrl string }
		Error string
	}
	PickVectors []struct {
		GroupsJSON string
		Prefs      []string
		Pick       *struct{ Language, URL, Ext, Name string }
	}
	ParseVectors []struct{ Raw, Ext, Text string }
	TooBig       struct {
		Ext   string
		Size  int
		Error string
	}
	HTMLVectors []struct {
		HTML string
		Meta struct{ Title, Description, CanonicalUrl string }
	}
	FrameVectors []struct {
		Duration any
		Second   int
	}
	MimeVectors  []struct{ File, Mime string }
	ErrorVectors []struct {
		Text  string
		Error ResultError
	}
	Jar struct {
		Cookies []struct {
			Name, Value, Domain, Path string
			Secure, HttpOnly          bool
			Expires                   float64
		}
		Text string
	}
	Cases  map[string]map[string]any
	Health Health
	Steps  []struct {
		Name      string
		Method    string
		Path      string
		User      *int
		Body      *string
		NoService bool
		Expect    struct {
			Status int
			Body   json.RawMessage
		}
		ExpectCalls []map[string]any
	}
}

func load(t *testing.T) scenario {
	t.Helper()
	raw, err := os.ReadFile("testdata/scenario.json")
	if err != nil {
		t.Fatal(err)
	}
	var s scenario
	if err := json.Unmarshal(raw, &s); err != nil {
		t.Fatal(err)
	}
	return s
}

func TestURLVectors(t *testing.T) {
	for _, v := range load(t).URLVectors {
		got, err := NormalizeAndDetect(v.Input)
		if v.OK == nil {
			if err == nil || err.Error() != v.Error {
				t.Errorf("%q: got %v %v, want error %q", v.Input, got, err, v.Error)
			}
			continue
		}
		if err != nil || got.Platform != v.OK.Platform || got.NormalizedURL != v.OK.NormalizedUrl {
			t.Errorf("%q: got %+v %v, want %+v", v.Input, got, err, *v.OK)
		}
	}
}

func TestCaptionPicks(t *testing.T) {
	for _, v := range load(t).PickVectors {
		got := PickCaptionTrack(decodeCaptionGroups(json.RawMessage(v.GroupsJSON)), v.Prefs)
		switch {
		case v.Pick == nil && got != nil, v.Pick != nil && got == nil:
			t.Errorf("%s %v: got %v want %v", v.GroupsJSON, v.Prefs, got, v.Pick)
		case v.Pick != nil && (got.Language != v.Pick.Language || got.URL != v.Pick.URL || got.Ext != v.Pick.Ext || got.Name != v.Pick.Name):
			t.Errorf("%s %v: got %+v want %+v", v.GroupsJSON, v.Prefs, *got, *v.Pick)
		}
	}
}

func TestCaptionParsing(t *testing.T) {
	s := load(t)
	for _, v := range s.ParseVectors {
		got, err := ParseCaptionText(v.Raw, v.Ext)
		if err != nil || got != v.Text {
			t.Errorf("%q (%s): got %q %v, want %q", v.Raw, v.Ext, got, err, v.Text)
		}
	}
	_, err := ParseWebVTT(strings.Repeat("a", s.TooBig.Size))
	if err == nil || err.Error() != s.TooBig.Error {
		t.Errorf("oversize: %v, want %q", err, s.TooBig.Error)
	}
}

func TestMetadataFrameAndErrors(t *testing.T) {
	s := load(t)
	for _, v := range s.HTMLVectors {
		got := extractPublicMetadata(v.HTML, "https://fallback")
		if got.Title != v.Meta.Title || got.Description != v.Meta.Description || got.CanonicalURL != v.Meta.CanonicalUrl {
			t.Errorf("%q: got %+v want %+v", v.HTML, got, v.Meta)
		}
	}
	for _, v := range s.FrameVectors {
		d := math.NaN()
		switch n := v.Duration.(type) {
		case float64:
			d = n
		case nil:
			d = 0
		}
		if got := frameSecond(d); got != v.Second {
			t.Errorf("duration %v: got %d want %d", v.Duration, got, v.Second)
		}
	}
	for _, v := range s.MimeVectors {
		if got := imageContentType(v.File); got != v.Mime {
			t.Errorf("%s: %s", v.File, got)
		}
	}
	for _, v := range s.ErrorVectors {
		if got := classifyError(errors.New(v.Text)); got != v.Error {
			t.Errorf("%q: got %+v want %+v", v.Text, got, v.Error)
		}
	}
	var cookies []Cookie
	for _, c := range s.Jar.Cookies {
		cookies = append(cookies, Cookie{Name: c.Name, Value: c.Value, Domain: c.Domain, Path: c.Path, Secure: c.Secure, HTTPOnly: c.HttpOnly, Expires: c.Expires})
	}
	if got := netscapeJar(cookies); got != s.Jar.Text {
		t.Errorf("cookie jar:\n%q\nwant\n%q", got, s.Jar.Text)
	}
}

// scripted answers the routes from the recorded cases, shaping them with the
// Go shaper just as Node used its own.
type scripted struct {
	s     scenario
	mu    sync.Mutex
	calls []map[string]any
}

func (f *scripted) HealthStatus(_ context.Context, refresh bool) (Health, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, map[string]any{"health": refresh})
	return f.s.Health, nil
}

func str(v any) string {
	switch v := v.(type) {
	case string:
		return v
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	}
	return ""
}

func (f *scripted) Extract(_ context.Context, userID int64, url string, o Options) (Result, error) {
	f.mu.Lock()
	f.calls = append(f.calls, map[string]any{"userId": float64(userID), "url": url, "includeFrame": o.IncludeFrame, "forceStt": o.ForceSTT})
	f.mu.Unlock()
	if url == "boom" {
		return Result{}, errors.New("kaboom")
	}
	in, ok := f.s.Cases[url]
	if !ok {
		in = f.s.Cases["ok"]
	}
	r := Result{
		SourceURL: str(in["sourceUrl"]), ResolvedURL: str(in["resolvedUrl"]), Platform: str(in["platform"]),
		Title: str(in["title"]), Description: str(in["description"]), Transcript: str(in["transcript"]),
		TranscriptSource: str(in["transcriptSource"]),
	}
	if c, ok := in["canonicalUrl"].(string); ok {
		r.CanonicalURL = &c
	}
	if m, ok := in["metadata"].(map[string]any); ok {
		r.Metadata = m
	}
	if fi, ok := in["frameImage"].(map[string]any); ok {
		raw, _ := json.Marshal(fi)
		var img FrameImage
		_ = json.Unmarshal(raw, &img)
		if img.Source == "" {
			img.Source = "frame"
		}
		r.FrameImage = &img
	}
	if raw, ok := in["setup"]; ok {
		b, _ := json.Marshal(raw)
		var h Health
		_ = json.Unmarshal(b, &h)
		r.Setup = &h
	}
	for _, w := range asList(in["warnings"]) {
		r.Warnings = append(r.Warnings, str(w))
	}
	for _, e := range asList(in["errors"]) {
		switch e := e.(type) {
		case string:
			r.Errors = append(r.Errors, ResultError{Message: e})
		case map[string]any:
			r.Errors = append(r.Errors, ResultError{Code: str(e["code"]), Message: str(e["message"])})
		}
	}
	return shape(r), nil
}

func asList(v any) []any {
	l, _ := v.([]any)
	return l
}

func TestRoutesReplayNode(t *testing.T) {
	s := load(t)
	fake := &scripted{s: s}
	handlerFor := func(ex Extractor) http.Handler {
		mux := http.NewServeMux()
		NewAPI(APIConfig{
			Extractor: ex,
			UserID: func(r *http.Request) (int64, bool) {
				id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
				return id, err == nil
			},
			AgentID: func(*http.Request, int64, map[string]json.RawMessage) (string, error) { return "agent", nil },
		}).Routes(mux)
		return mux
	}
	with, without := httptest.NewServer(handlerFor(fake)), httptest.NewServer(handlerFor(nil))
	defer with.Close()
	defer without.Close()

	for _, step := range s.Steps {
		base := with.URL
		if step.NoService {
			base = without.URL
		}
		var body io.Reader
		if step.Body != nil {
			body = strings.NewReader(*step.Body)
		}
		req, _ := http.NewRequest(step.Method, base+step.Path, body)
		if step.User != nil {
			req.Header.Set("X-Test-User", strconv.Itoa(*step.User))
		}
		if step.Body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		fake.calls = nil
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
		_ = json.Unmarshal(raw, &got)
		_ = json.Unmarshal(step.Expect.Body, &want)
		if !reflect.DeepEqual(got, want) {
			t.Errorf("%s:\n got %s\nwant %s", step.Name, raw, step.Expect.Body)
		}
		if !step.NoService && len(step.ExpectCalls) != len(fake.calls) {
			t.Errorf("%s: calls %v, want %v", step.Name, fake.calls, step.ExpectCalls)
		} else if !step.NoService && len(step.ExpectCalls) > 0 && !reflect.DeepEqual(fake.calls, step.ExpectCalls) {
			t.Errorf("%s: calls %v, want %v", step.Name, fake.calls, step.ExpectCalls)
		}
	}
}

// fakeTool writes a shell script that behaves like yt-dlp and ffmpeg for the
// pipeline test: it answers --version, writes an info file, captions and media.
func fakeTool(t *testing.T, dir string) string {
	t.Helper()
	script := `#!/bin/sh
case "$1" in --version|-version) echo "9.9.9"; exit 0;; esac
out=""; prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then out="$a"; fi
  prev="$a"
done
case "$*" in
  *--write-info-json*) d=$(dirname "$out"); cat > "$d/media.info.json" <<'JSON'
{"id":"vid1","title":"Info title","description":"Info desc","webpage_url":"https://www.youtube.com/watch?v=vid1","duration":100,
 "subtitles":{},"automatic_captions":{},"thumbnails":[{"url":"https://thumbs.test/a.jpg","width":10,"height":10}]}
JSON
  ;;
  *--write-subs*) d=$(dirname "$out"); printf 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello world\n' > "$d/captions.en.vtt";;
  *-frames:v*) for last; do :; done; printf 'jpg' > "$last";;
  *merge-output-format*) d=$(dirname "$out"); printf 'mp4' > "$d/video.mp4";;
esac
`
	path := filepath.Join(dir, "fake-tool")
	if err := os.WriteFile(path, []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestExtractPipeline(t *testing.T) {
	dir := t.TempDir()
	tool := fakeTool(t, dir)
	page := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `<title>Page title</title><meta name="description" content="Page desc"><link rel="canonical" href="https://www.youtube.com/watch?v=vid1">`)
	}))
	defer page.Close()
	svc := New(Config{YtDlp: tool, Ffmpeg: tool, TempDir: dir, HTTP: &http.Client{Transport: redirectTo(page.URL)}})
	res, err := svc.Extract(context.Background(), 1, "https://youtu.be/vid1?si=x", Options{IncludeFrame: true})
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Errors) != 0 || res.Title != "Page title" || res.Description != "Page desc" || res.Transcript != "Hello world" ||
		res.TranscriptSource != "captions" || res.Platform != "youtube" || res.FrameImage == nil || res.FrameImage.Source != "frame" {
		t.Fatalf("unexpected result: %+v frame=%+v", res, res.FrameImage)
	}
	meta := res.Metadata.(Metadata)
	if meta.VideoID == nil || *meta.VideoID != "vid1" || *meta.DurationSeconds != 100 {
		t.Fatalf("metadata: %+v", meta)
	}
	left, _ := filepath.Glob(filepath.Join(dir, "youtube-*"))
	if len(left) != 0 {
		t.Fatalf("work folder left behind: %v", left)
	}

	missing := New(Config{YtDlp: filepath.Join(dir, "does-not-exist"), TempDir: dir})
	res, err = missing.Extract(context.Background(), 1, "https://youtu.be/x", Options{})
	if err != nil || len(res.Errors) != 1 || !strings.HasPrefix(res.Errors[0].Message, "Missing required dependency") || res.Setup == nil || res.Setup.Ready {
		t.Fatalf("missing tool: %+v %v", res, err)
	}
	res, _ = svc.Extract(context.Background(), 1, "https://example.com/x", Options{})
	if len(res.Errors) != 1 || res.Errors[0].Code != "unsupported_url" {
		t.Fatalf("unsupported: %+v", res)
	}
}

// redirectTo sends every request to one test server.
type redirectTo string

func (r redirectTo) RoundTrip(req *http.Request) (*http.Response, error) {
	target := string(r)
	clone := req.Clone(req.Context())
	clone.URL.Scheme, clone.URL.Host = "http", strings.TrimPrefix(target, "http://")
	return http.DefaultTransport.RoundTrip(clone)
}
