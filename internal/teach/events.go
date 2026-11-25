// Package teach is Teach Mode: the user demonstrates a task on the agent's
// computer, the service records a semantic trace (windows, UI elements, shell
// and file changes, a few screenshots) in an encrypted temporary file, and a
// learner turns the trace into a reusable skill. The recording is purged when
// the session ends.
package teach

import (
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"unicode/utf16"
)

// Position is where a pointer event happened (null when unknown).
type Position struct {
	X *int `json:"x"`
	Y *int `json:"y"`
}

// Modifiers are the held modifier keys of a key event.
type Modifiers struct {
	Alt   bool `json:"alt"`
	Ctrl  bool `json:"ctrl"`
	Meta  bool `json:"meta"`
	Shift bool `json:"shift"`
}

// BrowserContext is what the browser showed at an event.
type BrowserContext struct {
	PageInfo any    `json:"pageInfo"`
	Content  string `json:"content"`
	Elements []any  `json:"elements"`
}

// Context is the semantic state of the computer at an event.
type Context struct {
	ActiveWindow  *string         `json:"activeWindow"`
	Accessibility []any           `json:"accessibility"`
	ShellEvents   []any           `json:"shellEvents"`
	Files         []any           `json:"files"`
	Browser       *BrowserContext `json:"browser"`
}

// Event is one recorded step.
type Event struct {
	Sequence   int        `json:"sequence"`
	Type       string     `json:"type"`
	AtMs       int64      `json:"atMs"`
	Position   *Position  `json:"position,omitempty"`
	Button     *float64   `json:"button,omitempty"`
	Key        string     `json:"key,omitempty"`
	Modifiers  *Modifiers `json:"modifiers,omitempty"`
	Value      string     `json:"value,omitempty"`
	Detail     string     `json:"detail,omitempty"`
	Screenshot string     `json:"screenshot,omitempty"`
	Context    *Context   `json:"context,omitempty"`
}

// normalize is String(value || ”).trim().slice(0, max) for a JSON value.
func normalize(value any, max int) string {
	var s string
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		s = v
	case bool:
		if !v {
			return ""
		}
		s = "true"
	case float64:
		if v == 0 || math.IsNaN(v) {
			return ""
		}
		b, _ := json.Marshal(v)
		s = string(b)
	case map[string]any:
		s = "[object Object]"
	default:
		s = fmt.Sprint(v)
	}
	return truncateUnits(strings.TrimSpace(s), max)
}

// truncateUnits keeps the first n UTF-16 code units, as JS String.slice does.
func truncateUnits(s string, n int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= n {
		return s
	}
	return string(utf16.Decode(units[:n]))
}

// TimelineEntry is an event as the skill learner sees it.
type TimelineEntry struct {
	Sequence  int
	Type      string
	AtMs      int64
	Key       string
	Modifiers *Modifiers
	Detail    string
	Context   Context
}

// MarshalJSON writes the entry in the key order Node used.
func (t TimelineEntry) MarshalJSON() ([]byte, error) {
	type full struct {
		Sequence  int     `json:"sequence"`
		Type      string  `json:"type"`
		AtMs      int64   `json:"atMs"`
		Key       *string `json:"key,omitempty"`
		Modifiers any     `json:"modifiers,omitempty"`
		Detail    *string `json:"detail,omitempty"`
		Context   Context `json:"context"`
	}
	out := full{Sequence: t.Sequence, Type: t.Type, AtMs: t.AtMs, Context: t.Context}
	if t.Key != "" {
		// A key event without modifiers (not recorded by this service) shows {}.
		out.Key, out.Modifiers = &t.Key, struct{}{}
		if t.Modifiers != nil {
			out.Modifiers = *t.Modifiers
		}
	}
	if t.Detail != "" {
		out.Detail = &t.Detail
	}
	return json.Marshal(out)
}

func headAny(list []any, n int) []any {
	if list == nil {
		return []any{}
	}
	return list[:min(len(list), n)]
}

func tailAny(list []any, n int) []any {
	if list == nil {
		return []any{}
	}
	return list[max(0, len(list)-n):]
}

// BuildTimeline samples at most 120 events evenly and trims their context for
// the learner.
func BuildTimeline(events []*Event) []TimelineEntry {
	const maximum = 120
	var indexes []int
	if len(events) <= maximum {
		for i := range events {
			indexes = append(indexes, i)
		}
	} else {
		seen := map[int]bool{}
		for i := 0; i < maximum; i++ {
			idx := int(math.Floor(float64(i)*float64(len(events)-1)/float64(maximum-1) + 0.5))
			if !seen[idx] {
				seen[idx] = true
				indexes = append(indexes, idx)
			}
		}
	}
	out := make([]TimelineEntry, 0, len(indexes))
	for _, i := range indexes {
		e := events[i]
		ctx := Context{}
		if e.Context != nil {
			ctx = *e.Context
		}
		entry := TimelineEntry{
			Sequence: e.Sequence, Type: e.Type, AtMs: e.AtMs,
			Key: e.Key, Modifiers: e.Modifiers, Detail: truncateUnits(e.Detail, 300),
			Context: Context{
				ActiveWindow:  ctx.ActiveWindow,
				Accessibility: headAny(ctx.Accessibility, 30),
				ShellEvents:   tailAny(ctx.ShellEvents, 10),
				Files:         headAny(ctx.Files, 30),
			},
		}
		if b := ctx.Browser; b != nil {
			entry.Context.Browser = &BrowserContext{PageInfo: b.PageInfo, Content: truncateUnits(b.Content, 1000), Elements: headAny(b.Elements, 30)}
		}
		out = append(out, entry)
	}
	return out
}

// ParseEvaluationResult unwraps what a browser evaluate call returned: the
// "result" member when there is one, parsed as JSON when it is a JSON string.
func ParseEvaluationResult(value any) any {
	raw := value
	if m, ok := value.(map[string]any); ok && m["result"] != nil {
		raw = m["result"]
	}
	s, ok := raw.(string)
	if !ok {
		return raw
	}
	var parsed any
	if err := json.Unmarshal([]byte(s), &parsed); err != nil {
		return s
	}
	return parsed
}
