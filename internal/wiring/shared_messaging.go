package wiring

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/sharedmessaging"
)

// sharedAdmin backs /api/admin/messaging: the instance-wide accounts, with a
// reconcile after every change so it applies at once (the CLI's changes are
// picked up by the reconcile timer).
type sharedAdmin struct {
	store  *sharedmessaging.Store
	shared *messaging.SharedConnections
}

func (s sharedAdmin) list(ctx context.Context) (any, error) { return s.store.AdminOverview(ctx) }

func boolField(body map[string]any, key string) *bool {
	if v, ok := body[key].(bool); ok {
		return &v
	}
	return nil
}

func (s sharedAdmin) update(ctx context.Context, platform string, body map[string]any) (any, error) {
	in := sharedmessaging.Input{
		Enabled: boolField(body, "enabled"), Available: boolField(body, "available"), AllowPersonal: boolField(body, "allowPersonal"),
		Reconnect: body["reconnect"] == true,
	}
	if token, ok := body["botToken"].(string); ok {
		in.BotToken = &token
	}
	if err := s.store.Configure(ctx, platform, in, "app"); err != nil {
		return nil, err
	}
	return s.overview(ctx)
}

func (s sharedAdmin) remove(ctx context.Context, platform string) (any, error) {
	if err := s.store.Remove(ctx, platform, "app"); err != nil {
		return nil, err
	}
	return s.overview(ctx)
}

func (s sharedAdmin) overview(ctx context.Context) (any, error) {
	if err := s.shared.Reconcile(ctx); err != nil {
		return nil, err
	}
	list, err := s.store.AdminOverview(ctx)
	if err != nil {
		return nil, err
	}
	return map[string]any{"connections": list}, nil
}
