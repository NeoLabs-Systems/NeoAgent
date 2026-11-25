package wiring

import (
	"context"
	"os"
	"strings"

	nlrelease "github.com/NeoLabs-Systems/neolabs-go/cli/release"

	"github.com/NeoLabs-Systems/neoagent/internal/admin"
	"github.com/NeoLabs-Systems/neoagent/internal/buildinfo"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/release"
)

// adminUpdates lets the admin UI check for and start updates: the newest
// release that carries a signed runtime manifest is what `neoagent update`
// would install.
func adminUpdates(cfg config.Config) *admin.UpdateDeps {
	exe, _ := os.Executable()
	client := &nlrelease.Client{UserAgent: "NeoAgent " + buildinfo.Version}
	return &admin.UpdateDeps{
		DataDir: cfg.Paths.DataDir,
		LogDir:  cfg.Paths.LogDir,
		Exe:     exe,
		Latest: func(ctx context.Context, channel string) (string, error) {
			rel, err := client.ResolveRelease(ctx, release.Repository, channel, release.RuntimeManifestPrefix)
			if err != nil {
				return "", err
			}
			return strings.TrimPrefix(rel.Tag, "v"), nil
		},
	}
}
