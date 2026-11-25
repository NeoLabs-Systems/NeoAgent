package ai

import "regexp"

// Characters a model reads but a person cannot see. Unicode Tags (U+E0000 to
// U+E007F) spell out ASCII invisibly and are the known carrier for hidden
// prompt injections and for smuggling data out; the variation selector
// supplement carries the same trick. Bidi controls reorder what a person sees
// (an approval prompt, a message preview) without changing what runs.
// Zero-width joiners stay: emoji sequences and several scripts need them.
var invisible = regexp.MustCompile("[\U000E0000-\U000E007F\U000E0100-\U000E01EF\u202A-\u202E\u2066-\u2069]")

// Every untrusted span the harness puts into a prompt is fenced with a tag from
// this family. Content may not contain the tag itself, so it can neither close
// its fence early nor forge a sender block of its own.
var fenceTag = regexp.MustCompile(`(?i)<(/?)(external_[a-z_]+|sender_identity)\b`)

// ScrubInvisible removes characters a person cannot see.
func ScrubInvisible(text string) string { return invisible.ReplaceAllString(text, "") }

// ScrubInvisibleDeep scrubs every string inside a tool-call argument value. It
// returns the value itself when nothing changed.
func ScrubInvisibleDeep(value any) any {
	switch v := value.(type) {
	case string:
		return ScrubInvisible(v)
	case []any:
		out := make([]any, len(v))
		for i, item := range v {
			out[i] = ScrubInvisibleDeep(item)
		}
		return out
	case map[string]any:
		out := make(map[string]any, len(v))
		for k, item := range v {
			out[k] = ScrubInvisibleDeep(item)
		}
		return out
	}
	return value
}

// NeutralizeFenceTags makes fence tags in untrusted text inert.
func NeutralizeFenceTags(text string) string {
	return fenceTag.ReplaceAllString(ScrubInvisible(text), "&lt;${1}${2}")
}

// FenceUntrusted wraps untrusted text in a tag of the fence family.
func FenceUntrusted(tag, text string) string {
	return "<" + tag + ">\n" + NeutralizeFenceTags(text) + "\n</" + tag + ">"
}
