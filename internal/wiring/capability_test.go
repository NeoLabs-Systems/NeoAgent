package wiring

import "testing"

func TestMessagingHealthLines(t *testing.T) {
	cases := []struct {
		statuses map[string]string
		source   string
		want     string
	}{
		{map[string]string{"telegram": "connected"}, "", ""},
		{map[string]string{}, "", ""},
		{map[string]string{"telegram": "disconnected"}, "", "messaging: unhealthy - telegram: disconnected"},
		{map[string]string{"telegram": "connected", "discord": "error"}, "", "messaging: degraded - discord: error; telegram: connected"},
		// The message that started the run proves its platform works.
		{map[string]string{"whatsapp": "connecting"}, "whatsapp", ""},
		{map[string]string{"telegram": "disconnected"}, "whatsapp", "messaging: degraded - telegram: disconnected; whatsapp: connected; this conversation is on whatsapp"},
	}
	for _, c := range cases {
		if got := messagingSummary(c.statuses, c.source); got != c.want {
			t.Errorf("%v %q: %q want %q", c.statuses, c.source, got, c.want)
		}
	}
}
