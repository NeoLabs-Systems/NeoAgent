package wiring

import (
	"context"
	"encoding/json"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// ingestionIntegrations lets memory ingestion sweep the past mail of
// connected accounts through the integrations that have a collector.
type ingestionIntegrations struct {
	mgr *integrations.Manager
	svc *integrations.Services
}

func (i ingestionIntegrations) SweepProvider(providerKey string) (memory.SweepProvider, bool) {
	s, ok := i.mgr.Provider(providerKey).(integrations.MemorySweeper)
	if !ok || !s.CanSweep() {
		return nil, false
	}
	return mailSweeper{i: i, s: s}, true
}

func (i ingestionIntegrations) SaveRefreshedCredentials(conn memory.Connection, credentials any) {
	creds, ok := credentials.(oauthclient.Credentials)
	if !ok || creds == nil {
		return
	}
	full, err := i.svc.ConnectionByID(context.Background(), conn.UserID, conn.ID, conn.AgentID)
	if err != nil || full == nil {
		return
	}
	_ = i.svc.SaveRefreshedCredentials(context.Background(), *full, creds)
}

type mailSweeper struct {
	i ingestionIntegrations
	s integrations.MemorySweeper
}

func (m mailSweeper) CollectMemorySweep(ctx context.Context, req memory.SweepRequest) (memory.SweepResult, error) {
	conn, err := m.i.svc.ConnectionByID(ctx, req.Connection.UserID, req.Connection.ID, req.Connection.AgentID)
	if err != nil {
		return memory.SweepResult{}, err
	}
	if conn == nil {
		return memory.SweepResult{}, nil
	}
	out, err := m.s.CollectMemorySweep(ctx, *conn, integrations.SweepInput{
		SourceTypes: req.SourceTypes, SkipObjectIDs: req.SkipObjectIDs, OnProgress: req.OnProgress,
	})
	if err != nil {
		return memory.SweepResult{}, err
	}
	res := memory.SweepResult{Documents: out.Documents, Cursor: out.Cursor}
	if out.Credentials != nil {
		res.Credentials = out.Credentials
	}
	return res, nil
}

// decorateWithCoverage adds what memory ingestion knows about a provider (its
// memory coverage, and per app whether connecting sweeps past mail) to an
// integrations snapshot.
func decorateWithCoverage(ing *memory.IngestionService) func(ctx context.Context, snap *integrations.Snapshot, userID int64, agentID string) {
	return func(ctx context.Context, snap *integrations.Snapshot, userID int64, agentID string) {
		raw, err := json.Marshal(snap)
		if err != nil {
			return
		}
		decorated, err := ing.DecorateProviderSnapshot(ctx, jsx.ParseObject(string(raw)), userID, agentID)
		if err != nil || decorated == nil {
			return
		}
		out := []byte(jsx.Marshal(decorated))
		snap.Decorated = out
		var coverage map[string]any
		var whole map[string]json.RawMessage
		if json.Unmarshal(out, &whole) == nil && json.Unmarshal(whole["memoryCoverage"], &coverage) == nil {
			if snap.Extra == nil {
				snap.Extra = map[string]any{}
			}
			snap.Extra["memoryCoverage"] = coverage
		}
	}
}
