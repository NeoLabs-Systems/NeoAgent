package sockets

import (
	"fmt"
	"log/slog"
	"math"
	"sort"
	"strconv"
	"sync"
	"time"
)

// Per-event limits of services/websocket.js. The budget is shared by all
// sockets of one account, so opening more connections buys nothing.
type eventLimit struct {
	window time.Duration
	max    int
}

const (
	defaultLimitWindow   = 10 * time.Second
	defaultLimitMax      = 30
	observerEntryTTL     = 10 * time.Minute
	observerMaxUserKeys  = 500
	observerSnapshotRows = 200
)

var eventLimits = map[string]eventLimit{
	"agent:run":            {15 * time.Second, 4},
	"agent:abort":          {10 * time.Second, 20},
	"agent:history":        {10 * time.Second, 30},
	"agent:run_detail":     {10 * time.Second, 30},
	"messaging:connect":    {10 * time.Second, 10},
	"messaging:disconnect": {10 * time.Second, 10},
	"messaging:send":       {10 * time.Second, 20},
	"messaging:status":     {10 * time.Second, 40},
	"voice:session_open":   {10 * time.Second, 10},
	"voice:audio":          {time.Second, 80},
	"voice:input_start":    {10 * time.Second, 40},
	"voice:input_end":      {10 * time.Second, 40},
	"voice:cancel_task":    {10 * time.Second, 10},
	"voice:interrupt":      {10 * time.Second, 20},
	"voice:session_close":  {10 * time.Second, 20},
	"voice:call_accept":    {10 * time.Second, 10},
	"voice:call_decline":   {10 * time.Second, 20},
	"mcp:status":           {10 * time.Second, 20},
	"mcp:tools":            {10 * time.Second, 20},
	"integrations:status":  {10 * time.Second, 20},
	"memory:read":          {10 * time.Second, 20},
	"memory:search":        {10 * time.Second, 20},
	"stream:subscribe":     {10 * time.Second, 40},
	"stream:unsubscribe":   {10 * time.Second, 40},
}

type window struct {
	start time.Time
	count int
}

// userLimits is one account's counters, shared by its sockets.
type userLimits struct {
	mu      sync.Mutex
	windows map[string]*window
	sockets int
}

// limiter hands out the per-account counters.
type limiter struct {
	mu    sync.Mutex
	users map[int64]*userLimits
	now   func() time.Time
	table map[string]eventLimit
}

func newLimiter(now func() time.Time) *limiter {
	return &limiter{users: map[int64]*userLimits{}, now: now, table: eventLimits}
}

// acquire registers a socket of the account and returns the shared counters.
func (l *limiter) acquire(userID int64) *userLimits {
	l.mu.Lock()
	defer l.mu.Unlock()
	u := l.users[userID]
	if u == nil {
		u = &userLimits{windows: map[string]*window{}}
		l.users[userID] = u
	}
	u.sockets++
	return u
}

// release forgets the account's counters once its last socket is gone.
func (l *limiter) release(userID int64) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if u := l.users[userID]; u != nil {
		if u.sockets--; u.sockets <= 0 {
			delete(l.users, userID)
		}
	}
}

// allow counts one use of an event and says whether it is within the limit;
// when it is not, retryAfter is how long until the window resets.
func (l *limiter) allow(u *userLimits, event string) (ok bool, retryAfter time.Duration) {
	cfg, found := l.table[event]
	if !found {
		cfg = eventLimit{defaultLimitWindow, defaultLimitMax}
	}
	now := l.now()
	u.mu.Lock()
	defer u.mu.Unlock()
	w := u.windows[event]
	if w == nil || now.Sub(w.start) >= cfg.window {
		u.windows[event] = &window{start: now, count: 1}
		return true, 0
	}
	if w.count >= cfg.max {
		return false, max(time.Millisecond, cfg.window-now.Sub(w.start))
	}
	w.count++
	return true, 0
}

// rateLimitMessage is the text clients see when an event is refused.
func rateLimitMessage(event string, retryAfter time.Duration) string {
	return fmt.Sprintf("Rate limit exceeded for %s. Retry in %ds.", event, int(math.Ceil(retryAfter.Seconds())))
}

// observer remembers refusals for the admin diagnostics.
type observer struct {
	mu          sync.Mutex
	log         *slog.Logger
	now         func() time.Time
	byEvent     map[string]*eventTotal
	byUserEvent map[string]*userEventTotal
}

type eventTotal struct {
	count  int
	lastAt time.Time
}

type userEventTotal struct {
	userID, eventName string
	count             int
	lastAt            time.Time
	lastRetryAfterMs  int64
	socketID          string
}

func newObserver(log *slog.Logger, now func() time.Time) *observer {
	return &observer{log: log, now: now, byEvent: map[string]*eventTotal{}, byUserEvent: map[string]*userEventTotal{}}
}

func (o *observer) record(userID int64, socketID, event string, retryAfter time.Duration) {
	now := o.now()
	user := strconv.FormatInt(userID, 10)
	o.mu.Lock()
	total := o.byEvent[event]
	if total == nil {
		total = &eventTotal{}
		o.byEvent[event] = total
	}
	total.count++
	total.lastAt = now

	key := user + ":" + event
	entry := o.byUserEvent[key]
	if entry == nil {
		entry = &userEventTotal{userID: user, eventName: event}
		o.byUserEvent[key] = entry
	}
	entry.count++
	entry.lastAt = now
	entry.lastRetryAfterMs = retryAfter.Milliseconds()
	entry.socketID = socketID
	if len(o.byUserEvent) > observerMaxUserKeys { // keep memory bounded over long uptime
		for k, e := range o.byUserEvent {
			if e.lastAt.Before(now.Add(-observerEntryTTL)) {
				delete(o.byUserEvent, k)
			}
		}
	}
	o.mu.Unlock()
	o.log.Warn("[WS] rate_limit_exceeded", "userId", user, "socketId", socketID, "eventName", event,
		"retryAfterMs", retryAfter.Milliseconds())
}

// RateLimitSnapshot is the diagnostics payload (getWebsocketRateLimitSnapshot).
type RateLimitSnapshot struct {
	GeneratedAt       string              `json:"generatedAt"`
	TotalsByEvent     []EventTotal        `json:"totalsByEvent"`
	RecentByUserEvent []UserEventSnapshot `json:"recentByUserEvent"`
}

// EventTotal counts the refusals of one event.
type EventTotal struct {
	EventName string `json:"eventName"`
	Count     int    `json:"count"`
	LastAt    string `json:"lastAt"`
}

// UserEventSnapshot counts the refusals of one event for one account.
type UserEventSnapshot struct {
	UserID           string `json:"userId"`
	EventName        string `json:"eventName"`
	Count            int    `json:"count"`
	LastRetryAfterMs int64  `json:"lastRetryAfterMs"`
	SocketID         string `json:"socketId"`
	LastAt           string `json:"lastAt"`
}

func isoTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

func (o *observer) snapshot() RateLimitSnapshot {
	o.mu.Lock()
	defer o.mu.Unlock()
	snap := RateLimitSnapshot{
		GeneratedAt:       isoTime(o.now()),
		TotalsByEvent:     []EventTotal{},
		RecentByUserEvent: []UserEventSnapshot{},
	}
	for name, t := range o.byEvent {
		snap.TotalsByEvent = append(snap.TotalsByEvent, EventTotal{EventName: name, Count: t.count, LastAt: isoTime(t.lastAt)})
	}
	sort.Slice(snap.TotalsByEvent, func(i, j int) bool { return snap.TotalsByEvent[i].EventName < snap.TotalsByEvent[j].EventName })
	entries := make([]*userEventTotal, 0, len(o.byUserEvent))
	for _, e := range o.byUserEvent {
		entries = append(entries, e)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].lastAt.After(entries[j].lastAt) })
	for i, e := range entries {
		if i == observerSnapshotRows {
			break
		}
		snap.RecentByUserEvent = append(snap.RecentByUserEvent, UserEventSnapshot{
			UserID: e.userID, EventName: e.eventName, Count: e.count,
			LastRetryAfterMs: e.lastRetryAfterMs, SocketID: e.socketID, LastAt: isoTime(e.lastAt),
		})
	}
	return snap
}
