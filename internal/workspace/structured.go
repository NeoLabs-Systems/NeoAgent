package workspace

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"math"
	"net/url"
	"path/filepath"
	"strings"

	_ "modernc.org/sqlite" // registers the "sqlite" driver
)

// ParseDelimited reads CSV or TSV text into one object per row, keyed by the
// header row. Quoted cells, doubled quotes and CRLF are handled; blank rows
// are skipped.
func ParseDelimited(text string, delimiter rune) []Obj {
	var rows [][]string
	var row []string
	var value strings.Builder
	quoted := false
	runes := []rune(text)
	flushRow := func() {
		row = append(row, value.String())
		value.Reset()
		for _, cell := range row {
			if cell != "" {
				rows = append(rows, row)
				break
			}
		}
		row = nil
	}
	for i := 0; i < len(runes); i++ {
		c := runes[i]
		switch {
		case c == '"':
			if quoted && i+1 < len(runes) && runes[i+1] == '"' {
				value.WriteRune('"')
				i++
			} else {
				quoted = !quoted
			}
		case c == delimiter && !quoted:
			row = append(row, value.String())
			value.Reset()
		case (c == '\n' || c == '\r') && !quoted:
			if c == '\r' && i+1 < len(runes) && runes[i+1] == '\n' {
				i++
			}
			flushRow()
		default:
			value.WriteRune(c)
		}
	}
	flushRow()
	if len(rows) == 0 {
		return []Obj{}
	}
	headers := rows[0]
	out := make([]Obj, 0, len(rows)-1)
	for _, cells := range rows[1:] {
		var obj Obj
		index := map[string]int{}
		for i, h := range headers {
			cell := ""
			if i < len(cells) {
				cell = cells[i]
			}
			if at, dup := index[h]; dup {
				obj[at].Value = cell
				continue
			}
			index[h] = len(obj)
			obj = append(obj, Field{h, cell})
		}
		if obj == nil {
			obj = Obj{}
		}
		out = append(out, obj)
	}
	return out
}

// decodeOrdered parses JSON keeping object member order (objects become Obj).
func decodeOrdered(data []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	v, err := readValue(dec)
	if err != nil {
		return nil, err
	}
	if _, err := dec.Token(); err != io.EOF {
		return nil, errors.New("Unexpected non-whitespace character after JSON")
	}
	return v, nil
}

func readValue(dec *json.Decoder) (any, error) {
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	delim, ok := tok.(json.Delim)
	if !ok {
		return tok, nil
	}
	if delim == '[' {
		arr := []any{}
		for dec.More() {
			v, err := readValue(dec)
			if err != nil {
				return nil, err
			}
			arr = append(arr, v)
		}
		_, err := dec.Token()
		return arr, err
	}
	obj := Obj{}
	index := map[string]int{}
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return nil, err
		}
		key := keyTok.(string)
		v, err := readValue(dec)
		if err != nil {
			return nil, err
		}
		if at, dup := index[key]; dup {
			obj[at].Value = v
			continue
		}
		index[key] = len(obj)
		obj = append(obj, Field{key, v})
	}
	_, err = dec.Token()
	return obj, err
}

// primitiveEqual is JS === for decoded JSON values; objects never match.
func primitiveEqual(a, b any) bool {
	fx, aNum := asFloat(a)
	fy, bNum := asFloat(b)
	if aNum || bNum {
		return aNum && bNum && fx == fy
	}
	switch a.(type) {
	case string, bool, nil:
		return a == b
	}
	return false
}

var sqliteExtensions = map[string]bool{".sqlite": true, ".db": true, ".sqlite3": true}

// Query reads rows from a CSV, TSV, JSON or SQLite file in the workspace.
// Options: path, limit (1-1000, default 100), columns, equals, and for SQLite
// sql and parameters.
func (m *Manager) Query(ctx context.Context, userKey string, o Options) (Obj, error) {
	rel, err := m.Rel(userKey, o.str("path"), "path")
	if err != nil {
		return nil, err
	}
	ext := strings.ToLower(filepath.Ext(rel))
	limit := 100.0
	if v, ok := number(o["limit"]); ok && v != 0 && !math.IsNaN(v) {
		limit = v
	}
	limit = math.Min(math.Max(limit, 1), 1000)
	n := int(limit)

	if sqliteExtensions[ext] {
		return m.querySQLite(ctx, userKey, rel, o, n)
	}
	root, err := m.open(userKey)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	raw, err := root.ReadFile(rel)
	if err != nil {
		return nil, confined(err, "path")
	}
	text := strings.ToValidUTF8(string(raw), "�")
	var rows []any
	switch ext {
	case ".json":
		parsed, err := decodeOrdered([]byte(text))
		if err != nil {
			return nil, err
		}
		if arr, ok := parsed.([]any); ok {
			rows = arr
		} else {
			rows = []any{parsed}
		}
	case ".csv", ".tsv":
		delim := ','
		if ext == ".tsv" {
			delim = '\t'
		}
		for _, r := range ParseDelimited(text, delim) {
			rows = append(rows, r)
		}
	default:
		return nil, errors.New("Supported structured-data formats are CSV, TSV, JSON, and SQLite.")
	}
	equals, _ := o["equals"].(map[string]any)
	var selected []string
	if cols, ok := o["columns"].([]any); ok {
		selected = []string{}
		for _, c := range cols {
			selected = append(selected, CoerceText(c))
		}
	}
	filtered := []any{}
	for _, row := range rows {
		obj, isObj := row.(Obj)
		keep := true
		for key, want := range equals {
			var got any = Undefined{}
			if isObj {
				if v, ok := obj.Get(key); ok {
					got = v
				}
			}
			if !primitiveEqual(got, want) {
				keep = false
				break
			}
		}
		if !keep {
			continue
		}
		if len(filtered) >= n {
			break
		}
		if selected != nil {
			picked := Obj{}
			for _, c := range selected {
				var v any = Undefined{}
				if isObj {
					if got, ok := obj.Get(c); ok {
						v = got
					}
				}
				picked = append(picked, Field{c, v})
			}
			row = picked
		}
		filtered = append(filtered, row)
	}
	columns := []string{}
	if len(filtered) > 0 {
		if first, ok := filtered[0].(Obj); ok {
			for _, f := range first {
				columns = append(columns, f.Key)
			}
		}
	}
	return Obj{{"format", strings.TrimPrefix(ext, ".")}, {"columns", columns}, {"rows", filtered}}, nil
}

func leadingWord(sqlText string) string {
	t := strings.TrimLeft(sqlText, " \t\r\n;")
	for strings.HasPrefix(t, "--") || strings.HasPrefix(t, "/*") {
		if strings.HasPrefix(t, "--") {
			i := strings.IndexByte(t, '\n')
			if i < 0 {
				return ""
			}
			t = strings.TrimLeft(t[i:], " \t\r\n")
		} else {
			i := strings.Index(t, "*/")
			if i < 0 {
				return ""
			}
			t = strings.TrimLeft(t[i+2:], " \t\r\n")
		}
	}
	end := strings.IndexAny(t, " \t\r\n(;")
	if end < 0 {
		end = len(t)
	}
	return strings.ToLower(t[:end])
}

func (m *Manager) querySQLite(ctx context.Context, userKey, rel string, o Options, limit int) (Obj, error) {
	statement := strings.TrimSpace(o.str("sql"))
	if statement == "" {
		return nil, errors.New("sql is required for SQLite data.")
	}
	// Only plain reads: ATTACH, PRAGMA writes and the like never run.
	switch leadingWord(statement) {
	case "select", "with", "values", "explain":
	default:
		return nil, errors.New("Only read-only queries are allowed.")
	}
	dir, err := m.Root(userKey)
	if err != nil {
		return nil, err
	}
	root, err := m.open(userKey)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	if _, err := root.Stat(rel); err != nil {
		return nil, confined(err, "path")
	}
	realRoot, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return nil, err
	}
	realFile, err := filepath.EvalSymlinks(filepath.Join(realRoot, filepath.FromSlash(rel)))
	if err != nil {
		return nil, err
	}
	if r, err := filepath.Rel(realRoot, realFile); err != nil || strings.HasPrefix(r, "..") {
		return nil, outside("path")
	}
	dsn := (&url.URL{Scheme: "file", Path: realFile, RawQuery: "mode=ro&_pragma=query_only(1)"}).String()
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	defer db.Close()
	db.SetMaxOpenConns(1)

	var args []any
	switch p := o["parameters"].(type) {
	case map[string]any:
		for k, v := range p {
			args = append(args, sql.Named(strings.TrimLeft(k, "@:$"), jsonParam(v)))
		}
	case []any:
		for _, v := range p {
			args = append(args, jsonParam(v))
		}
	}
	rows, err := db.QueryContext(ctx, statement, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	columns, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	out := []Obj{}
	for rows.Next() && len(out) < limit {
		values := make([]any, len(columns))
		ptrs := make([]any, len(columns))
		for i := range values {
			ptrs[i] = &values[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, err
		}
		row := make(Obj, len(columns))
		for i, c := range columns {
			row[i] = Field{c, sqlValue(values[i])}
		}
		out = append(out, row)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return Obj{{"format", "sqlite"}, {"columns", columns}, {"rows", out}}, nil
}

func jsonParam(v any) any {
	if n, ok := v.(json.Number); ok {
		if i, err := n.Int64(); err == nil {
			return i
		}
		f, _ := n.Float64()
		return f
	}
	if b, ok := v.(bool); ok {
		if b {
			return 1
		}
		return 0
	}
	return v
}

// sqlValue shapes a SQLite value the way better-sqlite3 handed it to JSON:
// blobs as a Buffer object.
func sqlValue(v any) any {
	if b, ok := v.([]byte); ok {
		data := make([]int, len(b))
		for i, x := range b {
			data[i] = int(x)
		}
		return Obj{{"type", "Buffer"}, {"data", data}}
	}
	return v
}

func asFloat(v any) (float64, bool) {
	switch x := v.(type) {
	case json.Number:
		f, err := x.Float64()
		return f, err == nil
	case float64:
		return x, true
	}
	return 0, false
}
