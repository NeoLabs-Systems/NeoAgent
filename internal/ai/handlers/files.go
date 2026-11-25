package handlers

import (
	"context"
	"path"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace/repotools"
)

var fileHandlers = map[string]handler{
	"workspace_rollback":    workspaceRollback,
	"read_file":             readFile,
	"read_files":            readFiles,
	"read_artifact":         readArtifact,
	"write_file":            writeFile,
	"edit_file":             editFile,
	"replace_file_range":    replaceFileRange,
	"list_directory":        listDirectory,
	"search_files":          searchFiles,
	"code_navigate":         codeNavigate,
	"query_structured_data": queryStructuredData,
}

const (
	readLineLimit     = 400
	readCharLimit     = 16000
	readManyCharLimit = 20000
	maxReadFiles      = 8
	layerCutMarker    = "\n...[truncated]"
)

func firstStringArg(args dyn.Map, names ...string) string {
	for _, name := range names {
		if s, ok := args[name].(string); ok && strings.TrimSpace(s) != "" {
			return s
		}
	}
	return ""
}

func coalesce(args dyn.Map, names ...string) any {
	for _, name := range names {
		if v := args[name]; v != nil {
			return v
		}
	}
	return nil
}

// normalizeReadFileArgs accepts the spellings models use for a line range.
func normalizeReadFileArgs(args dyn.Map) dyn.Map {
	start := coalesce(args, "start_line", "line_start", "startLine", "lineStart")
	end := coalesce(args, "end_line", "line_end", "endLine", "lineEnd")
	count := coalesce(args, "line_count", "lineCount")
	if end == nil && start != nil && count != nil {
		s, c := jsNumber(start), jsNumber(count)
		if isInteger(s) && isInteger(c) && c > 0 {
			end = s + c - 1
		}
	}
	out := dyn.Map{
		"path":     firstStringArg(args, "path", "file_path", "filePath", "filename"),
		"encoding": orAny(args["encoding"], "utf-8"),
	}
	if start != nil {
		out["start_line"] = start
	}
	if end != nil {
		out["end_line"] = end
	}
	return out
}

func isInteger(f float64) bool { return f == f && f == float64(int64(f)) }

// orAny is `value || fallback`.
func orAny(v, fallback any) any {
	if dyn.Truthy(v) {
		return v
	}
	return fallback
}

// boundedRead: a whole-file read of something long stops at a line limit and
// says where; an explicit range only answers to the size limit. Cuts land on
// line boundaries.
func boundedRead(result dyn.Map, hasRange bool, charLimit int) dyn.Map {
	content, ok := result["content"].(string)
	if !ok || dyn.Truthy(result["error"]) {
		return result
	}
	if strings.Contains(content, "\x00") {
		return dyn.Map{"path": result["path"], "binary": true, "byteSize": result["byteSize"], "content": "[binary file: not shown]"}
	}
	layerCut := strings.HasSuffix(content, layerCutMarker)
	if layerCut {
		content = strings.TrimSuffix(content, layerCutMarker)
	}
	lines := strings.Split(content, "\n")
	lineCount := len(lines)
	if lines[len(lines)-1] == "" {
		lineCount--
	}
	start := 1.0
	if shown := dyn.List(result["rangeShown"]); len(shown) > 0 {
		if f, ok := dyn.Float(shown[0]); ok {
			start = f
		}
	}
	totalLines := result["totalLines"]
	if totalLines == nil && !layerCut {
		totalLines = lineCount
	}
	kept := len(lines)
	if !hasRange && lineCount > readLineLimit {
		kept = readLineLimit
	}
	shownText := strings.Join(lines[:kept], "\n")
	if lenUTF16(shownText) > charLimit {
		cut := sliceUTF16(shownText, charLimit+1)
		if end := strings.LastIndex(cut, "\n"); end > 0 {
			shownText = shownText[:end]
		} else {
			shownText = sliceUTF16(shownText, charLimit)
		}
		kept = len(strings.Split(shownText, "\n"))
	}
	if !layerCut && shownText == content {
		return result
	}
	out := dyn.Map{}
	for k, v := range result {
		out[k] = v
	}
	out["content"] = shownText
	out["truncated"] = true
	out["rangeShown"] = []any{start, start + float64(kept) - 1}
	if totalLines != nil {
		out["totalLines"] = totalLines
	}
	return out
}

func (c *call) fileRequest(args dyn.Map) FileRequest {
	return FileRequest{UserID: c.run.UserID, DeviceTarget: c.run.DeviceTarget, WorkspaceRoot: c.run.WorkspaceRoot, Args: args}
}

func hasRange(args dyn.Map) bool { return args["start_line"] != nil || args["end_line"] != nil }

func workspaceRollback(ctx context.Context, c *call) (any, error) {
	if c.b.d.Engine == nil || c.run.RunID == "" || c.b.d.Engine.Run(c.run.RunID) == nil {
		return dyn.Ordered{{Key: "success", Value: false}, {Key: "error", Value: "This run has no workspace checkpoint to go back to."}}, nil
	}
	return c.b.d.Engine.RollbackWorkspace(ctx, c.run.RunID)
}

func readFile(ctx context.Context, c *call) (any, error) {
	ws := c.b.d.Workspace
	if ws == nil {
		return errResult("Workspace service is unavailable."), nil
	}
	args := normalizeReadFileArgs(c.args)
	if args["path"] == "" {
		return errResult("read_file requires path. Keep source files in the workspace; for repository work clone or move the checkout into the workspace before using file tools."), nil
	}
	result, err := ws.ReadFile(ctx, c.fileRequest(args))
	if err != nil {
		return failure(ctx, err)
	}
	return boundedRead(result, hasRange(args), readCharLimit), nil
}

func readFiles(ctx context.Context, c *call) (any, error) {
	ws := c.b.d.Workspace
	if ws == nil {
		return errResult("Workspace service is unavailable."), nil
	}
	entries, ok := c.args["files"].([]any)
	if !ok {
		entries, _ = c.args["paths"].([]any)
	}
	if len(entries) == 0 {
		return errResult("read_files requires a non-empty files or paths array."), nil
	}
	charLimit := readManyCharLimit / min(len(entries), maxReadFiles)
	shown := entries[:min(len(entries), maxReadFiles)]
	results := make([]any, len(shown))
	errs := make([]error, len(shown))
	var wg sync.WaitGroup
	for i, entry := range shown {
		wg.Add(1)
		go func(i int, entry any) {
			defer wg.Done()
			fileArgs := dyn.Map{}
			switch e := entry.(type) {
			case string:
				fileArgs["path"] = e
			case dyn.Map:
				for k, v := range e {
					fileArgs[k] = v
				}
			}
			fileArgs["encoding"] = orAny(fileArgs["encoding"], orAny(c.args["encoding"], "utf-8"))
			args := normalizeReadFileArgs(fileArgs)
			if args["path"] == "" {
				results[i] = dyn.Ordered{{Key: "index", Value: i}, {Key: "success", Value: false}, {Key: "error", Value: "Each read_files item requires path or file_path."}}
				return
			}
			result, err := ws.ReadFile(ctx, c.fileRequest(args))
			if err != nil {
				errs[i] = err
				return
			}
			result = boundedRead(result, hasRange(args), charLimit)
			item := dyn.Ordered{{Key: "index", Value: i}, {Key: "requestedPath", Value: args["path"]}, {Key: "success", Value: !dyn.Truthy(result["error"])}}
			for _, k := range dyn.SortedKeys(result) {
				item = item.Set(k, result[k])
			}
			results[i] = item
		}(i, entry)
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return failure(ctx, err)
		}
	}
	all := true
	for _, r := range results {
		m := asMap(r)
		if m["success"] == false || dyn.Truthy(m["error"]) {
			all = false
		}
	}
	return dyn.Ordered{{Key: "success", Value: all}, {Key: "count", Value: len(results)}, {Key: "truncated", Value: len(entries) > maxReadFiles}, {Key: "results", Value: results}}, nil
}

func readArtifact(ctx context.Context, c *call) (any, error) {
	if c.b.d.Artifacts == nil {
		return errResult("Artifact store is unavailable."), nil
	}
	result, err := c.b.d.Artifacts.ReadText(ctx, c.run.UserID, c.args["artifact_id"], c.args["start_line"], c.args["end_line"], c.args["query"])
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}

func writeFile(ctx context.Context, c *call) (any, error) {
	ws := c.b.d.Workspace
	if ws == nil {
		return errResult("Workspace service is unavailable."), nil
	}
	target := c.args["path"]
	if !dyn.Truthy(target) {
		return dyn.Ordered{{Key: "success", Value: false}, {Key: "error", Value: "write_file requires path."}}, nil
	}
	if c.args["content"] == nil {
		return dyn.Ordered{{Key: "success", Value: false}, {Key: "error", Value: "write_file requires a content argument; nothing was written."}}, nil
	}
	result, err := ws.WriteFile(ctx, c.fileRequest(dyn.Map{"path": target, "content": guestproto.CoerceWritableText(c.args["content"]), "mode": c.args["mode"]}))
	if err != nil {
		return failure(ctx, err)
	}
	return c.withDiagnostics(ctx, result, dyn.String(target))
}

func editFile(ctx context.Context, c *call) (any, error) {
	ws := c.b.d.Workspace
	if ws == nil {
		return errResult("Workspace service is unavailable."), nil
	}
	target := c.args["path"]
	if !dyn.Truthy(target) {
		return dyn.Ordered{{Key: "success", Value: false}, {Key: "error", Value: "edit_file requires path."}}, nil
	}
	edits := []any{}
	for _, raw := range dyn.List(c.args["edits"]) {
		e := asMap(raw)
		edit := dyn.Map{}
		for k, v := range e {
			edit[k] = v
		}
		edit["oldText"] = coalesce(e, "oldText", "old_text")
		edit["newText"] = coalesce(e, "newText", "new_text")
		edit["replaceAll"] = coalesce(e, "replaceAll", "replace_all") == true
		edits = append(edits, edit)
	}
	result, err := ws.EditFile(ctx, c.fileRequest(dyn.Map{"path": target, "edits": edits}))
	if err != nil {
		return failure(ctx, err)
	}
	return c.withDiagnostics(ctx, result, dyn.String(target))
}

func replaceFileRange(ctx context.Context, c *call) (any, error) {
	ws := c.b.d.Workspace
	if ws == nil {
		return errResult("Workspace service is unavailable."), nil
	}
	target := c.args["path"]
	if !dyn.Truthy(target) {
		return dyn.Ordered{{Key: "success", Value: false}, {Key: "error", Value: "replace_file_range requires path."}}, nil
	}
	result, err := ws.ReplaceFileRange(ctx, c.fileRequest(dyn.Map{
		"path":       target,
		"start_line": coalesce(c.args, "start_line", "startLine"),
		"end_line":   coalesce(c.args, "end_line", "endLine"),
		"content":    c.args["content"],
	}))
	if err != nil {
		return failure(ctx, err)
	}
	return c.withDiagnostics(ctx, result, dyn.String(target))
}

func listDirectory(ctx context.Context, c *call) (any, error) {
	ws := c.b.d.Workspace
	if ws == nil {
		return errResult("Workspace service is unavailable."), nil
	}
	result, err := ws.ListDirectory(ctx, c.fileRequest(dyn.Map{"path": c.args["path"], "depth": c.args["depth"], "recursive": c.args["recursive"]}))
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}

func searchFiles(ctx context.Context, c *call) (any, error) {
	if shell := c.workspaceShell(ctx); shell != nil {
		result, err := repotools.Search(ctx, shell, c.args)
		if err != nil {
			return failure(ctx, err)
		}
		return result, nil
	}
	// No computer to run on, so only the server's own workspace can be searched.
	ws := c.b.d.Workspace
	if ws == nil {
		return errResult("Workspace service is unavailable."), nil
	}
	result, err := ws.SearchFiles(ctx, c.fileRequest(dyn.Map{
		"path":        c.args["path"],
		"query":       c.args["query"],
		"include":     c.args["include"],
		"maxDepth":    coalesce(c.args, "maxDepth", "max_depth"),
		"maxFileSize": coalesce(c.args, "maxFileSize", "max_file_size"),
	}))
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}

func codeNavigate(ctx context.Context, c *call) (any, error) {
	if c.b.d.CodeNav == nil {
		return errResult("Code navigation service is unavailable."), nil
	}
	result, err := c.b.d.CodeNav.Navigate(ctx, c.run.UserID, c.args)
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}

func queryStructuredData(ctx context.Context, c *call) (any, error) {
	if c.b.d.Structured == nil {
		return errResult("Structured data service is unavailable."), nil
	}
	result, err := c.b.d.Structured.Query(ctx, c.run.UserID, c.args)
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}

// workspaceShell is the run's computer shell, or nil when no computer can run
// commands (createWorkspaceShell).
func (c *call) workspaceShell(ctx context.Context) repotools.Shell {
	rt := c.b.d.Runtime
	if rt == nil {
		return nil
	}
	return &runShell{c: c, rt: rt}
}

// runShell runs scripts in the workspace every computer maps to its own.
type runShell struct {
	c  *call
	rt Runtime
}

func (s *runShell) Run(ctx context.Context, script string, timeout time.Duration) (dyn.Map, error) {
	if timeout == 0 {
		timeout = 60 * time.Second
	}
	return s.rt.ExecuteCommand(ctx, s.c.run.UserID, script, CommandOptions{
		Cwd: repotools.GuestWorkspaceDir, Timeout: timeout, RunID: s.c.run.RunID, StepID: s.c.stepID, DeviceTarget: s.c.run.DeviceTarget,
	})
}

// File diagnostics (file_diagnostics.js): syntax-only checks after a write;
// none imports or runs the file.

const (
	diagnosticsTimeout = 15 * time.Second
	diagnosticsMaxOut  = 600
)

const pythonSyntaxCheck = "import ast, sys\n" +
	"p = sys.argv[1]\n" +
	"try: ast.parse(open(p).read(), p)\n" +
	`except SyntaxError as e: print(f"{p}:{e.lineno}: {type(e).__name__}: {e.msg}\n{(e.text or '').rstrip()}", file=sys.stderr); sys.exit(1)` + "\n" +
	"except Exception: sys.exit(2)"

type diagnosticState struct {
	signature string
	repeats   int
}

func diagnosticsCommand(file string) string {
	quoted := repotools.ShellQuote(file)
	switch strings.ToLower(path.Ext(file)) {
	case ".py":
		return "python3 -c " + repotools.ShellQuote(pythonSyntaxCheck) + " " + quoted
	case ".js", ".cjs", ".mjs":
		return "node --check " + quoted
	}
	return ""
}

var digitsRun = regexp.MustCompile(`\d+`)

func (c *call) withDiagnostics(ctx context.Context, result dyn.Map, file string) (any, error) {
	if result == nil || result["success"] == false || dyn.Truthy(result["error"]) {
		return result, nil
	}
	diagnostics := c.runDiagnostics(ctx, file)
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	if diagnostics == nil {
		return result, nil
	}
	out := dyn.Map{}
	for k, v := range result {
		out[k] = v
	}
	out["diagnostics"] = diagnostics
	return out, nil
}

func (c *call) runDiagnostics(ctx context.Context, file string) dyn.Ordered {
	command := diagnosticsCommand(file)
	if command == "" || c.b.d.Runtime == nil {
		return nil
	}
	result, err := c.b.d.Runtime.ExecuteCommand(ctx, c.run.UserID, command, CommandOptions{
		Cwd: repotools.GuestWorkspaceDir, Timeout: diagnosticsTimeout, DeviceTarget: c.run.DeviceTarget,
	})
	if err != nil {
		return nil
	}
	output := ""
	if code, ok := dyn.Float(result["exitCode"]); ok && code == 1 {
		output = dyn.Str(result["stderr"])
		if output == "" {
			output = dyn.Str(result["stdout"])
		}
		output = strings.TrimSpace(output)
		if n := lenUTF16(output); n > diagnosticsMaxOut {
			output = sliceUTF16Tail(output, diagnosticsMaxOut)
		}
	}
	b := c.b
	b.mu.Lock()
	defer b.mu.Unlock()
	history := b.diag[c.run.RunID]
	if output == "" {
		if history != nil {
			delete(history, file)
		}
		return nil
	}
	repeats := 1
	if c.run.RunID != "" {
		if history == nil {
			history = map[string]diagnosticState{}
			b.diag[c.run.RunID] = history
		}
		signature := digitsRun.ReplaceAllString(output, "#")
		if prev, ok := history[file]; ok && prev.signature == signature {
			repeats = prev.repeats + 1
		}
		history[file] = diagnosticState{signature: signature, repeats: repeats}
	}
	out := dyn.Ordered{{Key: "ok", Value: false}, {Key: "output", Value: output}}
	if repeats > 1 {
		out = append(out, dyn.KV{Key: "note", Value: "This is the same error as after the previous " + dyn.Number(float64(repeats-1)) + " edit(s); those edits did not address it. Rewrite the affected block or the whole file with write_file instead of patching again."})
	}
	return out
}

// sliceUTF16Tail is s.slice(-n) counted in UTF-16 units.
func sliceUTF16Tail(s string, n int) string {
	skip := lenUTF16(s) - n
	units := 0
	for i, r := range s {
		if units >= skip {
			return s[i:]
		}
		if r > 0xFFFF {
			units += 2
		} else {
			units++
		}
	}
	return ""
}
