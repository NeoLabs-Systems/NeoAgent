package tasks

import (
	"fmt"
	"math"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/cron"
)

const (
	minute = time.Minute
	// maxLeadTime caps a head start so one pathological run (a task that once
	// took hours) cannot drag every future occurrence arbitrarily far forward.
	maxLeadTime = time.Hour
	// runSampleSize is how many recent completed runs feed the average used for
	// the head start.
	runSampleSize = 10
)

var monthNames = map[string]int{"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12}
var weekdayNames = map[string]int{"sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6}

type cronField struct {
	wildcard bool
	values   map[int]bool
}

type cronFieldSpec struct {
	min, max  int
	name      string
	names     map[string]int
	normalize func(int) int
}

func cronValue(raw string, names map[string]int) (int, error) {
	value := strings.ToLower(jsv.Trim(raw))
	if n, ok := names[value]; ok {
		return n, nil
	}
	n, ok := jsv.ParseInt(value)
	if !ok {
		return 0, fmt.Errorf("Invalid cron value \"%s\"", raw)
	}
	return n, nil
}

func addRange(values map[int]bool, start, end, step int, spec cronFieldSpec) error {
	if start > end {
		return fmt.Errorf("Invalid %s range \"%d-%d\"", spec.name, start, end)
	}
	if start < spec.min || end > spec.max {
		return fmt.Errorf("%s range \"%d-%d\" is out of bounds", spec.name, start, end)
	}
	for current := start; current <= end; current += step {
		values[current] = true
	}
	return nil
}

func parseCronField(field string, spec cronFieldSpec) (cronField, error) {
	raw := jsv.Trim(field)
	if raw == "" {
		return cronField{}, fmt.Errorf("Missing %s field", spec.name)
	}
	out := cronField{wildcard: raw == "*", values: map[int]bool{}}
	for _, part := range strings.Split(raw, ",") {
		segment := jsv.Trim(part)
		if segment == "" {
			continue
		}
		pieces := strings.Split(segment, "/")
		rangePart, step := pieces[0], 1
		if len(pieces) > 1 {
			n, ok := jsv.ParseInt(pieces[1])
			if !ok || n <= 0 {
				return cronField{}, fmt.Errorf("Invalid %s step \"%s\"", spec.name, pieces[1])
			}
			step = n
		}
		if rangePart == "*" {
			if err := addRange(out.values, spec.min, spec.max, step, spec); err != nil {
				return cronField{}, err
			}
			continue
		}
		if strings.Contains(rangePart, "-") {
			ends := strings.SplitN(rangePart, "-", 3)[:2] // JavaScript's split("-", 2)
			start, err := cronValue(ends[0], spec.names)
			if err != nil {
				return cronField{}, err
			}
			end, err := cronValue(ends[1], spec.names)
			if err != nil {
				return cronField{}, err
			}
			if spec.normalize != nil {
				start, end = spec.normalize(start), spec.normalize(end)
			}
			if err := addRange(out.values, start, end, step, spec); err != nil {
				return cronField{}, err
			}
			continue
		}
		value, err := cronValue(rangePart, spec.names)
		if err != nil {
			return cronField{}, err
		}
		if spec.normalize != nil {
			value = spec.normalize(value)
		}
		if value < spec.min || value > spec.max {
			return cronField{}, fmt.Errorf("%s value \"%s\" is out of bounds", spec.name, rangePart)
		}
		out.values[value] = true
	}
	return out, nil
}

type cronSchedule struct{ minute, hour, dayOfMonth, month, dayOfWeek cronField }

var whitespace = regexp.MustCompile(`\s+`)

// parseCronExpression reads the five-field expressions the schedule trigger
// accepts. This is the reader used for display and for tasks that start early;
// the scheduler itself reads the same text with the cron package.
func parseCronExpression(expression string) (*cronSchedule, error) {
	fields := whitespace.Split(jsv.Trim(expression), -1)
	if len(fields) != 5 {
		return nil, fmt.Errorf("Invalid cron expression \"%s\"", expression)
	}
	specs := []cronFieldSpec{
		{min: 0, max: 59, name: "minute"},
		{min: 0, max: 23, name: "hour"},
		{min: 1, max: 31, name: "day-of-month"},
		{min: 1, max: 12, name: "month", names: monthNames},
		{min: 0, max: 6, name: "day-of-week", names: weekdayNames, normalize: func(v int) int {
			if v == 7 {
				return 0
			}
			return v
		}},
	}
	parsed := make([]cronField, 5)
	for i, spec := range specs {
		f, err := parseCronField(fields[i], spec)
		if err != nil {
			return nil, err
		}
		parsed[i] = f
	}
	return &cronSchedule{parsed[0], parsed[1], parsed[2], parsed[3], parsed[4]}, nil
}

func (s *cronSchedule) matches(t time.Time) bool {
	if !s.minute.values[t.Minute()] || !s.hour.values[t.Hour()] || !s.month.values[int(t.Month())] {
		return false
	}
	domMatch := s.dayOfMonth.values[t.Day()]
	dowMatch := s.dayOfWeek.values[int(t.Weekday())]
	switch {
	case s.dayOfMonth.wildcard && s.dayOfWeek.wildcard:
		return true
	case s.dayOfMonth.wildcard:
		return dowMatch
	case s.dayOfWeek.wildcard:
		return domMatch
	}
	return domMatch || dowMatch
}

const maxLookaheadMinutes = 366 * 24 * 60

// findNextRun is the first minute after `from` the expression matches on the
// wall clock of loc (the server's zone when nil); ok is false when none falls
// within a year.
func findNextRun(expression string, from time.Time, loc *time.Location) (time.Time, bool, error) {
	schedule, err := parseCronExpression(expression)
	if err != nil {
		return time.Time{}, false, err
	}
	if loc == nil {
		loc = time.Local
	}
	cursor := from.Truncate(minute)
	for i := 1; i <= maxLookaheadMinutes; i++ {
		candidate := cursor.Add(time.Duration(i) * minute)
		if schedule.matches(candidate.In(loc)) {
			return candidate, true, nil
		}
	}
	return time.Time{}, false, nil
}

// leadTime is how long before its scheduled time a run must start so that it
// finishes at that time: its measured average duration. Zero when there is no
// usable history yet, which keeps the task starting at its configured time.
func leadTime(averageSeconds float64) time.Duration {
	if math.IsNaN(averageSeconds) || math.IsInf(averageSeconds, 0) || averageSeconds <= 0 {
		return 0
	}
	return min(time.Duration(math.Floor(averageSeconds*1000+0.5))*time.Millisecond, maxLeadTime)
}

var zonelessDateTime = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?$`)

// offsetMinutes is the UTC offset of loc at t in whole minutes.
func offsetMinutes(loc *time.Location, t time.Time) int64 {
	_, seconds := t.In(loc).Zone()
	return int64(seconds / 60)
}

// wallClockToTime resolves a wall-clock time in loc, given as epoch milliseconds
// read as if the wall clock were UTC, to the real instant.
func wallClockToTime(wallClockAsUTC int64, loc *time.Location) time.Time {
	first := wallClockAsUTC - offsetMinutes(loc, time.UnixMilli(wallClockAsUTC))*60000
	return time.UnixMilli(wallClockAsUTC - offsetMinutes(loc, time.UnixMilli(first))*60000)
}

var errRunAt = fmt.Errorf("A valid runAt datetime is required.")

// normalizeRunAt reads a one-time schedule's datetime as an ISO instant. A
// datetime without an offset is the user's wall-clock time, not the server's.
// An empty value is no time (ok false).
func normalizeRunAt(value any, loc *time.Location) (string, bool, error) {
	if !jsv.Truthy(value) {
		return "", false, nil
	}
	raw := jsv.Trim(jsv.String(value))
	var t time.Time
	var ok bool
	if loc != nil && zonelessDateTime.MatchString(raw) {
		var utc time.Time
		if utc, ok = jsv.ParseDate(strings.Replace(raw, " ", "T", 1) + "Z"); ok {
			t = wallClockToTime(utc.UnixMilli(), loc)
		}
	} else {
		t, ok = jsv.ParseDate(raw)
	}
	if !ok {
		return "", false, errRunAt
	}
	return jsv.ISO(t), true, nil
}

var errCron = fmt.Errorf("A valid cron expression is required.")

// normalizeCronExpression accepts a five-field expression, a six-field one with
// a seconds field of 0 or *, and Quartz's "?" for "no specific value".
func normalizeCronExpression(value any) (string, error) {
	raw := jsv.Trim(jsv.Text(value))
	if raw == "" {
		return "", errCron
	}
	fields := whitespace.Split(raw, -1)
	if len(fields) == 6 {
		if seconds := jsv.Trim(fields[0]); seconds != "0" && seconds != "*" {
			return "", fmt.Errorf("Cron expressions with seconds are not supported. Use a 5-field expression.")
		}
		fields = fields[1:]
	}
	if len(fields) != 5 {
		return "", errCron
	}
	if fields[2] == "?" {
		fields[2] = "*"
	}
	if fields[4] == "?" {
		fields[4] = "*"
	}
	normalized := strings.Join(fields, " ")
	if _, err := parseCronExpression(normalized); err != nil {
		return "", err
	}
	if !cron.Validate(normalized) {
		return "", errCron
	}
	return normalized, nil
}
