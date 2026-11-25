package whatsapp

import (
	"regexp"
	"strings"
	"unicode"
)

// WhatsApp address helpers. They work on strings because chat ids travel through the system as text.

func jsTrimLower(s string) string {
	return strings.ToLower(strings.TrimFunc(s, func(r rune) bool {
		return unicode.IsSpace(r) || r == '\uFEFF'
	}))
}

// normalizeID reduces any WhatsApp address to the digits of its user part
// ("491234:12@s.whatsapp.net" -> "491234"), or to the user part itself when it
// has no digits.
func normalizeID(value string) string {
	raw := jsTrimLower(value)
	if raw == "" {
		return ""
	}
	base, _, _ := strings.Cut(raw, "@")
	primary, _, _ := strings.Cut(base, ":")
	digits := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, primary)
	if digits != "" {
		return digits
	}
	return primary
}

// toJID is the address a message is delivered to: an existing phone, group or
// LID address without its device suffix, or the number as a phone address.
func toJID(value string) string {
	raw := jsTrimLower(value)
	if raw == "" {
		return ""
	}
	if strings.Contains(raw, "@") {
		parts := strings.Split(raw, "@")
		user, _, _ := strings.Cut(parts[0], ":")
		jid := user + "@" + parts[1]
		for _, suffix := range []string{"@s.whatsapp.net", "@g.us", "@lid"} {
			if strings.HasSuffix(jid, suffix) {
				return jid
			}
		}
	}
	normalized := normalizeID(raw)
	if normalized == "" {
		return ""
	}
	return normalized + "@s.whatsapp.net"
}

var phoneJIDPattern = regexp.MustCompile(`@(s\.whatsapp\.net|hosted)$`)

func isPhoneJID(jid string) bool { return phoneJIDPattern.MatchString(jid) }

// normalizedUser is jidNormalizedUser: the address without its device.
func normalizedUser(jid string) string {
	user, server, ok := strings.Cut(jid, "@")
	if !ok {
		return jid
	}
	user, _, _ = strings.Cut(user, ":")
	user, _, _ = strings.Cut(user, ".")
	return user + "@" + server
}
