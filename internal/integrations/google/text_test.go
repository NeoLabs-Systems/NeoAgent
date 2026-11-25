package google

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

type textVectors struct {
	MimeWords []struct{ Input, Decoded string } `json:"mimeWords"`
	Bodies    []struct {
		Payload messagePayload `json:"payload"`
		Text    string         `json:"text"`
	} `json:"bodies"`
	Headers []struct {
		Headers []header `json:"headers"`
		Subject *string  `json:"subject"`
		Missing *string  `json:"missing"`
	} `json:"headers"`
	Subjects []struct{ Input, Encoded string } `json:"subjects"`
	Lists    []struct {
		Input json.RawMessage `json:"input"`
		List  []string        `json:"list"`
	} `json:"lists"`
}

func loadTextVectors(t *testing.T) textVectors {
	raw, err := os.ReadFile("testdata/text.json")
	if err != nil {
		t.Fatal(err)
	}
	var v textVectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

// The decoding of mail text matches the Node helpers on recorded inputs.
func TestMailTextMatchesNode(t *testing.T) {
	v := loadTextVectors(t)
	for _, c := range v.MimeWords {
		if got := normalizeDecodedText(c.Input); got != c.Decoded {
			t.Errorf("mime words %q: got %q, Node %q", c.Input, got, c.Decoded)
		}
	}
	for i, c := range v.Bodies {
		payload := c.Payload
		if got := extractMessageBody(&payload); got != c.Text {
			t.Errorf("body %d: got %q, Node %q", i, got, c.Text)
		}
	}
	for i, c := range v.Headers {
		got := getHeader(c.Headers, "subject")
		if !reflect.DeepEqual(got, c.Subject) || getHeader(c.Headers, "x-none") != nil || c.Missing != nil {
			t.Errorf("headers %d: got %v, Node %v", i, got, c.Subject)
		}
	}
	for _, c := range v.Subjects {
		if got := encodeHeaderWords(c.Input); got != c.Encoded {
			t.Errorf("subject %q: got %q, Node %q", c.Input, got, c.Encoded)
		}
	}
	for _, c := range v.Lists {
		var input any
		_ = json.Unmarshal(c.Input, &input)
		got := coerceStringList(input)
		if len(got) == 0 && len(c.List) == 0 {
			continue
		}
		if !reflect.DeepEqual(got, c.List) {
			t.Errorf("list %s: got %v, Node %v", c.Input, got, c.List)
		}
	}
}
