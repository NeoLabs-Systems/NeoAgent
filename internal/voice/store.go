package voice

import (
	"context"
	"encoding/json"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

// turnStore keeps what is said on a call. A spoken turn is stored exactly like
// a typed one: in the web chat history the app renders, and in the
// conversation thread that later runs load as context.
type turnStore struct {
	db             *dbx.DB
	userID         int64
	agentID        string
	conversationID string
	sessionID      string
}

type turnMetadata struct {
	Platform  string `json:"platform"`
	SessionID string `json:"sessionId,omitempty"`
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// RecordTurn stores one spoken turn.
func (s turnStore) RecordTurn(role, content string) error {
	text := livevoice.TrimJS(content)
	if text == "" {
		return nil
	}
	meta, _ := json.Marshal(turnMetadata{Platform: "voice_live", SessionID: s.sessionID})
	ctx := context.Background()
	if _, err := s.db.W.ExecContext(ctx, `INSERT INTO conversation_history (
		user_id, agent_id, conversation_id, role, content, metadata
	) VALUES (?, ?, ?, ?, ?, ?)`, s.userID, nullable(s.agentID), nullable(s.conversationID), role, text, string(meta)); err != nil {
		return err
	}
	if s.conversationID == "" {
		return nil
	}
	_, err := s.db.W.ExecContext(ctx, `INSERT INTO conversation_messages (
		conversation_id, agent_id, role, content, metadata_json
	) VALUES (?, ?, ?, ?, ?)`, s.conversationID, nullable(s.agentID), role, text, string(meta))
	return err
}

// RecordTaskReply stores the reply of a hand-off that finishes after the call
// ended or was never heard. Like a web chat run, its reply joins the chat
// history (the run itself already stored it in the conversation thread).
func (s turnStore) RecordTaskReply(runID, content string) error {
	meta, _ := json.Marshal(turnMetadata{Platform: "voice_live"})
	_, err := s.db.W.ExecContext(context.Background(), `INSERT INTO conversation_history (
		user_id, agent_id, agent_run_id, conversation_id, role, content, metadata
	) VALUES (?, ?, ?, ?, 'assistant', ?, ?)`, s.userID, nullable(s.agentID), runID, nullable(s.conversationID), content, string(meta))
	return err
}
