package email

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
	"github.com/emersion/go-ical"
	"github.com/teambition/rrule-go"
)

const (
	maxFeedBytes          = 10 * 1024 * 1024
	maxEvents             = 500
	maxOccurrencesPerItem = 5000
	feedService           = "Calendar link"
)

var webcal = regexp.MustCompile(`(?i)^webcals?://`)

// normalizeFeedURL reads an iCal address as calendar apps give it.
func normalizeFeedURL(value any) (string, error) {
	raw := webcal.ReplaceAllString(text(value), "https://")
	u, err := url.Parse(raw)
	if err != nil || !u.IsAbs() || u.Host == "" {
		return "", errors.New("Paste the calendar's full iCal address.")
	}
	if (u.Scheme != "https" && u.Scheme != "http") || u.User != nil {
		return "", errors.New("The iCal address must start with https:// or webcal://.")
	}
	if u.Path == "" {
		u.Path = "/"
	}
	return u.String(), nil
}

// fetchFeed downloads and parses a feed through the SSRF-safe client.
func (p *Provider) fetchFeed(ctx context.Context, feedURL string) (*ical.Calendar, error) {
	resp, err := p.svc.Client(feedService).Do(ctx, oauthclient.Request{URL: feedURL,
		Header: map[string]string{"Accept": "text/calendar, */*"}, MaxBytes: maxFeedBytes})
	if err != nil {
		var coded interface{ Code() string }
		if errors.As(err, &coded) && coded.Code() == "INTEGRATION_RESPONSE_TOO_LARGE" {
			return nil, errors.New("This calendar is too large to read.")
		}
		return nil, err
	}
	if resp.Status < 200 || resp.Status >= 300 {
		return nil, fmt.Errorf("The calendar link answered %d. Check that the address is still shared.", resp.Status)
	}
	cal, err := ical.NewDecoder(bytes.NewReader(resp.Body)).Decode()
	if err != nil || cal == nil {
		return nil, errors.New("That address did not return an iCal calendar.")
	}
	return cal, nil
}

func calendarName(cal *ical.Calendar) string {
	if prop := cal.Props.Get("X-WR-CALNAME"); prop != nil {
		v, _ := prop.Text()
		return strings.TrimSpace(v)
	}
	return ""
}

// stamp is a DATE or DATE-TIME value: a time and whether it is all-day. A
// TZID Go does not know (a Windows zone name) reads as floating local time.
type stamp struct {
	t      time.Time
	isDate bool
}

func readStamp(prop *ical.Prop) (stamp, bool) {
	if prop == nil {
		return stamp{}, false
	}
	isDate := prop.ValueType() == ical.ValueDate || (prop.ValueType() == ical.ValueDefault && len(prop.Value) == 8)
	t, err := prop.DateTime(time.Local)
	if err != nil && prop.Params.Get(ical.PropTimezoneID) != "" {
		t, err = time.ParseInLocation("20060102T150405", prop.Value, time.Local)
	}
	if err != nil {
		return stamp{}, false
	}
	return stamp{t: t, isDate: isDate}, true
}

func (s stamp) when() string {
	if s.isDate {
		return s.t.Format("2006-01-02")
	}
	return s.t.UTC().Format("2006-01-02T15:04:05.000Z")
}

func propText(e *ical.Component, name string) string {
	if prop := e.Props.Get(name); prop != nil {
		v, _ := prop.Text()
		return v
	}
	return ""
}

type detail struct {
	item       *ical.Component
	start, end stamp
}

func endOf(c *ical.Component, start stamp) stamp {
	if end, ok := readStamp(c.Props.Get(ical.PropDateTimeEnd)); ok {
		return end
	}
	if dur := c.Props.Get(ical.PropDuration); dur != nil {
		if d, err := dur.Duration(); err == nil {
			return stamp{t: start.t.Add(d), isDate: start.isDate}
		}
	}
	if start.isDate {
		return stamp{t: start.t.AddDate(0, 0, 1), isDate: true}
	}
	return start
}

func occurrence(d detail, name string) dyn.Ordered {
	notes, _ := sliceUTF16(strings.TrimSpace(propText(d.item, ical.PropDescription)), 1000)
	var calendar any
	if name != "" {
		calendar = name
	}
	return dyn.Ordered{
		{Key: "calendar", Value: calendar},
		{Key: "title", Value: strings.TrimSpace(propText(d.item, ical.PropSummary))},
		{Key: "start", Value: d.start.when()},
		{Key: "end", Value: d.end.when()},
		{Key: "allDay", Value: d.start.isDate},
		{Key: "location", Value: orNull(strings.TrimSpace(propText(d.item, ical.PropLocation)))},
		{Key: "notes", Value: orNull(notes)},
	}
}

// eventsBetween is every occurrence overlapping [start, end), soonest first.
func eventsBetween(cal *ical.Calendar, start, end time.Time) []dyn.Ordered {
	name := calendarName(cal)
	var bases, exceptions []*ical.Component
	for _, c := range cal.Children {
		if c.Name != ical.CompEvent {
			continue
		}
		if c.Props.Get(ical.PropRecurrenceID) != nil {
			exceptions = append(exceptions, c)
		} else {
			bases = append(bases, c)
		}
	}
	found := []dyn.Ordered{}
	for _, base := range bases {
		first, ok := readStamp(base.Props.Get(ical.PropDateTimeStart))
		if !ok {
			continue
		}
		baseEnd := endOf(base, first)
		roption, err := base.Props.RecurrenceRule()
		if err != nil || roption == nil {
			if first.t.Before(end) && baseEnd.t.After(start) {
				found = append(found, occurrence(detail{base, first, baseEnd}, name))
			}
			continue
		}
		uid := propText(base, ical.PropUID)
		moved := map[int64]*ical.Component{}
		for _, ex := range exceptions {
			if propText(ex, ical.PropUID) != uid {
				continue
			}
			if rid, ok := readStamp(ex.Props.Get(ical.PropRecurrenceID)); ok {
				moved[rid.t.Unix()] = ex
			}
		}
		roption.Dtstart = first.t
		rule, err := rrule.NewRRule(*roption)
		if err != nil {
			continue
		}
		set := rrule.Set{}
		set.RRule(rule)
		set.DTStart(first.t)
		for _, ex := range base.Props.Values(ical.PropExceptionDates) {
			for _, value := range strings.Split(ex.Value, ",") {
				one := ex
				one.Value = value
				if s, ok := readStamp(&one); ok {
					set.ExDate(s.t)
				}
			}
		}
		for _, rd := range base.Props.Values(ical.PropRecurrenceDates) {
			if s, ok := readStamp(&rd); ok {
				set.RDate(s.t)
			}
		}
		duration := baseEnd.t.Sub(first.t)
		next := set.Iterator()
		for step := 0; step < maxOccurrencesPerItem; step++ {
			t, more := next()
			if !more || !t.Before(end) {
				break
			}
			d := detail{item: base, start: stamp{t: t, isDate: first.isDate}, end: stamp{t: t.Add(duration), isDate: first.isDate}}
			if ex, ok := moved[t.Unix()]; ok {
				if s, ok := readStamp(ex.Props.Get(ical.PropDateTimeStart)); ok {
					d = detail{item: ex, start: s, end: endOf(ex, s)}
				}
			}
			if d.end.t.After(start) {
				found = append(found, occurrence(d, name))
			}
		}
	}
	sort.SliceStable(found, func(i, j int) bool { return found[i].Get("start").(string) < found[j].Get("start").(string) })
	if len(found) > maxEvents {
		found = found[:maxEvents]
	}
	return found
}

func feedMatches(event dyn.Ordered, query any) bool {
	needle := strings.ToLower(text(query))
	if needle == "" {
		return true
	}
	for _, k := range []string{"title", "location", "notes"} {
		if strings.Contains(strings.ToLower(text(event.Get(k))), needle) {
			return true
		}
	}
	return false
}

func isoArg(value any, name string) (time.Time, error) {
	ms, ok := jsx.ParseDate(text(value), time.Local)
	if !ok {
		return time.Time{}, fmt.Errorf("%s must be an ISO date or datetime.", name)
	}
	return time.UnixMilli(ms), nil
}

func (p *Provider) feedTool(ctx context.Context, name string, args map[string]any, creds map[string]any) (any, bool, error) {
	if name != "ical_list_events" {
		return nil, false, nil
	}
	start := p.svc.Now()
	if dyn.Truthy(args["start"]) {
		t, err := isoArg(args["start"], "start")
		if err != nil {
			return nil, true, err
		}
		start = t
	}
	end := start.Add(7 * 24 * time.Hour)
	if dyn.Truthy(args["end"]) {
		t, err := isoArg(args["end"], "end")
		if err != nil {
			return nil, true, err
		}
		end = t
	}
	cal, err := p.fetchFeed(ctx, integrations.Str(creds["url"]))
	if err != nil {
		return nil, true, err
	}
	events := []dyn.Ordered{}
	for _, e := range eventsBetween(cal, start, end) {
		if feedMatches(e, args["query"]) {
			events = append(events, e)
		}
	}
	return dyn.Ordered{{Key: "calendar", Value: creds["name"]}, {Key: "events", Value: events}}, true, nil
}
