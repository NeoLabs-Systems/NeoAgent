package models

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Models an admin has granted to one account beyond what the server enables for
// everyone. A grant only lifts the server-wide "disabled" switch for that
// account: the model still needs a provider the server can reach, and runs on it
// still count toward the account's rate limits.

// ParseGrantedIDs reads the allowed_models column.
func ParseGrantedIDs(raw string) []string {
	if raw == "" {
		return nil
	}
	var parsed []any
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		return nil
	}
	var ids []string
	for _, id := range parsed {
		if s := textx.Trim(fmt.Sprint(id)); s != "" {
			ids = append(ids, s)
		}
	}
	return ids
}

// GrantedModelIDs lists the models granted to a user.
func GrantedModelIDs(ctx context.Context, db *dbx.DB, userID int64) ([]string, error) {
	if userID <= 0 {
		return nil, nil
	}
	var raw sql.NullString
	err := db.R.QueryRowContext(ctx, `SELECT allowed_models FROM users WHERE id = ?`, userID).Scan(&raw)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return ParseGrantedIDs(raw.String), nil
}

// Access says whether the server-wide switch keeps an account from a model, and
// whether an admin grant is what lets the account use it anyway.
func Access(m Model, disabled, granted map[string]bool) (blocked, adminGranted bool) {
	disabledForEveryone := MatchesConfiguredID(m, disabled)
	adminGranted = disabledForEveryone && MatchesConfiguredID(m, granted)
	return disabledForEveryone && !adminGranted, adminGranted
}
