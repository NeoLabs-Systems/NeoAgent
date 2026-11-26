package wiring

import (
	"os"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/ssrf"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/versioninfo"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"github.com/NeoLabs-Systems/neoagent/internal/wearable"
)

// newWearable builds the server side of the ESP32 wearables: the
// /api/wearable routes, the voice socket and the connection trigger.
// No GeoIP database is bundled, so the time zone route answers with the
// server's own zone.
func newWearable(d Deps, voiceMgr *voice.Manager, taskRt *tasks.Runtime, sanitize func(string) string) (*wearable.API, *wearable.Gateway) {
	env := wearable.FirmwareEnvFrom(os.Getenv)
	svc := wearable.NewService(wearable.ServiceConfig{
		Voice: voiceMgr,
		Version: func() wearable.VersionInfo {
			return wearable.VersionInfo{Version: d.Version, Info: versioninfo.Info(os.Getenv)}
		},
		PublicURL:  d.Cfg.PublicURL,
		Firmware:   &wearable.FirmwareResolver{Client: ssrf.NewClient(ssrf.Options{Timeout: 15 * time.Second})},
		Env:        env,
		TrustProxy: d.Cfg.TrustProxy,
	})
	svc.OnConnectionChanged(func(c wearable.ConnectionChange) {
		taskRt.HandleEvent("wearable", "connection_changed", map[string]any{
			"userId": c.UserID, "deviceId": c.DeviceID, "deviceLabel": c.DeviceLabel,
			"transition": c.Transition, "occurredAt": c.OccurredAt,
		})
	})
	api := wearable.NewAPI(wearable.RoutesConfig{Service: svc, Sanitize: sanitize})
	gateway := wearable.NewGateway(wearable.GatewayConfig{
		Service: svc, Voice: voiceMgr, Log: d.Log, TrustProxy: d.Cfg.TrustProxy, Sanitize: sanitize,
	})
	return api, gateway
}
