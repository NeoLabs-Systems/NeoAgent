// Package calendarwindow shapes the events a calendar tool lists the way the
// Node server's calendar_window.js does: timed events that start in the window
// first, those already running next, all-day events apart, with counts the
// model can reason from.
package calendarwindow

import (
	"strings"
	"time"
)

// Event is what the window logic needs of a provider's event summary.
type Event interface {
	IsAllDay() bool
	StartText() string
	EndText() string
}

// Window is the queried time range; blank bounds are null.
type Window struct {
	TimeMin *string `json:"timeMin"`
	TimeMax *string `json:"timeMax"`
}

// Listed is the answer of a list call. The member order is the order the
// model has always seen.
type Listed[E Event] struct {
	Count                    int    `json:"count"`
	TimedCount               int    `json:"timedCount"`
	UpcomingTimedCount       int    `json:"upcomingTimedCount"`
	OngoingTimedCount        int    `json:"ongoingTimedCount"`
	AllDayCount              int    `json:"allDayCount"`
	HasTimedEvents           bool   `json:"hasTimedEvents"`
	HasUpcomingTimedEvents   bool   `json:"hasUpcomingTimedEvents"`
	HasOngoingTimedEvents    bool   `json:"hasOngoingTimedEvents"`
	HasOnlyOngoingTimedEvent bool   `json:"hasOnlyOngoingTimedEvents"`
	HasOnlyAllDayEvents      bool   `json:"hasOnlyAllDayEvents"`
	NextUpcomingTimedEvent   *E     `json:"nextUpcomingTimedEvent"`
	NextTimedEvent           *E     `json:"nextTimedEvent"`
	QueryWindow              Window `json:"queryWindow"`
	UpcomingTimedEvents      []E    `json:"upcomingTimedEvents"`
	OngoingTimedEvents       []E    `json:"ongoingTimedEvents"`
	TimedEvents              []E    `json:"timedEvents"`
	AllDayEvents             []E    `json:"allDayEvents"`
	Events                   []E    `json:"events"`
	OverlapCount             int    `json:"overlapCount"`
	OmittedOngoingTimedCount int    `json:"omittedOngoingTimedCount"`
	OmittedAllDayCount       int    `json:"omittedAllDayCount"`
	HasOnlyOmittedOverlaps   bool   `json:"hasOnlyOmittedOverlaps"`
	WindowMode               string `json:"windowMode"`
}

// Options are the arguments of Finalize.
type Options struct {
	TimeMin, TimeMax string
	// IncludeOngoing and IncludeAllDay are the include_ongoing and
	// include_all_day arguments of the call.
	IncludeOngoing, IncludeAllDay bool
	// AutomaticReminder is a scheduled task asking for events: already-started
	// timed events are dropped, judged against ScheduledAt.
	AutomaticReminder bool
	ScheduledAt       string
}

func blankToNil(s string) *string {
	if s = strings.TrimSpace(s); s == "" {
		return nil
	}
	return &s
}

// ParseMillis is Date.parse for the ISO forms calendars use. A time without a
// zone counts as UTC.
func ParseMillis(s string) (int64, bool) {
	s = strings.TrimSpace(s)
	for _, layout := range []string{time.RFC3339Nano, "2006-01-02T15:04:05.999999999", "2006-01-02T15:04", "2006-01-02"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UnixMilli(), true
		}
	}
	return 0, false
}

func nonNil[E any](s []E) []E {
	if s == nil {
		return []E{}
	}
	return s
}

func filter[E Event](events []E, keep func(E) bool) []E {
	out := []E{}
	for _, e := range events {
		if keep(e) {
			out = append(out, e)
		}
	}
	return out
}

// Finalize partitions listed events for a window and applies the list mode:
// with a bounded window only events starting inside it are returned unless
// ongoing or all-day events were asked for.
func Finalize[E Event](events []E, o Options) Listed[E] {
	window := Window{TimeMin: blankToNil(o.TimeMin), TimeMax: blankToNil(o.TimeMax)}
	hasStartArg := window.TimeMin != nil
	listed := events
	if o.AutomaticReminder {
		if instant, ok := ParseMillis(o.ScheduledAt); ok {
			listed = filter(events, func(e E) bool {
				if e.IsAllDay() {
					return true
				}
				start, ok := ParseMillis(e.StartText())
				return ok && start > instant
			})
		}
	}

	timed := filter(listed, func(e E) bool { return !e.IsAllDay() })
	allDay := filter(listed, func(e E) bool { return e.IsAllDay() })
	var winStart, winEnd int64
	var hasStart, hasEnd bool
	if window.TimeMin != nil {
		winStart, hasStart = ParseMillis(*window.TimeMin)
	}
	if window.TimeMax != nil {
		winEnd, hasEnd = ParseMillis(*window.TimeMax)
	}
	ongoing := []E{}
	if hasStart {
		ongoing = filter(timed, func(e E) bool {
			start, ok := ParseMillis(e.StartText())
			if !ok || start >= winStart {
				return false
			}
			end, endOK := ParseMillis(e.EndText())
			return !endOK || end > winStart
		})
	}
	upcoming := filter(timed, func(e E) bool {
		start, ok := ParseMillis(e.StartText())
		return ok && (!hasStart || start >= winStart) && (!hasEnd || start < winEnd)
	})

	includeOngoing := !hasStartArg || o.IncludeOngoing
	includeAllDay := !hasStartArg || o.IncludeAllDay
	keptOngoing, keptAllDay := []E{}, []E{}
	omittedOngoing, omittedAllDay := len(ongoing), len(allDay)
	if includeOngoing {
		keptOngoing, omittedOngoing = ongoing, 0
	}
	if includeAllDay {
		keptAllDay, omittedAllDay = allDay, 0
	}
	timedOut := append(append([]E{}, upcoming...), keptOngoing...)
	out := Listed[E]{
		Count:                    len(timedOut) + len(keptAllDay),
		TimedCount:               len(timedOut),
		UpcomingTimedCount:       len(upcoming),
		OngoingTimedCount:        len(keptOngoing),
		AllDayCount:              len(keptAllDay),
		HasTimedEvents:           len(timedOut) > 0,
		HasUpcomingTimedEvents:   len(upcoming) > 0,
		HasOngoingTimedEvents:    len(keptOngoing) > 0,
		HasOnlyOngoingTimedEvent: false,
		HasOnlyAllDayEvents:      len(timedOut) == 0 && len(keptAllDay) > 0,
		QueryWindow:              window,
		UpcomingTimedEvents:      nonNil(upcoming),
		OngoingTimedEvents:       keptOngoing,
		TimedEvents:              timedOut,
		AllDayEvents:             keptAllDay,
		Events:                   append(append([]E{}, timedOut...), keptAllDay...),
		OverlapCount:             len(listed),
		OmittedOngoingTimedCount: omittedOngoing,
		OmittedAllDayCount:       omittedAllDay,
		HasOnlyOmittedOverlaps:   len(upcoming) == 0 && omittedOngoing+omittedAllDay > 0,
		WindowMode:               "starts_within_window",
	}
	if includeOngoing {
		out.WindowMode = "overlap"
	}
	if len(upcoming) > 0 {
		first := upcoming[0]
		out.NextUpcomingTimedEvent, out.NextTimedEvent = &first, &first
	}
	return out
}

// Summary is an event as the calendar tools show it to the model, whichever
// provider it came from. An event is all-day when its start carries a date but
// no time: providers return every all-day or multi-day event that overlaps a
// window, so the flag lets a caller tell an appointment from a marker.
type Summary struct {
	ID          string   `json:"id"`
	Status      *string  `json:"status"`
	Summary     string   `json:"summary"`
	Description *string  `json:"description"`
	Location    *string  `json:"location"`
	HTMLLink    *string  `json:"htmlLink"`
	AllDay      bool     `json:"allDay"`
	Start       *string  `json:"start"`
	End         *string  `json:"end"`
	Attendees   []string `json:"attendees"`
}

func (e Summary) IsAllDay() bool { return e.AllDay }

func (e Summary) StartText() string { return deref(e.Start) }

func (e Summary) EndText() string { return deref(e.End) }

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
