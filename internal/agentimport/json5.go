package agentimport

import (
	"bytes"
	"encoding/json"
	"errors"
	"regexp"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"
)

// parseJSON5 reads JSON5 (comments, unquoted keys, single quotes, trailing
// commas, hex and loose numbers) into the same ordered values as parseJSON. It
// serves OpenClaw's hand-edited openclaw.json.
func parseJSON5(text string) (any, error) {
	var out strings.Builder
	p := &json5{src: text, out: &out}
	if err := p.value(); err != nil {
		return nil, err
	}
	p.skip()
	if p.pos < len(p.src) {
		return nil, errors.New("json5: unexpected data after value")
	}
	return parseJSON([]byte(out.String()))
}

type json5 struct {
	src string
	pos int
	out *strings.Builder
}

var errJSON5 = errors.New("json5: invalid syntax")

func (p *json5) peek() (rune, int) {
	if p.pos >= len(p.src) {
		return 0, 0
	}
	return utf8.DecodeRuneInString(p.src[p.pos:])
}

// skip passes whitespace and comments.
func (p *json5) skip() {
	for p.pos < len(p.src) {
		r, w := p.peek()
		switch {
		case isJSSpace(r):
			p.pos += w
		case strings.HasPrefix(p.src[p.pos:], "//"):
			for p.pos < len(p.src) && p.src[p.pos] != '\n' {
				p.pos++
			}
		case strings.HasPrefix(p.src[p.pos:], "/*"):
			end := strings.Index(p.src[p.pos+2:], "*/")
			if end < 0 {
				p.pos = len(p.src)
				return
			}
			p.pos += end + 4
		default:
			return
		}
	}
}

func (p *json5) value() error {
	p.skip()
	r, _ := p.peek()
	switch {
	case p.pos >= len(p.src):
		return errJSON5
	case r == '{':
		return p.object()
	case r == '[':
		return p.array()
	case r == '"' || r == '\'':
		return p.str()
	}
	return p.literal()
}

func (p *json5) object() error {
	p.pos++
	p.out.WriteByte('{')
	first := true
	for {
		p.skip()
		r, _ := p.peek()
		if r == '}' {
			p.pos++
			break
		}
		if !first {
			p.out.WriteByte(',')
		}
		first = false
		if err := p.key(); err != nil {
			return err
		}
		p.skip()
		if r, _ := p.peek(); r != ':' {
			return errJSON5
		}
		p.pos++
		p.out.WriteByte(':')
		if err := p.value(); err != nil {
			return err
		}
		p.skip()
		switch r, _ := p.peek(); r {
		case ',':
			p.pos++
		case '}':
		default:
			return errJSON5
		}
	}
	p.out.WriteByte('}')
	return nil
}

func (p *json5) key() error {
	r, _ := p.peek()
	if r == '"' || r == '\'' {
		return p.str()
	}
	start := p.pos
	for p.pos < len(p.src) {
		r, w := p.peek()
		if r == '$' || r == '_' || unicode.IsLetter(r) || (p.pos > start && (unicode.IsDigit(r) || unicode.Is(unicode.Mn, r))) {
			p.pos += w
			continue
		}
		break
	}
	if p.pos == start {
		return errJSON5
	}
	q, _ := jsonQuote(p.src[start:p.pos])
	p.out.WriteString(q)
	return nil
}

func (p *json5) array() error {
	p.pos++
	p.out.WriteByte('[')
	first := true
	for {
		p.skip()
		r, _ := p.peek()
		if r == ']' {
			p.pos++
			break
		}
		if !first {
			p.out.WriteByte(',')
		}
		first = false
		if err := p.value(); err != nil {
			return err
		}
		p.skip()
		switch r, _ := p.peek(); r {
		case ',':
			p.pos++
		case ']':
		default:
			return errJSON5
		}
	}
	p.out.WriteByte(']')
	return nil
}

func (p *json5) str() error {
	quote := p.src[p.pos]
	p.pos++
	var b strings.Builder
	for {
		if p.pos >= len(p.src) {
			return errJSON5
		}
		r, w := p.peek()
		p.pos += w
		switch {
		case byte(r) == quote && r < utf8.RuneSelf:
			s, _ := jsonQuote(b.String())
			p.out.WriteString(s)
			return nil
		case r == '\n':
			return errJSON5
		case r == '\\':
			esc, ew := p.peek()
			p.pos += ew
			switch esc {
			case 'n':
				b.WriteByte('\n')
			case 't':
				b.WriteByte('\t')
			case 'r':
				b.WriteByte('\r')
			case 'b':
				b.WriteByte('\b')
			case 'f':
				b.WriteByte('\f')
			case 'v':
				b.WriteByte('\v')
			case '0':
				b.WriteByte(0)
			case '\n':
			case '\r':
				if p.pos < len(p.src) && p.src[p.pos] == '\n' {
					p.pos++
				}
			case 'x', 'u':
				n := 2
				if esc == 'u' {
					n = 4
				}
				if p.pos+n > len(p.src) {
					return errJSON5
				}
				code, err := strconv.ParseUint(p.src[p.pos:p.pos+n], 16, 32)
				if err != nil {
					return errJSON5
				}
				p.pos += n
				b.WriteRune(rune(code))
			default:
				b.WriteRune(esc)
			}
		default:
			b.WriteRune(r)
		}
	}
}

// literal reads true, false, null, Infinity, NaN or a number. JSON has no
// Infinity or NaN; as in JSON.stringify they become null.
func (p *json5) literal() error {
	start := p.pos
	for p.pos < len(p.src) {
		r, w := p.peek()
		if isJSSpace(r) || strings.ContainsRune(",]}:/", r) {
			break
		}
		p.pos += w
	}
	tok := p.src[start:p.pos]
	switch tok {
	case "true", "false", "null":
		p.out.WriteString(tok)
		return nil
	case "Infinity", "+Infinity", "-Infinity", "NaN", "+NaN", "-NaN":
		p.out.WriteString("null")
		return nil
	}
	sign := ""
	body := tok
	if strings.HasPrefix(body, "+") {
		body = body[1:]
	} else if strings.HasPrefix(body, "-") {
		sign, body = "-", body[1:]
	}
	if len(body) > 2 && (body[:2] == "0x" || body[:2] == "0X") {
		n, err := strconv.ParseUint(body[2:], 16, 64)
		if err != nil {
			return errJSON5
		}
		p.out.WriteString(sign + strconv.FormatUint(n, 10))
		return nil
	}
	if strings.HasPrefix(body, ".") {
		body = "0" + body
	}
	body = strings.Replace(body, ".e", ".0e", 1)
	body = strings.Replace(body, ".E", ".0E", 1)
	body = strings.TrimSuffix(body, ".")
	if !plainNumber.MatchString(body) {
		return errJSON5
	}
	p.out.WriteString(sign + body)
	return nil
}

var plainNumber = regexp.MustCompile(`^(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$`)

func jsonQuote(s string) (string, error) {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(s); err != nil {
		return "", err
	}
	// JSON.stringify leaves U+2028 and U+2029 as they are.
	out := strings.TrimSuffix(b.String(), "\n")
	out = strings.ReplaceAll(out, `\u2028`, "\u2028")
	return strings.ReplaceAll(out, `\u2029`, "\u2029"), nil
}
