// Package replaytest replays steps recorded from the Node providers
// (gen/batch2_vectors.js): each step scripts the HTTP answers, and the test
// compares the requests the Go provider made, its result and its error.
package replaytest

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"reflect"
	"strings"
	"sync"
	"testing"
)

// Answer is one scripted HTTP answer.
type Answer struct {
	Status  int               `json:"status"`
	Body    json.RawMessage   `json:"body"`
	Headers map[string]string `json:"headers"`
}

// Request is one request a provider made.
type Request struct {
	Method  string            `json:"method"`
	URL     string            `json:"url"`
	Headers map[string]string `json:"headers"`
	Body    *string           `json:"body"`
}

// Step is one recorded call.
type Step struct {
	Name     string          `json:"name"`
	Answers  []Answer        `json:"answers"`
	Result   json.RawMessage `json:"result"`
	Error    *string         `json:"error"`
	Requests []Request       `json:"requests"`
	Calls    json.RawMessage `json:"calls"`
}

// Load reads testdata/node.json into v.
func Load(t *testing.T, v any) {
	t.Helper()
	raw, err := os.ReadFile("testdata/node.json")
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(raw, v); err != nil {
		t.Fatal(err)
	}
}

// Transport serves the scripted answers and records the requests.
type Transport struct {
	mu       sync.Mutex
	answers  []Answer
	requests []Request
}

// Script replaces the answers and forgets the recorded requests.
func (tr *Transport) Script(answers []Answer) {
	tr.mu.Lock()
	defer tr.mu.Unlock()
	tr.answers = append([]Answer(nil), answers...)
	tr.requests = nil
}

// Requests are the requests since the last Script.
func (tr *Transport) Requests() []Request {
	tr.mu.Lock()
	defer tr.mu.Unlock()
	return append([]Request(nil), tr.requests...)
}

// Unused is the number of answers nobody asked for.
func (tr *Transport) Unused() int {
	tr.mu.Lock()
	defer tr.mu.Unlock()
	return len(tr.answers)
}

// RoundTrip implements http.RoundTripper.
func (tr *Transport) RoundTrip(r *http.Request) (*http.Response, error) {
	headers := map[string]string{}
	for k := range r.Header {
		headers[strings.ToLower(k)] = r.Header.Get(k)
	}
	var body *string
	if r.Body != nil {
		raw, _ := io.ReadAll(r.Body)
		if len(raw) > 0 || r.Method != http.MethodGet {
			s := string(raw)
			body = &s
		}
	}
	tr.mu.Lock()
	tr.requests = append(tr.requests, Request{Method: r.Method, URL: r.URL.String(), Headers: headers, Body: body})
	if len(tr.answers) == 0 {
		tr.mu.Unlock()
		return nil, fmt.Errorf("unscripted request %s", r.URL)
	}
	a := tr.answers[0]
	tr.answers = tr.answers[1:]
	tr.mu.Unlock()
	status := a.Status
	if status == 0 {
		status = http.StatusOK
	}
	text := ""
	if len(a.Body) > 0 {
		var s string
		if json.Unmarshal(a.Body, &s) == nil {
			text = s
		} else {
			// Node sent JSON.stringify(body): the compact form.
			var compact bytes.Buffer
			if json.Compact(&compact, a.Body) == nil {
				text = compact.String()
			} else {
				text = string(a.Body)
			}
		}
	}
	resp := &http.Response{StatusCode: status, Status: fmt.Sprintf("%d %s", status, http.StatusText(status)), Header: http.Header{}, Body: io.NopCloser(strings.NewReader(text)), Request: r, ContentLength: int64(len(text))}
	if a.Headers == nil {
		resp.Header.Set("Content-Type", "application/json")
	}
	for k, v := range a.Headers {
		resp.Header.Set(k, v)
	}
	return resp, nil
}

// Client is an HTTP client over the transport that does not follow redirects.
func (tr *Transport) Client() *http.Client {
	return &http.Client{Transport: tr, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
}

// Normalize decodes JSON into plain values for comparison.
func Normalize(t *testing.T, v any) any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return Decode(t, raw)
}

// Decode decodes JSON text.
func Decode(t *testing.T, raw []byte) any {
	t.Helper()
	if len(bytes.TrimSpace(raw)) == 0 {
		return nil
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatalf("decode %s: %v", raw, err)
	}
	return out
}

// Check compares a step's outcome: the error text, or the result as JSON.
func Check(t *testing.T, step Step, got any, err error) {
	t.Helper()
	if step.Error != nil {
		if err == nil {
			t.Errorf("%s: got result %s, want error %q", step.Name, mustJSON(got), *step.Error)
		} else if err.Error() != *step.Error {
			t.Errorf("%s: error\n got %q\nwant %q", step.Name, err.Error(), *step.Error)
		}
		return
	}
	if err != nil {
		t.Errorf("%s: unexpected error %v", step.Name, err)
		return
	}
	g, w := Normalize(t, got), Decode(t, step.Result)
	if !reflect.DeepEqual(g, w) {
		t.Errorf("%s: result\n got %s\nwant %s", step.Name, mustJSON(g), mustJSON(w))
	}
}

// CheckRequests compares the requests made with the recorded ones: method,
// URL, the recorded headers and the body (as JSON when it is JSON).
func CheckRequests(t *testing.T, step Step, got []Request) {
	t.Helper()
	if len(got) != len(step.Requests) {
		t.Errorf("%s: %d requests, want %d:\n got %s\nwant %s", step.Name, len(got), len(step.Requests), mustJSON(got), mustJSON(step.Requests))
		return
	}
	for i, want := range step.Requests {
		g := got[i]
		if g.Method != want.Method || g.URL != want.URL {
			t.Errorf("%s #%d: %s %s, want %s %s", step.Name, i, g.Method, g.URL, want.Method, want.URL)
		}
		for k, v := range want.Headers {
			if g.Headers[k] != v {
				t.Errorf("%s #%d: header %s = %q, want %q", step.Name, i, k, g.Headers[k], v)
			}
		}
		if !sameBody(g.Body, want.Body) {
			t.Errorf("%s #%d: body\n got %v\nwant %v", step.Name, i, deref(g.Body), deref(want.Body))
		}
	}
}

func deref(s *string) string {
	if s == nil {
		return "<none>"
	}
	return *s
}

func sameBody(got, want *string) bool {
	if want == nil {
		return got == nil || *got == ""
	}
	if got == nil {
		return *want == ""
	}
	var g, w any
	if json.Unmarshal([]byte(*got), &g) == nil && json.Unmarshal([]byte(*want), &w) == nil {
		return reflect.DeepEqual(g, w)
	}
	return *got == *want
}

func mustJSON(v any) string {
	raw, _ := json.Marshal(v)
	return string(raw)
}
