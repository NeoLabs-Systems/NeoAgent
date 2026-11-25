package sockets

import (
	"context"
	"database/sql"
	"math"
)

// queryRows runs a SELECT and returns the rows keyed by column name, with
// values as better-sqlite3 hands them to JavaScript: blobs become the
// {type:"Buffer",data:[...]} object JSON.stringify makes of a Buffer, and
// infinities are null.
func queryRows(ctx context.Context, db *sql.DB, query string, args ...any) ([]map[string]any, error) {
	rows, err := db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	names, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	out := []map[string]any{}
	for rows.Next() {
		values := make([]any, len(names))
		targets := make([]any, len(names))
		for i := range values {
			targets[i] = &values[i]
		}
		if err := rows.Scan(targets...); err != nil {
			return nil, err
		}
		row := make(map[string]any, len(names))
		for i, name := range names {
			row[name] = rowValue(values[i])
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

func rowValue(v any) any {
	switch t := v.(type) {
	case float64:
		if math.IsInf(t, 0) || math.IsNaN(t) {
			return nil
		}
	case []byte:
		data := make([]int, len(t))
		for i, b := range t {
			data[i] = int(b)
		}
		return map[string]any{"type": "Buffer", "data": data}
	}
	return v
}
