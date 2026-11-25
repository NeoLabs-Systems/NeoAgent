// Package timeline is the user-wide activity feed: what tasks and runs did and
// when. The task scheduler and the agent engine record into it; the agent's
// prompt reads a short, relevant slice back as situational context. It keeps
// the timeline_events table of the Node server's services/timeline.
package timeline

import (
	"context"
	"database/sql"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

const (
	defaultFeedLimit          = 50
	maxFeedLimit              = 200
	defaultPromptContextLimit = 6
	maxPromptContextLimit     = 12
)

// Service reads and writes the timeline.
type Service struct {
	DB *dbx.DB
	// Now is the clock; nil is the real one.
	Now func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

var spaces = regexp.MustCompile(`\s+`)

// normalizeText collapses white space, trims and cuts to max UTF-16 units.
func normalizeText(v any, max int) string {
	text := jsv.Trim(spaces.ReplaceAllString(jsv.Text(v), " "))
	return jsv.Slice(text, max)
}

// normalizeTimestamp is an ISO time for value, or fallback when it is empty or
// not a date.
func normalizeTimestamp(value string, fallback time.Time) string {
	text := jsv.Trim(value)
	if text == "" {
		return jsv.ISO(fallback)
	}
	if t, ok := jsv.ParseDate(text); ok {
		return jsv.ISO(t)
	}
	return jsv.ISO(fallback)
}

var termSplit = regexp.MustCompile(`[^a-z0-9]+`)

func queryTerms(value string) []string {
	var terms []string
	for _, term := range termSplit.Split(strings.ToLower(normalizeText(value, 240)), -1) {
		if len(term) >= 4 && !slices.Contains(terms, term) {
			terms = append(terms, term)
		}
	}
	return terms
}

// Item is one entry of the feed.
type Item struct {
	ID         int64       `json:"id"`
	SourceKind string      `json:"sourceKind"`
	EventKind  string      `json:"eventKind"`
	OccurredAt string      `json:"occurredAt"`
	Title      string      `json:"title"`
	Summary    string      `json:"summary"`
	AgentID    *string     `json:"agentId"`
	SourceID   *string     `json:"sourceId"`
	Metadata   *jsv.Object `json:"metadata"`
}

type event struct {
	userID     int64
	agentID    string
	sourceKind string
	eventKind  string
	occurredAt string
	title      string
	summary    string
	sourceID   *string
	metadata   *jsv.Object
}

const columns = `id, agent_id, source_kind, event_kind, occurred_at, title, summary, source_id, metadata_json`

type rowScanner interface{ Scan(dest ...any) error }

func scanItem(row rowScanner) (*Item, error) {
	var item Item
	var agent, kind, source, event, occurred, title, summary, metadata sql.NullString
	if err := row.Scan(&item.ID, &agent, &kind, &event, &occurred, &title, &summary, &source, &metadata); err != nil {
		return nil, err
	}
	item.SourceKind, item.EventKind, item.OccurredAt, item.Title, item.Summary = kind.String, event.String, occurred.String, title.String, summary.String
	if agent.Valid && agent.String != "" {
		item.AgentID = &agent.String
	}
	if source.Valid && source.String != "" {
		item.SourceID = &source.String
	}
	if item.Metadata = jsv.ParseObject(metadata.String); item.Metadata == nil {
		item.Metadata = jsv.NewObject()
	}
	return &item, nil
}

func (s *Service) insert(ctx context.Context, e event) (*Item, error) {
	var agent any
	if e.agentID != "" {
		agent = e.agentID
	}
	res, err := s.DB.W.ExecContext(ctx, `INSERT INTO timeline_events (
         user_id, agent_id, source_kind, event_kind, occurred_at, title, summary, source_id, group_key, metadata_json
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		e.userID, agent, jsv.Trim(e.sourceKind), jsv.Trim(e.eventKind), e.occurredAt,
		normalizeText(e.title, 240), normalizeText(e.summary, 1000), e.sourceID, nil, jsv.Stringify(e.metadata))
	if err != nil {
		return nil, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return nil, err
	}
	return scanItem(s.DB.W.QueryRowContext(ctx, `SELECT `+columns+` FROM timeline_events WHERE id = ?`, id))
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// TaskLifecycle describes something that happened to a scheduled task.
type TaskLifecycle struct {
	UserID        int64
	AgentID       string
	TaskID        int64
	TaskName      string
	EventKind     string
	OccurredAt    time.Time // zero means now
	RunID         string
	Reason        string
	Error         string
	TriggerType   string
	TriggerSource string
}

// RecordTaskLifecycle adds a task event (started, completed, skipped, failed).
func (s *Service) RecordTaskLifecycle(ctx context.Context, t TaskLifecycle) (*Item, error) {
	taskLabel := "Task " + strconv.FormatInt(t.TaskID, 10)
	name := normalizeText(firstText(t.TaskName, taskLabel), 180)
	if name == "" {
		name = taskLabel
	}
	occurred := t.OccurredAt
	if occurred.IsZero() {
		occurred = s.now()
	}
	taskID := strconv.FormatInt(t.TaskID, 10)
	return s.insert(ctx, event{
		userID: t.UserID, agentID: t.AgentID, sourceKind: "tasks", eventKind: t.EventKind,
		occurredAt: jsv.ISO(occurred), title: name,
		summary:  normalizeText(firstText(t.Error, t.Reason, t.TriggerType), 240),
		sourceID: &taskID,
		metadata: jsv.NewObject().Set("taskId", float64(t.TaskID)).Set("taskName", name).
			Set("runId", nullIfEmpty(t.RunID)).Set("reason", nullIfEmpty(t.Reason)).Set("error", nullIfEmpty(t.Error)).
			Set("triggerType", nullIfEmpty(t.TriggerType)).Set("triggerSource", nullIfEmpty(t.TriggerSource)),
	})
}

func firstText(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// RunLifecycle describes something that happened to an agent run.
type RunLifecycle struct {
	UserID        int64
	AgentID       string
	RunID         string
	Title         string
	EventKind     string
	OccurredAt    time.Time // zero means now
	Status        string
	TriggerSource string
	Error         string
}

// RecordRunLifecycle adds a run event.
func (s *Service) RecordRunLifecycle(ctx context.Context, r RunLifecycle) (*Item, error) {
	title := normalizeText(firstText(r.Title, "Untitled run"), 180)
	if title == "" {
		title = "Untitled run"
	}
	occurred := r.OccurredAt
	if occurred.IsZero() {
		occurred = s.now()
	}
	var sourceID *string
	if r.RunID != "" {
		sourceID = &r.RunID
	}
	return s.insert(ctx, event{
		userID: r.UserID, agentID: r.AgentID, sourceKind: "runs", eventKind: r.EventKind,
		occurredAt: jsv.ISO(occurred), title: title,
		summary:  normalizeText(firstText(r.Error, r.Status, r.TriggerSource), 240),
		sourceID: sourceID,
		metadata: jsv.NewObject().Set("runId", nullIfEmpty(r.RunID)).Set("title", title).Set("status", nullIfEmpty(r.Status)).
			Set("triggerSource", nullIfEmpty(r.TriggerSource)).Set("error", nullIfEmpty(r.Error)),
	})
}

// ListOptions select feed entries. A Limit of 0 or less means 50; at most 200
// are returned. Sources limits the feed to those source kinds.
type ListOptions struct {
	Limit   int
	Sources []string
}

// List returns the user's newest entries first.
func (s *Service) List(ctx context.Context, userID int64, o ListOptions) ([]*Item, error) {
	limit := defaultFeedLimit
	if o.Limit > 0 {
		limit = min(o.Limit, maxFeedLimit)
	}
	var sources []any
	for _, source := range o.Sources {
		if trimmed := jsv.Trim(source); trimmed != "" {
			sources = append(sources, trimmed)
		}
	}
	query := `SELECT ` + columns + ` FROM timeline_events WHERE user_id = ?`
	args := []any{userID}
	if len(sources) > 0 {
		query += ` AND source_kind IN (` + strings.TrimSuffix(strings.Repeat("?, ", len(sources)), ", ") + `)`
		args = append(args, sources...)
	}
	rows, err := s.DB.R.QueryContext(ctx, query+` ORDER BY occurred_at DESC, id DESC LIMIT ?`, append(args, limit)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []*Item{}
	for rows.Next() {
		item, err := scanItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// PromptOptions shape the context BuildPromptContext writes.
type PromptOptions struct {
	// Limit is how many entries to include: 6 by default, at most 12.
	Limit int
	// Sources default to screen, tasks and runs.
	Sources []string
	// Query favours entries that mention its words.
	Query string
	// AgentID favours that agent's entries.
	AgentID string
}

func formatPromptTimestamp(value string) string {
	if t, ok := jsv.ParseDate(value); ok {
		return strings.Replace(jsv.ISO(t)[:16], "T", " ", 1)
	}
	return jsv.Slice(value, 16)
}

func (it *Item) promptLine() string {
	when := formatPromptTimestamp(it.OccurredAt)
	summary := normalizeText(it.Summary, 140)
	suffix := ""
	if summary != "" {
		suffix = " — " + summary
	}
	if it.SourceKind == "tasks" {
		name := firstText(normalizeText(it.Metadata.Val("taskName"), 120), it.Title)
		run := ""
		if id := normalizeText(it.Metadata.Val("runId"), 80); id != "" {
			run = " · run " + id
		}
		return "- [task " + when + "] " + name + " · " + it.EventKind + run + suffix
	}
	title := firstText(normalizeText(it.Title, 120), "Untitled run")
	return "- [run " + when + "] " + title + " · " + it.EventKind + suffix
}

// BuildPromptContext summarizes recent activity as a few lines for the agent's
// prompt, or "" when there is none.
func (s *Service) BuildPromptContext(ctx context.Context, userID int64, o PromptOptions) (string, error) {
	limit := defaultPromptContextLimit
	if o.Limit > 0 {
		limit = min(o.Limit, maxPromptContextLimit)
	}
	sources := o.Sources
	if len(sources) == 0 {
		sources = []string{"screen", "tasks", "runs"}
	}
	candidates, err := s.List(ctx, userID, ListOptions{Limit: max(limit*3, limit), Sources: sources})
	if err != nil || len(candidates) == 0 {
		return "", err
	}
	terms := queryTerms(jsv.Trim(o.Query))
	preferred := jsv.Trim(o.AgentID)
	type scoredItem struct {
		item  *Item
		index int
		score int
	}
	scored := make([]scoredItem, len(candidates))
	for i, item := range candidates {
		haystack := strings.ToLower(strings.Join(nonEmpty(
			normalizeText(item.SourceKind, 400), normalizeText(item.EventKind, 400), normalizeText(item.Title, 400), normalizeText(item.Summary, 400),
			normalizeText(item.Metadata.Val("appName"), 400), normalizeText(item.Metadata.Val("windowTitle"), 400),
			normalizeText(item.Metadata.Val("deviceLabel"), 400), normalizeText(item.Metadata.Val("previewText"), 400),
			normalizeText(item.Metadata.Val("taskName"), 400),
		), " "))
		score := 0
		for _, term := range terms {
			if strings.Contains(haystack, term) {
				score++
			}
		}
		if preferred != "" && item.AgentID != nil && *item.AgentID == preferred {
			score++
		}
		scored[i] = scoredItem{item, i, score}
	}
	relevant := scored
	if len(terms) > 0 {
		sort.SliceStable(scored, func(a, b int) bool {
			if scored[a].score != scored[b].score {
				return scored[a].score > scored[b].score
			}
			return scored[a].index < scored[b].index
		})
		relevant = nil
		for _, e := range scored {
			if e.score > 0 {
				relevant = append(relevant, e)
			}
		}
	}
	chosen := relevant
	if len(chosen) == 0 {
		chosen = scored
	}
	if len(chosen) > limit {
		chosen = chosen[:limit]
	}
	selected := make([]*Item, len(chosen))
	for i, e := range chosen {
		selected[i] = e.item
	}
	sort.SliceStable(selected, func(a, b int) bool { return selected[a].OccurredAt < selected[b].OccurredAt })
	lines := []string{"Recent timeline context (user-wide, recent activity only; use as soft situational context, not as authoritative proof):"}
	for _, item := range selected {
		lines = append(lines, item.promptLine())
	}
	return strings.Join(lines, "\n"), nil
}

func nonEmpty(values ...string) []string {
	var out []string
	for _, v := range values {
		if v != "" {
			out = append(out, v)
		}
	}
	return out
}
