package sockets

import (
	"regexp"
	"sync"
	"testing"
	"time"
)

type testClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *testClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.t
}

func (c *testClock) Advance(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

func strictStack(t *testing.T) (*stack, *testClock) {
	clock := &testClock{t: time.Date(2026, 11, 24, 10, 0, 0, 0, time.UTC)}
	st := newStack(t, func(o *stackOpts) {
		o.strictLimits = true
		o.mod = func(c *Config) { c.Now = clock.Now }
	})
	return st, clock
}

var retryText = regexp.MustCompile(`^Rate limit exceeded for agent:run\. Retry in (\d+)s\.$`)

func TestRateLimitIsSharedAcrossAnAccountsSockets(t *testing.T) {
	st, _ := strictStack(t)
	a1, a2, b := st.connect(1), st.connect(1), st.connect(2)

	// agent:run allows 4 per 15 s for the whole account, however many sockets it has.
	for i := 0; i < 2; i++ {
		a1.emit("agent:run", map[string]any{"task": ""})
		a2.emit("agent:run", map[string]any{"task": ""})
	}
	for _, c := range []*tclient{a1, a1, a2, a2} {
		if got := obj(c.expect("error")[0])["message"]; got != "Task must be a non-empty string" {
			t.Fatalf("within budget: %v", got)
		}
	}
	a2.emit("agent:run", map[string]any{"task": "x"})
	got := obj(a2.expect("run:error")[0])
	m := retryText.FindStringSubmatch(got["error"].(string))
	if m == nil || m[1] != "15" || len(got) != 1 {
		t.Fatalf("refusal %v", got)
	}
	a1.emit("agent:run", map[string]any{"task": "x"})
	a1.expect("run:error")

	b.emit("agent:run", map[string]any{"task": ""}) // another account has its own budget
	b.expect("error")
}

func TestRateLimitWindowResetsAndReportsRetryAfter(t *testing.T) {
	st, clock := strictStack(t)
	c := st.connect(1)
	for i := 0; i < 4; i++ {
		c.emit("agent:run", map[string]any{"task": ""})
		c.expect("error")
	}
	clock.Advance(10_500 * time.Millisecond)
	c.emit("agent:run", map[string]any{"task": ""})
	if m := retryText.FindStringSubmatch(obj(c.expect("run:error")[0])["error"].(string)); m == nil || m[1] != "5" {
		t.Fatalf("retry after: %v", m)
	}
	clock.Advance(4500 * time.Millisecond) // 15 s since the window opened
	c.emit("agent:run", map[string]any{"task": ""})
	c.expect("error")
}

func TestRateLimitBudgetIsReleasedWithTheLastSocket(t *testing.T) {
	st, _ := strictStack(t)
	c := st.connect(1)
	for i := 0; i < 5; i++ {
		c.emit("agent:run", map[string]any{"task": ""})
	}
	for i := 0; i < 4; i++ {
		c.expect("error")
	}
	c.expect("run:error")
	c.ws.CloseNow()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		st.srv.limits.mu.Lock()
		n := len(st.srv.limits.users)
		st.srv.limits.mu.Unlock()
		if n == 0 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	fresh := st.connect(1)
	fresh.emit("agent:run", map[string]any{"task": ""})
	fresh.expect("error") // a new connection starts with a new budget, as in Node
}

func TestEachEventAnswersItsRefusalTheNodeWay(t *testing.T) {
	st, _ := strictStack(t)
	c := st.connect(1)
	// voice:audio allows 80 per second; the 81st gets a recoverable voice:error.
	for i := 0; i < 81; i++ {
		c.emit("voice:audio", map[string]any{"sessionId": "s", "audioBase64": "AAAA"})
	}
	got := obj(c.expect("voice:error")[0])
	if got["error"] != "Rate limit exceeded for voice:audio. Retry in 1s." || got["recoverable"] != true {
		t.Fatalf("%v", got)
	}
	// stream:subscribe: 40 per 10 s, answered on stream:error.
	for i := 0; i < 41; i++ {
		c.emit("stream:subscribe", map[string]any{"deviceId": "d"})
	}
	var refusal map[string]any
	for {
		r, ok := c.next(time.Second)
		if !ok {
			break
		}
		if r.name == "stream:error" {
			refusal = obj(r.args[0])
		}
	}
	if refusal == nil || refusal["error"] != "Rate limit exceeded for stream:subscribe. Retry in 10s." {
		t.Fatalf("%v", refusal)
	}
	// voice:call_accept is refused without being recorded for the diagnostics.
	for i := 0; i < 11; i++ {
		c.emit("voice:call_accept", map[string]any{})
	}
	for {
		if _, ok := c.next(300 * time.Millisecond); !ok {
			break
		}
	}
	for _, e := range st.srv.RateLimitSnapshot().TotalsByEvent {
		if e.EventName == "voice:call_accept" {
			t.Fatal("call_accept refusals are not recorded")
		}
	}
}

func TestRateLimitSnapshot(t *testing.T) {
	st, _ := strictStack(t)
	c := st.connect(1)
	for i := 0; i < 20; i++ { // agent:abort allows 20 per 10 s
		c.emit("agent:abort", map[string]any{})
		c.expect("agent:aborted")
	}
	c.emit("agent:abort", map[string]any{})
	c.expect("error")
	snap := st.srv.RateLimitSnapshot()
	if snap.GeneratedAt != "2026-11-24T10:00:00.000Z" || len(snap.TotalsByEvent) != 1 ||
		snap.TotalsByEvent[0].EventName != "agent:abort" || snap.TotalsByEvent[0].Count != 1 {
		t.Fatalf("%+v", snap)
	}
	u := snap.RecentByUserEvent[0]
	if u.UserID != "1" || u.EventName != "agent:abort" || u.Count != 1 || u.LastRetryAfterMs != 10000 || u.SocketID == "" {
		t.Fatalf("%+v", u)
	}
}
