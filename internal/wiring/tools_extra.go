package wiring

import (
	"context"
	"encoding/base64"
	"errors"
	"net/url"
	"os"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agents"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/handlers"
	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/files"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/synthid"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"github.com/NeoLabs-Systems/neoagent/internal/webshares"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace/codenav"
	"github.com/NeoLabs-Systems/neolabs-go/llm/openaiimages"
)

// addToolExtras wires the tools whose services live outside the core
// domains: app settings, web shares, calls, agent creation, SynthID, code
// navigation and workspace file staging.
func addToolExtras(d *handlers.Deps, s toolSources, getenv func(string) string) {
	if s.Settings != nil && s.SettingsModels != nil {
		d.Settings = toolAppSettings{t: &settings.AssistantTools{
			Assistant:    &settings.Assistant{Store: s.Settings, Models: s.SettingsModels, BaseURL: s.PublicBaseURL},
			Integrations: settingsIntegrations{m: s.Integrations},
			Changed: func(userID int64, agentID, key string) {
				if s.Emit != nil {
					s.Emit(userID, "settings:changed", map[string]any{"agentId": agentID, "keys": []string{key}})
				}
			},
		}}
	}
	if s.DB != nil {
		store := &webshares.Store{DB: s.DB, Getenv: getenv}
		var guests webshares.Guests
		if s.Computer != nil {
			guests = s.Computer
		}
		d.WebShares = toolWebShares{s: &webshares.Sharer{Store: store, Guests: guests}, baseURL: s.PublicBaseURL}
		d.Agents = toolAgents{c: &agents.Creator{DB: s.DB}}
	}
	if s.Calls != nil {
		d.Calls = toolCalls{c: s.Calls}
	}
	home, _ := os.UserHomeDir()
	d.SynthID = toolSynthID{d: &synthid.Detector{Getenv: getenv, Home: home}}
	if s.Workspaces != nil && s.DB != nil {
		d.CodeNav = toolCodeNav{s: &codenav.Service{DB: s.DB, Workspace: s.Workspaces, Embed: s.Embed}}
	}
	if s.Computer != nil && s.Artifacts != nil {
		d.StageFiles = func(ctx context.Context, run *handlers.Run, args dyn.Map, fileArgs []string) (dyn.Map, error) {
			return files.FetchWorkspaceFileArgs(ctx, run.UserID, args, fileArgs, computerFiles{m: s.Computer}, stagedArtifacts{ctx: ctx, s: s.Artifacts}, run.DeviceTarget)
		}
	}
}

// xaiImages is the xAI images client of generate_image's fallback.
func xaiImages(getenv func(string) string) openaiimages.Client {
	base := strings.TrimSpace(getenv("XAI_BASE_URL"))
	if base == "" {
		base = "https://api.x.ai/v1"
	}
	return openaiimages.Client{BaseURL: base, APIKey: getenv("XAI_API_KEY")}
}

// toolAppSettings answers settings_read, settings_update and settings_link.
type toolAppSettings struct{ t *settings.AssistantTools }

func (a toolAppSettings) Read(ctx context.Context, userID int64, agentID string, args dyn.Map) (any, error) {
	return a.t.Read(ctx, userID, agentID, args)
}

func (a toolAppSettings) Update(ctx context.Context, userID int64, agentID string, args dyn.Map) (any, error) {
	return a.t.Update(ctx, userID, agentID, args)
}

func (a toolAppSettings) Link(ctx context.Context, args dyn.Map) (any, error) {
	return a.t.Link(ctx, args)
}

// settingsIntegrations lists the integrations settings_read shows.
type settingsIntegrations struct{ m *integrations.Manager }

func (i settingsIntegrations) List(ctx context.Context, userID int64, agentID string) ([]settings.Integration, error) {
	if i.m == nil {
		return nil, nil
	}
	list, err := i.m.ListProviders(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	out := make([]settings.Integration, 0, len(list))
	for _, p := range list {
		snap := toMap(p)
		out = append(out, settings.Integration{
			Key: p.ID, Label: p.Label,
			Connected: dyn.Get(snap, "connection", "connected") == true,
			Available: dyn.Get(snap, "env", "configured") != false,
		})
	}
	return out, nil
}

func (i settingsIntegrations) Keys() []string {
	if i.m == nil {
		return nil
	}
	var keys []string
	for _, p := range i.m.Providers() {
		keys = append(keys, p.Info().Key)
	}
	return keys
}

// toolWebShares shares pages of the user's computer.
type toolWebShares struct {
	s       *webshares.Sharer
	baseURL func() string
}

func (w toolWebShares) base() string {
	if w.baseURL == nil {
		return ""
	}
	return w.baseURL()
}

func (w toolWebShares) Share(ctx context.Context, userID int64, agentID string, name, port any) (any, error) {
	return w.s.Share(ctx, userID, agentID, name, port, w.base())
}

func (w toolWebShares) Stop(ctx context.Context, userID int64, name any) (any, error) {
	return w.s.Stop(ctx, userID, name)
}

func (w toolWebShares) List(ctx context.Context, userID int64) (any, error) {
	return w.s.Store.List(ctx, userID, w.base())
}

// toolCalls places in-app calls.
type toolCalls struct{ c *voice.Coordinator }

func (t toolCalls) CallUser(ctx context.Context, userID int64, agentID, runID, conversationID, opening string) (any, error) {
	return t.c.CallUser(ctx, voice.CallRequest{UserID: userID, AgentID: agentID, RunID: runID, ConversationID: conversationID, OpeningMessage: opening}), nil
}

// toolAgents creates agents for runs.
type toolAgents struct{ c *agents.Creator }

func (t toolAgents) CreateForRun(ctx context.Context, run *handlers.Run, already bool, args dyn.Map) (dyn.Map, error) {
	agent, err := t.c.CreateForRun(ctx, agents.Run{UserID: run.UserID, AgentID: run.AgentID, RunID: run.RunID, AlreadyCreated: already}, args)
	var refusal *agents.Refusal
	if errors.As(err, &refusal) {
		return dyn.Map{"error": refusal.Msg}, nil
	}
	if err != nil {
		return nil, err
	}
	return dyn.Map{"id": agent.ID, "slug": agent.Slug, "displayName": agent.DisplayName}, nil
}

// toolSynthID is the Vertex AI SynthID detector.
type toolSynthID struct{ d *synthid.Detector }

func (t toolSynthID) Available() bool { return t.d.Available() }

func (t toolSynthID) Detect(ctx context.Context, _ int64, path string) (any, error) {
	return t.d.Detect(ctx, path)
}

// toolCodeNav is code_navigate.
type toolCodeNav struct{ s *codenav.Service }

func (t toolCodeNav) Navigate(ctx context.Context, userID int64, args dyn.Map) (any, error) {
	return t.s.Navigate(ctx, userID, args)
}

// computerFiles downloads workspace files from the user's computer.
type computerFiles struct{ m *runtime.Manager }

func (c computerFiles) DownloadFile(ctx context.Context, userID int64, reference, deviceTarget string) (files.DownloadedFile, error) {
	result, err := guestMap(c.m.RequestComputer(ctx, userKey(userID), "GET",
		"/workspace/files/download?path="+encodeQuery(guestproto.FromWorkspacePath(reference, "")), nil, deviceTarget, runtime.RequestOptions{}))
	if err != nil {
		return files.DownloadedFile{}, err
	}
	content, err := decodeBase64(dyn.Str(result["content"]))
	if err != nil {
		return files.DownloadedFile{}, err
	}
	return files.DownloadedFile{
		Filename: dyn.Str(result["filename"]),
		Path:     guestproto.ToWorkspacePath(dyn.Str(result["path"])),
		Content:  content,
	}, nil
}

// stagedArtifacts keeps fetched workspace files as owned artifacts.
type stagedArtifacts struct {
	ctx context.Context
	s   *artifacts.Store
}

func (a stagedArtifacts) StoreBufferArtifact(ctx context.Context, userID int64, in files.BufferArtifact) (string, error) {
	stored, err := a.s.CreateBufferArtifact(ctx, userKey(userID), artifacts.File{
		Kind: in.Kind, FilenameBase: in.FilenameBase, Extension: in.Extension, OriginalFilename: in.OriginalFilename,
		Content: in.Content, Metadata: in.Metadata,
	})
	return stored.StoragePath, err
}

func (a stagedArtifacts) StoragePath(userID int64, id string) (string, bool) {
	r, err := a.s.Get(a.ctx, userID, id)
	if err != nil || r == nil {
		return "", false
	}
	return r.StoragePath, true
}

func (a stagedArtifacts) StoragePathByFile(userID int64, reference string) (string, bool) {
	r, err := a.s.GetByStoragePath(a.ctx, userID, reference)
	if err != nil || r == nil {
		return "", false
	}
	return r.StoragePath, true
}

// confineLocalPaths keeps the Nextcloud file tools to the user's own files:
// the upload source must be a workspace file or owned artifact, and a
// download lands in the workspace.
func (t toolIntegrations) confineLocalPaths(ctx context.Context, run *handlers.Run, name string, args dyn.Map) (dyn.Map, string) {
	var store handlers.Artifacts
	if t.artifacts != nil {
		store = toolArtifacts{s: t.artifacts}
	}
	var ws handlers.Workspace
	if t.workspaces != nil {
		ws = &handlers.ComputerWorkspace{Resolve: resolverOf(t.workspaces)}
	}
	switch name {
	case "nextcloud_upload_file":
		local, err := handlers.ResolveUserFile(ctx, store, ws, run.UserID, args["file_path"], "File")
		if err != nil {
			return nil, err.Error()
		}
		return withArg(args, "file_path", local), ""
	case "nextcloud_download_file":
		dest := strings.TrimSpace(dyn.Str(args["destination_path"]))
		if dest == "" {
			return args, ""
		}
		if t.workspaces == nil {
			return nil, "Workspace file access is unavailable."
		}
		local, err := t.workspaces.ResolvePath(userKey(run.UserID), dest, "destination_path")
		if err != nil {
			return nil, err.Error()
		}
		return withArg(args, "destination_path", local), ""
	}
	return args, ""
}

func withArg(args dyn.Map, key string, value any) dyn.Map {
	out := dyn.Map{}
	for k, v := range args {
		out[k] = v
	}
	out[key] = value
	return out
}

func encodeQuery(s string) string { return url.QueryEscape(s) }

func decodeBase64(s string) ([]byte, error) { return base64.StdEncoding.DecodeString(s) }
