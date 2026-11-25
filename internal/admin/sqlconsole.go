package admin

import (
	"bytes"
	"context"
	"encoding/json"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// The SQL console runs one read-only query for the admin page. Node's guards
// are kept as they are (the statement must start with SELECT or WITH and may
// not contain a write keyword). On top of them, queries run on the read-only
// connection pool, so a statement that slips past the keyword check still
// cannot write.

const maxQueryRows = 500

var (
	queryStart      = regexp.MustCompile(`(?i)^(SELECT|WITH)\b`)
	blockedKeywords = regexp.MustCompile(`(?i)\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|ATTACH|DETACH|TRUNCATE|VACUUM|REINDEX|REPLACE|UPSERT|PRAGMA)\b`)
	driverErrorText = regexp.MustCompile(`^(?:SQL logic error|constraint failed|[A-Za-z ]+ error): (.*?)(?: \(\d+\))?$`)
)

// QueryResult is what the console returns.
type QueryResult struct {
	Rows      []queryRow `json:"rows"`
	Columns   []string   `json:"columns"`
	Truncated bool       `json:"truncated"`
	Total     *int       `json:"total"`
}

// queryRow is a row as a JavaScript object: keys in property order, a repeated
// column name keeping its last value.
type queryRow struct {
	keys   []string
	values map[string]any
}

func (r queryRow) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, key := range r.keys {
		if i > 0 {
			buf.WriteByte(',')
		}
		name, _ := json.Marshal(key)
		value, err := json.Marshal(r.values[key])
		if err != nil {
			return nil, err
		}
		buf.Write(name)
		buf.WriteByte(':')
		buf.Write(value)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

// isArrayIndex reports whether a property name is a canonical array index,
// which JavaScript orders before every other key.
func isArrayIndex(name string) bool {
	if name == "" || (len(name) > 1 && name[0] == '0') {
		return false
	}
	n, err := strconv.ParseUint(name, 10, 64)
	return err == nil && n < math.MaxUint32 && strings.Trim(name, "0123456789") == ""
}

func propertyOrder(names []string) []string {
	var indices, others []string
	seen := map[string]bool{}
	for _, name := range names {
		if seen[name] {
			continue
		}
		seen[name] = true
		if isArrayIndex(name) {
			indices = append(indices, name)
		} else {
			others = append(others, name)
		}
	}
	sort.Slice(indices, func(i, j int) bool {
		a, _ := strconv.ParseUint(indices[i], 10, 64)
		b, _ := strconv.ParseUint(indices[j], 10, 64)
		return a < b
	})
	return append(indices, others...)
}

// jsValue maps a SQLite value to what better-sqlite3 hands JavaScript: integers
// become doubles, blobs become Buffers, and infinities serialise as null.
func jsValue(v any) any {
	switch v := v.(type) {
	case int64:
		return float64(v)
	case float64:
		if math.IsInf(v, 0) || math.IsNaN(v) {
			return nil
		}
		return v
	case []byte:
		data := make([]int, len(v))
		for i, b := range v {
			data[i] = int(b)
		}
		return map[string]any{"type": "Buffer", "data": data}
	}
	return v
}

// RunReadOnlyQuery runs one query and returns at most 500 rows.
func (s *Store) RunReadOnlyQuery(ctx context.Context, query any) (QueryResult, error) {
	text, ok := query.(string)
	if !ok || text == "" {
		return QueryResult{}, fail(400, "No query provided", "")
	}
	sqlText := jsTrim(text)
	if !queryStart.MatchString(sqlText) {
		return QueryResult{}, fail(400, "Only SELECT (or WITH …) queries are allowed", "")
	}
	if blockedKeywords.MatchString(sqlText) {
		return QueryResult{}, fail(400, "Query contains a blocked SQL keyword", "")
	}

	// better-sqlite3 compiles the first statement, then refuses a second one.
	first, rest := splitFirstStatement(sqlText)
	stmt, err := s.DB.R.PrepareContext(ctx, first)
	if err != nil {
		return QueryResult{}, fail(400, sqliteMessage(err), "")
	}
	defer stmt.Close()
	if hasStatement(rest) {
		return QueryResult{}, fail(400, "The supplied SQL string contains more than one statement", "")
	}
	rows, err := stmt.QueryContext(ctx)
	if err != nil {
		return QueryResult{}, fail(400, sqliteMessage(err), "")
	}
	defer rows.Close()
	names, err := rows.Columns()
	if err != nil {
		return QueryResult{}, fail(400, sqliteMessage(err), "")
	}
	order := propertyOrder(names)

	result := QueryResult{Rows: []queryRow{}, Columns: []string{}}
	for rows.Next() {
		values := make([]any, len(names))
		targets := make([]any, len(names))
		for i := range values {
			targets[i] = &values[i]
		}
		if err := rows.Scan(targets...); err != nil {
			return QueryResult{}, fail(400, sqliteMessage(err), "")
		}
		row := queryRow{keys: order, values: make(map[string]any, len(names))}
		for i, name := range names {
			row.values[name] = jsValue(values[i])
		}
		result.Rows = append(result.Rows, row)
		if len(result.Rows) > maxQueryRows {
			break
		}
	}
	if err := rows.Err(); err != nil {
		return QueryResult{}, fail(400, sqliteMessage(err), "")
	}

	result.Truncated = len(result.Rows) > maxQueryRows
	if result.Truncated {
		result.Rows = result.Rows[:maxQueryRows]
	} else {
		total := len(result.Rows)
		result.Total = &total
	}
	if len(result.Rows) > 0 {
		result.Columns = result.Rows[0].keys
	}
	return result, nil
}

// sqliteMessage is SQLite's own message (syntax error, unknown column, ...),
// which is what the admin needs, without the driver's wrapper text.
func sqliteMessage(err error) string {
	// A query with placeholders has nothing to bind: the console passes none.
	switch text := err.Error(); {
	case strings.HasPrefix(text, "missing named argument"):
		return "Missing named parameters"
	case strings.HasPrefix(text, "missing argument with index"):
		return "Too few parameter values were provided"
	}
	if m := driverErrorText.FindStringSubmatch(err.Error()); m != nil {
		return m[1]
	}
	return err.Error()
}

// splitFirstStatement cuts the text at the first semicolon that is not inside a
// quoted name or string or a comment.
func splitFirstStatement(text string) (first, rest string) {
	for i := 0; i < len(text); i++ {
		switch c := text[i]; c {
		case ';':
			return text[:i], text[i+1:]
		case '\'', '"', '`':
			i = skipPast(text, i+1, c)
		case '[':
			i = skipPast(text, i+1, ']')
		case '-':
			if strings.HasPrefix(text[i:], "--") {
				i = skipPast(text, i+2, '\n')
			}
		case '/':
			if strings.HasPrefix(text[i:], "/*") {
				i = skipBlockComment(text, i+2)
			}
		}
	}
	return text, ""
}

// skipPast returns the index of the first byte of text at or after from that
// equals end, or the last index when there is none. Doubled quotes need no
// special case: they close and reopen the string.
func skipPast(text string, from int, end byte) int {
	if j := strings.IndexByte(text[min(from, len(text)):], end); j >= 0 {
		return from + j
	}
	return len(text)
}

func skipBlockComment(text string, from int) int {
	if j := strings.Index(text[min(from, len(text)):], "*/"); j >= 0 {
		return from + j + 1
	}
	return len(text)
}

// hasStatement reports whether text holds anything but whitespace, semicolons
// and comments.
func hasStatement(text string) bool {
	for i := 0; i < len(text); i++ {
		switch c := text[i]; {
		case c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == ';':
		case c == 0:
			return false
		case strings.HasPrefix(text[i:], "--"):
			i = skipPast(text, i+2, '\n')
		case strings.HasPrefix(text[i:], "/*"):
			i = skipBlockComment(text, i+2)
		default:
			return true
		}
	}
	return false
}
