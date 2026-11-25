package settings

import (
	"regexp"
	"strings"
)

// The WhatsApp allow-list normalization of the Node server's utils/whatsapp.js,
// applied when platform_whitelist_whatsapp is saved. JavaScript's "." does not
// match line breaks, so the pattern spells that out.
var prefixedEntry = regexp.MustCompile(`^([A-Za-z_]+):([^\n\r\x{2028}\x{2029}]*)$`)

func lowerTrim(s string) string { return strings.ToLower(jsTrim(s)) }

func normalizeWhatsAppID(value string) string {
	raw := lowerTrim(value)
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

func normalizeWhatsAppGroupID(value string) string {
	raw := lowerTrim(value)
	if raw == "" {
		return ""
	}
	jid := raw
	if strings.Contains(raw, "@") {
		jid, _, _ = strings.Cut(raw, ":")
	}
	if strings.HasSuffix(jid, "@g.us") {
		return jid
	}
	return ""
}

func normalizeWhatsAppWhitelistEntry(value any) string {
	raw := jsTrim(orEmpty(value))
	if raw == "" {
		return ""
	}
	if m := prefixedEntry.FindStringSubmatch(raw); m != nil {
		scope := lowerTrim(m[1])
		scoped := jsTrim(m[2])
		switch scope {
		case "group", "chat":
			if groupID := normalizeWhatsAppGroupID(scoped); groupID != "" {
				return scope + ":" + groupID
			}
		case "user", "phone", "phone_number":
			id := normalizeWhatsAppID(scoped)
			if id == "" {
				return ""
			}
			if scope == "phone" {
				scope = "phone_number"
			}
			return scope + ":" + id
		}
	}
	if groupID := normalizeWhatsAppGroupID(raw); groupID != "" {
		return "group:" + groupID
	}
	return normalizeWhatsAppID(raw)
}

// normalizeWhatsAppWhitelist returns the cleaned, de-duplicated entries; a
// value that is not a list has none.
func normalizeWhatsAppWhitelist(values any) []string {
	list, _ := values.([]any)
	seen := map[string]bool{}
	normalized := []string{}
	for _, value := range list {
		entry := normalizeWhatsAppWhitelistEntry(value)
		if entry == "" || seen[entry] {
			continue
		}
		seen[entry] = true
		normalized = append(normalized, entry)
	}
	return normalized
}
