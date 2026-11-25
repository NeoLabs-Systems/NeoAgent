package jsv

import (
	"math"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// IsSpace reports whether r is white space or a line terminator to JavaScript.
func IsSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
		return true
	}
	return r >= 0x2000 && r <= 0x200a
}

// Trim is String.prototype.trim.
func Trim(s string) string { return strings.TrimFunc(s, IsSpace) }

// Truthy is Boolean(v).
func Truthy(v any) bool {
	switch v := v.(type) {
	case nil:
		return false
	case bool:
		return v
	case float64:
		return v != 0 && !math.IsNaN(v)
	case int:
		return v != 0
	case string:
		return v != ""
	}
	return true
}

// String is String(v). Objects read "[object Object]", arrays join their
// items with commas.
func String(v any) string {
	switch v := v.(type) {
	case nil:
		return "null"
	case string:
		return v
	case bool:
		return strconv.FormatBool(v)
	case float64:
		return NumberString(v)
	case int:
		return strconv.Itoa(v)
	case int64:
		return strconv.FormatInt(v, 10)
	case []any:
		parts := make([]string, len(v))
		for i, e := range v {
			if e != nil {
				parts[i] = String(e)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// Text is String(v || ”): the text of a value, empty for anything falsy.
func Text(v any) string {
	if !Truthy(v) {
		return ""
	}
	return String(v)
}

// Number is Number(v); NaN when v is not a number.
func Number(v any) float64 {
	switch v := v.(type) {
	case nil:
		return 0
	case bool:
		if v {
			return 1
		}
		return 0
	case float64:
		return v
	case int:
		return float64(v)
	case int64:
		return float64(v)
	case string:
		return stringToNumber(v)
	case []any:
		switch len(v) {
		case 0:
			return 0
		case 1:
			if v[0] == nil {
				return 0
			}
			return Number(String(v[0]))
		}
	}
	return math.NaN()
}

func stringToNumber(s string) float64 {
	s = Trim(s)
	if s == "" {
		return 0
	}
	switch s {
	case "Infinity", "+Infinity":
		return math.Inf(1)
	case "-Infinity":
		return math.Inf(-1)
	}
	if len(s) > 2 && s[0] == '0' {
		base := 0
		switch s[1] {
		case 'x', 'X':
			base = 16
		case 'o', 'O':
			base = 8
		case 'b', 'B':
			base = 2
		}
		if base != 0 {
			n, err := strconv.ParseUint(s[2:], base, 64)
			if err != nil {
				return math.NaN()
			}
			return float64(n)
		}
	}
	for _, c := range s {
		if !strings.ContainsRune("0123456789+-.eE", c) {
			return math.NaN()
		}
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil && !math.IsInf(f, 0) {
		return math.NaN()
	}
	return f
}

// Finite is Number.isFinite(Number(v)).
func Finite(v any) bool {
	f := Number(v)
	return !math.IsNaN(f) && !math.IsInf(f, 0)
}

// ParseInt is Number.parseInt(String(v), 10); ok is false for NaN.
func ParseInt(v any) (int, bool) {
	s := strings.TrimLeftFunc(String(v), IsSpace)
	neg := false
	if s != "" && (s[0] == '+' || s[0] == '-') {
		neg = s[0] == '-'
		s = s[1:]
	}
	end := 0
	for end < len(s) && s[end] >= '0' && s[end] <= '9' {
		end++
	}
	if end == 0 {
		return 0, false
	}
	const limit = 1 << 53
	n := 0
	for _, c := range s[:end] {
		n = n*10 + int(c-'0')
		if n > limit {
			n = limit
		}
	}
	if neg {
		n = -n
	}
	return n, true
}

// IsInteger is Number.isInteger on a float.
func IsInteger(f float64) bool { return !math.IsNaN(f) && !math.IsInf(f, 0) && f == math.Trunc(f) }

// ISO is Date.prototype.toISOString.
func ISO(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

var legacyLayouts = []string{
	time.RFC1123, time.RFC1123Z, time.RFC850, time.ANSIC, time.UnixDate,
	"Mon Jan 2 2006 15:04:05 GMT-0700", "Jan 2, 2006 15:04:05", "Jan 2, 2006", "January 2, 2006",
	"2 Jan 2006 15:04:05 MST", "2 Jan 2006", "2006/01/02 15:04:05", "2006/01/02", "01/02/2006 15:04:05", "01/02/2006",
}

// ParseDate is `new Date(v)` for a string or a number: ISO 8601 forms (a date
// alone is UTC, a date and time without an offset is local time, like
// JavaScript), a handful of common legacy forms, and epoch milliseconds.
// ok is false for an invalid date.
func ParseDate(v any) (time.Time, bool) {
	switch v := v.(type) {
	case float64:
		if math.IsNaN(v) || math.IsInf(v, 0) || math.Abs(v) > 8.64e15 {
			return time.Time{}, false
		}
		return time.UnixMilli(int64(v)).UTC(), true
	case int:
		return time.UnixMilli(int64(v)).UTC(), true
	case bool:
		return time.UnixMilli(int64(Number(v))).UTC(), true
	case nil:
		return time.UnixMilli(0).UTC(), true
	case string:
		return parseDateString(Trim(v))
	}
	return time.Time{}, false
}

func parseDateString(s string) (time.Time, bool) {
	if t, ok := parseISO(s); ok {
		return t, true
	}
	for _, layout := range legacyLayouts {
		if t, err := time.ParseInLocation(layout, s, time.Local); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

var isoDate = regexp.MustCompile(`^(\d{4})(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d):(\d\d)(?::(\d\d)(?:[.,](\d+))?)?)?(Z|[+-]\d\d:?\d\d)?$`)

// parseISO reads the ECMAScript date-time string format. Like V8 it accepts a
// space for the T, any day up to 31 (February 30th rolls into March) and 24:00.
func parseISO(s string) (time.Time, bool) {
	if len(s) > 10 && s[10] == ' ' {
		s = s[:10] + "T" + s[11:]
	}
	m := isoDate.FindStringSubmatch(s)
	if m == nil {
		return time.Time{}, false
	}
	num := func(i, def int) int {
		if m[i] == "" {
			return def
		}
		n, _ := strconv.Atoi(m[i])
		return n
	}
	year, month, day := num(1, 0), num(2, 1), num(3, 1)
	hour, minute, second := num(4, 0), num(5, 0), num(6, 0)
	millis := 0
	if m[7] != "" {
		frac := (m[7] + "000")[:3]
		millis, _ = strconv.Atoi(frac)
	}
	if month < 1 || month > 12 || day < 1 || day > 31 || hour > 24 || minute > 59 || second > 59 ||
		(hour == 24 && (minute != 0 || second != 0 || millis != 0)) {
		return time.Time{}, false
	}
	loc := time.Local
	switch zone := m[8]; {
	case zone == "":
		if m[4] == "" { // a date alone is UTC
			loc = time.UTC
		}
	case zone == "Z":
		loc = time.UTC
	default:
		sign := 1
		if zone[0] == '-' {
			sign = -1
		}
		digits := strings.Replace(zone[1:], ":", "", 1)
		hh, _ := strconv.Atoi(digits[:2])
		mm, _ := strconv.Atoi(digits[2:])
		if hh > 23 || mm > 59 {
			return time.Time{}, false
		}
		loc = time.FixedZone("", sign*(hh*3600+mm*60))
	}
	return time.Date(year, time.Month(month), day, hour, minute, second, millis*1e6, loc), true
}
