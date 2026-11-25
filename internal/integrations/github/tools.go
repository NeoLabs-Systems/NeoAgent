package github

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// toolRun is one tool call against the GitHub API.
type toolRun struct {
	p     *provider
	ctx   context.Context
	creds oauthclient.Credentials
	args  map[string]any
}

func (t *toolRun) get(path string, query oauthclient.Query) (any, error) {
	return t.p.request(t.ctx, t.creds, request{path: path, query: query})
}

func (t *toolRun) send(method, path string, body any) (any, error) {
	return t.p.request(t.ctx, t.creds, request{method: method, path: path, body: body})
}

// optional adds the argument to query when it is set.
func (t *toolRun) optional(query oauthclient.Query, key, arg string) oauthclient.Query {
	if v := t.args[arg]; integrations.Truthy(v) {
		return append(query, [2]string{key, integrations.Str(v)})
	}
	return query
}

// setIf puts the argument into body as text when it is set.
func (t *toolRun) setIf(body map[string]any, key, arg string) {
	if v := t.args[arg]; integrations.Truthy(v) {
		body[key] = integrations.Str(v)
	}
}

// pages collects list answers page by page until max items or a short page.
func (t *toolRun) pages(path string, query oauthclient.Query, max int, items func(any) []json.RawMessage) ([]json.RawMessage, error) {
	per := max
	if per > 100 {
		per = 100
	}
	var all []json.RawMessage
	for page := 1; len(all) < max; page++ {
		q := oauthclient.Query{{"per_page", fmt.Sprint(per)}}
		q = append(append(q, query...), [2]string{"page", fmt.Sprint(page)})
		res, err := t.get(path, q)
		if err != nil {
			return nil, err
		}
		list := items(res)
		if len(list) == 0 {
			break
		}
		all = append(all, list...)
		if len(list) < per {
			break
		}
	}
	if len(all) > max {
		all = all[:max]
	}
	if all == nil {
		all = []json.RawMessage{}
	}
	return all, nil
}

func rawList(v any) []json.RawMessage {
	raw, ok := v.(json.RawMessage)
	if !ok {
		return nil
	}
	var list []json.RawMessage
	if json.Unmarshal(raw, &list) != nil {
		return nil
	}
	return list
}

func runsOf(v any) []json.RawMessage {
	raw, ok := v.(json.RawMessage)
	if !ok {
		return nil
	}
	var holder struct {
		Runs []json.RawMessage `json:"workflow_runs"`
	}
	if json.Unmarshal(raw, &holder) != nil {
		return nil
	}
	return holder.Runs
}

func repoPath(or ownerRepo, rest string) string {
	return "/repos/" + or.owner + "/" + or.repo + rest
}

func (t *toolRun) run(name string) (any, error) {
	args := t.args
	var or ownerRepo
	if name != "github_get_auth_user" && name != "github_search_repos" && name != "github_list_user_repos" && name != "github_api_request" {
		var err error
		if or, err = parseOwnerRepoArg(args); err != nil {
			return nil, err
		}
	}
	switch name {
	case "github_get_auth_user":
		return t.get("/user", nil)

	case "github_search_repos":
		return t.get("/search/repositories", oauthclient.Query{{"q", textOf(args["query"])}, {"per_page", perPage(args["max_results"], 10)}})

	case "github_get_repo":
		return t.get(repoPath(or, ""), nil)

	case "github_list_issues":
		query := oauthclient.Query{{"per_page", perPage(args["max_results"], 30)}}
		for _, k := range []string{"state", "labels", "assignee", "creator", "sort", "direction"} {
			query = t.optional(query, k, k)
		}
		return t.get(repoPath(or, "/issues"), query)

	case "github_get_issue":
		return t.get(repoPath(or, "/issues/"+number(args["issue_number"])), nil)

	case "github_create_issue":
		body := map[string]any{"title": textOf(args["title"]), "labels": commaList(args["labels"]), "assignees": commaList(args["assignees"])}
		t.setIf(body, "body", "body")
		return t.send("POST", repoPath(or, "/issues"), body)

	case "github_update_issue":
		body := map[string]any{}
		t.setIf(body, "title", "title")
		if has(args, "body") {
			body["body"] = integrations.Str(args["body"])
		}
		if integrations.Truthy(args["state"]) {
			body["state"] = args["state"]
		}
		if integrations.Truthy(args["labels"]) {
			body["labels"] = commaList(args["labels"])
		}
		if integrations.Truthy(args["assignees"]) {
			body["assignees"] = commaList(args["assignees"])
		}
		return t.send("PATCH", repoPath(or, "/issues/"+number(args["issue_number"])), body)

	case "github_add_issue_labels":
		return t.send("POST", repoPath(or, "/issues/"+number(args["issue_number"])+"/labels"), map[string]any{"labels": commaList(args["labels"])})

	case "github_add_issue_assignees":
		return t.send("POST", repoPath(or, "/issues/"+number(args["issue_number"])+"/assignees"), map[string]any{"assignees": commaList(args["assignees"])})

	case "github_list_prs":
		query := oauthclient.Query{{"per_page", perPage(args["max_results"], 30)}}
		for _, k := range []string{"state", "sort", "direction"} {
			query = t.optional(query, k, k)
		}
		return t.get(repoPath(or, "/pulls"), query)

	case "github_get_pr":
		return t.get(repoPath(or, "/pulls/"+number(args["pr_number"])), nil)

	case "github_create_pr":
		body := map[string]any{
			"title": textOf(args["title"]), "head": textOf(args["head"]), "base": orDefault(textOf(args["base"]), "main"),
			"draft": args["draft"] == true, "maintainer_can_modify": args["maintainer_can_modify"] == true,
		}
		t.setIf(body, "body", "body")
		return t.send("POST", repoPath(or, "/pulls"), body)

	case "github_update_pr":
		body := map[string]any{}
		t.setIf(body, "title", "title")
		if has(args, "body") {
			body["body"] = integrations.Str(args["body"])
		}
		if integrations.Truthy(args["state"]) {
			body["state"] = args["state"]
		}
		return t.send("PATCH", repoPath(or, "/pulls/"+number(args["pr_number"])), body)

	case "github_merge_pr":
		body := map[string]any{"merge_method": integrations.Or(args["merge_method"], "squash")}
		t.setIf(body, "commit_title", "commit_title")
		t.setIf(body, "commit_message", "commit_message")
		return t.send("PUT", repoPath(or, "/pulls/"+number(args["pr_number"])+"/merge"), body)

	case "github_list_commits":
		query := oauthclient.Query{{"per_page", perPage(args["max_results"], 30)}}
		query = t.optional(query, "sha", "sha")
		query = t.optional(query, "path", "path")
		return t.get(repoPath(or, "/commits"), query)

	case "github_list_branches":
		var query oauthclient.Query
		if integrations.Truthy(args["max_results"]) {
			per := 30.0
			if n, ok := integrations.JSNumber(args["max_results"]); ok && n != 0 {
				per = n
			}
			query = oauthclient.Query{{"per_page", numberText(minFloat(per, 100))}}
		}
		return t.get(repoPath(or, "/branches"), query)

	case "github_get_branch":
		return t.get(repoPath(or, "/branches/"+url.PathEscape(textOf(args["branch"]))), nil)

	case "github_list_collaborators":
		var query oauthclient.Query
		query = t.optional(query, "affiliation", "affiliation")
		list, err := t.pages(repoPath(or, "/collaborators"), query, parsePositiveInt(args["max_results"], 30), rawList)
		if err != nil {
			return nil, err
		}
		return list, nil

	case "github_get_content":
		var query oauthclient.Query
		query = t.optional(query, "ref", "ref")
		res, err := t.get(repoPath(or, "/contents/"+textOf(args["path"])), query)
		if err != nil {
			return nil, err
		}
		return decodeContent(res), nil

	case "github_create_or_update_file":
		body := map[string]any{"message": textOf(args["message"]), "content": encodeFileContent(args)}
		t.setIf(body, "sha", "sha")
		t.setIf(body, "branch", "branch")
		return t.send("PUT", repoPath(or, "/contents/"+textOf(args["path"])), body)

	case "github_delete_file":
		body := map[string]any{"message": textOf(args["message"]), "sha": textOf(args["sha"])}
		t.setIf(body, "branch", "branch")
		return t.send("DELETE", repoPath(or, "/contents/"+textOf(args["path"])), body)

	case "github_list_workflow_runs":
		path := repoPath(or, "/actions/runs")
		if integrations.Truthy(args["workflow_id"]) {
			path = repoPath(or, "/actions/workflows/"+integrations.Str(args["workflow_id"])+"/runs")
		}
		var query oauthclient.Query
		query = t.optional(query, "branch", "branch")
		query = t.optional(query, "status", "status")
		return t.pages(path, query, parsePositiveInt(args["max_results"], 100), runsOf)

	case "github_get_workflow_run":
		return t.get(repoPath(or, "/actions/runs/"+number(args["run_id"])), nil)

	case "github_trigger_workflow":
		inputs := any(map[string]any{})
		if integrations.Truthy(args["inputs"]) {
			var parsed any
			if err := json.Unmarshal([]byte(integrations.Str(args["inputs"])), &parsed); err != nil {
				return nil, fmt.Errorf("Invalid workflow inputs JSON: %v", err)
			}
			inputs = parsed
		}
		return t.send("POST", repoPath(or, "/actions/workflows/"+integrations.Str(args["workflow_id"])+"/dispatches"),
			map[string]any{"ref": orDefault(textOf(args["ref"]), "main"), "inputs": inputs})

	case "github_list_workflows":
		return t.get(repoPath(or, "/actions/workflows"), nil)

	case "github_list_user_repos":
		path := "/user/repos"
		if integrations.Truthy(args["username"]) {
			path = "/users/" + integrations.Str(args["username"]) + "/repos"
		}
		var query oauthclient.Query
		for _, k := range []string{"visibility", "sort", "direction"} {
			query = t.optional(query, k, k)
		}
		return t.pages(path, query, parsePositiveInt(args["max_results"], 100), rawList)

	case "github_api_request":
		return t.apiRequest()
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}

func minFloat(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

func has(args map[string]any, key string) bool {
	_, ok := args[key]
	return ok
}

// decodeContent turns a base64 file body into text, as the tool always did.
func decodeContent(res any) any {
	raw, ok := res.(json.RawMessage)
	if !ok {
		return res
	}
	var obj map[string]json.RawMessage
	if json.Unmarshal(raw, &obj) != nil {
		return res
	}
	var encoding, content string
	if json.Unmarshal(obj["encoding"], &encoding) != nil || encoding != "base64" || json.Unmarshal(obj["content"], &content) != nil {
		return res
	}
	plain, err := decodeBase64Lenient(strings.ReplaceAll(content, "\n", ""))
	if err != nil {
		return res
	}
	// The member order of the answer is kept; only the two values change.
	var out strings.Builder
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	dec.Token()
	out.WriteByte('{')
	first := true
	for dec.More() {
		keyTok, _ := dec.Token()
		key := keyTok.(string)
		var value json.RawMessage
		dec.Decode(&value)
		switch key {
		case "content":
			value, _ = oauthclient.MarshalJS(plain)
		case "encoding":
			value, _ = oauthclient.MarshalJS("utf8")
		}
		if !first {
			out.WriteByte(',')
		}
		first = false
		k, _ := oauthclient.MarshalJS(key)
		out.Write(k)
		out.WriteByte(':')
		out.Write(value)
	}
	out.WriteByte('}')
	return json.RawMessage(out.String())
}

var errNoPath = errors.New("github_api_request requires path, endpoint, or url.")
