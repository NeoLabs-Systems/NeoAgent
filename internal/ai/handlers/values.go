package handlers

import (
	"fmt"
	"io"
	"math"
	"os"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// jsNumber is Number(v) of JavaScript: NaN for anything unreadable.
func jsNumber(v any) float64 { return jsv.Number(v) }

// jsInt is Math.floor(Number(v) || 0)-style reading with a fallback for NaN
// and missing values.
func jsInt(v any, fallback int) int {
	if v == nil {
		return fallback
	}
	n := jsNumber(v)
	if math.IsNaN(n) || math.IsInf(n, 0) || n == 0 {
		return fallback
	}
	return int(math.Floor(n))
}

// trimSpaceJS is String.prototype.trim.
func trimSpaceJS(s string) string { return jsv.Trim(s) }

// errorf is a thrown Error with a message.
func errorf(format string, a ...any) error { return fmt.Errorf(format, a...) }

// parseJSDate is Date.parse for the formats tools pass.
func parseJSDate(s string) (time.Time, bool) { return jsv.ParseDate(s) }

// lenUTF16 is String.prototype.length.
func lenUTF16(s string) int {
	n := 0
	for _, r := range s {
		if r > 0xFFFF {
			n += 2
		} else {
			n++
		}
	}
	return n
}

// sliceUTF16 is s.slice(0, n) counted in UTF-16 units.
func sliceUTF16(s string, n int) string {
	units := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > n {
			return s[:i]
		}
		units += w
	}
	return s
}

// readSmallFile reads a file of at most limit bytes.
func readSmallFile(path string, limit int64) (string, bool) {
	f, err := os.Open(path)
	if err != nil {
		return "", false
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, limit+1))
	if err != nil || int64(len(data)) > limit {
		return "", false
	}
	return string(data), true
}

// jsText is a value in a template literal: missing reads "undefined".
func jsText(v any) string {
	if v == nil {
		return "undefined"
	}
	return dyn.String(v)
}

// stringList is the strings of an array argument.
func stringList(v any) []string {
	var out []string
	for _, item := range dyn.List(v) {
		out = append(out, dyn.String(item))
	}
	return out
}
