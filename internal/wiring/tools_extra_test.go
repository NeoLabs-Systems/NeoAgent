package wiring

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/handlers"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

func TestNextcloudLocalPathsStayInTheWorkspace(t *testing.T) {
	ws, err := workspace.New(filepath.Join(t.TempDir(), "ws"), false)
	if err != nil {
		t.Fatal(err)
	}
	root, _ := ws.Root("1")
	if err := os.WriteFile(filepath.Join(root, "report.pdf"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	ti := toolIntegrations{workspaces: ws}
	run := &handlers.Run{UserID: 1}
	ctx := context.Background()

	if _, refusal := ti.confineLocalPaths(ctx, run, "nextcloud_download_file", dyn.Map{"destination_path": "/etc/cron.d/evil"}); refusal == "" {
		t.Fatal("a download outside the workspace was allowed")
	}
	args, refusal := ti.confineLocalPaths(ctx, run, "nextcloud_download_file", dyn.Map{"destination_path": "out/a.txt"})
	if refusal != "" || !strings.HasPrefix(dyn.Str(args["destination_path"]), root) {
		t.Fatalf("%v %q", args, refusal)
	}
	if _, refusal := ti.confineLocalPaths(ctx, run, "nextcloud_upload_file", dyn.Map{"file_path": "/etc/passwd"}); refusal == "" {
		t.Fatal("an upload of a host file was allowed")
	}
	args, refusal = ti.confineLocalPaths(ctx, run, "nextcloud_upload_file", dyn.Map{"file_path": "report.pdf"})
	if refusal != "" || !strings.HasSuffix(dyn.Str(args["file_path"]), "report.pdf") {
		t.Fatalf("%v %q", args, refusal)
	}
	if args, refusal := ti.confineLocalPaths(ctx, run, "nextcloud_list", dyn.Map{"path": "/"}); refusal != "" || args["path"] != "/" {
		t.Fatal("other tools must pass through")
	}
}
