// Package timezone resolves time zone names the way the Node server did
// (Intl.DateTimeFormat in en-US): names are matched without regard to case and
// come back under the name ICU resolves them to ("europe/berlin" becomes
// "Europe/Berlin", "US/Pacific" becomes "America/Los_Angeles"), and fixed
// offsets such as "+0530" become "+05:30". The name table is generated from
// Node by gen/zones.js.
package timezone

import (
	"fmt"
	"regexp"
	"strconv"
)

var offsetZone = regexp.MustCompile(`^([+\-\x{2212}])(\d{2})(?::?(\d{2}))?$`)

// Normalize returns the canonical name for value, or false when it is not a
// zone Node knew.
func Normalize(value string) (string, bool) {
	if name, ok := canonicalByLowerName[asciiLower(value)]; ok {
		return name, true
	}
	return normalizeOffset(value)
}

func normalizeOffset(value string) (string, bool) {
	m := offsetZone.FindStringSubmatch(value)
	if m == nil {
		return "", false
	}
	hours, _ := strconv.Atoi(m[2])
	minutes := 0
	if m[3] != "" {
		minutes, _ = strconv.Atoi(m[3])
	}
	if hours > 23 || minutes > 59 {
		return "", false
	}
	sign := "+"
	if m[1] != "+" && (hours != 0 || minutes != 0) {
		sign = "-"
	}
	return fmt.Sprintf("%s%02d:%02d", sign, hours, minutes), true
}

// asciiLower lower-cases A-Z only: ICU does not fold other letters, so the
// Kelvin sign must not turn into a "k".
func asciiLower(s string) string {
	b := []byte(s)
	for i, c := range b {
		if 'A' <= c && c <= 'Z' {
			b[i] = c + 'a' - 'A'
		}
	}
	return string(b)
}
