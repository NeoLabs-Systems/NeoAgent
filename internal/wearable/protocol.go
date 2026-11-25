package wearable

import (
	"encoding/json"
	"errors"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

// WSPath is where wearables open their socket.
const WSPath = "/api/wearable/ws"

// Wearable platform whose small screen shows no audio events.
const platformStickC = "m5stickc-plus2"

var clientMessageTypes = map[string]bool{
	"wearable:hello":      true,
	"voice:session_open":  true,
	"voice:audio":         true,
	"voice:input_start":   true,
	"voice:input_end":     true,
	"voice:interrupt":     true,
	"voice:session_close": true,
}

// Message is a parsed client message: its type and every field it carried.
type Message struct {
	Type   string
	Fields map[string]any
}

// ParseMessage reads one client message, which is a JSON object with a type.
func ParseMessage(data []byte) (Message, error) {
	var parsed any
	if err := json.Unmarshal(data, &parsed); err != nil {
		return Message{}, errors.New("Invalid JSON: " + err.Error())
	}
	object, ok := parsed.(map[string]any)
	if !ok {
		return Message{}, errors.New("Wearable message must be a JSON object.")
	}
	typ := livevoice.TrimJS(jsString(object["type"]))
	if typ == "" {
		return Message{}, errors.New("Wearable message type is required.")
	}
	return Message{Type: typ, Fields: object}, nil
}

// IsHello reports the opening message of a connection.
func (m Message) IsHello() bool { return m.Type == "wearable:hello" }

// Supported reports whether the type is one a wearable may send.
func (m Message) Supported() bool { return clientMessageTypes[livevoice.TrimJS(m.Type)] }

// ShouldSendEvent: the StickC has no speaker, so it is never sent audio.
func ShouldSendEvent(platform, event string) bool {
	return platform != platformStickC || event != "voice:audio"
}

// jsString is String(value), with null and undefined as "".
func jsString(v any) string {
	switch x := v.(type) {
	case nil:
		return ""
	case string:
		return x
	case bool:
		if x {
			return "true"
		}
		return "false"
	case float64:
		return formatNumber(x)
	case []any:
		parts := make([]string, len(x))
		for i, item := range x {
			if item != nil {
				parts[i] = jsString(item)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// optionalString is toOptionalString: trimmed, cut to max UTF-16 units, or "".
func optionalString(v any, max int) string {
	return truncateUnits(livevoice.TrimJS(jsString(v)), max)
}

// trimmedString is toTrimmedString: a falsy value is empty.
func trimmedString(v any, max int) string {
	switch x := v.(type) {
	case nil:
		return ""
	case bool:
		if !x {
			return ""
		}
	case float64:
		if x == 0 {
			return ""
		}
	}
	return optionalString(v, max)
}
