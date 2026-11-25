package microsoft

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

const (
	outlookMessageFields = "subject,from,toRecipients,receivedDateTime,sentDateTime,body,bodyPreview,conversationId,importance,flag,inferenceClassification"
	// Received mail fills most of the sweep; sent mail (who the user writes
	// to) fills the rest.
	outlookConversationLimit = 100
	outlookReceivedLimit     = 70
	outlookMaxPages          = 20
	outlookBodyChars         = 2000
)

var outlookTextBody = map[string]string{"Prefer": `outlook.body-content-type="text"`}

type outlookAddress struct {
	EmailAddress struct {
		Name    string `json:"name"`
		Address string `json:"address"`
	} `json:"emailAddress"`
}

type outlookMessage struct {
	ID               string                   `json:"id"`
	Subject          string                   `json:"subject"`
	From             *outlookAddress          `json:"from"`
	ToRecipients     []outlookAddress         `json:"toRecipients"`
	ReceivedDateTime string                   `json:"receivedDateTime"`
	SentDateTime     string                   `json:"sentDateTime"`
	Body             struct{ Content string } `json:"body"`
	BodyPreview      string                   `json:"bodyPreview"`
	ConversationID   string                   `json:"conversationId"`
	Importance       string                   `json:"importance"`
	Flag             struct {
		FlagStatus string `json:"flagStatus"`
	} `json:"flag"`
	InferenceClassification string `json:"inferenceClassification"`
}

func (m outlookMessage) important() bool {
	return m.Importance == "high" || m.Flag.FlagStatus == "flagged"
}

func formatAddress(a *outlookAddress) string {
	if a == nil {
		return ""
	}
	name, address := strings.TrimSpace(a.EmailAddress.Name), strings.TrimSpace(a.EmailAddress.Address)
	if name != "" && address != "" && name != address {
		return name + " <" + address + ">"
	}
	if address != "" {
		return address
	}
	return name
}

type conversation struct {
	id       string
	latest   outlookMessage
	messages []outlookMessage
}

// sweep reads the past year's important Outlook mail for memory: high
// importance, flagged and Focused mail received, plus what the user sent.
// Conversations already in memory are skipped.
func (p *provider) sweep(ctx context.Context, tc *integrations.ToolContext, req integrations.SweepInput) ([]any, error) {
	if tc.Connection.AppKey != "outlook" {
		return []any{}, nil
	}
	email := false
	for _, t := range req.SourceTypes {
		email = email || t == "email"
	}
	if !email {
		return []any{}, nil
	}
	collectedAt := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	since := time.Now().UTC().Add(-365 * 24 * time.Hour).Format("2006-01-02T15:04:05.000Z")
	byID := map[string]*conversation{}
	var order []*conversation
	add := func(limit int) func(outlookMessage) bool {
		return func(m outlookMessage) bool {
			id := m.ConversationID
			if id == "" {
				id = m.ID
			}
			if id == "" || req.SkipObjectIDs[id] {
				return true
			}
			if c := byID[id]; c != nil {
				c.messages = append(c.messages, m)
				return true
			}
			if len(order) >= limit {
				return false
			}
			c := &conversation{id: id, latest: m, messages: []outlookMessage{m}}
			byID[id] = c
			order = append(order, c)
			if req.OnProgress != nil {
				req.OnProgress(len(order), nil)
			}
			return len(order) < limit
		}
	}
	received := func(filter string) oauthclient.Query {
		return oauthclient.Query{{"$filter", filter}, {"$orderby", "receivedDateTime desc"}, {"$select", outlookMessageFields}, {"$top", "50"}}
	}
	err := p.listMessages(ctx, tc, "/v1.0/me/messages",
		received("receivedDateTime ge "+since+" and (importance eq 'high' or flag/flagStatus eq 'flagged' or inferenceClassification eq 'focused')"),
		nil, add(outlookReceivedLimit))
	if err != nil {
		if ctx.Err() != nil {
			return nil, err
		}
		// Some mailboxes reject the combined filter; narrow it down here then.
		// A later page failing keeps what the earlier pages already gave.
		if len(order) == 0 {
			_ = p.listMessages(ctx, tc, "/v1.0/me/messages", received("receivedDateTime ge "+since),
				func(m outlookMessage) bool { return m.important() || m.InferenceClassification == "focused" }, add(outlookReceivedLimit))
		}
	}
	if err := p.listMessages(ctx, tc, "/v1.0/me/mailFolders/sentitems/messages",
		oauthclient.Query{{"$filter", "sentDateTime ge " + since}, {"$orderby", "sentDateTime desc"}, {"$select", outlookMessageFields}, {"$top", "50"}},
		nil, add(outlookConversationLimit)); err != nil {
		return nil, err
	}
	docs := make([]any, 0, len(order))
	for _, c := range order {
		docs = append(docs, conversationDocument(c, collectedAt))
	}
	return docs, nil
}

func (p *provider) listMessages(ctx context.Context, tc *integrations.ToolContext, path string, query oauthclient.Query, accept func(outlookMessage) bool, onMessage func(outlookMessage) bool) error {
	for page := 0; path != "" && page < outlookMaxPages; page++ {
		raw, err := p.graph(ctx, tc, graphCall{path: path, query: query, header: outlookTextBody})
		if err != nil {
			return err
		}
		var payload struct {
			Value    []outlookMessage `json:"value"`
			NextLink string           `json:"@odata.nextLink"`
		}
		_ = json.Unmarshal(raw, &payload)
		for _, m := range payload.Value {
			if (accept == nil || accept(m)) && !onMessage(m) {
				return nil
			}
		}
		path, query = payload.NextLink, nil
	}
	return nil
}

func conversationDocument(c *conversation, collectedAt string) map[string]any {
	latest := c.latest
	subject := strings.TrimSpace(latest.Subject)
	if subject == "" {
		subject = "Outlook conversation"
	}
	var participants []string
	seen := map[string]bool{}
	important := false
	for _, m := range c.messages {
		important = important || m.important()
		addrs := []string{formatAddress(m.From)}
		for i := range m.ToRecipients {
			addrs = append(addrs, formatAddress(&m.ToRecipients[i]))
		}
		for _, a := range addrs {
			if a != "" && !seen[a] {
				seen[a] = true
				participants = append(participants, a)
			}
		}
	}
	date := latest.ReceivedDateTime
	if date == "" {
		date = latest.SentDateTime
	}
	if date == "" {
		date = collectedAt
	}
	body := strings.TrimSpace(latest.Body.Content)
	if body == "" {
		body = strings.TrimSpace(latest.BodyPreview)
	}
	if r := []rune(body); len(r) > outlookBodyChars {
		body = string(r[:outlookBodyChars])
	}
	lines := []string{subject}
	if len(participants) > 0 {
		lines = append(lines, "Participants: "+strings.Join(participants, ", "))
	}
	lines = append(lines, "Date: "+date, "Messages: "+itoa(len(c.messages)))
	if body != "" {
		lines = append(lines, body)
	}
	summary := latest.BodyPreview
	if summary == "" {
		summary = subject
	}
	salience := 7
	if important {
		salience = 8
	}
	return map[string]any{
		"externalObjectId": c.id, "sourceType": "email", "normalizedType": "email", "title": subject,
		"content": strings.Join(lines, "\n"), "summary": summary, "sourceTimestamp": date, "salience": salience,
		"payload": map[string]any{"conversationId": c.id, "messageCount": len(c.messages)},
	}
}

func itoa(n int) string { return strconv.Itoa(n) }
