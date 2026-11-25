package tasks

import (
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// ---- messaging platforms ---------------------------------------------------

var membershipPlatforms = []string{"discord", "telegram", "whatsapp", "slack", "matrix"}

// membershipAdapter builds the join and leave triggers, which share one
// config and payload: the platform, and optionally the one server, group,
// channel or room to watch.
func membershipAdapter(typ, label, eventName, verb string) Adapter {
	return Adapter{
		Type:  typ,
		Label: label,
		ConfigHint: "{ platform: " + strings.Join(membershipPlatforms, "|") + ", spaceId?: Discord server, Telegram/WhatsApp group, Slack channel, or Matrix room ID }; " +
			"each run receives the member, with chatId for the group and dmChatId to message them directly via send_message (Telegram only reaches people who started the bot; Matrix has no dmChatId)",
		Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
			platform := strings.ToLower(trimText(config.Val("platform"), 40))
			if !slices.Contains(membershipPlatforms, platform) {
				return nil, fmt.Errorf("Platform must be one of: %s.", strings.Join(membershipPlatforms, ", "))
			}
			return jsv.NewObject().Set("platform", platform).Set("spaceId", trimText(pick(config, "spaceId", "space_id"), 200)), nil
		},
		Summarize: func(config *jsv.Object) string {
			return summaryParts("Member "+verb, config.Val("platform"), when(config.Val("spaceId"), "in "+str(config.Val("spaceId"))))
		},
		Event: &EventSpec{
			Source: "messaging", Name: eventName,
			Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
				space := config.Val("spaceId")
				return config.Val("platform") == event["platform"] && (!jsv.Truthy(space) || space == event["spaceId"])
			},
			ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
				return Payload{
					Fingerprint: fmt.Sprintf("%s:%s:%s:%s:%s", eventName, jsv.String(event["platform"]), idText(event["spaceId"]), idText(event["memberId"]), jsv.String(event["occurredAt"])),
					Timestamp:   str(event["occurredAt"]),
					Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
						Set("provider", event["platform"]).Set("event", eventName).Set("spaceId", event["spaceId"]).
						Set("spaceName", event["spaceName"]).Set("chatId", event["chatId"]).Set("memberId", event["memberId"]).
						Set("memberName", event["memberName"]).Set("dmChatId", event["dmChatId"]).Set("occurredAt", event["occurredAt"])),
				}
			},
		},
	}
}

var reactionPlatforms = []string{"discord", "telegram", "whatsapp"}

var reactionAdapter = Adapter{
	Type:       "messaging_reaction_added",
	Label:      "Reaction Added",
	ConfigHint: "{ platform?: " + strings.Join(reactionPlatforms, "|") + ", emoji?, chatId? }; private chats with allowed people only",
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		platform := strings.ToLower(trimText(config.Val("platform"), 40))
		if platform != "" && !slices.Contains(reactionPlatforms, platform) {
			return nil, fmt.Errorf("Platform must be one of: %s.", strings.Join(reactionPlatforms, ", "))
		}
		return jsv.NewObject().Set("platform", platform).Set("emoji", trimText(config.Val("emoji"), 20)).
			Set("chatId", trimText(pick(config, "chatId", "chat_id"), 200)), nil
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Reaction", config.Val("emoji"), config.Val("platform"), when(config.Val("chatId"), "chat: "+str(config.Val("chatId"))))
	},
	Event: &EventSpec{
		Source: "messaging", Name: "reaction_added",
		Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
			unset := func(key string) bool { return !jsv.Truthy(config.Val(key)) }
			return (unset("platform") || config.Val("platform") == event["platform"]) &&
				(unset("emoji") || config.Val("emoji") == event["emoji"]) &&
				(unset("chatId") || config.Val("chatId") == event["chatId"])
		},
		ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
			return Payload{
				Fingerprint: fmt.Sprintf("reaction:%s:%s:%s:%s:%s", jsv.String(event["platform"]), idText(event["chatId"]), idText(event["targetMessageId"]), idText(event["sender"]), idText(event["emoji"])),
				Timestamp:   str(event["timestamp"]),
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", event["platform"]).Set("event", "reaction_added").Set("chatId", event["chatId"]).
					Set("sender", event["sender"]).Set("senderName", event["senderName"]).
					Set("targetMessageId", event["targetMessageId"]).Set("emoji", event["emoji"])),
			}
		},
	},
}

var platformDisconnectedAdapter = Adapter{
	Type:       "messaging_platform_disconnected",
	Label:      "Messaging Disconnected",
	ConfigHint: "{ platform?: e.g. whatsapp }; fires when a connection stops and needs the user, such as a logout",
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		return jsv.NewObject().Set("platform", strings.ToLower(trimText(config.Val("platform"), 40))), nil
	},
	Summarize: func(config *jsv.Object) string { return summaryParts("Messaging disconnected", config.Val("platform")) },
	Event: &EventSpec{
		Source: "messaging", Name: "platform_disconnected",
		Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
			return !jsv.Truthy(config.Val("platform")) || config.Val("platform") == event["platform"]
		},
		ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
			return Payload{
				Fingerprint: fmt.Sprintf("platform_disconnected:%s:%s", jsv.String(event["platform"]), jsv.String(event["occurredAt"])),
				Timestamp:   str(event["occurredAt"]),
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", event["platform"]).Set("event", "platform_disconnected").
					Set("reason", event["reason"]).Set("occurredAt", event["occurredAt"])),
			}
		},
	},
}

// Only a server that was running and then failed counts: its reconnect
// attempts fail again and again, and those are not new outages.
var mcpServerAdapter = Adapter{
	Type:       "mcp_server_disconnected",
	Label:      "MCP Server Failed",
	ConfigHint: "{ serverId?: one MCP server, otherwise any }",
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		return jsv.NewObject().Set("serverId", trimText(pick(config, "serverId", "server_id"), 100)), nil
	},
	Summarize: func(config *jsv.Object) string { return summaryParts("MCP server failed", config.Val("serverId")) },
	Event: &EventSpec{
		Source: "mcp", Name: "server_status",
		Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
			failed := event["status"] == "error" || event["status"] == "auth_required"
			server := config.Val("serverId")
			return failed && event["previousStatus"] == "running" && (!jsv.Truthy(server) || jsv.String(server) == str(event["serverId"]))
		},
		ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
			return Payload{
				Fingerprint: fmt.Sprintf("mcp:%s:%s", idText(event["serverId"]), jsv.String(event["changedAt"])),
				Timestamp:   str(event["changedAt"]),
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", "mcp").Set("event", "server_failed").Set("serverId", event["serverId"]).
					Set("serverName", event["serverName"]).Set("status", event["status"]).Set("error", event["error"])),
			}
		},
	},
}

// ---- WhatsApp personal: push events plus a poll for what the push missed ----

func isGroupChat(chatID any) bool { return strings.HasSuffix(str(chatID), "@g.us") }

func whatsappEvent(chatID, messageID, sender, senderTag, content any, isGroup bool) *jsv.Object {
	return jsv.NewObject().Set("provider", "whatsapp_personal").Set("chatId", chatID).Set("messageId", messageID).
		Set("sender", orNil(sender)).Set("senderTag", orNil(senderTag)).Set("content", textOrEmpty(content)).Set("isGroup", isGroup)
}

// textOrEmpty is `value || ”`.
func textOrEmpty(v any) any {
	if jsv.Truthy(v) {
		return v
	}
	return ""
}

var whatsappPersonalAdapter = Adapter{
	Type: "whatsapp_personal_message_received", Label: "WhatsApp Personal Message Received",
	ProviderKey: "whatsapp_personal", AppKey: "personal",
	ConfigHint: "{ connectionId, chatId, sender?, ignoreGroups?: boolean }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "whatsapp_personal", "personal", func(out *jsv.Object) error {
			chat, err := requiredText(pick(config, "chatId", "chat_id"), 200, "WhatsApp chat ID is required.")
			if err != nil {
				return err
			}
			out.Set("chatId", chat).Set("sender", trimText(config.Val("sender"), 200)).
				Set("ignoreGroups", normalizeBoolean(coalesce(config, "ignoreGroups", "ignore_groups"), false))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("WhatsApp Personal", config.Val("accountEmail"), config.Val("chatId"),
			when(config.Val("sender"), "sender: "+str(config.Val("sender"))), when(config.Val("ignoreGroups"), "ignore groups"))
	},
	Poll: &Poll{
		Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("whatsapp_personal_get_messages", jsv.NewObject().Set("chat_id", config.Val("chatId")).Set("limit", 25.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, item := range objects(dig(result, "messages")) {
				if item.Val("fromMe") == true {
					continue
				}
				if sender := config.Val("sender"); jsv.Truthy(sender) && str(sender) != jsv.Text(pick(item, "senderTag", "sender")) {
					continue
				}
				if config.Val("ignoreGroups") == true && isGroupChat(item.Val("chatId")) {
					continue
				}
				stamp := item.Val("timestamp")
				if !jsv.Truthy(stamp) {
					stamp = jsv.ISO(now)
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("whatsapp:%s:%s", idText(config.Val("connectionId")), idText(item.Val("id"))),
					Timestamp:   jsv.String(stamp),
					Context: jsv.NewObject().Set("triggerEvent", whatsappEvent(item.Val("chatId"), item.Val("id"), item.Val("sender"),
						item.Val("senderTag"), item.Val("text"), isGroupChat(item.Val("chatId")))),
				})
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
	Event: &EventSpec{
		Source: "whatsapp_personal", Name: "message",
		Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
			if jsv.Text(config.Val("connectionId")) != jsv.Text(event["connectionId"]) {
				return false
			}
			if chat := config.Val("chatId"); jsv.Truthy(chat) && jsv.String(chat) != str(event["chatId"]) {
				return false
			}
			if sender := config.Val("sender"); jsv.Truthy(sender) {
				actual := event["senderTag"]
				if !jsv.Truthy(actual) {
					actual = event["sender"]
				}
				if jsv.String(sender) != jsv.Text(actual) {
					return false
				}
			}
			return !(config.Val("ignoreGroups") == true && jsv.Truthy(event["isGroup"]))
		},
		ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
			return Payload{
				Fingerprint: fmt.Sprintf("whatsapp:%s:%s", idText(event["connectionId"]), idText(event["messageId"])),
				Timestamp:   str(event["timestamp"]),
				Context: jsv.NewObject().Set("triggerEvent", whatsappEvent(event["chatId"], event["messageId"], event["sender"],
					event["senderTag"], event["text"], event["isGroup"] == true)),
			}
		},
	},
}
