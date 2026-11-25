package agentsapi

import (
	"database/sql"

	"github.com/NeoLabs-Systems/neolabs-go/publicerr"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

// scanObjects reads every row as an object with the table's column order, as
// `SELECT *` rows reached clients from the Node server.
func scanObjects(rows *sql.Rows) ([]*jsonobj.Object, error) {
	cols, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	out := []*jsonobj.Object{}
	for rows.Next() {
		values := make([]any, len(cols))
		ptrs := make([]any, len(cols))
		for i := range values {
			ptrs[i] = &values[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, err
		}
		o := jsonobj.New()
		for i, c := range cols {
			if b, ok := values[i].([]byte); ok {
				values[i] = string(b)
			}
			o.Set(c, values[i])
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// redactRun hides a failed run's technical error (and result) from accounts
// that are not admins.
func redactRun(run *jsonobj.Object) {
	if e, _ := run.Get("error"); e == nil || e == "" {
		return
	}
	run.Set("error", publicerr.Generic)
	if run.Has("result") {
		run.Set("result", nil)
	}
}
