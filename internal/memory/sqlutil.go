package memory

import (
	"context"
	"database/sql"
	"strings"
)

// queryer is what *sql.DB and *sql.Tx both offer. Memory code takes one so the
// same function runs inside a transaction or on its own.
type queryer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// atomically runs fn in a transaction. Given a transaction already, it joins it.
func atomically(ctx context.Context, q queryer, fn func(queryer) error) error {
	db, ok := q.(*sql.DB)
	if !ok {
		return fn(q)
	}
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}

func placeholders(n int) string {
	if n <= 0 {
		return ""
	}
	return strings.TrimSuffix(strings.Repeat("?, ", n), ", ")
}

func anySlice[T any](items []T) []any {
	out := make([]any, len(items))
	for i, item := range items {
		out[i] = item
	}
	return out
}

// rowScanner is the part of *sql.Rows a scan function needs.
type rowScanner interface{ Scan(dest ...any) error }

func scanString(r rowScanner) (string, error) {
	var s string
	err := r.Scan(&s)
	return s, err
}

// collect runs a query and maps every row.
func collect[T any](ctx context.Context, q queryer, scan func(rowScanner) (T, error), query string, args ...any) ([]T, error) {
	rows, err := q.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []T
	for rows.Next() {
		item, err := scan(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

// one runs a query for a single row; found is false when there is none.
func one(ctx context.Context, q queryer, dest []any, query string, args ...any) (found bool, err error) {
	err = q.QueryRowContext(ctx, query, args...).Scan(dest...)
	if err == sql.ErrNoRows {
		return false, nil
	}
	return err == nil, err
}
