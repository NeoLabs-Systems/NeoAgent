// Package codenav is the code_navigate tool (workspace/code_navigation.js):
// the top-level declarations of a JavaScript or TypeScript file, and a
// semantic search over them across the workspace.
//
// Node parsed files with oxc-parser. There is no pure-Go JavaScript/TypeScript
// parser with a public AST (esbuild and typescript-go keep theirs internal,
// tree-sitter needs cgo), and this tool only needs the spans of top-level
// declarations, so a lexical scanner finds them: it skips comments, strings,
// template literals and regular expressions, tracks bracket depth, and reads
// declarations at depth zero.
package codenav

import (
	"strings"
	"unicode"
	"unicode/utf8"
)

// Symbol is one top-level declaration.
type Symbol struct {
	Name      string `json:"name"`
	Type      string `json:"type"`
	StartLine int    `json:"startLine"`
	EndLine   int    `json:"endLine"`
	Excerpt   string `json:"excerpt"`
}

const excerptUnits = 1600

type scanner struct {
	src    string
	errors []string
	// decoratorStart is where the decorators before the current declaration
	// begin, -1 when there are none.
	decoratorStart int
}

// skipDecorator returns the offset after `@name.chain(args)`.
func (s *scanner) skipDecorator(at token) int {
	prev := at
	i := at.end
	for {
		t, ok := s.next(i, prev)
		if !ok {
			return i
		}
		if t.word != "" || t.char == '.' || (t.char == '(' && prev.char != '(') {
			if t.char == '(' {
				return t.end
			}
			if t.word != "" && prev.word != "" {
				return i
			}
			prev, i = t, t.end
			continue
		}
		return i
	}
}

func isIdentStart(r rune) bool { return r == '_' || r == '$' || unicode.IsLetter(r) }
func isIdentPart(r rune) bool {
	return isIdentStart(r) || unicode.IsDigit(r) || r == 0x200C || r == 0x200D
}

func (s *scanner) runeAt(i int) (rune, int) {
	if i >= len(s.src) {
		return 0, 0
	}
	return utf8.DecodeRuneInString(s.src[i:])
}

// skipString returns the offset after a quoted string starting at i.
func (s *scanner) skipString(i int) int {
	quote := s.src[i]
	for j := i + 1; j < len(s.src); j++ {
		switch s.src[j] {
		case '\\':
			j++
		case quote:
			return j + 1
		case '\n':
			if quote != '`' {
				s.errors = append(s.errors, "Unterminated string")
				return j
			}
		}
	}
	s.errors = append(s.errors, "Unterminated string")
	return len(s.src)
}

// skipTemplate returns the offset after a template literal starting at i,
// stepping over ${...} substitutions.
func (s *scanner) skipTemplate(i int) int {
	for j := i + 1; j < len(s.src); j++ {
		switch s.src[j] {
		case '\\':
			j++
		case '`':
			return j + 1
		case '$':
			if j+1 < len(s.src) && s.src[j+1] == '{' {
				j = s.skipBalanced(j+1, '{', '}') - 1
			}
		}
	}
	s.errors = append(s.errors, "Unterminated template")
	return len(s.src)
}

// skipRegex returns the offset after a regular expression literal at i.
func (s *scanner) skipRegex(i int) int {
	inClass := false
	for j := i + 1; j < len(s.src); j++ {
		switch s.src[j] {
		case '\\':
			j++
		case '[':
			inClass = true
		case ']':
			inClass = false
		case '/':
			if !inClass {
				j++
				for j < len(s.src) {
					r, w := s.runeAt(j)
					if !isIdentPart(r) {
						break
					}
					j += w
				}
				return j
			}
		case '\n':
			return j
		}
	}
	return len(s.src)
}

// skipComment returns the offset after a comment at i, or i when none starts.
func (s *scanner) skipComment(i int) int {
	if i+1 >= len(s.src) || s.src[i] != '/' {
		return i
	}
	switch s.src[i+1] {
	case '/':
		if end := strings.IndexByte(s.src[i:], '\n'); end >= 0 {
			return i + end
		}
		return len(s.src)
	case '*':
		if end := strings.Index(s.src[i+2:], "*/"); end >= 0 {
			return i + 2 + end + 2
		}
		s.errors = append(s.errors, "Unterminated multiline comment")
		return len(s.src)
	}
	return i
}

// regexAllowed: a '/' after these starts a regular expression, not a division.
func regexAllowed(prev byte, prevWord string) bool {
	switch prevWord {
	case "return", "typeof", "instanceof", "in", "of", "new", "delete", "void", "throw", "case", "do", "else", "yield", "await":
		return true
	}
	if prevWord != "" {
		return false
	}
	return prev == 0 || strings.IndexByte("(,=:[!&|?{};+-*%<>~^", prev) >= 0
}

// skipBalanced returns the offset after the bracket closing the one at i.
func (s *scanner) skipBalanced(i int, open, close byte) int {
	depth := 0
	var prev byte
	prevWord := ""
	for j := i; j < len(s.src); {
		if k := s.skipComment(j); k != j {
			j = k
			continue
		}
		c := s.src[j]
		switch {
		case c == '"' || c == '\'':
			j = s.skipString(j)
			prev, prevWord = '"', ""
			continue
		case c == '`':
			j = s.skipTemplate(j)
			prev, prevWord = '`', ""
			continue
		case c == '/' && regexAllowed(prev, prevWord):
			j = s.skipRegex(j)
			prev, prevWord = 'r', ""
			continue
		case c == open:
			depth++
		case c == close:
			depth--
			if depth == 0 {
				return j + 1
			}
		}
		r, w := s.runeAt(j)
		if isIdentStart(r) {
			k := j
			for k < len(s.src) {
				r2, w2 := s.runeAt(k)
				if !isIdentPart(r2) {
					break
				}
				k += w2
			}
			prev, prevWord = 'a', s.src[j:k]
			j = k
			continue
		}
		if !unicode.IsSpace(r) {
			prev, prevWord = c, ""
		}
		j += w
	}
	s.errors = append(s.errors, "Unexpected end of file")
	return len(s.src)
}

// token is a significant token at depth zero.
type token struct {
	start, end int
	word       string // identifier text, "" for punctuation
	char       byte
}

// next returns the next significant token at or after i, skipping space,
// comments and (as whole tokens) strings, templates, regexes and brackets.
func (s *scanner) next(i int, prev token) (token, bool) {
	for i < len(s.src) {
		if k := s.skipComment(i); k != i {
			i = k
			continue
		}
		r, w := s.runeAt(i)
		if unicode.IsSpace(r) {
			i += w
			continue
		}
		c := s.src[i]
		switch {
		case c == '"' || c == '\'':
			return token{start: i, end: s.skipString(i), char: '"'}, true
		case c == '`':
			return token{start: i, end: s.skipTemplate(i), char: '`'}, true
		case c == '/' && regexAllowed(prev.char, prev.word):
			return token{start: i, end: s.skipRegex(i), char: 'r'}, true
		case c == '{':
			return token{start: i, end: s.skipBalanced(i, '{', '}'), char: '{'}, true
		case c == '(':
			return token{start: i, end: s.skipBalanced(i, '(', ')'), char: '('}, true
		case c == '[':
			return token{start: i, end: s.skipBalanced(i, '[', ']'), char: '['}, true
		case isIdentStart(r):
			k := i
			for k < len(s.src) {
				r2, w2 := s.runeAt(k)
				if !isIdentPart(r2) {
					break
				}
				k += w2
			}
			return token{start: i, end: k, word: s.src[i:k], char: 'a'}, true
		}
		return token{start: i, end: i + w, char: c}, true
	}
	return token{}, false
}

// newlineBetween reports a line break between two offsets.
func (s *scanner) newlineBetween(a, b int) bool { return strings.IndexByte(s.src[a:b], '\n') >= 0 }

// continues: an expression goes on after a line ending with these.
func continues(t token) bool {
	if t.word != "" {
		return false
	}
	return strings.IndexByte("=,.([+-*/%&|^!?:<>~", t.char) >= 0
}

// startsContinuation: a line starting with these continues the previous one.
func startsContinuation(t token) bool {
	return t.word == "" && strings.IndexByte(".,([+-*/%&|^?:=<>`", t.char) >= 0
}

// statementEnd is where a statement starting at from ends: after its ';', or
// where automatic semicolon insertion ends it at a line break.
func (s *scanner) statementEnd(from int) int {
	var prev token
	i := from
	end := from
	first := true
	for {
		t, ok := s.next(i, prev)
		if !ok {
			return end
		}
		if t.char == ';' {
			return t.end
		}
		if !first && s.newlineBetween(prev.end, t.start) && !continues(prev) && !startsContinuation(t) {
			return end
		}
		if t.char == '}' || t.char == ')' || t.char == ']' {
			return end
		}
		first = false
		end = t.end
		prev = t
		i = t.end
	}
}

// bodyEnd is the end of a function, class, enum or interface: the brace
// closing its body, which is the first '{' at depth zero after the keyword.
// ok=false for a declaration without a body (an overload or declare).
func (s *scanner) bodyEnd(from int) (int, bool) {
	var prev token
	angles := 0
	i := from
	for {
		t, ok := s.next(i, prev)
		if !ok {
			return len(s.src), false
		}
		switch t.char {
		case '<':
			angles++
		case '>':
			if prev.char != '=' && angles > 0 {
				angles--
			}
		case '{':
			// A '{' inside type arguments or right after ':' is a type, as in
			// `(): Promise<{ ok: boolean }> {` or `(): { a: 1 } {`.
			if prev.char == ':' || angles > 0 {
				prev, i = t, t.end
				continue
			}
			return t.end, true
		case ';':
			return t.end, false
		}
		if prev.word != "" && t.word != "" && s.newlineBetween(prev.end, t.start) && isStatementKeyword(t.word) {
			return prev.end, false
		}
		prev, i = t, t.end
	}
}

func isStatementKeyword(w string) bool {
	switch w {
	case "export", "import", "function", "class", "const", "let", "var", "interface", "type", "enum", "declare", "async", "abstract":
		return true
	}
	return false
}

func lineAt(src string, offset int) int { return strings.Count(src[:offset], "\n") + 1 }

// excerpt is content.slice(start, min(end, start+1600)) in UTF-16 units.
func excerpt(src string, start, end int) string {
	units := 0
	for i, r := range src[start:end] {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > excerptUnits {
			return src[start : start+i]
		}
		units += w
	}
	return src[start:end]
}

// Structure lists the top-level declarations of a source file, with the
// problems the scanner met.
func Structure(src string) ([]Symbol, []string) {
	s := &scanner{src: src}
	symbols := []Symbol{}
	var prev token
	i := 0
	decorators := -1
	for {
		t, ok := s.next(i, prev)
		if !ok {
			break
		}
		atStatement := prev.end == 0 && prev.char == 0 || prev.char == ';' || prev.char == '{' ||
			(s.newlineBetween(prev.end, t.start) && !continues(prev) && !startsContinuation(t))
		if atStatement && t.char == '@' {
			// Decorators belong to the class they precede.
			if decorators < 0 {
				decorators = t.start
			}
			i = s.skipDecorator(t)
			prev = token{start: i - 1, end: i, char: ';'}
			continue
		}
		if atStatement && t.word != "" {
			s.decoratorStart = decorators
			decorators = -1
			if sym, end, found := s.declaration(t); found {
				symbols = append(symbols, sym)
				prev = token{start: end - 1, end: end, char: ';'}
				i = end
				continue
			}
		}
		prev, i = t, t.end
	}
	errors := s.errors
	if len(errors) > 20 {
		errors = errors[:20]
	}
	if errors == nil {
		errors = []string{}
	}
	return symbols, errors
}

// declaration reads a declaration starting at t; end is where scanning
// resumes.
func (s *scanner) declaration(t token) (Symbol, int, bool) {
	words := func(from int, n int) []token {
		var out []token
		var prev token
		i := from
		for len(out) < n {
			tk, ok := s.next(i, prev)
			if !ok {
				break
			}
			out = append(out, tk)
			prev, i = tk, tk.end
		}
		return out
	}
	cur := t
	isDefault := false
	if cur.word == "export" {
		ahead := words(cur.end, 1)
		if len(ahead) == 0 {
			return Symbol{}, 0, false
		}
		cur = ahead[0]
		if cur.word == "default" {
			isDefault = true
			ahead = words(cur.end, 1)
			if len(ahead) == 0 {
				return Symbol{}, 0, false
			}
			cur = ahead[0]
		}
	}
	start := cur.start
	for cur.word == "declare" || cur.word == "abstract" || cur.word == "async" {
		modifier := cur.word
		ahead := words(cur.end, 1)
		if len(ahead) == 0 {
			return Symbol{}, 0, false
		}
		if modifier == "declare" {
			// declare function/const/... has no body in the output tree here.
			return Symbol{}, s.statementEnd(start), false
		}
		cur = ahead[0]
	}
	name := func(after int) (string, int) {
		ahead := words(after, 1)
		if len(ahead) == 1 && ahead[0].word != "" {
			return ahead[0].word, ahead[0].end
		}
		return "", after
	}
	symbol := func(kind, n string, end int) (Symbol, int, bool) {
		if n == "" {
			n = "default"
		}
		return Symbol{Name: n, Type: kind, StartLine: lineAt(s.src, start), EndLine: lineAt(s.src, end), Excerpt: excerpt(s.src, start, end)}, end, true
	}
	switch cur.word {
	case "function":
		after := cur.end
		if ahead := words(after, 1); len(ahead) == 1 && ahead[0].char == '*' {
			after = ahead[0].end
		}
		n, _ := name(after)
		end, hasBody := s.bodyEnd(after)
		if !hasBody {
			return Symbol{}, end, false
		}
		return symbol("FunctionDeclaration", n, end)
	case "class":
		if s.decoratorStart >= 0 {
			start = s.decoratorStart
		}
		n, after := name(cur.end)
		if n == "extends" || n == "implements" {
			n, after = "", cur.end
		}
		end, _ := s.bodyEnd(after)
		return symbol("ClassDeclaration", n, end)
	case "interface":
		n, after := name(cur.end)
		end, _ := s.bodyEnd(after)
		return symbol("TSInterfaceDeclaration", n, end)
	case "enum":
		n, after := name(cur.end)
		end, _ := s.bodyEnd(after)
		return symbol("TSEnumDeclaration", n, end)
	case "type":
		if isDefault {
			return Symbol{}, 0, false
		}
		n, after := name(cur.end)
		if n == "" {
			return Symbol{}, 0, false
		}
		ahead := words(after, 1)
		if len(ahead) == 0 || (ahead[0].char != '=' && ahead[0].char != '<') {
			return Symbol{}, 0, false
		}
		return symbol("TSTypeAliasDeclaration", n, s.statementEnd(start))
	case "const", "let", "var":
		if isDefault {
			return Symbol{}, 0, false
		}
		ahead := words(cur.end, 2)
		if cur.word == "const" && len(ahead) > 0 && ahead[0].word == "enum" {
			n, after := name(ahead[0].end)
			end, _ := s.bodyEnd(after)
			return symbol("TSEnumDeclaration", n, end)
		}
		end := s.statementEnd(start)
		if len(ahead) == 0 || ahead[0].word == "" {
			// Destructuring has no single name.
			return Symbol{}, end, false
		}
		return symbol("VariableDeclaration", ahead[0].word, end)
	}
	return Symbol{}, 0, false
}
