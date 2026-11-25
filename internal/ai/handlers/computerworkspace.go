package handlers

import (
	"context"
	"encoding/json"
	"math"
	"net/url"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

// ComputerWorkspace is the file service of the user's computer: every call goes to the computer's
// own workspace through its agent. Resolve maps a path for tools that read
// files on this server (media, SynthID).
type ComputerWorkspace struct {
	Request func(ctx context.Context, userID int64, method, path string, body any, deviceTarget string) (dyn.Map, error)
	Resolve func(userID int64, path, label string) (string, error)
}

var _ Workspace = (*ComputerWorkspace)(nil)

const workspaceReadCap = 20000

func (w *ComputerWorkspace) readContent(ctx context.Context, r FileRequest, path any) (dyn.Map, error) {
	result, err := w.Request(ctx, r.UserID, "GET", "/workspace/files/content?path="+url.QueryEscape(str(path)), nil, r.DeviceTarget)
	if err != nil {
		return nil, err
	}
	out := dyn.Map{}
	for k, v := range result {
		out[k] = v
	}
	out["content"] = guestproto.CoerceWritableText(result["content"])
	return out, nil
}

func pathOrNil(v any) any {
	if dyn.Truthy(v) {
		return v
	}
	return nil
}

func toGuestPath(v any) string { return guestproto.ToWorkspacePath(str(v)) }

func (w *ComputerWorkspace) ReadFile(ctx context.Context, r FileRequest) (dyn.Map, error) {
	result, err := w.readContent(ctx, r, r.Args["path"])
	if err != nil {
		return dyn.Map{"error": err.Error(), "path": pathOrNil(r.Args["path"])}, nil
	}
	content := dyn.String(result["content"])
	lines := strings.Split(content, "\n")
	start, end := 1.0, float64(len(lines))
	if v, ok := r.Args["start_line"]; ok && v != nil {
		start = jsNumber(v)
	}
	if v, ok := r.Args["end_line"]; ok && v != nil {
		end = jsNumber(v)
	}
	if !isInteger(start) || start < 1 || !isInteger(end) || end < start {
		return dyn.Map{"error": "Invalid line range.", "path": result["path"]}, nil
	}
	from, to := min(int(start)-1, len(lines)), min(int(end), len(lines))
	text := strings.Join(lines[from:to], "\n")
	if lenUTF16(text) > workspaceReadCap {
		text = sliceUTF16(text, workspaceReadCap) + "\n...[truncated]"
	}
	size := jsNumber(result["size"])
	if math.IsNaN(size) || size == 0 {
		size = float64(len(strings.Join(lines[from:to], "\n")))
	}
	return dyn.Map{
		"path":       toGuestPath(result["path"]),
		"content":    text,
		"byteSize":   size,
		"totalLines": len(lines),
		"rangeShown": []any{start, math.Min(end, float64(len(lines)))},
	}, nil
}

func (w *ComputerWorkspace) write(ctx context.Context, r FileRequest, path any, content string) (dyn.Map, error) {
	result, err := w.Request(ctx, r.UserID, "PUT", "/workspace/files/content", dyn.Map{"path": path, "content": content}, r.DeviceTarget)
	if err != nil {
		return dyn.Map{"success": false, "error": err.Error(), "path": pathOrNil(path)}, nil
	}
	out := dyn.Map{}
	for k, v := range result {
		out[k] = v
	}
	out["path"] = toGuestPath(result["path"])
	return out, nil
}

func (w *ComputerWorkspace) WriteFile(ctx context.Context, r FileRequest) (dyn.Map, error) {
	content := guestproto.CoerceWritableText(r.Args["content"])
	if strings.ToLower(str(r.Args["mode"])) == "append" {
		current, err := w.readContent(ctx, r, r.Args["path"])
		if err != nil {
			return dyn.Map{"success": false, "error": err.Error(), "path": pathOrNil(r.Args["path"])}, nil
		}
		content = dyn.String(current["content"]) + content
	}
	return w.write(ctx, r, r.Args["path"], content)
}

func (w *ComputerWorkspace) EditFile(ctx context.Context, r FileRequest) (dyn.Map, error) {
	current, err := w.readContent(ctx, r, r.Args["path"])
	if err != nil {
		return dyn.Map{"error": err.Error(), "path": pathOrNil(r.Args["path"])}, nil
	}
	var edits []workspace.Edit
	raw, _ := json.Marshal(r.Args["edits"])
	_ = json.Unmarshal(raw, &edits)
	res := workspace.ApplyEdits(dyn.String(current["content"]), edits)
	report, _ := normalize(res.Report)
	if !res.Modified {
		return dyn.Map{"success": false, "report": report, "path": current["path"]}, nil
	}
	result, err := w.write(ctx, r, r.Args["path"], res.Content)
	if err != nil {
		return nil, err
	}
	result["report"] = report
	return result, nil
}

var trailingNewline = regexp.MustCompile(`\r?\n$`)

func (w *ComputerWorkspace) ReplaceFileRange(ctx context.Context, r FileRequest) (dyn.Map, error) {
	current, err := w.readContent(ctx, r, r.Args["path"])
	if err != nil {
		return dyn.Map{"error": err.Error(), "path": pathOrNil(r.Args["path"])}, nil
	}
	lines := strings.Split(dyn.String(current["content"]), "\n")
	start := jsNumber(r.Args["start_line"])
	endArg := r.Args["end_line"]
	if endArg == nil {
		endArg = r.Args["start_line"]
	}
	end := jsNumber(endArg)
	if !isInteger(start) || !isInteger(end) || start < 1 || end < start {
		return dyn.Map{"success": false, "error": "Invalid line range.", "path": current["path"]}, nil
	}
	if int(start) > len(lines) {
		return dyn.Map{"success": false, "error": "Line " + dyn.Number(start) + " is past the end of the file (" + dyn.Number(float64(len(lines))) + " lines).", "path": current["path"]}, nil
	}
	content := ""
	if r.Args["content"] != nil {
		content = dyn.String(r.Args["content"])
	}
	var replacement []string
	if content != "" {
		replacement = strings.Split(trailingNewline.ReplaceAllString(content, ""), "\n")
	}
	from, to := int(start)-1, min(int(end), len(lines))
	next := append(append(append([]string{}, lines[:from]...), replacement...), lines[to:]...)
	return w.write(ctx, r, r.Args["path"], strings.Join(next, "\n"))
}

func (w *ComputerWorkspace) ListDirectory(ctx context.Context, r FileRequest) (dyn.Map, error) {
	result, err := w.Request(ctx, r.UserID, "GET", "/workspace/files?path="+url.QueryEscape(orString(r.Args["path"], ".")), nil, r.DeviceTarget)
	if err != nil {
		return dyn.Map{"error": err.Error(), "entries": []any{}}, nil
	}
	return dyn.Map{"path": toGuestPath(orString(result["path"], "")), "entries": result["entries"]}, nil
}

func (w *ComputerWorkspace) SearchFiles(ctx context.Context, r FileRequest) (dyn.Map, error) {
	a := r.Args
	result, err := w.Request(ctx, r.UserID, "POST", "/workspace/search", dyn.Map{
		"path":       orAny(a["path"], "."),
		"glob":       orAny(a["glob"], orAny(a["pattern"], "")),
		"query":      orAny(a["query"], ""),
		"maxResults": orAny(a["max_results"], orAny(a["maxResults"], 100)),
	}, r.DeviceTarget)
	if err != nil {
		return dyn.Map{"error": err.Error(), "results": []any{}}, nil
	}
	return result, nil
}

func (w *ComputerWorkspace) ResolvePath(userID int64, path, label string) (string, error) {
	if w.Resolve == nil {
		return "", errorf("Workspace file access is unavailable.")
	}
	return w.Resolve(userID, path, label)
}
