package jsx

import (
	"regexp"
	"strconv"
	"strings"
	"time"
)

var (
	isoDate = regexp.MustCompile(`^([+-]\d{6}|\d{4})(?:-(\d\d)(?:-(\d\d))?)?(?:[T ](\d\d):(\d\d)(?::(\d\d)(?:[.,](\d{1,9}))?)?)?\s*(Z|[+-]\d\d(?::?\d\d)?)?$`)
	legacy  = []string{
		"Jan 2, 2006", "Jan 2 2006", "January 2, 2006", "January 2 2006",
		"2 Jan 2006", "2 January 2006", "Jan 2, 2006 15:04:05", "January 2, 2006 15:04:05",
		"Mon, 02 Jan 2006 15:04:05 MST", "Mon, 02 Jan 2006 15:04:05 -0700", "Mon Jan 02 2006 15:04:05 GMT-0700",
		"2006/01/02", "2006/01/02 15:04:05", "1/2/2006", "1/2/2006 15:04:05",
		"January 2006", "Jan 2006", "2 Jan 2006 15:04:05", "02 Jan 2006 15:04:05 MST",
	}
)

// ParseDate is Date.parse for the forms memory text carries: ISO 8601 dates and
// times, SQLite's "YYYY-MM-DD HH:MM:SS" (local time, as V8 reads it), and the
// common English date formats. ok is false where Date.parse answers NaN.
func ParseDate(text string, local *time.Location) (ms int64, ok bool) {
	text = Trim(text)
	if text == "" {
		return 0, false
	}
	if m := isoDate.FindStringSubmatch(text); m != nil {
		if t, valid := fromISO(m, local); valid {
			return t.UnixMilli(), true
		}
		return 0, false
	}
	for _, layout := range legacy {
		if t, err := time.ParseInLocation(layout, text, local); err == nil {
			return t.UnixMilli(), true
		}
	}
	return 0, false
}

func fromISO(m []string, local *time.Location) (time.Time, bool) {
	atoi := func(s string, def int) int {
		if s == "" {
			return def
		}
		n, _ := strconv.Atoi(s)
		return n
	}
	year := atoi(m[1], 0)
	if strings.HasPrefix(m[1], "-") && year == 0 {
		return time.Time{}, false
	}
	month, day := atoi(m[2], 1), atoi(m[3], 1)
	hour, minute, second := atoi(m[4], 0), atoi(m[5], 0), atoi(m[6], 0)
	nanos := 0
	if m[7] != "" {
		frac := (m[7] + "000000000")[:9]
		nanos, _ = strconv.Atoi(frac)
	}
	if month < 1 || month > 12 || day < 1 || day > 31 || hour > 24 || minute > 59 || second > 59 {
		return time.Time{}, false
	}
	if hour == 24 && (minute != 0 || second != 0 || nanos != 0) {
		return time.Time{}, false
	}
	loc := time.UTC
	switch zone := m[8]; {
	case zone == "Z":
	case zone != "":
		sign := 1
		if zone[0] == '-' {
			sign = -1
		}
		digits := strings.ReplaceAll(zone[1:], ":", "")
		oh := atoi(digits[:2], 0)
		om := 0
		if len(digits) >= 4 {
			om = atoi(digits[2:4], 0)
		}
		loc = time.FixedZone("", sign*(oh*3600+om*60))
	case m[4] != "":
		// A date and time without an offset is local time.
		loc = local
	}
	t := time.Date(year, time.Month(month), day, hour, minute, second, nanos, loc)
	if t.Day() != day && hour != 24 {
		return time.Time{}, false
	}
	return t, true
}
