package models

import (
	"context"
	"database/sql"
	"fmt"
	"math"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Per-account token budgets over a four-hour and a seven-day window, measured
// from the token totals of the account's runs.

const (
	// DefaultRateLimit4h and DefaultRateLimitWeekly apply to accounts without a
	// limit of their own.
	DefaultRateLimit4h     = 2_500_000
	DefaultRateLimitWeekly = 10_000_000
	// MaxRunReservation bounds what one starting run holds back while it runs.
	MaxRunReservation = 100_000
)

var windows = []struct {
	Key      string
	Duration time.Duration
}{
	{"fourHour", 4 * time.Hour},
	{"weekly", 7 * 24 * time.Hour},
}

// RateLimitConfig holds the server-wide defaults.
type RateLimitConfig struct {
	DefaultFourHour, DefaultWeekly int64
	// Disabled switches enforcement off (NEOAGENT_DISABLE_RATE_LIMITS=true).
	Disabled bool
}

// RateLimitConfigFromEnv reads NEOAGENT_RATE_LIMIT_4H, NEOAGENT_RATE_LIMIT_WEEKLY
// and NEOAGENT_DISABLE_RATE_LIMITS.
func RateLimitConfigFromEnv(getenv func(string) string) RateLimitConfig {
	positive := func(name string, fallback int64) int64 {
		var n int64
		if _, err := fmt.Sscanf(strings.TrimSpace(getenv(name)), "%d", &n); err != nil || n <= 0 {
			return fallback
		}
		return n
	}
	return RateLimitConfig{
		DefaultFourHour: positive("NEOAGENT_RATE_LIMIT_4H", DefaultRateLimit4h),
		DefaultWeekly:   positive("NEOAGENT_RATE_LIMIT_WEEKLY", DefaultRateLimitWeekly),
		Disabled:        strings.EqualFold(getenv("NEOAGENT_DISABLE_RATE_LIMITS"), "true"),
	}
}

// Limits are an account's budgets; nil means unlimited.
type Limits struct {
	FourHour, Weekly                 *int64
	FourHourIsCustom, WeeklyIsCustom bool
}

func (l Limits) of(window string) *int64 {
	if window == "fourHour" {
		return l.FourHour
	}
	return l.Weekly
}

// WindowValues holds one number per window.
type WindowValues[T any] struct {
	FourHour T `json:"fourHour"`
	Weekly   T `json:"weekly"`
}

// RateLimitSnapshot is where an account stands against its budgets.
type RateLimitSnapshot struct {
	Limits    Limits
	Usage     WindowValues[int64]
	Remaining WindowValues[*int64]
	Reached   struct{ FourHour, Weekly, Any bool }
	// RecoversAt is when the usage over the limit has aged out of the window.
	RecoversAt WindowValues[*string]
	// FullResetAt is when every run inside the window has aged out.
	FullResetAt WindowValues[*string]
}

// RateLimitExceeded is returned when an account has used up a window. Its
// message is the one shown to the user.
type RateLimitExceeded struct {
	Window   string
	Snapshot RateLimitSnapshot
}

// Error describes the exhausted window.
func (e *RateLimitExceeded) Error() string {
	label := "the last 7 days"
	usage, limit := e.Snapshot.Usage.Weekly, e.Snapshot.Limits.Weekly
	if e.Window == "fourHour" {
		label = "the last 4 hours"
		usage, limit = e.Snapshot.Usage.FourHour, e.Snapshot.Limits.FourHour
	}
	limitText := "null"
	if limit != nil {
		limitText = fmt.Sprint(*limit)
	}
	return fmt.Sprintf("Rate limit exceeded: You have used %d tokens in %s (limit: %s).", usage, label, limitText)
}

// StatusCode is 429.
func (e *RateLimitExceeded) StatusCode() int { return 429 }

// Code is RATE_LIMIT_EXCEEDED.
func (e *RateLimitExceeded) Code() string { return "RATE_LIMIT_EXCEEDED" }

// RateLimiter measures usage and reserves room for runs in flight. The
// reservations make concurrent run starts see each other, so together they
// cannot bypass the budget.
type RateLimiter struct {
	DB     *dbx.DB
	Config RateLimitConfig

	mu           sync.Mutex
	reservations map[int64]int64
}

type usageRow struct {
	tokens    int64
	createdAt string
}

func (r *RateLimiter) usageRows(ctx context.Context, userID int64, window time.Duration) ([]usageRow, error) {
	modifier := fmt.Sprintf("-%d seconds", int64(window/time.Second))
	rows, err := r.DB.R.QueryContext(ctx,
		`SELECT COALESCE(total_tokens, 0) AS tokens, created_at FROM agent_runs
		 WHERE user_id = ? AND created_at > datetime('now', ?) ORDER BY datetime(created_at) ASC`, userID, modifier)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []usageRow
	for rows.Next() {
		var row usageRow
		var created sql.NullString
		if err := rows.Scan(&row.tokens, &created); err != nil {
			return nil, err
		}
		row.createdAt = created.String
		out = append(out, row)
	}
	return out, rows.Err()
}

func parseSQLiteDate(value string) (time.Time, bool) {
	text := strings.TrimSpace(value)
	if text == "" {
		return time.Time{}, false
	}
	if !strings.Contains(text, "T") {
		text = strings.Replace(text, " ", "T", 1) + "Z"
	}
	for _, layout := range []string{time.RFC3339Nano, "2006-01-02T15:04:05"} {
		if t, err := time.Parse(layout, text); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

func isoString(t time.Time) *string {
	s := t.UTC().Format("2006-01-02T15:04:05.000Z")
	return &s
}

func positiveRows(rows []usageRow) []usageRow {
	var out []usageRow
	for _, row := range rows {
		if row.tokens > 0 {
			out = append(out, row)
		}
	}
	return out
}

// recoversAt is the first moment the account can start a run again: when the
// committed usage that currently exceeds the limit has aged out of the window.
func recoversAt(rows []usageRow, window time.Duration, committed int64, limit *int64) *string {
	if limit == nil || committed < *limit {
		return nil
	}
	required := committed - *limit + 1
	var expired int64
	for _, row := range positiveRows(rows) {
		expired += row.tokens
		if expired < required {
			continue
		}
		if created, ok := parseSQLiteDate(row.createdAt); ok {
			return isoString(created.Add(window))
		}
		return nil
	}
	return nil
}

// fullResetAt is when every run currently inside the window has aged out: when
// usage returns to zero if no further runs are started.
func fullResetAt(rows []usageRow, window time.Duration) *string {
	var newest time.Time
	found := false
	for _, row := range positiveRows(rows) {
		if created, ok := parseSQLiteDate(row.createdAt); ok && (!found || created.After(newest)) {
			newest, found = created, true
		}
	}
	if !found {
		return nil
	}
	return isoString(newest.Add(window))
}

func (r *RateLimiter) limitsFor(ctx context.Context, userID int64) (Limits, error) {
	var fourHour, weekly sql.NullInt64
	err := r.DB.R.QueryRowContext(ctx, `SELECT rate_limit_4h, rate_limit_weekly FROM users WHERE id = ?`, userID).Scan(&fourHour, &weekly)
	if err != nil && err != sql.ErrNoRows {
		return Limits{}, err
	}
	pick := func(custom sql.NullInt64, fallback int64) *int64 {
		switch {
		case !custom.Valid:
			return &fallback
		case custom.Int64 > 0:
			v := custom.Int64
			return &v
		}
		return nil
	}
	return Limits{
		FourHour: pick(fourHour, r.Config.DefaultFourHour), Weekly: pick(weekly, r.Config.DefaultWeekly),
		FourHourIsCustom: fourHour.Valid, WeeklyIsCustom: weekly.Valid,
	}, nil
}

// Snapshot measures an account against its budgets. With includeReservations the
// tokens held back for runs in flight count as used.
func (r *RateLimiter) Snapshot(ctx context.Context, userID int64, includeReservations bool) (RateLimitSnapshot, error) {
	limits, err := r.limitsFor(ctx, userID)
	if err != nil {
		return RateLimitSnapshot{}, err
	}
	var reserved int64
	if includeReservations {
		r.mu.Lock()
		reserved = r.reservations[userID]
		r.mu.Unlock()
	}
	snap := RateLimitSnapshot{Limits: limits}
	for _, w := range windows {
		rows, err := r.usageRows(ctx, userID, w.Duration)
		if err != nil {
			return RateLimitSnapshot{}, err
		}
		var committed int64
		for _, row := range rows {
			committed += row.tokens
		}
		used := committed + reserved
		limit := limits.of(w.Key)
		var remaining *int64
		reached := false
		if limit != nil {
			left := max(0, *limit-used)
			remaining, reached = &left, used >= *limit
		}
		// Reservations belong to in-flight runs and are released when those runs
		// finish, so only committed usage has a time-based expiry.
		recovers, reset := recoversAt(rows, w.Duration, committed, limit), fullResetAt(rows, w.Duration)
		if w.Key == "fourHour" {
			snap.Usage.FourHour, snap.Remaining.FourHour, snap.Reached.FourHour = used, remaining, reached
			snap.RecoversAt.FourHour, snap.FullResetAt.FourHour = recovers, reset
		} else {
			snap.Usage.Weekly, snap.Remaining.Weekly, snap.Reached.Weekly = used, remaining, reached
			snap.RecoversAt.Weekly, snap.FullResetAt.Weekly = recovers, reset
		}
	}
	snap.Reached.Any = snap.Reached.FourHour || snap.Reached.Weekly
	return snap, nil
}

// reservationFor is a bounded placeholder: concurrent starts see this run as in
// flight without letting one run consume the account's entire budget.
func reservationFor(l Limits) int64 {
	smallest := int64(math.MaxInt64)
	for _, limit := range []*int64{l.FourHour, l.Weekly} {
		if limit != nil && *limit > 0 && *limit < smallest {
			smallest = *limit
		}
	}
	if smallest == math.MaxInt64 {
		return 1
	}
	return min(MaxRunReservation, max(1, int64(math.Floor(float64(smallest)*0.1))))
}

// Enforce refuses a run when the account has used up a window, and otherwise
// reserves room for it. The returned release must be called when the run ends.
// bypass skips the check (and so does the disabled switch).
func (r *RateLimiter) Enforce(ctx context.Context, userID int64, bypass bool) (snapshot RateLimitSnapshot, release func(), err error) {
	if bypass || r.Config.Disabled {
		snapshot, err = r.Snapshot(ctx, userID, false)
		return snapshot, func() {}, err
	}
	snapshot, err = r.Snapshot(ctx, userID, true)
	if err != nil {
		return snapshot, func() {}, err
	}
	if snapshot.Reached.FourHour {
		return snapshot, func() {}, &RateLimitExceeded{Window: "fourHour", Snapshot: snapshot}
	}
	if snapshot.Reached.Weekly {
		return snapshot, func() {}, &RateLimitExceeded{Window: "weekly", Snapshot: snapshot}
	}
	reserve := reservationFor(snapshot.Limits)
	r.mu.Lock()
	if r.reservations == nil {
		r.reservations = map[int64]int64{}
	}
	r.reservations[userID] += reserve
	r.mu.Unlock()
	return snapshot, func() { r.release(userID, reserve) }, nil
}

func (r *RateLimiter) release(userID, amount int64) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if next := r.reservations[userID] - amount; next > 0 {
		r.reservations[userID] = next
	} else {
		delete(r.reservations, userID)
	}
}
