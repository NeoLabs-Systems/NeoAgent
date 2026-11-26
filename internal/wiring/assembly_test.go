package wiring

import (
	"context"
	"fmt"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"regexp"
	"slices"
	"strings"
	"testing"
	"unsafe"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/android"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
)

const module = "github.com/NeoLabs-Systems/neoagent/"

// assemble builds the application exactly as the server does, on a throwaway
// home, without starting its background services.
func assemble(t *testing.T) *App {
	t.Helper()
	home := t.TempDir()
	env := map[string]string{
		"HOME": home, "NEOAGENT_HOME": filepath.Join(home, ".neoagent"), "TERMINAL_ENV": "host",
		"SESSION_SECRET": strings.Repeat("s", 48),
	}
	for k, v := range env {
		t.Setenv(k, v)
	}
	cfg, err := config.Load(func(k string) string { return env[k] }, home, home)
	if err != nil {
		t.Fatal(err)
	}
	if err := cfg.Paths.Ensure(); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(cfg.Paths.DataDir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	store, err := sessionx.NewStore(ctx, db.W)
	if err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New(config.SecretPrefix, cfg.SessionSecret)
	if err != nil {
		t.Fatal(err)
	}
	app, err := Build(ctx, Deps{
		Cfg: cfg, DB: db, Store: store, Box: box, Version: "test",
		Users:          &accounts.Repo{DB: db},
		Records:        &accounts.SessionRecords{DB: db, Store: store, Secret: cfg.SessionSecret},
		BindOAuthState: func(*sessionx.Session, string) {},
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Stop)
	return app
}

// unsetFields walks everything the application holds and names the hooks and
// collaborators (functions, interfaces, pointers to our own types) that are
// nil, as "package.Type.Field".
func unsetFields(root any) []string {
	var unset []string
	seen := map[string]bool{}
	visited := map[string]bool{}
	var walk func(v reflect.Value)
	walk = func(v reflect.Value) {
		switch v.Kind() {
		case reflect.Pointer:
			key := fmt.Sprintf("%x %s", v.Pointer(), v.Type())
			if !v.IsNil() && !visited[key] {
				visited[key] = true
				walk(v.Elem())
			}
		case reflect.Interface:
			if !v.IsNil() {
				walk(v.Elem())
			}
		case reflect.Slice, reflect.Array:
			for i := range v.Len() {
				walk(v.Index(i))
			}
		case reflect.Map:
			for it := v.MapRange(); it.Next(); {
				walk(it.Value())
			}
		case reflect.Struct:
			t := v.Type()
			if !strings.HasPrefix(t.PkgPath(), module) {
				return
			}
			if !v.CanAddr() {
				copied := reflect.New(t).Elem()
				copied.Set(v)
				v = copied
			}
			for i := range t.NumField() {
				f := v.Field(i)
				f = reflect.NewAt(f.Type(), unsafe.Pointer(f.UnsafeAddr())).Elem()
				ours := f.Kind() == reflect.Pointer && strings.HasPrefix(f.Type().Elem().PkgPath(), module)
				if (f.Kind() == reflect.Func || f.Kind() == reflect.Interface || ours) && f.IsNil() {
					name := strings.TrimPrefix(t.PkgPath(), module+"internal/") + "." + t.Name() + "." + t.Field(i).Name
					if !seen[name] {
						seen[name] = true
						unset = append(unset, name)
					}
					continue
				}
				walk(f)
			}
		}
	}
	walk(reflect.ValueOf(root))
	slices.Sort(unset)
	return unset
}

// restState are fields that are nil in a correctly assembled server: test
// seams and optional overrides with a built-in default, state that only exists
// once the services run, and per-entry capabilities of a table.
var restState = []string{
	// Test seams and optional overrides: the owner falls back by itself.
	"agentimport.Config.Now", "agentimport.Scanner.Now", "agentsapi.Config.UserID",
	"ai.SystemPrompts.Now", "ai/handlers.HTTPRequester.LookupHost", "ai/handlers.HTTPRequester.Transport",
	"ai/models.Failures.Now", "artifacts.Config.UserID", "behavior.Config.UserID", "behavior.Pipeline.Now",
	"cloudsec.Checker.Lookup", "integrations/bitwarden.CLI.Now", "integrations/bitwarden.CLI.Run",
	"integrations/companion.Server.Now", "messaging.ManagerConfig.UserID", "providersignin.Config.UserID",
	"runledger.Ledger.Now", "setupapi.Config.UserID", "tasks.Config.Clock", "tasks.Config.UserID",
	"taskwebhooks.Config.UserID", "timeline.Service.Now", "voice.Defaults.Getenv",
	"wearable.FirmwareResolver.Now", "webshares.Config.UserID",
	// Built on first use or by Start.
	"admin.API.upd", "behavior.Pipeline.Store", "behavior.Pipeline.cancel", "behavior.Pipeline.ctx",
	"behavior.Pipeline.states", "memory.Manager.stop", "messaging.SharedConnections.cancel",
	"socialvideo.Service.health", "tasks.Runtime.cancel", "tasks.Runtime.ctx", "wiring.App.mcpCancel",
	// Not every entry of the table has the capability.
	"ai/tools.Definition.Integration", "integrations.AccountHooks.Decorate", "integrations.AccountHooks.Disconnect",
	"integrations.AccountHooks.Summarize", "integrations.AccountHooks.Test", "integrations.OAuthHooks.Disconnect",
	"integrations.OAuthHooks.FilterTools", "integrations.OAuthHooks.Sweep", "integrations/companion.Product.FilterTools",
	"tasks.Adapter.Event", "tasks.Adapter.Poll", "tasks.Adapter.ReplyTarget", "tasks.Poll.InitialCheckpoint",
	"tasks.Poll.IntervalMinutes",
	// TERMINAL_ENV=host, which the test uses, has no cloud computers; cmd
	// sets OpenSignup.
	"runtime.LocalBackend.Host", "runtime.Manager.backend", "runtime.ManagerOptions.Backend", "accounts.Repo.OpenSignup",
	// The prompt is assembled per run and settings are read per message, so
	// there is no cache for these to drop.
	"behavior.Config.OnChange", "settings.Hooks.PromptChanged",
}

// knownGaps are collaborators with no Go implementation to connect yet.
// Remove an entry when it is wired.
var knownGaps = []string{
	"admin.ExtraDeps.Analytics",    // the admin analytics chart is empty
	"admin.ExtraDeps.Logs",         // the admin log view is empty
	"mcpserver.API.auditor",        // GET /api/mcp/audit is not served
	"memory.Manager.styles",        // facts do not become voice-profile style notes
	"socialreach.Config.Runtime",   // no cookie import from the cloud computer
	"socialvideo.Config.Artifacts", // video stills are not kept
	"socialvideo.Config.Browser",   // no browser fallback for social videos
	"tasks.Config.Failures",        // task runs do not tell passing provider limits apart
	"wearable.ServiceConfig.Geo",   // no GeoIP database: wearables get the server's zone
}

// TestAssemblyHasNoUnsetCollaborators fails when a port adds a hook that
// Build never connects.
func TestAssemblyHasNoUnsetCollaborators(t *testing.T) {
	unset := unsetFields(assemble(t))
	expected := slices.Concat(restState, knownGaps)
	for _, name := range unset {
		if !slices.Contains(expected, name) {
			t.Errorf("%s is nil in the assembled server: wire it in internal/wiring", name)
		}
	}
	for _, name := range expected {
		if !slices.Contains(unset, name) {
			t.Errorf("%s is set now (or gone): remove it from the lists", name)
		}
	}
}

// mountedElsewhere are route types that app.Routes does not hold.
var mountedElsewhere = map[string]string{
	"authapi.API":   "mounted by internal/httpserver",
	"streaming.API": "unused: sockets.Server serves /api/stream",
}

// TestEveryRoutePackageIsMounted compares the route types in the source with
// what the assembled server mounts.
func TestEveryRoutePackageIsMounted(t *testing.T) {
	mounted := map[string]bool{}
	mux := http.NewServeMux()
	app := assemble(t)
	for _, r := range app.Routes {
		r.Routes(mux)
		typ := reflect.TypeOf(r)
		if typ.Kind() == reflect.Pointer {
			typ = typ.Elem()
		}
		mounted[strings.TrimPrefix(typ.PkgPath(), module+"internal/")+"."+typ.Name()] = true
	}
	declaration := regexp.MustCompile(`(?m)^func \(\w+ \*?(\w+)\) Routes\(\w+ \*http\.ServeMux\)`)
	err := filepath.WalkDir("..", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return err
		}
		source, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		pkg := filepath.ToSlash(strings.TrimPrefix(filepath.Dir(path), ".."+string(filepath.Separator)))
		for _, match := range declaration.FindAllStringSubmatch(string(source), -1) {
			if name := pkg + "." + match[1]; !mounted[name] && mountedElsewhere[name] == "" {
				t.Errorf("%s has routes the server never mounts", name)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{
		"/api/wearable/ws", "/api/wearable/timezone", "/api/wearable/bootstrap",
		"/api/wearable/firmware/manifest", "/api/wearable/connections",
	} {
		if _, pattern := mux.Handler(httptest.NewRequest(http.MethodGet, path, nil)); pattern == "" {
			t.Errorf("no route for GET %s", path)
		}
	}
	for _, platform := range []string{
		"whatsapp", "discord", "telegram", "github", "slack", "google_chat", "teams", "matrix", "signal", "imessage",
		"bluebubbles", "irc", "feishu", "line", "mattermost", "nextcloud_talk", "nostr", "synology_chat", "tlon",
		"twitch", "zalo", "zalo_personal", "wechat", "webchat",
	} {
		if app.messaging.GetPlatformStatus(context.Background(), 1, "main", platform)["status"] == "not_supported" {
			t.Errorf("messaging platform %s is not registered", platform)
		}
	}
}

// TestEveryPackageReachesTheServer fails for a ported package that nothing
// imports.
func TestEveryPackageReachesTheServer(t *testing.T) {
	list := func(args ...string) []string {
		out, err := exec.Command("go", append([]string{"list"}, args...)...).Output()
		if err != nil {
			t.Fatalf("go list %v: %v", args, err)
		}
		return strings.Fields(string(out))
	}
	linked := list("-deps", module+"cmd/...")
	for _, pkg := range list(module + "internal/...") {
		// Test helpers are only imported by tests.
		if !slices.Contains(linked, pkg) && !strings.HasSuffix(pkg, "test") && !strings.HasSuffix(pkg, "/replay") {
			t.Errorf("%s is imported by no command", pkg)
		}
	}
}

// TestWiredStrings covers connections a nil check cannot see: the MCP sign-in
// return address and what the Android host is given.
func TestWiredStrings(t *testing.T) {
	if got := mcpRedirectURL(config.Config{Port: 3333}); got != "http://localhost:3333/api/mcp/oauth/callback" {
		t.Errorf("redirect without PUBLIC_URL = %q", got)
	}
	if got := mcpRedirectURL(config.Config{PublicURL: "https://a.example/"}); got != "https://a.example/api/mcp/oauth/callback" {
		t.Errorf("redirect = %q", got)
	}
	ctx := context.Background()
	if allowed, reason, err := checkIntentURL(ctx, "https://93.184.216.34/"); err != nil || !allowed {
		t.Errorf("public web intent: allowed=%v reason=%q err=%v", allowed, reason, err)
	}
	if allowed, _, _ := checkIntentURL(ctx, "http://127.0.0.1/"); allowed {
		t.Error("a loopback intent was allowed")
	}
	app := assemble(t)
	if _, err := app.db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'neo', 'x')`); err != nil {
		t.Fatal(err)
	}
	url, err := androidArtifacts{app.computer.Artifacts}.CreateBufferArtifact(ctx, "1", android.BufferArtifact{
		Kind: "android-screenshot", Extension: "png", ContentType: "image/png", Content: []byte("png"),
	})
	if err != nil || !strings.HasPrefix(url, "/api/artifacts/") {
		t.Errorf("screenshot url = %q, err = %v", url, err)
	}
}
