package models

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"reflect"
	"testing"
)

type snapshotJSON struct {
	Limits struct {
		FourHour         *int64 `json:"fourHour"`
		Weekly           *int64 `json:"weekly"`
		FourHourIsCustom bool   `json:"fourHourIsCustom"`
		WeeklyIsCustom   bool   `json:"weeklyIsCustom"`
	} `json:"limits"`
	Usage     WindowValues[int64]  `json:"usage"`
	Remaining WindowValues[*int64] `json:"remaining"`
	Reached   struct {
		FourHour bool `json:"fourHour"`
		Weekly   bool `json:"weekly"`
		Any      bool `json:"any"`
	} `json:"reached"`
	RecoversAt  WindowValues[*string] `json:"recoversAt"`
	FullResetAt WindowValues[*string] `json:"fullResetAt"`
}

func toJSONShape(s RateLimitSnapshot) snapshotJSON {
	var out snapshotJSON
	out.Limits.FourHour, out.Limits.Weekly = s.Limits.FourHour, s.Limits.Weekly
	out.Limits.FourHourIsCustom, out.Limits.WeeklyIsCustom = s.Limits.FourHourIsCustom, s.Limits.WeeklyIsCustom
	out.Usage, out.Remaining = s.Usage, s.Remaining
	out.Reached.FourHour, out.Reached.Weekly, out.Reached.Any = s.Reached.FourHour, s.Reached.Weekly, s.Reached.Any
	out.RecoversAt, out.FullResetAt = s.RecoversAt, s.FullResetAt
	return out
}

func TestRateLimitsMatchNode(t *testing.T) {
	var v struct {
		Snapshots []struct {
			Env      map[string]string `json:"env"`
			User     int64             `json:"user"`
			Snapshot snapshotJSON      `json:"snapshot"`
		} `json:"snapshots"`
		Enforce []struct {
			User     int64               `json:"user"`
			Bypass   bool                `json:"bypass"`
			OK       bool                `json:"ok"`
			Snapshot snapshotJSON        `json:"snapshot"`
			Bypassed bool                `json:"bypassed"`
			Message  string              `json:"message"`
			Code     string              `json:"code"`
			Status   int                 `json:"statusCode"`
			Window   string              `json:"window"`
			After    WindowValues[int64] `json:"after"`
		} `json:"enforce"`
		AfterRelease []WindowValues[int64] `json:"afterRelease"`
		Disabled     bool                  `json:"disabled"`
	}
	raw, err := os.ReadFile("testdata/ratelimits.json")
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	db := openDB(t)
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (3, 'c', 'x'), (4, 'd', 'x')`); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		`UPDATE users SET rate_limit_4h = 500, rate_limit_weekly = 5000 WHERE id = 2`,
		`UPDATE users SET rate_limit_4h = 0, rate_limit_weekly = -1 WHERE id = 3`,
		`INSERT INTO agent_runs (id, user_id, total_tokens, created_at) VALUES
		 ('r1', 1, 1000, '2099-01-01 10:00:00'), ('r2', 1, 2000, '2099-01-01 11:00:00'), ('r3', 1, 0, '2099-01-01 12:00:00'), ('r4', 1, 500, '2000-01-01 00:00:00'),
		 ('r5', 2, 300, '2099-03-01 10:00:00'), ('r6', 2, 300, '2099-03-01 10:30:00'), ('r7', 2, 100, '2099-03-01 11:00:00'),
		 ('r8', 3, 9999999, '2099-04-01 09:00:00'), ('r9', 4, 5, '2099-05-01T09:00:00Z')`,
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	for _, c := range v.Snapshots {
		limiter := &RateLimiter{DB: db, Config: RateLimitConfigFromEnv(func(k string) string { return c.Env[k] })}
		got, err := limiter.Snapshot(ctx, c.User, false)
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(toJSONShape(got), c.Snapshot) {
			gj, _ := json.Marshal(toJSONShape(got))
			wj, _ := json.Marshal(c.Snapshot)
			t.Errorf("env %v user %d:\n got  %s\n want %s", c.Env, c.User, gj, wj)
		}
	}
	limiter := &RateLimiter{DB: db, Config: RateLimitConfigFromEnv(func(k string) string {
		return map[string]string{"NEOAGENT_RATE_LIMIT_4H": "2000", "NEOAGENT_RATE_LIMIT_WEEKLY": "100000"}[k]
	})}
	var releases []func()
	for i, c := range v.Enforce {
		snapshot, release, err := limiter.Enforce(ctx, c.User, c.Bypass)
		if c.OK {
			if err != nil {
				t.Fatalf("step %d: unexpected %v", i, err)
			}
			releases = append(releases, release)
			if !reflect.DeepEqual(toJSONShape(snapshot), c.Snapshot) {
				t.Errorf("step %d: snapshot differs", i)
			}
		} else {
			var exceeded *RateLimitExceeded
			if !errors.As(err, &exceeded) || exceeded.Error() != c.Message || exceeded.Code() != c.Code || exceeded.StatusCode() != c.Status || exceeded.Window != c.Window {
				t.Errorf("step %d: error %v, want %q %s %s", i, err, c.Message, c.Code, c.Window)
			}
		}
		after, _ := limiter.Snapshot(ctx, c.User, true)
		if after.Usage != c.After {
			t.Errorf("step %d: usage with reservations %+v, want %+v", i, after.Usage, c.After)
		}
	}
	for _, release := range releases {
		release()
	}
	for i, user := range []int64{1, 2, 3} {
		after, _ := limiter.Snapshot(ctx, user, true)
		if after.Usage != v.AfterRelease[i] {
			t.Errorf("after release user %d: %+v, want %+v", user, after.Usage, v.AfterRelease[i])
		}
	}
	disabled := &RateLimiter{DB: db, Config: RateLimitConfigFromEnv(func(k string) string {
		return map[string]string{"NEOAGENT_DISABLE_RATE_LIMITS": "TRUE", "NEOAGENT_RATE_LIMIT_4H": "1"}[k]
	})}
	if _, _, err := disabled.Enforce(ctx, 1, false); err != nil || !v.Disabled {
		t.Errorf("disabled limits must not refuse: %v", err)
	}
}
