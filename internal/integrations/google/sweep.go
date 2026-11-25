package google

import (
	"context"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

// The past year's important mail: threads the user marked, Gmail ranked
// important, or the user replied to.
const (
	gmailSweepQuery       = "newer_than:12m (is:important OR is:starred OR in:sent) -category:promotions -category:social -category:updates -category:forums"
	gmailSweepThreadLimit = 100
	gmailSweepMaxPages    = 20
	gmailSweepConcurrency = 4
	gmailSweepBodyChars   = 2000
)

// sweep reads Gmail threads for memory. Threads already in memory are
// skipped, so a repeat sweep picks up the next ones instead.
func (p *provider) sweep(ctx context.Context, tc *integrations.ToolContext, req integrations.SweepInput) ([]any, error) {
	if tc.Connection.AppKey != "gmail" || !contains(req.SourceTypes, "email") {
		return []any{}, nil
	}
	s := &session{p: p, tc: tc}
	var mu sync.Mutex // the session refreshes credentials in place
	collectedAt := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")

	var threadIDs []string
	seen := map[string]bool{}
	pageToken := ""
	for page := 0; page < gmailSweepMaxPages; page++ {
		q := oauthclient.Query{{"q", gmailSweepQuery}, {"maxResults", "100"}}
		if pageToken != "" {
			q = append(q, [2]string{"pageToken", pageToken})
		}
		res, err := s.call(ctx, "GET", s.gmailURL("threads"), q, nil)
		if err != nil {
			return nil, err
		}
		var list struct {
			Threads []struct {
				ID string `json:"id"`
			} `json:"threads"`
			NextPageToken string `json:"nextPageToken"`
		}
		_ = decodeInto(res.body, &list)
		for _, t := range list.Threads {
			if t.ID != "" && !req.SkipObjectIDs[t.ID] && !seen[t.ID] {
				seen[t.ID] = true
				threadIDs = append(threadIDs, t.ID)
			}
		}
		pageToken = list.NextPageToken
		if pageToken == "" || len(threadIDs) >= gmailSweepThreadLimit {
			break
		}
	}
	if len(threadIDs) > gmailSweepThreadLimit {
		threadIDs = threadIDs[:gmailSweepThreadLimit]
	}

	total := len(threadIDs)
	progress := func(done int) {
		if req.OnProgress != nil {
			req.OnProgress(done, &total)
		}
	}
	progress(0)
	docs := make([]any, 0, total)
	queue := make(chan string, total)
	for _, id := range threadIDs {
		queue <- id
	}
	close(queue)
	read := 0
	var firstErr error
	var wg sync.WaitGroup
	for i := 0; i < gmailSweepConcurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for id := range queue {
				mu.Lock()
				res, err := s.call(ctx, "GET", s.gmailURL("threads/"+url.PathEscape(id)), oauthclient.Query{{"format", "full"}}, nil)
				read++
				progress(read)
				if err != nil {
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					return
				}
				mu.Unlock()
				var t gmailThread
				if decodeInto(res.body, &t) != nil || len(t.Messages) == 0 {
					continue
				}
				doc := threadDocument(t, collectedAt)
				mu.Lock()
				docs = append(docs, doc)
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if firstErr != nil {
		return nil, firstErr
	}
	return docs, nil
}

func threadDocument(t gmailThread, collectedAt string) map[string]any {
	messages := make([]messageSummary, 0, len(t.Messages))
	for _, m := range t.Messages {
		messages = append(messages, summarizeMessage(m))
	}
	last := messages[len(messages)-1]
	subject := strings.TrimSpace(deref(messages[0].Subject))
	if subject == "" {
		subject = strings.TrimSpace(deref(last.Subject))
	}
	if subject == "" {
		subject = "Gmail thread"
	}
	var participants, labels []string
	seenP, seenL := map[string]bool{}, map[string]bool{}
	for _, m := range messages {
		for _, v := range []*string{m.From, m.To} {
			if v != nil && *v != "" && !seenP[*v] {
				seenP[*v] = true
				participants = append(participants, *v)
			}
		}
		for _, l := range m.LabelIDs {
			if !seenL[l] {
				seenL[l] = true
				labels = append(labels, l)
			}
		}
	}
	if labels == nil {
		labels = []string{}
	}
	body := last.BodyText
	if body == "" {
		body = normalizeDecodedText(t.Snippet)
	}
	if r := []rune(body); len(r) > gmailSweepBodyChars {
		body = string(r[:gmailSweepBodyChars])
	}
	var lines []string
	add := func(s string) {
		if s != "" {
			lines = append(lines, s)
		}
	}
	add(subject)
	if len(participants) > 0 {
		add("Participants: " + strings.Join(participants, ", "))
	}
	if last.Date != nil && *last.Date != "" {
		add("Date: " + *last.Date)
	}
	add("Messages: " + itoa(len(messages)))
	add(body)
	salience := 7
	if seenL["IMPORTANT"] || seenL["STARRED"] {
		salience = 8
	}
	summary := normalizeDecodedText(t.Snippet)
	if summary == "" {
		summary = subject
	}
	timestamp := collectedAt
	if last.InternalDate != nil && *last.InternalDate != "" {
		timestamp = *last.InternalDate
	} else if last.Date != nil && *last.Date != "" {
		timestamp = *last.Date
	}
	return map[string]any{
		"externalObjectId": t.ID, "sourceType": "email", "normalizedType": "email", "title": subject,
		"content": strings.Join(lines, "\n"), "summary": summary, "sourceTimestamp": timestamp, "salience": salience,
		"payload": map[string]any{"id": t.ID, "labelIds": labels, "messageCount": len(messages)},
	}
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}
