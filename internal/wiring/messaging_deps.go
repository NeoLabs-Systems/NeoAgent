package wiring

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"

	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/discord"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp"
)

// githubMentions reads the token of the agent's connected GitHub "Mentions"
// integration, on every call so a reconnect takes effect at once.
type githubMentions struct{ svc *integrations.Services }

func (g githubMentions) MentionsToken(ctx context.Context, userID int64, agentID string) (string, error) {
	rows, err := g.svc.ListConnections(ctx, userID, "github", agentID)
	if err != nil {
		return "", err
	}
	for _, c := range rows {
		if c.Status == "connected" && c.AppKey == "mentions" {
			return strings.TrimSpace(g.svc.Credentials(c).String("access_token")), nil
		}
	}
	return "", nil
}

// githubCursors keeps each agent's GitHub polling position in the agent
// setting github_mentions_cursors.
type githubCursors struct{ db *dbx.DB }

const githubCursorKey = "github_mentions_cursors"

func (g githubCursors) Load(ctx context.Context, userID int64, agentID string) (map[string]string, error) {
	var raw string
	err := g.db.R.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`,
		userID, agentID, githubCursorKey).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return map[string]string{}, nil
	}
	if err != nil {
		return nil, err
	}
	cursors := map[string]string{}
	if json.Unmarshal([]byte(raw), &cursors) != nil {
		return map[string]string{}, nil
	}
	return cursors, nil
}

func (g githubCursors) Save(ctx context.Context, userID int64, agentID string, cursors map[string]string) error {
	raw, err := json.Marshal(cursors)
	if err != nil {
		return err
	}
	_, err = g.db.W.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)
		ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`, userID, agentID, githubCursorKey, string(raw))
	return err
}

// inboundMedia stores attachments people send in chats as the receiving
// user's artifacts, as kind messaging-inbound-media.
type inboundMedia struct{ store *artifacts.Store }

func (m inboundMedia) save(ctx context.Context, userID int64, base, ext, contentType string, content []byte, metadata map[string]any) (string, error) {
	if base == "" {
		base = strconv.FormatInt(time.Now().UnixMilli(), 10)
	}
	stored, err := m.store.CreateBufferArtifact(ctx, strconv.FormatInt(userID, 10), artifacts.File{
		Kind: "messaging-inbound-media", FilenameBase: base, Extension: ext, ContentType: contentType,
		Content: content, Metadata: metadata,
	})
	return stored.StoragePath, err
}

type discordMedia struct{ inboundMedia }

func (m discordMedia) SaveInboundMedia(ctx context.Context, userID int64, f discord.InboundMedia) (string, error) {
	return m.save(ctx, userID, f.FilenameBase, f.Extension, f.ContentType, f.Content, f.Metadata)
}

type whatsappMedia struct{ inboundMedia }

func (m whatsappMedia) SaveInboundMedia(ctx context.Context, userID int64, f whatsapp.InboundMedia) (string, error) {
	var messageID any
	if f.MessageID != "" {
		messageID = f.MessageID
	}
	return m.save(ctx, userID, f.FilenameBase, f.Extension, f.ContentType, f.Content,
		map[string]any{"platform": "whatsapp", "mediaType": f.MediaType, "messageId": messageID})
}

// agentDisplayName is the name that labels an agent's replies in chats.
func agentDisplayName(db *dbx.DB) func(userID int64, agentID string) string {
	return func(userID int64, agentID string) string {
		var name sql.NullString
		_ = db.R.QueryRow(`SELECT display_name FROM agents WHERE user_id = ? AND id = ?`, userID, agentID).Scan(&name)
		return name.String
	}
}
