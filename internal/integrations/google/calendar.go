package google

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/calendarwindow"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

func summarizeEvent(event map[string]any) calendarwindow.Summary {
	pick := func(key string) *string {
		if v := integrations.Get(event, key); integrations.Truthy(v) {
			s := integrations.Str(v)
			return &s
		}
		return nil
	}
	when := func(key string) *string {
		if v := integrations.Or(integrations.Get(event, key, "dateTime"), integrations.Get(event, key, "date"), nil); integrations.Truthy(v) {
			s := integrations.Str(v)
			return &s
		}
		return nil
	}
	attendees := []string{}
	if list, ok := event["attendees"].([]any); ok {
		for _, a := range list {
			if email := integrations.Get(a, "email"); integrations.Truthy(email) {
				attendees = append(attendees, integrations.Str(email))
			}
		}
	}
	return calendarwindow.Summary{
		ID: textOf(event["id"]), Status: pick("status"), Summary: textOf(event["summary"]),
		Description: pick("description"), Location: pick("location"), HTMLLink: pick("htmlLink"),
		AllDay: integrations.Truthy(integrations.Get(event, "start", "date")) && !integrations.Truthy(integrations.Get(event, "start", "dateTime")),
		Start:  when("start"), End: when("end"), Attendees: attendees,
	}
}

var eventsPath = regexp.MustCompile(`(?i)/calendar/v3/calendars/[^/]+/events(?:\?|$)`)

func (s *session) calendarURL(calendarID, rest string) string {
	return s.p.ep.api + "/calendar/v3/calendars/" + url.PathEscape(calendarID) + rest
}

func timeBound(args map[string]any, snake, camel string) any {
	if v := integrations.Or(args[snake], args[camel], nil); integrations.Truthy(v) {
		return v
	}
	return nil
}

func attendeeList(value any) []map[string]string {
	out := []map[string]string{}
	for _, email := range coerceStringList(value) {
		out = append(out, map[string]string{"email": email})
	}
	return out
}

func (s *session) calendar(ctx context.Context, name string, args map[string]any) (any, error) {
	calendarID := orDefault(trimmed(args["calendar_id"]), "primary")
	timeMin := timeBound(args, "time_min", "timeMin")
	timeMax := timeBound(args, "time_max", "timeMax")
	run := integrations.RunFrom(ctx)

	switch name {
	case "google_workspace_calendar_list_events":
		if run.Automatic() && (timeMin == nil || timeMax == nil) {
			return nil, errors.New("Automatic calendar checks require both time_min and time_max. Query a bounded event-start window derived from the task schedule and requested reminder offset.")
		}
		query := oauthclient.Query{}
		if q := trimmed(args["query"]); q != "" {
			query = append(query, [2]string{"q", q})
		}
		if timeMin != nil {
			query = append(query, [2]string{"timeMin", integrations.Str(timeMin)})
		}
		if timeMax != nil {
			query = append(query, [2]string{"timeMax", integrations.Str(timeMax)})
		}
		query = append(query, [2]string{"singleEvents", "true"}, [2]string{"orderBy", "startTime"},
			[2]string{"maxResults", integrations.Clamp(args["max_results"], 10, 1, 50)})
		res, err := s.call(ctx, "GET", s.calendarURL(calendarID, "/events"), query, nil)
		if err != nil {
			return nil, err
		}
		events := []calendarwindow.Summary{}
		if items, ok := res.object()["items"].([]any); ok {
			for _, item := range items {
				if m, ok := item.(map[string]any); ok {
					events = append(events, summarizeEvent(m))
				}
			}
		}
		return calendarwindow.Finalize(events, calendarwindow.Options{
			TimeMin: textOf(timeMin), TimeMax: textOf(timeMax),
			IncludeOngoing: args["include_ongoing"] == true, IncludeAllDay: args["include_all_day"] == true,
			AutomaticReminder: run.Automatic() && args["include_ongoing"] != true, ScheduledAt: run.ScheduledAt,
		}), nil

	case "google_workspace_calendar_create_event":
		body := map[string]any{
			"summary": textOf(args["summary"]),
			"start":   dateTime(args["start"], args["timezone"], ""),
			"end":     dateTime(args["end"], args["timezone"], ""),
		}
		if integrations.Truthy(args["description"]) {
			body["description"] = args["description"]
		}
		if integrations.Truthy(args["location"]) {
			body["location"] = args["location"]
		}
		body["attendees"] = attendeeList(args["attendees"])
		res, err := s.call(ctx, "POST", s.calendarURL(calendarID, "/events"), nil, body)
		if err != nil {
			return nil, err
		}
		return summarizeEvent(res.object()), nil

	case "google_workspace_calendar_update_event":
		eventID := textOf(args["event_id"])
		path := "/events/" + url.PathEscape(eventID)
		existing, err := s.call(ctx, "GET", s.calendarURL(calendarID, path), nil, nil)
		if err != nil {
			return nil, err
		}
		next := existing.object()
		if has(args, "summary") {
			next["summary"] = textOf(args["summary"])
		}
		if has(args, "description") {
			next["description"] = textOf(args["description"])
		}
		if has(args, "location") {
			next["location"] = textOf(args["location"])
		}
		if has(args, "start") {
			next["start"] = dateTime(args["start"], args["timezone"], integrations.Str(integrations.Get(existing.object(), "start", "timeZone")))
		}
		if has(args, "end") {
			next["end"] = dateTime(args["end"], args["timezone"], integrations.Str(integrations.Get(existing.object(), "end", "timeZone")))
		}
		if has(args, "attendees") {
			next["attendees"] = attendeeList(args["attendees"])
		}
		res, err := s.call(ctx, "PUT", s.calendarURL(calendarID, path), nil, next)
		if err != nil {
			return nil, err
		}
		return summarizeEvent(res.object()), nil

	case "google_workspace_calendar_delete_event":
		eventID := textOf(args["event_id"])
		if _, err := s.call(ctx, "DELETE", s.calendarURL(calendarID, "/events/"+url.PathEscape(eventID)), nil, nil); err != nil {
			return nil, err
		}
		return struct {
			Deleted bool   `json:"deleted"`
			EventID string `json:"eventId"`
		}{true, eventID}, nil

	case "google_workspace_calendar_free_busy":
		items := []map[string]string{}
		for _, id := range coerceStringList(args["calendar_ids"]) {
			items = append(items, map[string]string{"id": id})
		}
		if len(items) == 0 {
			items = append(items, map[string]string{"id": "primary"})
		}
		body := map[string]any{"timeMin": textOf(timeMin), "timeMax": textOf(timeMax)}
		if integrations.Truthy(args["timezone"]) {
			body["timeZone"] = args["timezone"]
		}
		body["items"] = items
		res, err := s.call(ctx, "POST", s.p.ep.api+"/calendar/v3/freeBusy", nil, body)
		if err != nil {
			return nil, err
		}
		calendars := integrations.Or(res.object()["calendars"], map[string]any{})
		return map[string]any{"calendars": calendars}, nil

	case "google_workspace_calendar_api_request":
		if run.Automatic() && strings.ToUpper(strings.TrimSpace(orDefault(textOf(args["method"]), "GET"))) == "GET" &&
			eventsPath.MatchString(textOf(args["path"])) {
			return nil, errors.New("Automatic calendar checks must use google_workspace_calendar_list_events with explicit time_min and time_max bounds.")
		}
		return s.apiRequest(ctx, args, s.p.ep.api)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}

// dateTime is {dateTime, timeZone?}: the argument's time zone, else the
// fallback (the event's own zone on update).
func dateTime(value, zone any, fallbackZone string) map[string]string {
	out := map[string]string{"dateTime": textOf(value)}
	switch {
	case integrations.Truthy(zone):
		out["timeZone"] = integrations.Str(zone)
	case fallbackZone != "":
		out["timeZone"] = fallbackZone
	}
	return out
}
