package accounterase

import (
	"bytes"
	"context"
	"encoding/json"
	"strconv"
	"strings"
	"time"
)

// exportSchema labels the export format.
const exportSchema = "neoagent.user-export.v1"

// row is one table row with its columns in schema order, the way a JavaScript
// object keeps them.
type row struct {
	keys   []string
	values []any
}

// section is one named group of the export, in insertion order.
type section struct {
	name string
	rows []row
}

// Export builds the portability document of an account as the exact bytes the
// download carries: JSON indented by two spaces, credential columns redacted.
func (e *Eraser) Export(ctx context.Context, userID int64) ([]byte, error) {
	if userID <= 0 {
		return nil, ErrInvalidID
	}
	account, err := e.queryRows(ctx, `SELECT * FROM users WHERE id = ?`, userID)
	if err != nil {
		return nil, err
	}
	if len(account) == 0 {
		return nil, ErrNotFound
	}
	data := []section{{name: "account", rows: account[:1]}}

	tables, err := e.userScopedTables(ctx)
	if err != nil {
		return nil, err
	}
	for _, table := range tables {
		rows, err := e.queryRows(ctx, `SELECT * FROM `+quote(table)+` WHERE user_id = ?`, userID)
		if err != nil || len(rows) == 0 {
			continue // an unreadable table is skipped, as in Node
		}
		data = append(data, section{name: table, rows: rows})
	}
	// Messages are keyed by conversation, not by user.
	messages, err := e.queryRows(ctx, `SELECT m.* FROM conversation_messages m JOIN conversations c ON m.conversation_id = c.id WHERE c.user_id = ?`, userID)
	if err == nil && len(messages) > 0 {
		data = append(data, section{name: "conversation_messages", rows: messages})
	}

	var out bytes.Buffer
	out.WriteString("{\n  \"exportedAt\": ")
	writeScalar(&out, time.Now().UTC().Format("2006-01-02T15:04:05.000Z"))
	out.WriteString(",\n  \"schema\": ")
	writeScalar(&out, exportSchema)
	out.WriteString(",\n  \"userId\": " + strconv.FormatInt(userID, 10) + ",\n  \"data\": {")
	for i, s := range data {
		if i > 0 {
			out.WriteString(",")
		}
		out.WriteString("\n    ")
		writeScalar(&out, s.name)
		if s.name == "account" {
			out.WriteString(": ")
			writeRow(&out, s.rows[0], 4)
			continue
		}
		out.WriteString(": [")
		for j, r := range s.rows {
			if j > 0 {
				out.WriteString(",")
			}
			out.WriteString("\n      ")
			writeRow(&out, r, 6)
		}
		out.WriteString("\n    ]")
	}
	out.WriteString("\n  }\n}")
	return out.Bytes(), nil
}

func (e *Eraser) queryRows(ctx context.Context, query string, args ...any) ([]row, error) {
	rs, err := e.DB.W.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rs.Close()
	columns, err := rs.Columns()
	if err != nil {
		return nil, err
	}
	var out []row
	for rs.Next() {
		values := make([]any, len(columns))
		ptrs := make([]any, len(columns))
		for i := range values {
			ptrs[i] = &values[i]
		}
		if err := rs.Scan(ptrs...); err != nil {
			return nil, err
		}
		for i, name := range columns {
			if values[i] != nil && sensitiveColumn.MatchString(name) {
				values[i] = "[redacted]"
			}
		}
		out = append(out, row{keys: columns, values: values})
	}
	return out, rs.Err()
}

// writeRow writes an object whose members are indented to indent+2 and whose
// closing brace sits at indent.
func writeRow(out *bytes.Buffer, r row, indent int) {
	pad := strings.Repeat(" ", indent)
	out.WriteString("{")
	for i, key := range r.keys {
		if i > 0 {
			out.WriteString(",")
		}
		out.WriteString("\n" + pad + "  ")
		writeScalar(out, key)
		out.WriteString(": ")
		writeValue(out, r.values[i], indent+2)
	}
	out.WriteString("\n" + pad + "}")
}

func writeValue(out *bytes.Buffer, v any, indent int) {
	blob, ok := v.([]byte)
	if !ok {
		writeScalar(out, v)
		return
	}
	// JSON.stringify(Buffer) is {"type":"Buffer","data":[...]}.
	pad := strings.Repeat(" ", indent)
	out.WriteString("{\n" + pad + "  \"type\": \"Buffer\",\n" + pad + "  \"data\": [")
	for i, b := range blob {
		if i > 0 {
			out.WriteString(",")
		}
		out.WriteString("\n" + pad + "    " + strconv.Itoa(int(b)))
	}
	if len(blob) > 0 {
		out.WriteString("\n" + pad + "  ")
	}
	out.WriteString("]\n" + pad + "}")
}

// writeScalar writes a string, number or null as JSON.stringify would: no HTML
// escaping, and U+2028/U+2029 left as they are.
func writeScalar(out *bytes.Buffer, v any) {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		out.WriteString("null")
		return
	}
	s := strings.TrimSuffix(b.String(), "\n")
	s = strings.ReplaceAll(s, ` `, " ")
	s = strings.ReplaceAll(s, ` `, " ")
	out.WriteString(s)
}
