package wiring

import (
	"context"
	"strconv"
	"sync/atomic"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/homeassistant"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/neocloud"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/neorecall"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/phone"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/tailscale"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/whatsapppersonal"
	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// integrationsBatch2 are Home Assistant, NeoCloud, NeoRecall, phone sharing,
// Tailscale and personal WhatsApp. Some need components built after the
// integrations (the tasks runtime, the computer runtime); bind connects them.
type integrationsBatch2 struct {
	tailscale *tailscale.Provider
	tasks     atomic.Pointer[tasks.Runtime]
}

// addIntegrationsBatch2 appends the providers to the registration list.
func addIntegrationsBatch2(providers *[]integrations.Provider, svc *integrations.Services, db *dbx.DB, box *secretbox.Box, emitter *deferredEmitter, agentDataDir string) *integrationsBatch2 {
	b := &integrationsBatch2{tailscale: tailscale.New(svc)}
	wa := whatsapppersonal.New(svc, whatsapppersonal.Options{AgentDataDir: agentDataDir, OnMessage: b.whatsappMessage})
	*providers = append(*providers,
		homeassistant.New(svc, homeassistant.Options{}),
		neocloud.New(svc, neocloud.Options{}),
		neorecall.New(svc, neorecall.Options{}),
		phone.New(svc, phone.Options{
			Store: &mobilesync.Phone{DB: db, Box: box},
			Wake: func(userID int64, deviceID string) {
				emitter.EmitToUser(userID, "device_sync:wake", map[string]any{"deviceId": deviceID})
			},
		}),
		b.tailscale,
		wa,
	)
	return b
}

// bind connects the late collaborators.
func (b *integrationsBatch2) bind(mgr *integrations.Manager, taskRt *tasks.Runtime) {
	b.tailscale.SetLocker(mgr.LockConnection)
	b.tasks.Store(taskRt)
}

// bindComputer gives Tailscale the computer runtime its node runs in.
func (b *integrationsBatch2) bindComputer(m *runtime.Manager) {
	b.tailscale.SetComputer(tailscaleComputer{m: m})
}

// whatsappMessage fires the tasks triggered by a personal WhatsApp message.
func (b *integrationsBatch2) whatsappMessage(e whatsapppersonal.MessageEvent) {
	rt := b.tasks.Load()
	if rt == nil {
		return
	}
	rt.HandleEvent("whatsapp_personal", "message", map[string]any{
		"userId": e.UserID, "agentId": e.AgentID, "connectionId": e.ConnectionID, "chatId": e.ChatID,
		"sender": e.Sender, "senderTag": e.SenderTag, "messageId": e.MessageID, "text": e.Text,
		"timestamp": e.Timestamp, "isGroup": e.IsGroup,
	})
}

// tailscaleComputer reaches the guest agent of a user's cloud computer.
type tailscaleComputer struct{ m *runtime.Manager }

func (t tailscaleComputer) Isolated() bool { return t.m != nil && t.m.Backend() != nil }

func (t tailscaleComputer) Request(ctx context.Context, userID int64, method, path string, body any, o tailscale.ComputerRequest) (map[string]any, error) {
	return guestMap(t.m.RequestComputer(ctx, strconv.FormatInt(userID, 10), method, path, body, "cloud", runtime.RequestOptions{
		Timeout: o.Timeout, MaxResponseBytes: o.MaxResponseBytes, Retries: runtime.Retries(0),
	}))
}
