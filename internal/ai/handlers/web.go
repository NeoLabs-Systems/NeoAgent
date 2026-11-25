package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var webHandlers = map[string]handler{
	"web_search":   webSearch,
	"http_request": httpRequest,
}

const (
	braveSearchURL     = "https://api.search.brave.com/res/v1/web/search"
	braveTimeout       = 20 * time.Second
	braveMaxBodyBytes  = 2 * 1024 * 1024
	braveDetailsPrefix = 1000
)

func searchLimit(v any) int {
	n := jsNumber(v)
	if math.IsNaN(n) || n == 0 {
		n = 5
	}
	return int(math.Max(1, math.Min(n, 10)))
}

func webSearch(ctx context.Context, c *call) (any, error) {
	limit := searchLimit(c.args["count"])
	query := c.args["query"]
	if c.b.d.Router != nil {
		results, ok, err := c.b.d.Router.SearchWeb(ctx, c.run.UserID, c.run.AgentID, str(query), limit, c.args["freshness"])
		if ok || err != nil {
			if err != nil {
				return failure(ctx, err)
			}
			if results == nil {
				results = []any{}
			}
			return dyn.Ordered{{Key: "query", Value: query}, {Key: "count", Value: len(results)}, {Key: "results", Value: results}}, nil
		}
	}
	key := c.b.d.BraveSearchKey
	if key == "" {
		return errResult("BRAVE_SEARCH_API_KEY is not configured"), nil
	}
	params := []string{
		"q=" + url.QueryEscape(str(query)),
		fmt.Sprintf("count=%d", limit),
		"text_decorations=false",
		"result_filter=web",
	}
	if dyn.Truthy(c.args["country"]) {
		params = append(params, "country="+url.QueryEscape(strings.ToUpper(dyn.String(c.args["country"]))))
	}
	if dyn.Truthy(c.args["search_lang"]) {
		params = append(params, "search_lang="+url.QueryEscape(strings.ToLower(dyn.String(c.args["search_lang"]))))
	}
	if dyn.Truthy(c.args["freshness"]) {
		params = append(params, "freshness="+url.QueryEscape(dyn.String(c.args["freshness"])))
	}
	endpoint := c.b.d.BraveSearchURL
	if endpoint == "" {
		endpoint = braveSearchURL
	}
	reqCtx, cancel := context.WithTimeout(ctx, braveTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, endpoint+"?"+strings.Join(params, "&"), nil)
	if err != nil {
		return errResult(err.Error()), nil
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("X-Subscription-Token", key)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		if errors.Is(reqCtx.Err(), context.DeadlineExceeded) {
			return errResult(fmt.Sprintf("Brave Search API request timed out after %dms", braveTimeout.Milliseconds())), nil
		}
		return errResult(err.Error()), nil
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, braveMaxBodyBytes+1))
	if err != nil {
		return failure(ctx, err)
	}
	if len(body) > braveMaxBodyBytes {
		return errResult("Brave Search response exceeded the 2097152-byte limit"), nil
	}
	text := string(body)
	var data any
	if json.Unmarshal(body, &data) != nil {
		data = nil
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		var details any = data
		if !dyn.Truthy(data) {
			details = sliceUTF16(text, braveDetailsPrefix)
		}
		return dyn.Ordered{
			{Key: "error", Value: fmt.Sprintf("Brave Search API request failed with status %d", resp.StatusCode)},
			{Key: "details", Value: details},
		}, nil
	}
	raw := dyn.List(dyn.Get(data, "web", "results"))
	results := []any{}
	for i, item := range raw {
		if i >= limit {
			break
		}
		profile := dyn.Get(item, "profile", "long_name")
		if !dyn.Truthy(profile) {
			profile = dyn.Get(item, "profile", "name")
		}
		results = append(results, dyn.Ordered{
			{Key: "rank", Value: i + 1},
			{Key: "title", Value: orString(dyn.Get(item, "title"), "")},
			{Key: "url", Value: orString(dyn.Get(item, "url"), "")},
			{Key: "description", Value: orString(dyn.Get(item, "description"), "")},
			{Key: "age", Value: truthyOrNil(dyn.Get(item, "age"))},
			{Key: "language", Value: truthyOrNil(dyn.Get(item, "language"))},
			{Key: "profile", Value: truthyOrNil(profile)},
		})
	}
	return dyn.Ordered{{Key: "query", Value: query}, {Key: "count", Value: len(results)}, {Key: "results", Value: results}}, nil
}

// truthyOrNil is `value || null`.
func truthyOrNil(v any) any {
	if dyn.Truthy(v) {
		return v
	}
	return nil
}

func httpRequest(ctx context.Context, c *call) (any, error) {
	h := c.b.d.HTTP
	if h == nil {
		h = &HTTPRequester{}
	}
	result, err := h.Do(ctx, c.args)
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}
