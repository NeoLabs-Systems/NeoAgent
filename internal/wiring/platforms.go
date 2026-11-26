package wiring

import (
	"context"
	"os"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"

	"github.com/NeoLabs-Systems/neoagent/internal/android"
	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/mcpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/discord"
	msggithub "github.com/NeoLabs-Systems/neoagent/internal/messaging/github"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/httpplatforms"
	msgslack "github.com/NeoLabs-Systems/neoagent/internal/messaging/slack"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/telegram"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging/whatsapp"
	"github.com/NeoLabs-Systems/neoagent/internal/skills"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
)

// messagingFactories is every chat platform the server can connect.
func messagingFactories(db *dbx.DB, intSvc *integrations.Services, media inboundMedia) map[string]messaging.Factory {
	factories := httpplatforms.Factories(httpplatforms.Deps{})
	factories["telegram"] = telegram.Factory(telegram.Deps{})
	factories["discord"] = discord.Factory(discord.Deps{Media: discordMedia{media}})
	factories["slack"] = msgslack.Factory(msgslack.Deps{})
	factories["github"] = msggithub.Factory(msggithub.Deps{Credentials: githubMentions{intSvc}, Cursors: githubCursors{db}})
	factories["whatsapp"] = whatsapp.Factory(whatsapp.Deps{Media: whatsappMedia{media}, AgentName: agentDisplayName(db)})
	return factories
}

func newSkillsSh() *skills.SkillsSh {
	return skills.NewSkillsSh(skills.SkillsShConfig{Client: ssrf.NewClient(ssrf.Options{}), GithubToken: os.Getenv("GITHUB_TOKEN")})
}

// mcpRedirectURL is where an MCP server's OAuth sign-in returns to.
func mcpRedirectURL(cfg config.Config) string {
	base := strings.TrimRight(cfg.PublicURL, "/")
	if base == "" {
		base = "http://localhost:" + strconv.Itoa(cfg.Port)
	}
	return base + "/api/mcp/oauth/callback"
}

// publishMCPStatus hands a server's state change to the MCP trigger.
func publishMCPStatus(rt *tasks.Runtime, e mcpserver.StatusEvent) {
	// A stopped server carries no account, and no trigger waits for it.
	if rt == nil || e.UserID == 0 {
		return
	}
	rt.HandleEvent("mcp", "server_status", map[string]any{
		"userId": e.UserID, "agentId": e.AgentID, "serverId": e.ServerID, "serverName": e.ServerName,
		"status": e.Status, "previousStatus": e.PreviousStatus, "changedAt": e.ChangedAt, "error": e.Error,
	})
}

// androidArtifacts keeps emulator screenshots in the artifact store.
type androidArtifacts struct{ store *artifacts.Store }

func (a androidArtifacts) CreateBufferArtifact(ctx context.Context, userID string, in android.BufferArtifact) (string, error) {
	stored, err := a.store.CreateBufferArtifact(ctx, userID, artifacts.File{
		Kind: in.Kind, Backend: in.Backend, Extension: in.Extension, ContentType: in.ContentType,
		FilenameBase: in.FilenameBase, Content: in.Content,
	})
	return stored.URL, err
}

// checkIntentURL refuses web addresses an Android intent must not open.
func checkIntentURL(ctx context.Context, raw string) (bool, string, error) {
	verdict, err := cloudsec.Checker{}.Validate(ctx, raw)
	return verdict.Allowed, verdict.Reason, err
}
