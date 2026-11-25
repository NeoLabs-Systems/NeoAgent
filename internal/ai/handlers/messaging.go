package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"regexp"
	"strings"
	"unicode"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var messagingHandlers = map[string]handler{
	"list_chats":          listChats,
	"read_messages":       readMessages,
	"send_interim_update": sendInterimUpdate,
	"react_to_message":    reactToMessage,
	"send_message":        sendMessage,
	"call_user":           callUser,
	"notify_user":         notifyUser,
}

const noResponse = "[NO RESPONSE]"

func normalizeSendPurpose(v any) string {
	p := strings.ToLower(strings.TrimSpace(dyn.Str(v)))
	if p == "final_result" || p == "blocker" || p == "no_response" {
		return p
	}
	return ""
}

// proactiveValidation is validateProactiveSendMessageArgs: a background
// send_message must say why it speaks.
type proactiveValidation struct {
	ok, skipped, suppressed bool
	purpose, err, reason    string
}

func validateProactiveSend(purpose any, normalized string) proactiveValidation {
	p := normalizeSendPurpose(purpose)
	if p == "" {
		msg := "Background send_message requires purpose=final_result, blocker, or no_response."
		return proactiveValidation{err: msg, reason: msg}
	}
	if p == "no_response" {
		if normalized != "" && normalized != noResponse {
			msg := `purpose=no_response requires content "[NO RESPONSE]".`
			return proactiveValidation{err: msg, reason: msg}
		}
		return proactiveValidation{skipped: true, suppressed: true, reason: "no_response"}
	}
	if normalized == noResponse {
		msg := "purpose=" + p + ` cannot use content "[NO RESPONSE]".`
		return proactiveValidation{err: msg, reason: msg}
	}
	return proactiveValidation{ok: true, purpose: p}
}

func alreadySentProactive(run *Run) bool {
	if run.TaskID == "" || run.AllowMultipleProactiveMessages || run.Delivery == nil {
		return false
	}
	return run.Delivery.SentCount() > 0 || run.Delivery.Staged()
}

var nonDigits = regexp.MustCompile(`[^0-9]`)

func normalizeWhatsAppID(value string) string {
	raw := strings.ToLower(strings.TrimSpace(value))
	if raw == "" {
		return ""
	}
	base := strings.Split(raw, "@")[0]
	primary := strings.Split(base, ":")[0]
	if digits := nonDigits.ReplaceAllString(primary, ""); digits != "" {
		return digits
	}
	return primary
}

func canonicalAddress(platform, value string) string {
	p := strings.ToLower(strings.TrimSpace(platform))
	raw := strings.TrimSpace(value)
	if p == "" || raw == "" {
		return ""
	}
	if p != "whatsapp" {
		return raw
	}
	lower := strings.ToLower(raw)
	id := normalizeWhatsAppID(lower)
	switch {
	case id == "":
		return ""
	case strings.Contains(lower, "@g.us"):
		return "group:" + id
	case strings.Contains(lower, "@lid"):
		return "lid:" + id
	}
	return "direct:" + id
}

func isOriginDelivery(triggerSource, source, chatID, platform, to string) bool {
	if triggerSource != "messaging" {
		return true
	}
	origin := strings.ToLower(strings.TrimSpace(source))
	target := strings.ToLower(strings.TrimSpace(platform))
	if origin == "" || target == "" || origin != target {
		return false
	}
	a, b := canonicalAddress(origin, chatID), canonicalAddress(target, to)
	return a != "" && b != "" && a == b
}

func isSenderDirectTarget(platform, to, sender string) bool {
	target, sender := strings.TrimSpace(to), strings.TrimSpace(sender)
	if target == "" || sender == "" {
		return false
	}
	if target == sender || target == "dm_"+sender {
		return true
	}
	if strings.ToLower(strings.TrimSpace(platform)) != "whatsapp" {
		return false
	}
	a, b := canonicalAddress("whatsapp", target), canonicalAddress("whatsapp", sender)
	return a != "" && b != "" && a == b && strings.HasPrefix(a, "direct:")
}

type sendTarget struct {
	platform, to string
	redirected   bool
}

// resolveSendTarget keeps a group run's reply in the group: a "direct" reply
// to the sender is moved back to the chat the run answers.
func resolveSendTarget(triggerSource, source, chatID, platform, to string, isGroup bool, sender string) sendTarget {
	resolvedPlatform := strings.TrimSpace(platform)
	if resolvedPlatform == "" {
		resolvedPlatform = strings.TrimSpace(source)
	}
	resolvedTo := strings.TrimSpace(to)
	originChat := strings.TrimSpace(chatID)
	originPlatform := strings.TrimSpace(source)
	if originPlatform == "" {
		originPlatform = resolvedPlatform
	}
	if triggerSource == "messaging" && isGroup && originChat != "" &&
		isSenderDirectTarget(resolvedPlatform, resolvedTo, sender) &&
		!isOriginDelivery(triggerSource, originPlatform, originChat, resolvedPlatform, resolvedTo) {
		return sendTarget{platform: originPlatform, to: originChat, redirected: true}
	}
	return sendTarget{platform: resolvedPlatform, to: resolvedTo}
}

func inboundIsGroup(run *Run) bool {
	return (run.Behavior != nil && run.Behavior.IsGroup) || (run.Inbound != nil && run.Inbound.IsGroup)
}

func inboundSender(run *Run) string {
	if run.Inbound != nil {
		return strings.TrimSpace(run.Inbound.Sender)
	}
	return ""
}

func metaOf(raw string) dyn.Map {
	if raw == "" {
		return dyn.Map{}
	}
	var m dyn.Map
	if json.Unmarshal([]byte(raw), &m) != nil || m == nil {
		return dyn.Map{}
	}
	return m
}

func firstTruthy(m dyn.Map, keys ...string) any {
	for _, k := range keys {
		if dyn.Truthy(m[k]) {
			return m[k]
		}
	}
	return nil
}

var groupFlag = regexp.MustCompile(`(?i)^(true|1)$`)

func listChats(ctx context.Context, c *call) (any, error) {
	if c.b.d.DB == nil {
		return nil, errorf("Database is unavailable.")
	}
	query := `SELECT platform, platform_chat_id, metadata
                FROM messages
                WHERE user_id = ? AND platform_chat_id IS NOT NULL AND platform != 'web'`
	params := []any{c.run.UserID}
	if p, ok := c.args["platform"].(string); ok {
		query += " AND platform = ?"
		params = append(params, strings.ToLower(strings.TrimSpace(p)))
	}
	query += " ORDER BY id DESC LIMIT 2000"
	rows, err := c.b.d.DB.R.QueryContext(ctx, query, params...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	seen := map[string]bool{}
	chats := []any{}
	for rows.Next() {
		var platform, chatID string
		var metadata *string
		if err := rows.Scan(&platform, &chatID, &metadata); err != nil {
			return nil, err
		}
		key := platform + ":" + chatID
		if seen[key] {
			continue
		}
		seen[key] = true
		meta := dyn.Map{}
		if metadata != nil {
			meta = metaOf(*metadata)
		}
		flag := dyn.Str(meta["isGroup"])
		isGroup := groupFlag.MatchString(flag) && flag != ""
		var name any
		if n := strings.TrimSpace(dyn.Str(firstTruthy(meta, "groupName", "group_name", "guildName", "guild_name", "chatName", "chat_name"))); n != "" {
			name = n
		} else if n := strings.TrimSpace(dyn.Str(firstTruthy(meta, "senderName", "sender_name"))); n != "" {
			name = n
		}
		kind := "dm"
		if isGroup {
			kind = "group"
		}
		chats = append(chats, dyn.Ordered{{Key: "platform", Value: platform}, {Key: "chat_id", Value: chatID}, {Key: "name", Value: name}, {Key: "type", Value: kind}})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return dyn.Ordered{{Key: "count", Value: len(chats)}, {Key: "chats", Value: chats}}, nil
}

func readMessages(ctx context.Context, c *call) (any, error) {
	if c.b.d.DB == nil {
		return nil, errorf("Database is unavailable.")
	}
	limit := int(min(max(orNumber(jsNumber(c.args["limit"]), 20), 1), 100))
	query := "SELECT role, content, platform, platform_chat_id, metadata, created_at FROM messages WHERE user_id = ? AND role = 'user'"
	params := []any{c.run.UserID}
	if p, ok := c.args["platform"].(string); ok {
		if p = strings.ToLower(strings.TrimSpace(p)); p != "" {
			query += " AND platform = ?"
			params = append(params, p)
		}
	}
	if id, ok := c.args["chat_id"].(string); ok {
		if id = strings.TrimSpace(id); id != "" {
			query += " AND platform_chat_id = ?"
			params = append(params, id)
		}
	}
	if s, ok := c.args["search"].(string); ok {
		if s = strings.TrimSpace(s); s != "" {
			query += " AND content LIKE ?"
			params = append(params, "%"+s+"%")
		}
	}
	groupName := ""
	if g, ok := c.args["group_name"].(string); ok {
		groupName = strings.ToLower(strings.TrimSpace(g))
	}
	query += " ORDER BY created_at DESC LIMIT ?"
	if groupName != "" {
		params = append(params, min(limit*10, 500))
	} else {
		params = append(params, limit)
	}
	rows, err := c.b.d.DB.R.QueryContext(ctx, query, params...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	type row struct {
		content, platform, createdAt any
		chatID                       *string
		meta                         dyn.Map
	}
	var list []row
	for rows.Next() {
		var role string
		var content, platform, createdAt any
		var chatID, metadata *string
		if err := rows.Scan(&role, &content, &platform, &chatID, &metadata, &createdAt); err != nil {
			return nil, err
		}
		r := row{content: sqlText(content), platform: sqlText(platform), createdAt: sqlText(createdAt), chatID: chatID, meta: dyn.Map{}}
		if metadata != nil {
			r.meta = metaOf(*metadata)
		}
		list = append(list, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if groupName != "" {
		var filtered []row
		for _, r := range list {
			name := dyn.Str(firstTruthy(r.meta, "groupName", "group_name", "guildName", "guild_name", "chatName", "chat_name"))
			if name == "" && r.chatID != nil {
				name = *r.chatID
			}
			if strings.Contains(strings.ToLower(name), groupName) {
				filtered = append(filtered, r)
			}
		}
		list = filtered[:min(len(filtered), limit)]
	}
	messages := []any{}
	for i := len(list) - 1; i >= 0; i-- {
		r := list[i]
		var chatID any
		if r.chatID != nil {
			chatID = *r.chatID
		}
		messages = append(messages, dyn.Ordered{
			{Key: "platform", Value: r.platform},
			{Key: "chat_id", Value: chatID},
			{Key: "group_name", Value: firstTruthy(r.meta, "groupName", "group_name", "guildName", "guild_name")},
			{Key: "sender", Value: firstTruthy(r.meta, "senderName", "sender_name")},
			{Key: "content", Value: r.content},
			{Key: "timestamp", Value: r.createdAt},
		})
	}
	return dyn.Ordered{{Key: "count", Value: len(messages)}, {Key: "messages", Value: messages}}, nil
}

// sqlText turns a scanned TEXT value ([]byte from the driver) into a string.
func sqlText(v any) any {
	if b, ok := v.([]byte); ok {
		return string(b)
	}
	return v
}

func sendInterimUpdate(ctx context.Context, c *call) (any, error) {
	run := c.run
	if run.TriggerSource == "agent_delegation" || run.TriggerSource == "agent" || run.TriggerType == "subagent" {
		return errResult("Interim user-facing updates are not allowed from delegated or sub-agent runs."), nil
	}
	if c.b.d.Engine == nil || run.RunID == "" {
		return errResult("Interim updates require an active run."), nil
	}
	if run.Behavior != nil && run.Behavior.IsGroup {
		return dyn.Ordered{{Key: "sent", Value: false}, {Key: "skipped", Value: true}, {Key: "reason", Value: "Interim progress updates are suppressed in shared rooms."}}, nil
	}
	content, _ := c.args["content"].(string)
	return c.b.d.Engine.PublishInterimUpdate(ctx, InterimUpdate{
		UserID: run.UserID, RunID: run.RunID, AgentID: run.AgentID, TriggerSource: run.TriggerSource,
		ConversationID: run.ConversationID, Platform: run.Source, ChatID: run.ChatID,
		Content: content, Kind: ai.NormalizeInterimKind(c.args["kind"]),
		ExpectsReply: c.args["expects_reply"] == true, DeferFollowUp: c.args["defer_follow_up"] == true,
	})
}

func reactToMessage(ctx context.Context, c *call) (any, error) {
	inbound := c.run.Inbound
	if c.run.TriggerSource != "messaging" || inbound == nil || inbound.MessageID == "" {
		return errResult("This run has no incoming chat message to react to."), nil
	}
	m := c.b.d.Messaging
	if m == nil || !m.SupportsReactions(c.run.UserID, c.run.AgentID, inbound.Platform) {
		return errResult(inbound.Platform + " does not support reactions."), nil
	}
	emoji := strings.TrimSpace(dyn.Str(c.args["emoji"]))
	if !validEmoji(emoji) {
		return errResult("emoji must be a single emoji."), nil
	}
	if err := m.SendReaction(ctx, c.run.UserID, c.run.AgentID, inbound.Platform, inbound.ChatID, inbound.MessageID, emoji, c.run.RunID); err != nil {
		return nil, err
	}
	return dyn.Ordered{{Key: "success", Value: true}, {Key: "reacted", Value: emoji}}, nil
}

// validEmoji: at most 16 UTF-16 units, at least one pictograph, and no
// letters, digits or spaces.
func validEmoji(s string) bool {
	if s == "" || lenUTF16(s) > 16 {
		return false
	}
	pictographic := false
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsNumber(r) || unicode.IsSpace(r) {
			return false
		}
		if isExtendedPictographic(r) {
			pictographic = true
		}
	}
	return pictographic
}

func sendMessage(ctx context.Context, c *call) (any, error) {
	run := c.run
	if run.TriggerSource == "agent_delegation" && !run.AllowExternalSideEffects {
		return errResult("Delegated agents cannot send external messages unless external side effects were explicitly allowed."), nil
	}
	m := c.b.d.Messaging
	if m == nil {
		return errResult("Messaging not available"), nil
	}
	to := strings.TrimSpace(dyn.Str(c.args["to"]))
	if to == "" {
		return errResult(`send_message needs "to": a chat ID, or "owner" for the owner's own chat on that platform.`), nil
	}
	if strings.ToLower(to) == "owner" {
		to = m.OwnerDestination(run.UserID, run.AgentID, dyn.Str(c.args["platform"]))
		if to == "" {
			return errResult("There is no verified chat with the owner on " + orString(c.args["platform"], "that platform") + ". Name the chat, or ask the owner where to send it."), nil
		}
	}
	target := resolveSendTarget(run.TriggerSource, run.Source, run.ChatID, dyn.Str(c.args["platform"]), to, inboundIsGroup(run), inboundSender(run))
	message, _ := c.args["content"].(string)
	normalized := m.FormatOutgoing(target.platform, message)
	suppress := normalized == noResponse
	origin := isOriginDelivery(run.TriggerSource, run.Source, run.ChatID, target.platform, target.to)
	chooseSilence := func() {
		if run.Delivery != nil {
			run.Delivery.ChooseSilence()
		}
	}
	if run.TaskID != "" {
		v := validateProactiveSend(c.args["purpose"], normalized)
		if !v.ok {
			if v.err != "" {
				return errResult(v.err), nil
			}
			if v.reason == "no_response" {
				chooseSilence()
			}
			return dyn.Ordered{{Key: "sent", Value: false}, {Key: "suppressed", Value: v.suppressed}, {Key: "skipped", Value: v.skipped}, {Key: "reason", Value: v.reason}}, nil
		}
	}
	if suppress {
		chooseSilence()
	}
	if !suppress && alreadySentProactive(run) {
		return dyn.Ordered{{Key: "sent", Value: false}, {Key: "skipped", Value: true}, {Key: "reason", Value: "A proactive message was already sent in this task run; duplicate send_message was suppressed."}}, nil
	}
	mediaPath := dyn.Str(c.args["media_path"])
	if run.TaskID != "" && run.StageProactiveMessages && !suppress {
		// A task reports to the target the run resolved, whatever the model named.
		platform, stagedTo := c.args["platform"], c.args["to"]
		if run.Delivery != nil {
			if p, t, ok := run.Delivery.NotifyTarget(); ok {
				if p != "" {
					platform = p
				}
				if t != "" {
					stagedTo = t
				}
			}
			run.Delivery.Stage(StagedMessage{
				Platform:  strings.TrimSpace(str(platform)),
				To:        strings.TrimSpace(str(stagedTo)),
				Content:   strings.TrimSpace(normalized),
				Purpose:   strings.ToLower(strings.TrimSpace(str(c.args["purpose"]))),
				MediaPath: mediaPath,
				StagedAt:  c.b.d.Now().UTC().Format("2006-01-02T15:04:05.000Z"),
			})
		}
		return dyn.Ordered{
			{Key: "success", Value: true}, {Key: "staged", Value: true},
			{Key: "purpose", Value: normalizeSendPurpose(c.args["purpose"])},
			{Key: "platform", Value: platform}, {Key: "to", Value: stagedTo}, {Key: "content", Value: normalized},
		}, nil
	}

	var sendResult dyn.Ordered
	var thrown error
	transmit := func(ctx context.Context) TransmitResult {
		if origin && run.Behavior != nil && run.Behavior.Enabled && c.b.d.Behavior != nil {
			br, err := c.b.d.Behavior.DeliverReply(ctx, run.UserID, run.AgentID, run.Behavior, normalized, mediaPath, run.RunID)
			switch {
			case err != nil:
				thrown = err
				return TransmitResult{Error: err.Error()}
			case br.Delivered:
				sendResult = dyn.Ordered{{Key: "success", Value: true}, {Key: "behavior", Value: true}, {Key: "result", Value: br.Delivery}}
			case br.Suppressed:
				chooseSilence()
				sendResult = dyn.Ordered{{Key: "success", Value: true}, {Key: "sent", Value: false}, {Key: "suppressed", Value: true}, {Key: "reason", Value: br.Reason}}
			default:
				reason := br.Reason
				if reason == "" {
					reason = "Behavior delivery was not confirmed."
				}
				sendResult = dyn.Ordered{{Key: "success", Value: false}, {Key: "error", Value: reason}, {Key: "deliveryAmbiguous", Value: br.DeliveredBubbles > 0}}
			}
		} else {
			result, err := m.Send(ctx, run.UserID, run.AgentID, target.platform, target.to, message, mediaPath, run.RunID, run.TaskID != "")
			if err != nil {
				thrown = err
				return TransmitResult{Error: err.Error()}
			}
			sendResult = spread(result, nil)
		}
		if sendResult.Get("suppressed") == true {
			return TransmitResult{OK: true, SkippedTransmission: true, Reason: orString(sendResult.Get("reason"), "suppressed")}
		}
		if sendResult.Get("success") == true {
			return TransmitResult{OK: true, PlatformMessageID: dyn.Str(dyn.Get(asMap(sendResult), "result", "messageId"))}
		}
		errText := orString(sendResult.Get("error"), orString(sendResult.Get("reason"), "send failed"))
		return TransmitResult{OK: false, Ambiguous: sendResult.Get("deliveryAmbiguous") == true, Error: errText}
	}

	if run.Persisted && !suppress && run.RunID != "" && c.b.d.Engine != nil {
		recipient := target.platform + ":" + target.to
		if origin && run.TriggerSource == "messaging" && run.ChatID != "" {
			recipient = run.ChatID
		}
		purpose := "message"
		if origin {
			purpose = "reply"
		}
		var purposeMeta any
		if p := normalizeSendPurpose(c.args["purpose"]); p != "" {
			purposeMeta = p
		}
		outcome, err := c.b.d.Engine.CommitDelivery(ctx, run.RunID, DeliveryCommit{
			ScopeID: run.DeliveryScopeID, Channel: "messaging", Recipient: recipient, Purpose: purpose,
			SlotContent: normalized + "\n" + mediaPath, Content: normalized,
			Metadata:      dyn.Map{"platform": target.platform, "purpose": purposeMeta},
			DedupeContent: mediaPath == "", AllowEmptyContent: mediaPath != "",
			Transmit: transmit,
		})
		if err != nil {
			return nil, err
		}
		if outcome.Duplicate && sendResult == nil {
			if outcome.OK {
				sendResult = dyn.Ordered{{Key: "success", Value: true}, {Key: "sent", Value: false}, {Key: "duplicate", Value: true}, {Key: "note", Value: "This exact message already reached this recipient in this run, so it was not sent again."}}
			} else {
				sendResult = dyn.Ordered{{Key: "success", Value: false}, {Key: "sent", Value: false}, {Key: "duplicate", Value: true}, {Key: "error", Value: "An earlier attempt to send exactly this may or may not have arrived, so it was not sent again. Do not retry it; tell the user it may not have gone through."}}
			}
		}
		if !outcome.OK && sendResult == nil {
			msg := outcome.Error
			if msg == "" {
				msg = outcome.Reason
			}
			sendResult = dyn.Ordered{{Key: "success", Value: false}, {Key: "error", Value: msg}}
		}
	} else {
		transmit(ctx)
	}
	if sendResult == nil && thrown != nil {
		return nil, thrown
	}
	delivered := !suppress && sendResult.Get("success") == true && sendResult.Get("suppressed") != true
	if delivered && origin {
		active := c.b.d.Engine != nil && run.RunID != "" && c.b.d.Engine.Run(run.RunID) != nil
		if active && run.TriggerSource == "messaging" {
			// A reply in the chat the run answers is not the run's end: its
			// final answer is still owed unless this reply stays its last word.
			if run.Delivery != nil {
				run.Delivery.MarkLastWordSent()
			}
			c.b.d.Engine.MarkRunVisibleReply(run.RunID)
		} else if run.Delivery != nil {
			run.Delivery.MarkFinalDelivered()
		}
	}
	if delivered && sendResult.Get("duplicate") != true && run.Delivery != nil {
		run.Delivery.MarkSent(normalized)
	}
	return append(sendResult,
		dyn.KV{Key: "originDelivery", Value: origin},
		dyn.KV{Key: "redirectedFromDirect", Value: target.redirected},
		dyn.KV{Key: "platform", Value: target.platform},
		dyn.KV{Key: "to", Value: target.to},
	), nil
}

func callUser(ctx context.Context, c *call) (any, error) {
	if c.b.d.Calls == nil {
		return dyn.Ordered{
			{Key: "status", Value: "unavailable"},
			{Key: "reason", Value: "call_service_not_initialized"},
			{Key: "message", Value: "The call_user tool is available, but the in-app call service is not initialized on this server."},
		}, nil
	}
	opening := ""
	if s, ok := c.args["opening_message"].(string); ok {
		opening = strings.TrimSpace(s)
	}
	if opening == "" {
		return errResult("opening_message is required"), nil
	}
	if lenUTF16(opening) > 4000 {
		return errResult("opening_message must be 4000 characters or fewer"), nil
	}
	return c.b.d.Calls.CallUser(ctx, c.run.UserID, c.run.AgentID, c.run.RunID, c.run.ConversationID, opening)
}

func notifyUser(ctx context.Context, c *call) (any, error) {
	run := c.run
	message := ""
	if s, ok := c.args["message"].(string); ok {
		message = strings.TrimSpace(s)
	}
	if message == "" {
		return errResult("message is required"), nil
	}
	if run.TaskID == "" {
		if c.b.d.Engine != nil {
			c.b.d.Engine.Emit(run.UserID, "run:interim", dyn.Map{"runId": run.RunID, "message": message})
		}
		return dyn.Ordered{{Key: "sent", Value: true}, {Key: "via", Value: "interim"}}, nil
	}
	m := c.b.d.Messaging
	if m == nil {
		return nil, errors.New("Messaging manager not available")
	}
	if alreadySentProactive(run) {
		return dyn.Ordered{{Key: "sent", Value: false}, {Key: "skipped", Value: true}, {Key: "reason", Value: "A notification was already sent in this run; duplicate task message was suppressed."}}, nil
	}
	var platform, to string
	ok := false
	if run.Delivery != nil {
		platform, to, ok = run.Delivery.NotifyTarget()
	}
	if !ok {
		return nil, errors.New("No messaging target is configured for this task run. Connect a platform and send at least one message on this server, or recreate the task after reconnecting.")
	}
	if m.PlatformStatus(ctx, run.UserID, run.AgentID, platform) != "connected" {
		return nil, errors.New("Platform " + platform + " is not connected on this server.")
	}
	var sendResult dyn.Map
	send := func(ctx context.Context) error {
		result, err := m.Send(ctx, run.UserID, run.AgentID, platform, to, message, "", run.RunID, true)
		sendResult = result
		return err
	}
	if run.Persisted && run.RunID != "" && c.b.d.Engine != nil {
		var sendErr error
		outcome, err := c.b.d.Engine.CommitDelivery(ctx, run.RunID, DeliveryCommit{
			Channel: "messaging", Recipient: platform + ":" + to, Purpose: "notify",
			SlotContent: message, Content: message, Metadata: dyn.Map{"platform": platform},
			DedupeContent: true,
			Transmit: func(ctx context.Context) TransmitResult {
				if sendErr = send(ctx); sendErr != nil {
					return TransmitResult{Error: sendErr.Error()}
				}
				return TransmitResult{OK: true, PlatformMessageID: dyn.Str(dyn.Get(sendResult, "result", "messageId"))}
			},
		})
		if err != nil {
			return nil, err
		}
		if !outcome.OK && sendErr != nil {
			return nil, sendErr
		}
	} else if err := send(ctx); err != nil {
		return nil, err
	}
	if run.Delivery != nil {
		run.Delivery.MarkSent(message)
		run.Delivery.MarkFinalDelivered()
	}
	return dyn.Ordered{{Key: "sent", Value: true}, {Key: "via", Value: "messaging"}, {Key: "platform", Value: platform}, {Key: "to", Value: to}, {Key: "result", Value: sendResult}}, nil
}
