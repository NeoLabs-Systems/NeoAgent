package delegation

import (
	"context"
	"database/sql"
	"encoding/json"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

// AccessEvents lists the newest access audit entries with the usernames the
// entries' user ids refer to.
func (s *Service) AccessEvents(ctx context.Context, limit int) (*jsonobj.Object, error) {
	rows, err := s.db.R.QueryContext(ctx, `
    SELECT log.id, log.action, log.detail_json, log.created_at,
           actor.id AS actor_id, actor.username AS actor_username,
           subject.id AS subject_id, subject.username AS subject_username
    FROM access_audit_log log
    LEFT JOIN users actor ON actor.id = log.actor_user_id
    LEFT JOIN users subject ON subject.id = log.subject_user_id
    ORDER BY log.id DESC
    LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	entries := []*jsonobj.Object{}
	ids := map[int64]bool{}
	var order []int64
	for rows.Next() {
		var id int64
		var action, detailJSON, created string
		var actorID, subjectID sql.NullInt64
		var actorName, subjectName sql.NullString
		if err := rows.Scan(&id, &action, &detailJSON, &created, &actorID, &actorName, &subjectID, &subjectName); err != nil {
			return nil, err
		}
		detail := jsonobj.New()
		if detailJSON == "" {
			detailJSON = "{}"
		}
		_ = json.Unmarshal([]byte(detailJSON), detail)
		var values map[string]any
		_ = json.Unmarshal([]byte(detailJSON), &values)
		for _, k := range detail.Keys() {
			if f, ok := values[k].(float64); ok && strings.HasSuffix(k, "UserId") && f == float64(int64(f)) {
				if !ids[int64(f)] {
					ids[int64(f)] = true
					order = append(order, int64(f))
				}
			}
		}
		person := func(id sql.NullInt64, name sql.NullString) any {
			if !id.Valid {
				return nil
			}
			return jsonobj.New("id", id.Int64, "username", name.String)
		}
		entries = append(entries, jsonobj.New("id", id, "action", action, "actor", person(actorID, actorName),
			"subject", person(subjectID, subjectName), "detail", detail, "createdAt", created))
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	usernames := jsonobj.New()
	if len(order) > 0 {
		args := make([]any, len(order))
		marks := make([]string, len(order))
		for i, id := range order {
			args[i], marks[i] = id, "?"
		}
		urows, err := s.db.R.QueryContext(ctx, `SELECT id, username FROM users WHERE id IN (`+strings.Join(marks, ", ")+`) ORDER BY id`, args...)
		if err != nil {
			return nil, err
		}
		defer urows.Close()
		for urows.Next() {
			var id int64
			var name string
			if err := urows.Scan(&id, &name); err != nil {
				return nil, err
			}
			usernames.Set(jsonInt(id), name)
		}
	}
	return jsonobj.New("entries", entries, "usernames", usernames), nil
}

func jsonInt(id int64) string {
	raw, _ := json.Marshal(id)
	return string(raw)
}
