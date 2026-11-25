package credentials

import (
	"encoding/base64"
	"encoding/hex"
	"sort"
	"strings"
)

// Item is a vault item as the Bitwarden CLI prints it (`bw get item`): a
// decoded JSON object. Only login.username, login.password, login.uris and
// fields are read.
type Item = map[string]any

func object(v any) map[string]any {
	m, _ := v.(map[string]any)
	return m
}

func list(v any) []any {
	l, _ := v.([]any)
	return l
}

func login(item Item) map[string]any { return object(item["login"]) }

// itemOrigins are the HTTPS origins saved as URIs on the item, sorted.
func itemOrigins(item Item) []string {
	seen := map[string]bool{}
	origins := []string{}
	for _, entry := range list(login(item)["uris"]) {
		o, err := normalizeHTTPSOrigin(object(entry)["uri"])
		if err != nil || seen[o] {
			continue
		}
		seen[o] = true
		origins = append(origins, o)
	}
	sort.Strings(origins)
	return origins
}

// ItemField is a custom field of a vault item, without its value.
type ItemField struct {
	ID   string  `json:"id"`
	Name string  `json:"name"`
	Type float64 `json:"type"`
}

// SafeItem is what the user sees of a vault item: no secrets.
type SafeItem struct {
	ID             string      `json:"id"`
	Name           string      `json:"name"`
	UsernameMasked string      `json:"usernameMasked"`
	Origins        []string    `json:"origins"`
	HasPassword    bool        `json:"hasPassword"`
	Fields         []ItemField `json:"fields"`
}

func orString(v any, fallback string) string {
	if !truthy(v) {
		return fallback
	}
	return jsString(v)
}

func maskUsername(username string) string {
	if username == "" {
		return ""
	}
	n := utf16Len(username)
	stars := min(8, max(3, n-2))
	out := utf16Slice(username, 0, 1) + strings.Repeat("*", stars)
	if n > 1 {
		out += utf16Slice(username, n-1, n)
	}
	return out
}

func sanitizeItem(item Item) SafeItem {
	fields := []ItemField{}
	for _, f := range list(item["fields"]) {
		field := object(f)
		out := ItemField{ID: orString(field["id"], ""), Name: orString(field["name"], "")}
		if truthy(field["type"]) {
			out.Type = toNumber(field["type"])
		}
		if out.ID != "" || out.Name != "" {
			fields = append(fields, out)
		}
	}
	_, hasPassword := login(item)["password"]
	return SafeItem{
		ID:             orString(item["id"], ""),
		Name:           orString(item["name"], "Untitled"),
		UsernameMasked: maskUsername(orString(login(item)["username"], "")),
		Origins:        itemOrigins(item),
		HasPassword:    login(item) != nil && hasPassword,
		Fields:         fields,
	}
}

// readItemField reads login.username, login.password or a custom field by id
// or name.
func readItemField(item Item, reference string) string {
	ref := jsTrim(reference)
	switch ref {
	case "login.username":
		return orString(login(item)["username"], "")
	case "login.password":
		return orString(login(item)["password"], "")
	}
	for _, f := range list(item["fields"]) {
		field := object(f)
		if orString(field["id"], "") == ref || orString(field["name"], "") == ref {
			return orString(field["value"], "")
		}
	}
	return ""
}

// encodeURIComponent is the JavaScript function.
func encodeURIComponent(s string) string {
	const unreserved = "-_.!~*'()"
	var b strings.Builder
	for _, c := range []byte(s) {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte(unreserved, c) >= 0 {
			b.WriteByte(c)
		} else {
			b.WriteString("%" + strings.ToUpper(hex.EncodeToString([]byte{c})))
		}
	}
	return b.String()
}

// secretVariants are the spellings a secret might come back in, longest first.
func secretVariants(value string) []string {
	if value == "" {
		return nil
	}
	raw := []byte(value)
	candidates := []string{
		value,
		encodeURIComponent(value),
		base64.StdEncoding.EncodeToString(raw),
		base64.RawURLEncoding.EncodeToString(raw),
		hex.EncodeToString(raw),
	}
	seen := map[string]bool{}
	var out []string
	for _, c := range candidates {
		if c != "" && !seen[c] {
			seen[c] = true
			out = append(out, c)
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return utf16Len(out[i]) > utf16Len(out[j]) })
	return out
}

// redactResolvedValues replaces every spelling of the resolved secrets.
func redactResolvedValues(value string, resolved []string) string {
	for _, r := range resolved {
		for _, variant := range secretVariants(r) {
			value = strings.ReplaceAll(value, variant, "[redacted]")
		}
	}
	return value
}

var blockedResponseHeaders = map[string]bool{
	"authorization": true, "cookie": true, "set-cookie": true,
	"proxy-authenticate": true, "proxy-authorization": true, "www-authenticate": true,
}

func safeResponseHeaders(headers map[string]string, resolved []string) map[string]string {
	out := map[string]string{}
	for name, value := range headers {
		if !blockedResponseHeaders[strings.ToLower(name)] {
			out[name] = redactResolvedValues(value, resolved)
		}
	}
	return out
}

func sortStrings(l []string) { sort.Strings(l) }
