// Package schema owns NeoAgent's database layout.
//
// baseline.sql is the exact schema a fresh install of the last Node release
// produces (regenerate it with gen/dump_schema.js). A new database gets the
// baseline in one transaction; an existing database must already be at that
// level, which the Node server guarantees by migrating itself on every start.
// From there on, schema changes are Go steps appended to Steps().
package schema

import (
	"context"
	"database/sql"
	_ "embed"
	"fmt"
	"sort"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

//go:embed baseline.sql
var baseline string

//go:embed USER_VERSION
var userVersionText string

// BaselineVersion is PRAGMA user_version of a fresh Node-era database.
func BaselineVersion() int {
	n, err := strconv.Atoi(strings.TrimSpace(userVersionText))
	if err != nil {
		panic("schema: USER_VERSION is not a number: " + err.Error())
	}
	return n
}

// Steps are the ordered migrations. The first BaselineVersion() entries are
// the Node-era versioned migrations, already part of the baseline; real Go
// migrations are appended after them.
func Steps() []dbx.Step {
	steps := make([]dbx.Step, BaselineVersion())
	for i := range steps {
		steps[i] = func(context.Context, *sql.Tx) error { return nil }
	}
	return steps
}

// Ensure prepares db for use: a new database receives the baseline, an
// existing one is verified against it, then pending Go migrations run.
func Ensure(ctx context.Context, db *sql.DB) error {
	empty, err := isEmpty(ctx, db)
	if err != nil {
		return err
	}
	if empty {
		if err := applyBaseline(ctx, db); err != nil {
			return err
		}
	} else if err := Verify(ctx, db); err != nil {
		return err
	}
	return dbx.Migrate(ctx, db, Steps())
}

func isEmpty(ctx context.Context, db *sql.DB) (bool, error) {
	var n int
	err := db.QueryRowContext(ctx, `SELECT COUNT(*) FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'`).Scan(&n)
	if err != nil {
		return false, fmt.Errorf("schema: inspect database: %w", err)
	}
	return n == 0, nil
}

func applyBaseline(ctx context.Context, db *sql.DB) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("schema: begin: %w", err)
	}
	if _, err := tx.ExecContext(ctx, baseline); err != nil {
		tx.Rollback()
		return fmt.Errorf("schema: apply baseline: %w", err)
	}
	if _, err := tx.ExecContext(ctx, fmt.Sprintf(`PRAGMA user_version = %d`, BaselineVersion())); err != nil {
		tx.Rollback()
		return fmt.Errorf("schema: record version: %w", err)
	}
	return tx.Commit()
}

// Verify checks that an existing database has every baseline table and every
// baseline column, and that it was migrated to at least the baseline version.
func Verify(ctx context.Context, db *sql.DB) error {
	var version int
	if err := db.QueryRowContext(ctx, `PRAGMA user_version`).Scan(&version); err != nil {
		return fmt.Errorf("schema: read user_version: %w", err)
	}
	if version < BaselineVersion() {
		return fmt.Errorf("schema: database is at version %d, this build needs %d; start the last NeoAgent 3.x release once to upgrade it, then switch", version, BaselineVersion())
	}

	ref, err := sql.Open("sqlite", "file::memory:")
	if err != nil {
		return err
	}
	defer ref.Close()
	ref.SetMaxOpenConns(1)
	if _, err := ref.ExecContext(ctx, baseline); err != nil {
		return fmt.Errorf("schema: build reference: %w", err)
	}
	want, err := columns(ctx, ref)
	if err != nil {
		return err
	}
	have, err := columns(ctx, db)
	if err != nil {
		return err
	}

	var problems []string
	for table, cols := range want {
		actual, ok := have[table]
		if !ok {
			problems = append(problems, "missing table "+table)
			continue
		}
		for col := range cols {
			if !actual[col] {
				problems = append(problems, "missing column "+table+"."+col)
			}
		}
	}
	if len(problems) > 0 {
		sort.Strings(problems)
		if len(problems) > 8 {
			problems = append(problems[:8], fmt.Sprintf("... and %d more", len(problems)-8))
		}
		return fmt.Errorf("schema: database does not match the expected layout (%s); start the last NeoAgent 3.x release once to upgrade it", strings.Join(problems, ", "))
	}
	return nil
}

func columns(ctx context.Context, db *sql.DB) (map[string]map[string]bool, error) {
	rows, err := db.QueryContext(ctx, `SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite_%'`)
	if err != nil {
		return nil, fmt.Errorf("schema: list tables: %w", err)
	}
	var tables []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			rows.Close()
			return nil, err
		}
		tables = append(tables, name)
	}
	rows.Close()

	out := make(map[string]map[string]bool, len(tables))
	for _, table := range tables {
		infos, err := db.QueryContext(ctx, fmt.Sprintf(`PRAGMA table_info("%s")`, strings.ReplaceAll(table, `"`, `""`)))
		if err != nil {
			return nil, fmt.Errorf("schema: describe %s: %w", table, err)
		}
		cols := map[string]bool{}
		for infos.Next() {
			var cid int
			var name, typ string
			var notnull, pk int
			var dflt sql.NullString
			if err := infos.Scan(&cid, &name, &typ, &notnull, &dflt, &pk); err != nil {
				infos.Close()
				return nil, err
			}
			cols[name] = true
		}
		infos.Close()
		out[table] = cols
	}
	return out, nil
}
