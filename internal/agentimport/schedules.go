package agentimport

import (
	"fmt"
	"math"
	"strings"
)

// cron is a five-field expression; exact is false when the source schedule had
// to be rounded.
type cron struct {
	Expr  string
	Exact bool
}

// closest returns the value of options nearest to x (the first on a tie).
func closest(options []int, x int) int {
	best := 1
	for _, v := range options {
		if abs(v-x) < abs(best-x) {
			best = v
		}
	}
	return best
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

// jsRound is Math.round: halves round up.
func jsRound(x float64) int { return int(math.Floor(x + 0.5)) }

// intervalToCron maps an interval in milliseconds to the closest 5-field cron
// expression.
func intervalToCron(everyMs float64) cron {
	minutes := jsRound(everyMs / 60000)
	if minutes < 1 {
		minutes = 1
	}
	if minutes < 60 {
		step := closest([]int{1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30}, minutes)
		if step == 1 {
			return cron{"* * * * *", step == minutes}
		}
		return cron{fmt.Sprintf("*/%d * * * *", step), step == minutes}
	}
	hours := jsRound(float64(minutes) / 60)
	if hours < 24 {
		step := closest([]int{1, 2, 3, 4, 6, 8, 12}, hours)
		if step == 1 {
			return cron{"0 * * * *", step*60 == minutes}
		}
		return cron{fmt.Sprintf("0 */%d * * *", step), step*60 == minutes}
	}
	days := jsRound(float64(hours) / 24)
	if days == 7 {
		return cron{"0 9 * * 1", minutes == 7*24*60}
	}
	return cron{"0 9 * * *", minutes == 24*60}
}

// toFiveFieldCron drops a zero or any seconds field; anything finer than a
// minute cannot be kept.
func toFiveFieldCron(expr string) (cron, bool) {
	fields := strings.Fields(trim(expr))
	switch len(fields) {
	case 5:
		return cron{strings.Join(fields, " "), true}, true
	case 6:
		return cron{strings.Join(fields[1:], " "), fields[0] == "0" || fields[0] == "*"}, true
	}
	return cron{}, false
}
