package agentsapi

import (
	"database/sql"
	"net/http"
	"slices"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

// A chat is the web conversation plus the messages of every other platform.
// Stored times are "YYYY-MM-DD HH:MM:SS" or ISO 8601, so they are ordered as
// instants; source and id break ties, which makes the three a paging cursor.
const (
	chatHistoryRows = `SELECT id, role, content, COALESCE(json_extract(metadata, '$.platform'), 'web') AS platform,
		NULL AS sender_name, created_at, agent_run_id AS run_id, metadata, NULL AS tool_calls, 'conversation' AS history_source
		FROM conversation_history WHERE user_id = @userId AND agent_id = @agentId
		UNION ALL
		SELECT id, role, content, platform, json_extract(metadata, '$.senderName'), created_at, run_id, metadata, tool_calls, 'message'
		FROM messages WHERE user_id = @userId AND agent_id = @agentId AND platform != 'web'`
	rowInstant    = `julianday(CASE WHEN instr(created_at, 'T') > 0 THEN created_at ELSE replace(created_at, ' ', 'T') || 'Z' END)`
	cursorInstant = `julianday(CASE WHEN instr(@beforeCreatedAt, 'T') > 0 THEN @beforeCreatedAt ELSE replace(@beforeCreatedAt, ' ', 'T') || 'Z' END)`
	beforeCursor  = ` WHERE ` + rowInstant + ` < ` + cursorInstant + `
		OR (` + rowInstant + ` = ` + cursorInstant + ` AND history_source < @beforeSource)
		OR (` + rowInstant + ` = ` + cursorInstant + ` AND history_source = @beforeSource AND CAST(id AS TEXT) < @beforeId)`
)

// handleChatHistory answers the newest page, or the page before the cursor,
// oldest message first.
func (a *API) handleChatHistory(w http.ResponseWriter, r *http.Request, userID int64) {
	query := r.URL.Query()
	limit := 40
	if n, err := strconv.Atoi(query.Get("limit")); err == nil && n > 0 {
		limit = min(n, 100)
	}
	agentID := a.agentFromRequest(r, userID)
	statement := `SELECT * FROM (` + chatHistoryRows + `)`
	args := []any{sql.Named("userId", userID), sql.Named("agentId", agentID), sql.Named("limit", limit+1)}
	createdAt := strings.TrimSpace(query.Get("beforeCreatedAt"))
	source := strings.TrimSpace(query.Get("beforeSource"))
	id := strings.TrimSpace(query.Get("beforeId"))
	if createdAt != "" && source != "" && id != "" {
		statement += beforeCursor
		args = append(args, sql.Named("beforeCreatedAt", createdAt), sql.Named("beforeSource", source), sql.Named("beforeId", id))
	}
	statement += ` ORDER BY ` + rowInstant + ` DESC, history_source DESC, CAST(id AS TEXT) DESC LIMIT @limit`

	var messages []*jsonobj.Object
	rows, err := a.cfg.DB.R.QueryContext(r.Context(), statement, args...)
	if err == nil {
		defer rows.Close()
		messages, err = scanObjects(rows)
	}
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Internal server error"})
		return
	}

	hasMore := len(messages) > limit
	messages = messages[:min(len(messages), limit)]
	var nextCreatedAt, nextSource, nextID any
	if len(messages) > 0 {
		oldest := messages[len(messages)-1]
		nextCreatedAt, _ = oldest.Get("created_at")
		nextSource, _ = oldest.Get("history_source")
		if v, ok := oldest.Get("id"); ok {
			if n, isInt := v.(int64); isInt {
				nextID = strconv.FormatInt(n, 10)
			}
		}
	}
	slices.Reverse(messages)
	httpx.WriteJSON(w, http.StatusOK, jsonobj.New("messages", messages, "agentId", agentID, "hasMore", hasMore,
		"nextBeforeCreatedAt", nextCreatedAt, "nextBeforeSource", nextSource, "nextBeforeId", nextID))
}
