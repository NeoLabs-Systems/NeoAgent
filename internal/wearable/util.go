package wearable

import (
	"strconv"
	"time"
	"unicode/utf16"
)

func truncateUnits(s string, max int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= max {
		return s
	}
	return string(utf16.Decode(units[:max]))
}

func formatNumber(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }

// isoTime is Date.prototype.toISOString.
func isoTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }
