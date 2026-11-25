package delegation

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

type querier interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
	QueryRowContext(context.Context, string, ...any) *sql.Row
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}

// Service owns user_delegations, delegation_invites and the access audit log.
type Service struct {
	db *dbx.DB
}

// NewService builds the access service.
func NewService(db *dbx.DB) *Service { return &Service{db: db} }

// publicUser is all a manager ever sees about the people they manage.
func publicUser(ctx context.Context, q querier, userID int64) any {
	var id int64
	var username string
	var display sql.NullString
	if err := q.QueryRowContext(ctx, `SELECT id, username, display_name FROM users WHERE id = ?`, userID).Scan(&id, &username, &display); err != nil {
		return nil
	}
	var name any
	if display.Valid && display.String != "" {
		name = display.String
	}
	return jsonobj.New("id", id, "username", username, "displayName", name)
}

func publicUsername(u any) string {
	if o, ok := u.(*jsonobj.Object); ok {
		return o.String("username")
	}
	return ""
}

type delegationRow struct {
	managed, manager int64
	allowed, since   string
}

func getDelegation(ctx context.Context, q querier, managed int64) (*delegationRow, error) {
	var d delegationRow
	err := q.QueryRowContext(ctx, `SELECT managed_user_id, manager_user_id, allowed_permissions_json, created_at
    FROM user_delegations WHERE managed_user_id = ?`, managed).Scan(&d.managed, &d.manager, &d.allowed, &d.since)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &d, nil
}

func listDirectlyManaged(ctx context.Context, q querier, manager int64) ([]delegationRow, error) {
	rows, err := q.QueryContext(ctx, `SELECT managed_user_id, allowed_permissions_json, created_at
    FROM user_delegations WHERE manager_user_id = ? ORDER BY created_at`, manager)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []delegationRow
	for rows.Next() {
		d := delegationRow{manager: manager}
		if err := rows.Scan(&d.managed, &d.allowed, &d.since); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// subtreeHeight is how many levels of management sit below userID.
func subtreeHeight(ctx context.Context, q querier, userID int64) (int, error) {
	var height int
	err := q.QueryRowContext(ctx, `
    WITH RECURSIVE below(user_id, depth) AS (
      SELECT managed_user_id, 1 FROM user_delegations WHERE manager_user_id = ?
      UNION ALL
      SELECT d.managed_user_id, below.depth + 1
      FROM user_delegations d
      JOIN below ON d.manager_user_id = below.user_id
      WHERE below.depth <= ?
    )
    SELECT COALESCE(MAX(depth), 0) AS height FROM below`, userID, MaxChainDepth).Scan(&height)
	return height, err
}

// assertCanAttach returns why managed cannot be placed under manager.
func (s *Service) assertCanAttach(ctx context.Context, q querier, manager, managed int64) error {
	if manager == managed {
		return apperr.New(http.StatusBadRequest, "You can’t redeem your own invite link.", "INVITE_SELF")
	}
	current, err := getDelegation(ctx, q, managed)
	if err != nil {
		return err
	}
	if current != nil {
		name := publicUsername(publicUser(ctx, q, current.manager))
		if name == "" {
			name = "Another account"
		}
		return apperr.New(http.StatusConflict, name+" already manages this account. Leave that first.", "ALREADY_MANAGED")
	}
	chain, err := s.managerChain(ctx, q, manager)
	if err != nil {
		return err
	}
	for _, h := range chain {
		if h.manager == managed {
			return apperr.New(http.StatusConflict, "You already manage the account that created this link.", "DELEGATION_CYCLE")
		}
	}
	height, err := subtreeHeight(ctx, q, managed)
	if err != nil {
		return err
	}
	if len(chain)+1+height > MaxChainDepth {
		return apperr.New(http.StatusConflict, fmt.Sprintf("This would make the management chain longer than %d levels.", MaxChainDepth), "DELEGATION_TOO_DEEP")
	}
	return nil
}

// record writes an access audit entry: user ids only, never names.
func record(ctx context.Context, q querier, action string, actor, subject any, detail *jsonobj.Object) error {
	raw, err := json.Marshal(detail)
	if err != nil {
		return err
	}
	_, err = q.ExecContext(ctx, `INSERT INTO access_audit_log (action, actor_user_id, subject_user_id, detail_json) VALUES (?, ?, ?, ?)`,
		action, actor, subject, string(raw))
	return err
}

func (s *Service) inTx(ctx context.Context, fn func(q querier) error) error {
	tx, err := s.db.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}

// Leave detaches userID from its manager.
func (s *Service) Leave(ctx context.Context, userID int64) error {
	current, err := getDelegation(ctx, s.db.R, userID)
	if err != nil {
		return err
	}
	if current == nil {
		return apperr.New(http.StatusNotFound, "Nobody manages this account.", "NOT_MANAGED")
	}
	return s.inTx(ctx, func(q querier) error {
		if _, err := q.ExecContext(ctx, `DELETE FROM user_delegations WHERE managed_user_id = ?`, userID); err != nil {
			return err
		}
		return record(ctx, q, "delegation.leave", userID, userID, jsonobj.New("managerUserId", current.manager))
	})
}

func requireDirectlyManaged(ctx context.Context, q querier, manager, managed int64) (*delegationRow, error) {
	current, err := getDelegation(ctx, q, managed)
	if err != nil {
		return nil, err
	}
	if current == nil || current.manager != manager {
		return nil, apperr.New(http.StatusNotFound, "You don’t manage this account.", "NOT_MANAGED_BY_YOU")
	}
	return current, nil
}

// Release stops manager managing managed.
func (s *Service) Release(ctx context.Context, manager, managed int64) error {
	if _, err := requireDirectlyManaged(ctx, s.db.R, manager, managed); err != nil {
		return err
	}
	return s.inTx(ctx, func(q querier) error {
		if _, err := q.ExecContext(ctx, `DELETE FROM user_delegations WHERE managed_user_id = ?`, managed); err != nil {
			return err
		}
		return record(ctx, q, "delegation.release", manager, managed, jsonobj.New("managerUserId", manager))
	})
}

// SetPermission turns one permission on or off for an account manager manages
// directly. A manager can only hand out what they hold themselves.
func (s *Service) SetPermission(ctx context.Context, manager, managed int64, permission any, allowed any) error {
	key, _ := permission.(string)
	if !knownPermission(key) {
		return apperr.New(http.StatusBadRequest, fmt.Sprintf("Unknown permission: %s", jsString(permission)), "UNKNOWN_PERMISSION")
	}
	on, ok := allowed.(bool)
	if !ok {
		return apperr.New(http.StatusBadRequest, "allowed must be true or false.", "INVALID_PERMISSION_VALUE")
	}
	current, err := requireDirectlyManaged(ctx, s.db.R, manager, managed)
	if err != nil {
		return err
	}
	if on {
		held, err := s.held(ctx, s.db.R, manager)
		if err != nil {
			return err
		}
		if !held[key] {
			return apperr.New(http.StatusForbidden, "You can only hand out permissions you hold yourself.", "PERMISSION_NOT_HELD")
		}
	}
	next := allowedList(current.allowed)
	present := false
	kept := next[:0]
	for _, p := range next {
		if p == key {
			present = true
			if !on {
				continue
			}
		}
		kept = append(kept, p)
	}
	next = kept
	if on && !present {
		next = append(next, key)
	}
	raw, _ := json.Marshal(next)
	return s.inTx(ctx, func(q querier) error {
		if _, err := q.ExecContext(ctx, `UPDATE user_delegations SET allowed_permissions_json = ? WHERE managed_user_id = ?`, string(raw), managed); err != nil {
			return err
		}
		return record(ctx, q, "delegation.permission", manager, managed, jsonobj.New("permission", key, "allowed", on))
	})
}

// jsString is how a JavaScript template literal prints a JSON value.
func jsString(v any) string {
	switch t := v.(type) {
	case nil:
		return "undefined"
	case string:
		return t
	case bool:
		if t {
			return "true"
		}
		return "false"
	case float64:
		raw, _ := json.Marshal(t)
		return string(raw)
	}
	return "[object Object]"
}
