package google

import (
	"bytes"
	"encoding/base64"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf16"
	"unicode/utf8"

	"golang.org/x/text/encoding/htmlindex"
)

// This file ports services/integrations/google/common.js: decoding of mail
// headers and bodies the way the Node server did, down to its mojibake repair,
// so the model reads the same text.

// jsSpace is what JavaScript's \s matches.
const jsSpace = `[\s\x{00A0}\x{FEFF}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}]`

var (
	mimeWord   = regexp.MustCompile(`=\?([^?]+)\?([bqBQ])\?([^?]*)\?=`)
	qpBreak    = regexp.MustCompile(`=\r?\n`)
	quotedCS   = regexp.MustCompile(`(?i)charset\s*=\s*"([^";\s]+)"`)
	plainCS    = regexp.MustCompile(`(?i)charset\s*=\s*([^";\s]+)`)
	styleTag   = regexp.MustCompile(`(?is)<style.*?</style>`)
	scriptTag  = regexp.MustCompile(`(?is)<script.*?</script>`)
	anyTag     = regexp.MustCompile(`<[^>]+>`)
	spaceRun   = regexp.MustCompile(jsSpace + `+`)
	whitespace = regexp.MustCompile(`^` + jsSpace + `+|` + jsSpace + `+$`)
)

// jsTrim is String.prototype.trim.
func jsTrim(s string) string { return whitespace.ReplaceAllString(s, "") }

func stripHTML(html string) string {
	html = styleTag.ReplaceAllString(html, " ")
	html = scriptTag.ReplaceAllString(html, " ")
	html = anyTag.ReplaceAllString(html, " ")
	return jsTrim(spaceRun.ReplaceAllString(html, " "))
}

// base64URLDecode is Buffer.from(value, 'base64') after the URL-safe mapping:
// characters outside the alphabet are skipped and missing padding is fine.
func base64URLDecode(value string) []byte {
	var b strings.Builder
	for _, c := range value {
		switch {
		case c == '-':
			b.WriteByte('+')
		case c == '_':
			b.WriteByte('/')
		case c >= 'A' && c <= 'Z', c >= 'a' && c <= 'z', c >= '0' && c <= '9', c == '+', c == '/':
			b.WriteRune(c)
		}
	}
	out, _ := base64.RawStdEncoding.DecodeString(b.String())
	if out == nil && b.Len()%4 == 1 {
		out, _ = base64.RawStdEncoding.DecodeString(b.String()[:b.Len()-1])
	}
	return out
}

func normalizeCharset(charset string) string {
	n := strings.ToLower(strings.TrimSpace(charset))
	switch n {
	case "":
		return "utf-8"
	case "utf8":
		return "utf-8"
	case "us-ascii":
		return "ascii"
	case "latin1", "latin-1", "iso-8859-1", "iso8859-1":
		return "windows-1252"
	}
	return n
}

// decodeBytes is TextDecoder(label).decode with the fallbacks of decodeBytes
// in common.js: the declared charset, else UTF-8 when the label is unknown.
func decodeBytes(data []byte, charset string) string {
	enc, err := htmlindex.Get(normalizeCharset(charset))
	if err != nil {
		enc, _ = htmlindex.Get("utf-8")
	}
	out, err := enc.NewDecoder().Bytes(data)
	if err != nil {
		out = data
	}
	return strings.TrimPrefix(strings.ToValidUTF8(string(out), "�"), "\uFEFF")
}

func mojibakeScore(s string) int {
	score := 0
	for _, r := range s {
		switch r {
		case '�':
			score += 4
		case 'Ã', 'Â':
			score += 3
		case 'â', 'ð', 'ï':
			score += 2
		}
	}
	return score
}

// latin1Bytes is Buffer.from(s, 'latin1'): the low byte of every UTF-16 unit.
func latin1Bytes(s string) []byte {
	units := utf16.Encode([]rune(s))
	out := make([]byte, len(units))
	for i, u := range units {
		out[i] = byte(u)
	}
	return out
}

func repairMojibake(value string) string {
	current := value
	for i := 0; i < 2; i++ {
		if mojibakeScore(current) == 0 {
			break
		}
		repaired := decodeUTF8Lossy(latin1Bytes(current))
		if repaired == "" || mojibakeScore(repaired) >= mojibakeScore(current) {
			break
		}
		current = repaired
	}
	return current
}

// decodeUTF8Lossy is buffer.toString('utf8'): invalid bytes become U+FFFD.
func decodeUTF8Lossy(b []byte) string {
	var out strings.Builder
	for len(b) > 0 {
		r, size := utf8.DecodeRune(b)
		if r == utf8.RuneError && size == 1 {
			out.WriteRune('�')
		} else {
			out.WriteRune(r)
		}
		b = b[size:]
	}
	return out.String()
}

func parseCharset(contentType string) string {
	if m := quotedCS.FindStringSubmatch(contentType); m != nil {
		return m[1]
	}
	if m := plainCS.FindStringSubmatch(contentType); m != nil {
		return m[1]
	}
	return "utf-8"
}

func isHex(s string) bool {
	_, err := strconv.ParseUint(s, 16, 8)
	return err == nil && len(s) == 2 && !strings.ContainsAny(s, "+-")
}

// decodeQuotedPrintable is decodeQuotedPrintableToBuffer: "=XX" becomes a
// byte, any other character contributes its low byte.
func decodeQuotedPrintable(value string) []byte {
	cleaned := qpBreak.ReplaceAllString(value, "")
	units := utf16.Encode([]rune(cleaned))
	var out []byte
	for i := 0; i < len(units); i++ {
		if units[i] == '=' && i+2 < len(units) {
			pair := string(utf16.Decode(units[i+1 : i+3]))
			if isHex(pair) {
				n, _ := strconv.ParseUint(pair, 16, 8)
				out = append(out, byte(n))
				i += 2
				continue
			}
		}
		out = append(out, byte(units[i]))
	}
	return out
}

func decodeMimeWord(charset, encoding, value string) string {
	switch strings.ToUpper(strings.TrimSpace(encoding)) {
	case "B":
		return repairMojibake(decodeBytes(base64StdLenient(value), charset))
	case "Q":
		return repairMojibake(decodeBytes(decodeQuotedPrintable(strings.ReplaceAll(value, "_", " ")), charset))
	}
	return value
}

// base64StdLenient is Buffer.from(value, 'base64').
func base64StdLenient(value string) []byte { return base64URLDecode(value) }

func decodeMimeWords(value string) string {
	return mimeWord.ReplaceAllStringFunc(value, func(m string) string {
		parts := mimeWord.FindStringSubmatch(m)
		return decodeMimeWord(parts[1], parts[2], parts[3])
	})
}

func normalizeDecodedText(value string) string {
	return repairMojibake(decodeMimeWords(value))
}

type header struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

// getHeader is the decoded value of a header, nil when absent.
func getHeader(headers []header, name string) *string {
	for _, h := range headers {
		if strings.EqualFold(h.Name, name) {
			v := normalizeDecodedText(h.Value)
			return &v
		}
	}
	return nil
}

func headerText(headers []header, name string) string {
	if v := getHeader(headers, name); v != nil {
		return *v
	}
	return ""
}

type messagePayload struct {
	MimeType string `json:"mimeType"`
	Headers  []header
	Body     struct {
		Data string `json:"data"`
	} `json:"body"`
	Parts []messagePayload `json:"parts"`
}

// extractMessageBody is the first text/plain or text/html part as text.
func extractMessageBody(p *messagePayload) string {
	if p == nil {
		return ""
	}
	contentType := headerText(p.Headers, "Content-Type")
	transfer := strings.ToLower(headerText(p.Headers, "Content-Transfer-Encoding"))
	charset := parseCharset(contentType)
	if p.Body.Data != "" && (p.MimeType == "text/plain" || p.MimeType == "text/html") {
		raw := base64URLDecode(p.Body.Data)
		var decoded string
		if strings.Contains(transfer, "quoted-printable") {
			decoded = decodeBytes(decodeQuotedPrintable(string(latin1Decode(raw))), charset)
		} else {
			decoded = decodeBytes(raw, charset)
		}
		text := normalizeDecodedText(decoded)
		if p.MimeType == "text/html" {
			return stripHTML(text)
		}
		return text
	}
	for i := range p.Parts {
		if text := extractMessageBody(&p.Parts[i]); text != "" {
			return text
		}
	}
	return ""
}

// latin1Decode is raw.toString('latin1'): one character per byte.
func latin1Decode(raw []byte) []rune {
	out := make([]rune, len(raw))
	for i, b := range raw {
		out[i] = rune(b)
	}
	return out
}

// stringToBase64URL is the unpadded URL-safe encoding Gmail wants for "raw".
func stringToBase64URL(text string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(text))
}

// encodeHeaderWords is RFC 2047: raw 8-bit header bytes are read as Latin-1 by
// Gmail, so non-ASCII values go out as UTF-8 base64 encoded-words, each kept
// under 75 characters.
func encodeHeaderWords(value string) string {
	ascii := true
	for _, r := range value {
		if r < 0x20 || r > 0x7e {
			ascii = false
			break
		}
	}
	if ascii {
		return value
	}
	var words []string
	var chunk bytes.Buffer
	for _, r := range value {
		if chunk.Len()+utf8.RuneLen(r) > 45 {
			words = append(words, chunk.String())
			chunk.Reset()
		}
		chunk.WriteRune(r)
	}
	if chunk.Len() > 0 {
		words = append(words, chunk.String())
	}
	for i, w := range words {
		words[i] = "=?UTF-8?B?" + base64.StdEncoding.EncodeToString([]byte(w)) + "?="
	}
	return strings.Join(words, "\r\n ")
}

// coerceStringList is a list of trimmed, non-empty strings from an array or a
// comma-separated string.
func coerceStringList(value any) []string {
	var parts []string
	switch v := value.(type) {
	case []any:
		for _, item := range v {
			parts = append(parts, jsTrim(textOf(item)))
		}
	case string:
		parts = strings.Split(v, ",")
		for i := range parts {
			parts[i] = jsTrim(parts[i])
		}
	}
	out := []string{}
	for _, p := range parts {
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
