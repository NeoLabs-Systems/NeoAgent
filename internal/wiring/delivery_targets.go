package wiring

import (
	"cmp"
	"context"
	"database/sql"
	"encoding/json"
	"slices"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
)

const maxDeliveryTargets = 80

// discoverableChats are the platforms that can name chats nobody wrote from.
var discoverableChats = []string{"whatsapp", "discord", "telegram", "slack"}

var chatLabels = map[string]string{"whatsapp": "WhatsApp", "discord": "Discord", "telegram": "Telegram", "slack": "Slack"}

// sourceRank puts what a platform lists before defaults and recent chats.
var sourceRank = map[string]int{"discovered": 0, "default": 1, "recent": 2}

func chatLabel(platform string) string {
	if label := chatLabels[platform]; label != "" {
		return label
	}
	words := strings.Fields(strings.ReplaceAll(platform, "_", " "))
	for i, w := range words {
		words[i] = strings.ToUpper(w[:1]) + w[1:]
	}
	return strings.Join(words, " ")
}

func deliveryTarget(platform, to, label, subtitle, source string) tasks.AccessTarget {
	return tasks.AccessTarget{
		Platform: platform, PlatformLabel: chatLabel(platform), To: strings.TrimSpace(to),
		Label: cmp.Or(strings.TrimSpace(label), strings.TrimSpace(to)), Subtitle: cmp.Or(subtitle, chatLabel(platform)),
		Source: source, Connected: true, SupportsDelivery: true,
	}
}

// AccessTargets lists the chats a task of the agent could report to: what the
// platforms list, the default chat and recent conversations.
func (a *taskMessagingAdapter) AccessTargets(ctx context.Context, userID int64, agentID, platform string) ([]tasks.AccessTarget, error) {
	platform = strings.ToLower(strings.TrimSpace(platform))
	var found []tasks.AccessTarget
	for _, p := range discoverableChats {
		if platform == "" || platform == p {
			found = append(found, a.discoveredTargets(ctx, userID, agentID, p)...)
		}
	}
	defaults, err := a.defaultTargets(ctx, userID, agentID, platform)
	if err != nil {
		return nil, err
	}
	recent, err := a.recentChatTargets(ctx, userID, agentID, platform)
	if err != nil {
		return nil, err
	}
	found, err = a.limitToLinkedChats(ctx, userID, agentID, platform, slices.Concat(found, defaults, recent))
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	found = slices.DeleteFunc(found, func(t tasks.AccessTarget) bool {
		key := t.Platform + ":" + t.To
		drop := t.To == "" || seen[key]
		seen[key] = true
		return drop
	})
	slices.SortStableFunc(found, func(x, y tasks.AccessTarget) int {
		return cmp.Or(cmp.Compare(sourceRank[x.Source], sourceRank[y.Source]),
			cmp.Compare(x.PlatformLabel, y.PlatformLabel), cmp.Compare(strings.ToLower(x.Label), strings.ToLower(y.Label)))
	})
	return found[:min(len(found), maxDeliveryTargets)], nil
}

func (a *taskMessagingAdapter) discoveredTargets(ctx context.Context, userID int64, agentID, platform string) []tasks.AccessTarget {
	if platform == "slack" {
		return a.slackTargets(ctx, userID, agentID)
	}
	var out []tasks.AccessTarget
	for _, t := range a.mgr.ListAccessTargets(ctx, userID, agentID, platform) {
		out = append(out, deliveryTarget(platform, t.Value, t.Label, t.Subtitle, "discovered"))
	}
	return out
}

// slackTargets lists the conversations of a connected Slack account; without
// one there is nothing to discover.
func (a *taskMessagingAdapter) slackTargets(ctx context.Context, userID int64, agentID string) []tasks.AccessTarget {
	result, err := a.integrations.ExecuteTool(ctx, userID, "slack_list_conversations",
		map[string]any{"types": "public_channel,private_channel,im,mpim", "limit": float64(200)}, agentID, integrations.ExecOptions{})
	if err != nil {
		return nil
	}
	var answer struct {
		Channels []struct {
			ID        string `json:"id"`
			Name      string `json:"name"`
			User      string `json:"user"`
			IsIM      bool   `json:"is_im"`
			IsPrivate bool   `json:"is_private"`
		} `json:"channels"`
	}
	raw, err := json.Marshal(result)
	if err != nil || json.Unmarshal(raw, &answer) != nil {
		return nil
	}
	var out []tasks.AccessTarget
	for _, c := range answer.Channels {
		name := cmp.Or(c.Name, c.User, c.ID)
		label, subtitle := "#"+name, "Slack channel"
		switch {
		case c.IsIM:
			label, subtitle = name, "Slack direct message"
		case c.IsPrivate:
			subtitle = "Private Slack channel"
		}
		out = append(out, deliveryTarget("slack", c.ID, label, subtitle, "discovered"))
	}
	return out
}

func (a *taskMessagingAdapter) defaultTargets(ctx context.Context, userID int64, agentID, platform string) ([]tasks.AccessTarget, error) {
	rows, err := a.db.R.QueryContext(ctx, `SELECT key, value FROM agent_settings
		WHERE user_id = ? AND agent_id = ? AND key IN ('last_platform', 'last_chat_id')`, userID, agentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	values := map[string]string{}
	for rows.Next() {
		var key string
		var stored sql.NullString
		if err := rows.Scan(&key, &stored); err != nil {
			return nil, err
		}
		var value any
		if json.Unmarshal([]byte(stored.String), &value) != nil {
			value = stored.String
		}
		text, ok := value.(string)
		if !ok {
			text = stored.String
		}
		values[key] = strings.TrimSpace(text)
	}
	last, to := strings.ToLower(values["last_platform"]), values["last_chat_id"]
	if last == "" || to == "" || (platform != "" && last != platform) || a.mgr.IsPublicPlatform(last) {
		return nil, rows.Err()
	}
	return []tasks.AccessTarget{deliveryTarget(last, to, to, "Current default channel", "default")}, rows.Err()
}

func (a *taskMessagingAdapter) recentChatTargets(ctx context.Context, userID int64, agentID, platform string) ([]tasks.AccessTarget, error) {
	rows, err := a.db.R.QueryContext(ctx, `SELECT platform, platform_chat_id, metadata FROM messages
		WHERE user_id = ? AND agent_id = ? AND platform IS NOT NULL AND platform_chat_id IS NOT NULL AND (? = '' OR platform = ?)
		ORDER BY id DESC LIMIT 80`, userID, agentID, platform, platform)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []tasks.AccessTarget
	for rows.Next() {
		var p, chat string
		var raw sql.NullString
		if err := rows.Scan(&p, &chat, &raw); err != nil {
			return nil, err
		}
		var metadata map[string]any
		_ = json.Unmarshal([]byte(raw.String), &metadata)
		label := chat
		for _, key := range []string{"groupName", "group_name", "channelName", "channel_name", "guildName", "guild_name", "senderName", "sender_name"} {
			if name, _ := metadata[key].(string); name != "" {
				label = name
				break
			}
		}
		out = append(out, deliveryTarget(p, chat, label, "Recent conversation", "recent"))
	}
	return out, rows.Err()
}

// limitToLinkedChats: a shared account only reaches its owner's own chat, so
// contacts from before the switch to it are no longer places to report to.
func (a *taskMessagingAdapter) limitToLinkedChats(ctx context.Context, userID int64, agentID, platform string, targets []tasks.AccessTarget) ([]tasks.AccessTarget, error) {
	links, err := a.shared.LinksForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	linked := map[string]bool{}
	var own []tasks.AccessTarget
	for _, l := range links {
		if l.AgentID != agentID {
			continue
		}
		linked[l.Platform] = true
		if platform == "" || platform == l.Platform {
			own = append(own, deliveryTarget(l.Platform, l.ChatID, l.DisplayName.String, "Your own chat on the shared account", "default"))
		}
	}
	return append(own, slices.DeleteFunc(targets, func(t tasks.AccessTarget) bool { return linked[t.Platform] })...), nil
}
