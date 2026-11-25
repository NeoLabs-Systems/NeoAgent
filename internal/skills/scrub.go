package skills

import "strings"

// scrubInvisible drops characters a model reads but a person cannot see:
// Unicode Tags and variation selector supplement (hidden prompt injections)
// and bidi controls. Zero-width joiners stay, since emoji and several scripts
// need them.
func scrubInvisible(text string) string {
	return strings.Map(func(r rune) rune {
		switch {
		case r >= 0xE0000 && r <= 0xE007F, r >= 0xE0100 && r <= 0xE01EF,
			r >= 0x202A && r <= 0x202E, r >= 0x2066 && r <= 0x2069:
			return -1
		}
		return r
	}, text)
}
