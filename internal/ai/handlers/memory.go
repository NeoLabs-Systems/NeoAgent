package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"golang.org/x/text/unicode/norm"
)

var memoryHandlers = map[string]handler{
	"memory_save":        memorySave,
	"memory_recall":      memoryRecall,
	"memory_list":        memoryList,
	"memory_forget":      memoryForget,
	"session_search":     sessionSearch,
	"memory_update_core": memoryUpdateCore,
	"memory_write":       memoryWrite,
	"memory_read":        memoryRead,
}

var unicodeSpace = regexp.MustCompile(`\s+`)

// statementInText: exact, complete authored text is evidence of what was
// stated (memory/provenance.js).
func statementInText(text, statement string) bool {
	normalize := func(v string) string {
		return strings.TrimSpace(unicodeSpace.ReplaceAllString(norm.NFC.String(v), " "))
	}
	return normalize(statement) != "" && normalize(text) == normalize(statement)
}

func ownerVerification(content string) dyn.Map {
	sum := sha256.Sum256([]byte(strings.TrimSpace(content)))
	return dyn.Map{"source": "owner", "digest": hex.EncodeToString(sum[:])}
}

// saveProvenance is what the model declares about a fact it saves. It can only
// claim the user said something the run's record of the user's words backs.
func saveProvenance(source any, content string, run *Run) MemorySave {
	if run.Tainted {
		return MemorySave{Metadata: dyn.Map{"trustLevel": "external_source"}}
	}
	if source == "inference" || source == "tool_observed" {
		days := 30.0
		return MemorySave{Metadata: dyn.Map{"trustLevel": "model_inference", "relation": "derives"}, Confidence: 0.45, StaleAfterDays: &days}
	}
	if source == "user_stated" {
		for _, text := range run.OwnerStatements {
			if statementInText(text, content) {
				return MemorySave{Metadata: dyn.Map{"trustLevel": "user_stated", "verification": ownerVerification(content)}}
			}
		}
	}
	return MemorySave{Metadata: dyn.Map{"trustLevel": "agent_statement", "relation": "derives"}, Confidence: 0.45}
}

func (c *call) memory() (Memory, error) {
	if c.b.d.Memory == nil {
		return nil, errorf("Memory service is unavailable.")
	}
	return c.b.d.Memory, nil
}

func memorySave(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	var content string
	if s, ok := c.args["content"].(string); ok {
		content = s
	} else {
		content = str(c.args["value"])
		if c.args["value"] == nil {
			content = ""
		}
	}
	if length := lenUTF16(strings.TrimSpace(content)); length > mm.MaxMemoryChars() {
		return errResult(fmt.Sprintf("Memory is %d characters; the limit is %d. Rewrite it as one shorter fact, or split it into several facts.", length, mm.MaxMemoryChars())), nil
	}
	provenance := saveProvenance(c.args["source"], content, c.run)
	if !c.run.Tainted && provenance.Metadata["trustLevel"] == "user_stated" {
		if list, ok := c.args["replaces"].([]any); ok {
			ids := make([]string, 0, len(list))
			for _, id := range list {
				ids = append(ids, dyn.String(id))
			}
			owned, err := mm.OwnedMemoryIDs(ctx, c.run.UserID, c.run.AgentID, ids)
			if err != nil {
				return nil, err
			}
			provenance.Replaces = owned
		}
	}
	category := orString(c.args["category"], "episodic")
	importance := jsNumber(c.args["importance"])
	if !dyn.Truthy(c.args["importance"]) || math.IsNaN(importance) {
		importance = 5
	}
	id, err := mm.SaveMemory(ctx, c.run.UserID, c.run.AgentID, content, category, importance, provenance)
	if err != nil {
		return nil, err
	}
	if id == "" {
		return dyn.Ordered{
			{Key: "success", Value: true},
			{Key: "skipped", Value: true},
			{Key: "message", Value: "Skipped saving transient operational detail or empty content to memory"},
		}, nil
	}
	similar, err := mm.FindSimilar(ctx, c.run.UserID, c.run.AgentID, content, id)
	if err != nil {
		return nil, err
	}
	if len(similar) > 0 {
		return dyn.Ordered{
			{Key: "success", Value: true},
			{Key: "id", Value: id},
			{Key: "message", Value: "Saved to memory. These read alike; if the new fact replaces one, save it again with its id in replaces."},
			{Key: "similar", Value: similar},
		}, nil
	}
	return dyn.Ordered{{Key: "success", Value: true}, {Key: "id", Value: id}, {Key: "message", Value: "Saved to memory"}}, nil
}

func memoryRecall(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	validAt := ""
	if s := str(c.args["as_of"]); s != "" {
		if t, ok := parseJSDate(s); ok {
			validAt = t.UTC().Format("2006-01-02T15:04:05.000Z")
		}
	}
	limit := jsInt(c.args["limit"], 6)
	results, err := mm.Recall(ctx, c.run.UserID, c.run.AgentID, str(c.args["query"]), limit, validAt, c.args["include_history"] == true)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return dyn.Ordered{{Key: "results", Value: []any{}}, {Key: "message", Value: "Nothing found"}}, nil
	}
	return dyn.Map{"results": results}, nil
}

func memoryList(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	offset := int(math.Max(0, math.Floor(nanToZero(jsNumber(c.args["offset"])))))
	limit := int(math.Max(1, math.Min(40, math.Floor(orNumber(jsNumber(c.args["limit"]), 30)))))
	page, err := mm.List(ctx, c.run.UserID, c.run.AgentID, offset, limit+1)
	if err != nil {
		return nil, err
	}
	results := []any{}
	for i, m := range page {
		if i == limit {
			break
		}
		results = append(results, dyn.Ordered{
			{Key: "id", Value: m["id"]},
			{Key: "content", Value: m["content"]},
			{Key: "category", Value: m["category"]},
			{Key: "importance", Value: m["importance"]},
			{Key: "updated_at", Value: m["updated_at"]},
		})
	}
	var next any
	if len(page) > limit {
		next = offset + limit
	}
	return dyn.Ordered{{Key: "results", Value: results}, {Key: "next_offset", Value: next}}, nil
}

func nanToZero(n float64) float64 {
	if math.IsNaN(n) {
		return 0
	}
	return n
}

// orNumber is `Number(v) || fallback`.
func orNumber(n, fallback float64) float64 {
	if math.IsNaN(n) || n == 0 {
		return fallback
	}
	return n
}

func memoryForget(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	ids, err := mm.OwnedMemoryIDs(ctx, c.run.UserID, c.run.AgentID, stringList(c.args["ids"]))
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return errResult("None of these ids is a memory of this agent."), nil
	}
	archived, err := mm.Archive(ctx, c.run.UserID, ids)
	if err != nil {
		return nil, err
	}
	return dyn.Ordered{{Key: "success", Value: true}, {Key: "archived", Value: archived}, {Key: "message", Value: fmt.Sprintf("Archived %d memories", archived)}}, nil
}

func sessionSearch(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	results, err := mm.SearchConversations(ctx, c.run.UserID, c.run.AgentID, str(c.args["query"]), jsInt(c.args["limit"], 6))
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return dyn.Ordered{{Key: "results", Value: []any{}}, {Key: "message", Value: "No matching sessions found"}}, nil
	}
	return dyn.Map{"results": results}, nil
}

func memoryUpdateCore(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	key, _ := c.args["key"].(string)
	if !contains(mm.CoreKeys(), key) {
		return errResult("Core memory key must be one of: " + strings.Join(mm.CoreKeys(), ", ") + "."), nil
	}
	value, ok := c.args["value"].(string)
	if !ok || strings.TrimSpace(value) == "" {
		return errResult("Core memory value must be a non-empty string."), nil
	}
	if err := mm.UpdateCore(ctx, c.run.UserID, c.run.AgentID, key, value); err != nil {
		return nil, err
	}
	return dyn.Ordered{{Key: "success", Value: true}, {Key: "key", Value: key}, {Key: "message", Value: "Core memory updated"}}, nil
}

// memoryWrite and memoryRead are the generic daily-log and API-key targets.
func memoryWrite(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	target := c.args["target"]
	switch target {
	case "daily":
		line, err := mm.AppendDailyLog(c.run.UserID, str(c.args["content"]))
		if err != nil {
			return nil, err
		}
		return dyn.Ordered{{Key: "line", Value: line}, {Key: "target", Value: "daily"}}, nil
	case "api_keys":
		parsed, ok := dyn.Parse(str(c.args["content"]))
		if !ok {
			return errResult("Invalid JSON for api_keys"), nil
		}
		if m, isMap := parsed.(dyn.Map); isMap {
			for _, k := range dyn.SortedKeys(m) {
				if err := mm.SetAPIKey(c.run.UserID, k, dyn.String(m[k])); err != nil {
					return nil, err
				}
			}
		}
		return dyn.Ordered{{Key: "success", Value: true}, {Key: "target", Value: "api_keys"}}, nil
	}
	return errResult("Unknown target: " + dyn.String(target)), nil
}

func memoryRead(ctx context.Context, c *call) (any, error) {
	mm, err := c.memory()
	if err != nil {
		return nil, err
	}
	target := c.args["target"]
	switch target {
	case "daily":
		var date *time.Time
		if dyn.Truthy(c.args["date"]) {
			if t, ok := parseJSDate(dyn.String(c.args["date"])); ok {
				date = &t
			}
		}
		content, err := mm.ReadDailyLog(c.run.UserID, date)
		if err != nil {
			return nil, err
		}
		return dyn.Map{"content": content}, nil
	case "all_daily":
		logs, err := mm.ListDailyLogs(c.run.UserID, 7)
		if err != nil {
			return nil, err
		}
		return dyn.Map{"logs": logs}, nil
	case "api_keys":
		names, err := mm.APIKeyNames(c.run.UserID)
		if err != nil {
			return nil, err
		}
		if names == nil {
			names = []string{}
		}
		return dyn.Map{"keys": names}, nil
	}
	return errResult("Unknown target: " + dyn.String(target)), nil
}
