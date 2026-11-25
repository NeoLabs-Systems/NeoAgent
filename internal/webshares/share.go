package webshares

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// Guests reaches the agent inside a user's running computer.
type Guests interface {
	// RunningGuest is the guest agent of a running computer, never booting one.
	RunningGuest(userKey string) (baseURL, token string, ok bool)
}

const probeTimeout = 5 * time.Second

// PublicPageRules is what a published page may contain.
const PublicPageRules = "A shared page is public and appears under this server's name, so it must stay clean: " +
	"no profanity or hard swearing, no slurs, no racist, sexist or otherwise hateful content, no harassment of anyone, " +
	"no sexual content and nothing illegal, also not in text the page generates. This holds even when the user asks for it: " +
	"then do not share the page, and tell the user why."

const pathNote = "The page is served under that path, not at a domain root: links, scripts and styles must use relative paths " +
	"(or the base path from the X-Forwarded-Prefix header). It runs sandboxed, so it gets no cookies or local storage. " +
	"It is reachable only while your computer and the app on it run. " +
	PublicPageRules + " If anything on it breaks that, stop sharing it now."

// Sharer is the share_web_page tool.
type Sharer struct {
	Store  *Store
	Guests Guests
	Client *http.Client
}

func userKey(id int64) string { return strconv.FormatInt(id, 10) }

// probe reports whether anything answers on the port inside the computer.
func (s *Sharer) probe(ctx context.Context, baseURL, token string, port int) bool {
	ctx, cancel := context.WithTimeout(ctx, probeTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(baseURL, "/")+"/proxy/"+strconv.Itoa(port)+"/", nil)
	if err != nil {
		return false
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", "text/html,*/*")
	client := s.Client
	if client == nil {
		client = &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	}
	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	resp.Body.Close()
	return !(resp.StatusCode == http.StatusBadGateway && resp.Header.Get("X-Neoagent-Proxy") != "")
}

func refusal(msg string) map[string]any { return map[string]any{"error": msg} }

// Share publishes the app on a port of the user's computer.
func (s *Sharer) Share(ctx context.Context, userID int64, agentID string, name, port any, baseURL string) (map[string]any, error) {
	if !s.Store.Enabled(ctx, userID) {
		return refusal("Web page sharing is turned off in settings."), nil
	}
	valid := ValidatePort(port)
	if valid == 0 {
		return refusal("port must be the port the app listens on inside your computer (1-65535)."), nil
	}
	nameText := jsString(name)
	if strings.TrimSpace(nameText) == "" {
		return refusal("name is required."), nil
	}
	base, token, ok := "", "", false
	if s.Guests != nil {
		base, token, ok = s.Guests.RunningGuest(userKey(userID))
	}
	if !ok {
		return refusal("Your computer is not running, so there is nothing to share. Start the app on it first."), nil
	}
	if !s.probe(ctx, base, token, valid) {
		return refusal(fmt.Sprintf("Nothing answers on port %d inside your computer. Start the app there (listening on localhost or 0.0.0.0), then share it.", valid)), nil
	}
	share, replaced, err := s.Store.Save(ctx, userID, agentID, nameText, valid, baseURL)
	var refused *UserError
	if errors.As(err, &refused) {
		return refusal(refused.Msg), nil
	}
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"shared": true, "id": share.ID, "name": share.Name, "slug": share.Slug, "port": share.Port, "url": share.URL,
		"created_at": share.CreatedAt, "updated_at": share.UpdatedAt, "replaced_existing": replaced, "note": pathNote,
	}, nil
}

// Stop stops a share by id, slug or name.
func (s *Sharer) Stop(ctx context.Context, userID int64, ref any) (map[string]any, error) {
	refText := jsString(ref)
	removed, err := s.Store.Remove(ctx, userID, refText)
	if err != nil {
		return nil, err
	}
	if removed {
		return map[string]any{"stopped": true}, nil
	}
	list, err := s.Store.List(ctx, userID, "")
	if err != nil {
		return nil, err
	}
	names := []string{}
	for _, sh := range list {
		names = append(names, sh.Name)
	}
	return map[string]any{"error": `No shared page matches "` + refText + `".`, "shared_pages": names}, nil
}

// jsString is String(v || ”).
func jsString(v any) string {
	switch x := v.(type) {
	case nil:
		return ""
	case string:
		return x
	case float64:
		if x == 0 {
			return ""
		}
		return strconv.FormatFloat(x, 'f', -1, 64)
	case bool:
		if !x {
			return ""
		}
		return "true"
	}
	return fmt.Sprint(v)
}
