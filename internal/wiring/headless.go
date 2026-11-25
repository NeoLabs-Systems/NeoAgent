package wiring

import (
	"context"
	"database/sql"
	"encoding/base64"
	"errors"
	"fmt"
	"io/fs"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/agentimport"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
)

// HeadlessRequest is one `neoagent exec` run.
type HeadlessRequest struct {
	Instruction string
	// Model is "provider/model" or "provider::model"; Provider, when set,
	// names the provider and Model is then the provider's own id (OpenRouter
	// ids contain slashes themselves).
	Model, Provider string
	AgentSlug       string
	// WorkspaceRoot is the directory the run works in.
	WorkspaceRoot string
	// Log receives progress notes for the operator (stderr).
	Log func(string)
}

// RunHeadless runs one task through the same engine entry point as the app,
// without the HTTP layer. There is deliberately no way to choose an account:
// the CLI authenticates nobody, so it only runs on an install with exactly
// one. With an isolated computer runtime the guest has no view of the host,
// so the workspace is copied in before and back after the run.
func (a *App) RunHeadless(ctx context.Context, req HeadlessRequest) (agent.Result, error) {
	logf := req.Log
	if logf == nil {
		logf = func(string) {}
	}
	userID, err := singleUser(ctx, a)
	if err != nil {
		return agent.Result{}, err
	}
	resolver := agentscope.Resolver{DB: a.db}
	agentID, err := resolver.Resolve(ctx, userID, "")
	if err != nil {
		return agent.Result{}, err
	}
	if slug := strings.TrimSpace(req.AgentSlug); slug != "" {
		if err := a.db.R.QueryRowContext(ctx, `SELECT id FROM agents WHERE user_id = ? AND slug = ?`, userID, slug).Scan(&agentID); errors.Is(err, sql.ErrNoRows) {
			return agent.Result{}, fmt.Errorf("No such agent: %s", slug)
		} else if err != nil {
			return agent.Result{}, err
		}
	}
	selection, err := selectionFor(req.Provider, req.Model)
	if err != nil {
		return agent.Result{}, err
	}
	if selection != "" {
		if err := a.assertModelAvailable(ctx, userID, agentID, selection); err != nil {
			return agent.Result{}, err
		}
	}
	conversation, err := a.memory.DefaultWebConversationID(ctx, userID, agentID)
	if err != nil {
		return agent.Result{}, err
	}
	if a.engine == nil {
		return agent.Result{}, errEngineNotReady
	}
	containerized := runtime.ParseTerminalEnv(os.Getenv("TERMINAL_ENV")) != runtime.TerminalHost
	if containerized {
		seeded, skipped := a.seedGuestWorkspace(ctx, userID, req.WorkspaceRoot)
		if len(skipped) > 0 {
			logf(fmt.Sprintf("[exec] %d file(s) not copied into the guest workspace: %s", len(skipped), strings.Join(skipped[:min(10, len(skipped))], ", ")))
		}
		logf(fmt.Sprintf("[exec] copied %d file(s) from %s into the guest workspace", seeded, req.WorkspaceRoot))
		// Partial output is what a grader needs most, so it comes back even
		// when the run fails.
		defer func() {
			synced, err := a.syncGuestWorkspaceBack(ctx, userID, req.WorkspaceRoot)
			if err != nil {
				logf("[exec] could not sync the guest workspace back: " + err.Error())
			}
			logf(fmt.Sprintf("[exec] synced %d file(s) from the guest workspace back to %s", synced, req.WorkspaceRoot))
		}()
	}
	return a.engine.Run(ctx, userID, req.Instruction, agent.Options{
		AgentID: agentID, ConversationID: conversation, DeviceTarget: "cloud", WorkspaceRoot: req.WorkspaceRoot,
		TriggerType: "user", TriggerSource: "cli", Model: selection,
	})
}

func singleUser(ctx context.Context, a *App) (int64, error) {
	rows, err := a.db.R.QueryContext(ctx, `SELECT id FROM users ORDER BY id LIMIT 2`)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return 0, err
		}
		ids = append(ids, id)
	}
	switch len(ids) {
	case 0:
		return 0, errors.New(`No account exists yet. Run "neoagent setup" first.`)
	case 1:
		return ids[0], rows.Err()
	}
	return 0, errors.New(`This install has more than one account, so "neoagent exec" cannot tell which one to run as. Use the web or API interfaces, which authenticate.`)
}

// selectionFor turns --provider/--model into a selection id.
func selectionFor(provider, model string) (string, error) {
	provider, model = strings.TrimSpace(provider), strings.TrimSpace(model)
	switch {
	case provider != "" && model == "":
		return "", errors.New("--provider requires --model (a provider alone does not select a model).")
	case provider != "":
		return aimodels.CreateSelectionID(provider, model), nil
	case model == "" || strings.Contains(model, aimodels.SelectionSeparator):
		return model, nil
	}
	if i := strings.Index(model, "/"); i > 0 {
		return aimodels.CreateSelectionID(model[:i], model[i+1:]), nil
	}
	return model, nil
}

// assertModelAvailable fails for a model the account cannot reach: routing
// would quietly fall back to another one, and a caller that named a model
// wants that model.
func (a *App) assertModelAvailable(ctx context.Context, userID int64, agentID, selection string) error {
	models, err := a.models.Catalog(ctx, userID, agentID)
	if err != nil {
		return err
	}
	var ids []string
	for _, m := range models {
		id := m.ID
		if !strings.Contains(id, aimodels.SelectionSeparator) && m.Provider != "" && id != "" {
			id = aimodels.CreateSelectionID(m.Provider, id)
		}
		if id != "" {
			ids = append(ids, id)
		}
	}
	if slices.Contains(ids, selection) {
		return nil
	}
	shown := strings.Join(ids[:min(10, len(ids))], ", ")
	if shown == "" {
		shown = "none"
	}
	return fmt.Errorf("Model %s is not available to this account. Available: %s", selection, shown)
}

// seedExcluded are directories never worth copying into a guest.
var seedExcluded = map[string]bool{".git": true, "node_modules": true, ".neobench": true, "__pycache__": true}

func (a *App) guestRequest(ctx context.Context, userID int64, method, path string, body any) (*runtime.Object, error) {
	return a.computer.Manager.RequestComputer(ctx, userKey(userID), method, path, body, "cloud", runtime.RequestOptions{})
}

// seedGuestWorkspace empties the account's guest workspace (it persists
// between runs) and copies the host directory in, binary files included.
func (a *App) seedGuestWorkspace(ctx context.Context, userID int64, root string) (int, []string) {
	_, _ = a.guestRequest(ctx, userID, "POST", "/exec", map[string]any{"command": "rm -rf /home/neo/workspace/* /home/neo/workspace/.[!.]* 2>/dev/null; true"})
	var skipped []string
	seeded := 0
	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		name := d.Name()
		if path != root && strings.HasPrefix(name, ".") {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if d.IsDir() {
			if seedExcluded[name] {
				return filepath.SkipDir
			}
			return nil
		}
		if !d.Type().IsRegular() {
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		rel = filepath.ToSlash(rel)
		data, err := os.ReadFile(path)
		if err == nil {
			_, err = a.guestRequest(ctx, userID, "PUT", "/workspace/files/content", map[string]any{"path": rel, "encoding": "base64", "content": base64.StdEncoding.EncodeToString(data)})
		}
		if err != nil {
			skipped = append(skipped, rel)
		} else {
			seeded++
		}
		return nil
	})
	return seeded, skipped
}

// syncGuestWorkspaceBack copies the guest workspace's files to the host.
func (a *App) syncGuestWorkspaceBack(ctx context.Context, userID int64, root string) (int, error) {
	synced := 0
	var walk func(dir string) error
	walk = func(dir string) error {
		listing, err := a.guestRequest(ctx, userID, "GET", "/workspace/files?path="+url.QueryEscape(dir), nil)
		if err != nil {
			return err
		}
		var entries []struct{ Path, Type string }
		listing.Decode("entries", &entries)
		for _, e := range entries {
			switch e.Type {
			case "directory":
				if err := walk(e.Path); err != nil {
					return err
				}
			case "file":
				file, err := a.guestRequest(ctx, userID, "GET", "/workspace/files/download?path="+url.QueryEscape(e.Path), nil)
				if err != nil {
					continue
				}
				data, err := base64.StdEncoding.DecodeString(file.String("content"))
				if err != nil {
					continue
				}
				dest := filepath.Join(root, filepath.FromSlash(e.Path))
				if rel, err := filepath.Rel(root, dest); err != nil || strings.HasPrefix(rel, "..") {
					continue
				}
				if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
					return err
				}
				if err := os.WriteFile(dest, data, 0o644); err != nil {
					return err
				}
				synced++
			}
		}
		return nil
	}
	return synced, walk(".")
}

// Importer is the OpenClaw/Hermes import, reading the installations s finds.
func (a *App) Importer(s agentimport.Scanner) *agentimport.API { return a.importer.WithScanner(s) }
