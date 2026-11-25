package messaging

import (
	_ "embed"
	"encoding/json"
	"errors"
	"math"
	"regexp"
	"strings"
	"time"
)

// Texts the runtime sends without a model call, set per UI language. Ports of
// fixed_messages.js and usage_limit_notice.js; the tables in data/ are
// generated from the Node modules by gen/vectors.js.

//go:embed data/fixed_messages.json
var fixedMessagesJSON []byte

//go:embed data/usage_notices.json
var usageNoticesJSON []byte

var fixedMessages = mustDecode[map[string]map[string]string](fixedMessagesJSON)

type usageTables struct {
	Notices  map[string][2]string `json:"notices"`
	Relative map[string]struct {
		Minute []string `json:"minute"`
		Hour   []string `json:"hour"`
		Day    []string `json:"day"`
	} `json:"relative"`
}

var usageNotices = mustDecode[usageTables](usageNoticesJSON)

func mustDecode[T any](raw []byte) T {
	var v T
	if err := json.Unmarshal(raw, &v); err != nil {
		panic("messaging: embedded text table is invalid: " + err.Error())
	}
	return v
}

var placeholderRe = regexp.MustCompile(`\{(\w+)\}`)

// FixedMessage is the runtime's fixed reply for key in the UI language, with
// {name} placeholders filled from values (unknown ones stay as written).
func FixedMessage(language, key string, values map[string]string) string {
	table, ok := fixedMessages[language]
	if !ok {
		table = fixedMessages["en"]
	}
	return placeholderRe.ReplaceAllStringFunc(table[key], func(match string) string {
		if v, ok := values[match[1:len(match)-1]]; ok {
			return v
		}
		return match
	})
}

// RateLimit says when a used-up usage limit recovers: RecoversAt maps a window
// name to an RFC 3339 time, Window is the one that blocked the request.
type RateLimit struct {
	Window     string
	RecoversAt map[string]string
}

// UsageLimitError is what the reply path returns when the account's usage limit
// is used up; the runtime then answers with a fixed notice.
type UsageLimitError struct{ Limit RateLimit }

func (e *UsageLimitError) Error() string { return "Usage limit reached" }

// IsUsageLimit reports whether err is a used-up usage limit.
func IsUsageLimit(err error) (RateLimit, bool) {
	var limit *UsageLimitError
	if errors.As(err, &limit) {
		return limit.Limit, true
	}
	return RateLimit{}, false
}

// relativeRetryTime is Intl.RelativeTimeFormat(language, {numeric: "auto"}) for
// the time left, from the generated table. A wait beyond 31 days has no entry
// and reads as no hint.
func relativeRetryTime(language string, recoversAt string, now time.Time) (string, bool) {
	at, err := time.Parse(time.RFC3339Nano, recoversAt)
	if err != nil {
		return "", false
	}
	wait := at.Sub(now)
	if wait <= 0 {
		return "", false
	}
	minutes := int(math.Ceil(float64(wait.Milliseconds()) / 60000))
	table := usageNotices.Relative[language]
	var entries []string
	var value int
	switch {
	case minutes < 60:
		entries, value = table.Minute, minutes
	case minutes < 48*60:
		entries, value = table.Hour, (minutes+59)/60
	default:
		entries, value = table.Day, (minutes+1439)/1440
	}
	if value < 1 || value > len(entries) {
		return "", false
	}
	return entries[value-1], true
}

// BuildUsageLimitNotice is the chat reply sent when a message arrives after the
// usage limit is used up.
func BuildUsageLimitNotice(language string, limit RateLimit, now time.Time) string {
	if _, ok := usageNotices.Notices[language]; !ok {
		language = "en"
	}
	text := usageNotices.Notices[language]
	when, ok := relativeRetryTime(language, limit.RecoversAt[limit.Window], now)
	if !ok {
		return text[0]
	}
	return text[0] + " " + strings.Replace(text[1], "{when}", when, 1)
}
