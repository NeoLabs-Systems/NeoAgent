package messaging

import (
	"testing"
	"time"
)

func TestUsageLimitNoticeMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Usage {
		lang := ""
		if c.Lang != nil {
			lang = *c.Lang
		}
		var limit RateLimit
		if c.RateLimit != nil {
			limit = RateLimit{Window: c.RateLimit.Window, RecoversAt: c.RateLimit.RecoversAt}
		}
		got := BuildUsageLimitNotice(lang, limit, time.UnixMilli(c.Now))
		if got != c.Result {
			t.Errorf("%q %+v:\n got  %q\n want %q", lang, c.RateLimit, got, c.Result)
		}
	}
}

func TestFixedMessagesMatchNode(t *testing.T) {
	if got := FixedMessage("de", "unknownCommand", map[string]string{"command": "foo"}); got != "Unbekannter Befehl: /foo. Mit /help siehst du, was verfügbar ist." {
		t.Errorf("got %q", got)
	}
	if got := FixedMessage("xx", "commandFailed", nil); got != "That command didn’t work: {error}" {
		t.Errorf("unknown language and missing value: got %q", got)
	}
	if got := FixedMessage("en", "stopped", nil); got != "Stopped." {
		t.Errorf("got %q", got)
	}
}
