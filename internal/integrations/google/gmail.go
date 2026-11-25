package google

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

type gmailMessage struct {
	ID           string          `json:"id"`
	ThreadID     string          `json:"threadId"`
	LabelIDs     []string        `json:"labelIds"`
	Snippet      string          `json:"snippet"`
	InternalDate string          `json:"internalDate"`
	Payload      *messagePayload `json:"payload"`
}

type gmailThread struct {
	ID        string         `json:"id"`
	HistoryID string         `json:"historyId"`
	Snippet   string         `json:"snippet"`
	Messages  []gmailMessage `json:"messages"`
}

// messageSummary is a message as the model reads it.
type messageSummary struct {
	ID           string   `json:"id"`
	ThreadID     string   `json:"threadId"`
	LabelIDs     []string `json:"labelIds"`
	Snippet      string   `json:"snippet"`
	InternalDate *string  `json:"internalDate"`
	Subject      *string  `json:"subject"`
	From         *string  `json:"from"`
	To           *string  `json:"to"`
	Date         *string  `json:"date"`
	BodyText     string   `json:"bodyText"`
}

func summarizeMessage(m gmailMessage) messageSummary {
	var headers []header
	if m.Payload != nil {
		headers = m.Payload.Headers
	}
	labels := m.LabelIDs
	if labels == nil {
		labels = []string{}
	}
	s := messageSummary{
		ID: m.ID, ThreadID: m.ThreadID, LabelIDs: labels, Snippet: normalizeDecodedText(m.Snippet),
		Subject: getHeader(headers, "Subject"), From: getHeader(headers, "From"),
		To: getHeader(headers, "To"), Date: getHeader(headers, "Date"),
		BodyText: extractMessageBody(m.Payload),
	}
	if ms, err := strconv.ParseInt(m.InternalDate, 10, 64); err == nil && m.InternalDate != "" {
		iso := oauthclient.ISO(time.UnixMilli(ms))
		s.InternalDate = &iso
	}
	return s
}

type labelSummary struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Type          string `json:"type"`
	MessagesTotal *int64 `json:"messagesTotal"`
	ThreadsTotal  *int64 `json:"threadsTotal"`
}

func sanitizeHeaderValue(value any, label string) (string, error) {
	v := trimmed(value)
	if strings.ContainsAny(v, "\r\n") {
		return "", fmt.Errorf("%s must not contain newline characters.", label)
	}
	return v, nil
}

func (s *session) gmailURL(path string) string {
	return s.p.ep.gmail + "/gmail/v1/users/me/" + path
}

func (s *session) listLabels(ctx context.Context) ([]labelSummary, error) {
	res, err := s.call(ctx, "GET", s.gmailURL("labels"), nil, nil)
	if err != nil {
		return nil, err
	}
	var data struct {
		Labels []labelSummary `json:"labels"`
	}
	if err := decodeInto(res.body, &data); err != nil {
		return nil, err
	}
	out := make([]labelSummary, 0, len(data.Labels))
	for _, l := range data.Labels {
		if l.Type == "" {
			l.Type = "user"
		}
		out = append(out, l)
	}
	return out, nil
}

func (s *session) resolveLabelIDs(ctx context.Context, names []string) ([]string, error) {
	wanted := map[string]bool{}
	for _, n := range names {
		wanted[strings.ToLower(n)] = true
	}
	ids := []string{}
	if len(wanted) == 0 {
		return ids, nil
	}
	labels, err := s.listLabels(ctx)
	if err != nil {
		return nil, err
	}
	for _, l := range labels {
		if wanted[strings.ToLower(l.Name)] {
			ids = append(ids, l.ID)
		}
	}
	return ids, nil
}

type threadSummary struct {
	ID           string  `json:"id"`
	Snippet      string  `json:"snippet"`
	HistoryID    *string `json:"historyId"`
	MessageCount int     `json:"messageCount"`
	Subject      *string `json:"subject"`
	From         *string `json:"from"`
	Date         *string `json:"date"`
}

func (s *session) gmail(ctx context.Context, name string, args map[string]any) (any, error) {
	switch name {
	case "google_workspace_gmail_search_threads":
		return s.searchThreads(ctx, args)
	case "google_workspace_gmail_get_thread":
		res, err := s.call(ctx, "GET", s.gmailURL("threads/"+url.PathEscape(textOf(args["thread_id"]))), oauthclient.Query{{"format", "full"}}, nil)
		if err != nil {
			return nil, err
		}
		var t gmailThread
		if err := decodeInto(res.body, &t); err != nil {
			return nil, err
		}
		messages := make([]messageSummary, 0, len(t.Messages))
		for _, m := range t.Messages {
			messages = append(messages, summarizeMessage(m))
		}
		return struct {
			ID        string           `json:"id"`
			HistoryID *string          `json:"historyId"`
			Snippet   string           `json:"snippet"`
			Messages  []messageSummary `json:"messages"`
		}{t.ID, nonEmpty(t.HistoryID), normalizeDecodedText(t.Snippet), messages}, nil
	case "google_workspace_gmail_get_message":
		res, err := s.call(ctx, "GET", s.gmailURL("messages/"+url.PathEscape(textOf(args["message_id"]))), oauthclient.Query{{"format", "full"}}, nil)
		if err != nil {
			return nil, err
		}
		var m gmailMessage
		if err := decodeInto(res.body, &m); err != nil {
			return nil, err
		}
		return summarizeMessage(m), nil
	case "google_workspace_gmail_list_labels":
		labels, err := s.listLabels(ctx)
		if err != nil {
			return nil, err
		}
		return struct {
			Count  int            `json:"count"`
			Labels []labelSummary `json:"labels"`
		}{len(labels), labels}, nil
	case "google_workspace_gmail_send_email":
		return s.sendEmail(ctx, args)
	case "google_workspace_gmail_modify_thread_labels":
		return s.modifyThreadLabels(ctx, args)
	case "google_workspace_gmail_api_request":
		return s.apiRequest(ctx, args, s.p.ep.gmail)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}

func (s *session) searchThreads(ctx context.Context, args map[string]any) (any, error) {
	max := integrations.Clamp(args["max_results"], 10, 1, 25)
	query := textOf(args["query"])
	res, err := s.call(ctx, "GET", s.gmailURL("threads"), oauthclient.Query{{"q", query}, {"maxResults", max}}, nil)
	if err != nil {
		return nil, err
	}
	var list struct {
		Threads []struct {
			ID string `json:"id"`
		} `json:"threads"`
	}
	if err := decodeInto(res.body, &list); err != nil {
		return nil, err
	}
	threads := make([]threadSummary, len(list.Threads))
	errs := make([]error, len(list.Threads))
	var wg sync.WaitGroup
	for i, ref := range list.Threads {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, err := s.call(ctx, "GET", s.gmailURL("threads/"+url.PathEscape(ref.ID)), oauthclient.Query{
				{"format", "metadata"}, {"metadataHeaders", "Subject"}, {"metadataHeaders", "From"}, {"metadataHeaders", "Date"},
			}, nil)
			if err != nil {
				errs[i] = err
				return
			}
			var t gmailThread
			if err := decodeInto(r.body, &t); err != nil {
				errs[i] = err
				return
			}
			var headers []header
			if n := len(t.Messages); n > 0 && t.Messages[n-1].Payload != nil {
				headers = t.Messages[n-1].Payload.Headers
			}
			threads[i] = threadSummary{
				ID: t.ID, Snippet: normalizeDecodedText(t.Snippet), HistoryID: nonEmpty(t.HistoryID),
				MessageCount: len(t.Messages), Subject: getHeader(headers, "Subject"),
				From: getHeader(headers, "From"), Date: getHeader(headers, "Date"),
			}
		}()
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return nil, err
		}
	}
	return struct {
		Query   string          `json:"query"`
		Count   int             `json:"count"`
		Threads []threadSummary `json:"threads"`
	}{query, len(threads), threads}, nil
}

func nonEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (s *session) sendEmail(ctx context.Context, args map[string]any) (any, error) {
	to, err := sanitizeHeaderValue(args["to"], "to")
	if err != nil {
		return nil, err
	}
	cc, err := sanitizeHeaderValue(args["cc"], "cc")
	if err != nil {
		return nil, err
	}
	bcc, err := sanitizeHeaderValue(args["bcc"], "bcc")
	if err != nil {
		return nil, err
	}
	subject, err := sanitizeHeaderValue(args["subject"], "subject")
	if err != nil {
		return nil, err
	}
	lines := []string{"To: " + to}
	if cc != "" {
		lines = append(lines, "Cc: "+cc)
	}
	if bcc != "" {
		lines = append(lines, "Bcc: "+bcc)
	}
	lines = append(lines, "Subject: "+encodeHeaderWords(subject), "Content-Type: text/plain; charset=utf-8", "MIME-Version: 1.0", "", textOf(args["body_text"]))
	body := map[string]any{"raw": stringToBase64URL(strings.Join(lines, "\r\n"))}
	if integrations.Truthy(args["thread_id"]) {
		body["threadId"] = integrations.Str(args["thread_id"])
	}
	res, err := s.call(ctx, "POST", s.gmailURL("messages/send"), nil, body)
	if err != nil {
		return nil, err
	}
	var sent struct {
		ID       string   `json:"id"`
		ThreadID string   `json:"threadId"`
		LabelIDs []string `json:"labelIds"`
	}
	if err := decodeInto(res.body, &sent); err != nil {
		return nil, err
	}
	if sent.LabelIDs == nil {
		sent.LabelIDs = []string{}
	}
	return struct {
		ID       *string  `json:"id"`
		ThreadID *string  `json:"threadId"`
		LabelIDs []string `json:"labelIds"`
	}{nonEmpty(sent.ID), nonEmpty(sent.ThreadID), sent.LabelIDs}, nil
}

func (s *session) modifyThreadLabels(ctx context.Context, args map[string]any) (any, error) {
	add, err := s.resolveLabelIDs(ctx, coerceStringList(args["add_label_names"]))
	if err != nil {
		return nil, err
	}
	removeNames := coerceStringList(args["remove_label_names"])
	if args["archive"] == true {
		hasInbox := false
		for _, n := range removeNames {
			hasInbox = hasInbox || strings.EqualFold(n, "INBOX")
		}
		if !hasInbox {
			removeNames = append(removeNames, "INBOX")
		}
	}
	remove, err := s.resolveLabelIDs(ctx, removeNames)
	if err != nil {
		return nil, err
	}
	threadID := textOf(args["thread_id"])
	res, err := s.call(ctx, "POST", s.gmailURL("threads/"+url.PathEscape(threadID)+"/modify"), nil,
		map[string]any{"addLabelIds": add, "removeLabelIds": remove})
	if err != nil {
		return nil, err
	}
	var t gmailThread
	if err := decodeInto(res.body, &t); err != nil {
		return nil, err
	}
	return struct {
		ID        string   `json:"id"`
		HistoryID *string  `json:"historyId"`
		Added     []string `json:"added"`
		Removed   []string `json:"removed"`
	}{orDefault(t.ID, threadID), nonEmpty(t.HistoryID), add, remove}, nil
}

var errBadJSON = errors.New("Google returned an unreadable answer.")

func decodeInto(body []byte, out any) error {
	if err := jsonUnmarshal(body, out); err != nil {
		return errBadJSON
	}
	return nil
}
