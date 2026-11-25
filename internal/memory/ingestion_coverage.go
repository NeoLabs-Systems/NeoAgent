package memory

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Integrations reach memory only through the mail sweep, so only mail apps of
// providers with a sweep collector count as feeding memory.
func (s *IngestionService) sweepDomains(providerKey, appKey string) []string {
	canSweep := false
	if s.integ != nil {
		_, canSweep = s.integ.SweepProvider(providerKey)
	}
	domains := []string{}
	if canSweep {
		for _, t := range SourceTypesForConnection(providerKey, appKey) {
			if t == "email" {
				domains = append(domains, t)
			}
		}
	}
	return domains
}

// ConnectionStatus is how one connection feeds memory.
type ConnectionStatus struct {
	ConnectionID int64   `json:"connectionId"`
	ProviderKey  string  `json:"providerKey"`
	AppKey       string  `json:"appKey"`
	AccountEmail *string `json:"accountEmail"`
	Coverage
	Sweep *jsx.Obj `json:"sweep"`
}

func latestJobFor(jobs []IngestionJob, connectionID int64) *IngestionJob {
	for i := range jobs {
		var id int64
		if jobs[i].ConnectionID != nil {
			id = *jobs[i].ConnectionID
		}
		if id == connectionID {
			return &jobs[i]
		}
	}
	return nil
}

// ListConnectionStatuses lists the connections of an agent with their memory coverage.
func (s *IngestionService) ListConnectionStatuses(ctx context.Context, userID int64, agentID string) ([]ConnectionStatus, error) {
	scoped, err := s.mm.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	connections, err := s.connections(ctx, `SELECT id, user_id, agent_id, provider_key, app_key, status, account_email, metadata_json
     FROM integration_connections
     WHERE user_id = ? AND agent_id = ?
     ORDER BY updated_at DESC, id DESC`, userID, scoped)
	if err != nil {
		return nil, err
	}
	jobs, err := s.mm.ListIngestionJobs(ctx, userID, JobFilter{AgentID: scoped, Limit: 100})
	if err != nil {
		return nil, err
	}
	out := make([]ConnectionStatus, len(connections))
	for i, c := range connections {
		out[i] = ConnectionStatus{
			ConnectionID: c.ID, ProviderKey: c.ProviderKey, AppKey: c.AppKey, AccountEmail: nonEmptyPtr(c.AccountEmail),
			Coverage: buildCoverageForConnection(c.Status, latestJobFor(jobs, c.ID), s.sweepDomains(c.ProviderKey, c.AppKey)),
			Sweep:    s.SweepProgress(c.ID),
		}
	}
	return out, nil
}

func (c Coverage) obj() *jsx.Obj {
	domains := make([]any, len(c.DomainsOrEmpty()))
	for i, d := range c.DomainsOrEmpty() {
		domains[i] = d
	}
	return jsx.O("supported", c.Supported, "contributesToMemory", c.ContributesToMemory,
		"contributesToTaskExecution", c.ContributesToTaskExecution, "status", c.Status, "dataDomains", domains,
		"lastRefreshAt", strPtr(c.LastRefreshAt), "documentCount", c.DocumentCount, "error", strPtr(c.Error))
}

// DomainsOrEmpty is the data domains, never nil.
func (c Coverage) DomainsOrEmpty() []string {
	if c.DataDomains == nil {
		return []string{}
	}
	return c.DataDomains
}

func asList(v any) []any {
	list, _ := v.([]any)
	return list
}

func connectedFlag(o *jsx.Obj) bool {
	conn, ok := o.Value("connection").(*jsx.Obj)
	return ok && conn.Value("connected") == true
}

// DecorateProviderSnapshot adds the memory coverage of a provider, its apps and
// their accounts to an integrations snapshot.
func (s *IngestionService) DecorateProviderSnapshot(ctx context.Context, snapshot *jsx.Obj, userID int64, agentID string) (*jsx.Obj, error) {
	if snapshot == nil {
		return nil, nil
	}
	providerKey := jsString(snapshot.Value("id"))
	scoped, err := s.mm.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	connections, err := s.connections(ctx, `SELECT id, user_id, agent_id, provider_key, app_key, status, account_email, metadata_json
     FROM integration_connections
     WHERE user_id = ? AND agent_id = ? AND provider_key = ?`, userID, scoped, providerKey)
	if err != nil {
		return nil, err
	}
	jobs, err := s.mm.ListIngestionJobs(ctx, userID, JobFilter{AgentID: scoped, ProviderKey: providerKey, Limit: 100})
	if err != nil {
		return nil, err
	}

	type item struct {
		connectionID int64
		appKey       string
		coverage     Coverage
		obj          *jsx.Obj
	}
	var items []item
	for _, c := range connections {
		coverage := buildCoverageForConnection(c.Status, latestJobFor(jobs, c.ID), s.sweepDomains(providerKey, c.AppKey))
		var sweep any
		if p := s.SweepProgress(c.ID); p != nil {
			sweep = p
		}
		obj := jsx.O("connectionId", c.ID, "appKey", c.AppKey, "accountEmail", strPtr(nonEmptyPtr(c.AccountEmail))).Assign(coverage.obj())
		obj.Set("sweep", sweep)
		items = append(items, item{c.ID, c.AppKey, coverage, obj})
	}
	providerDomains := newOrderedSet()
	documentTotal := 0
	for _, it := range items {
		providerDomains.add(it.coverage.DomainsOrEmpty()...)
		documentTotal += it.coverage.DocumentCount
	}
	var providerJob *IngestionJob
	if len(jobs) > 0 {
		providerJob = &jobs[0]
	}
	providerStatus := "not_supported"
	if len(providerDomains.items) > 0 {
		providerStatus = "ready"
	}
	var providerRefresh, providerError *string
	if providerJob != nil {
		if providerJob.Status != "" {
			providerStatus = providerJob.Status
		}
		providerRefresh = firstNonNil(providerJob.CompletedAt, providerJob.UpdatedAt)
		providerError = providerJob.Error
	}
	domainList := make([]any, len(providerDomains.items))
	for i, d := range providerDomains.items {
		domainList[i] = d
	}
	decorated := snapshot.Clone()
	decorated.Set("memoryCoverage", jsx.O(
		"supported", len(domainList) > 0, "contributesToMemory", len(domainList) > 0,
		"contributesToTaskExecution", connectedFlag(snapshot), "status", providerStatus, "dataDomains", domainList,
		"documentCount", documentTotal, "lastRefreshAt", strPtr(providerRefresh), "error", strPtr(providerError)))

	apps := []any{}
	for _, rawApp := range asList(snapshot.Value("apps")) {
		app, ok := rawApp.(*jsx.Obj)
		if !ok {
			apps = append(apps, rawApp)
			continue
		}
		appID := app.Value("id")
		var appItems []item
		for _, it := range items {
			if appID == it.appKey {
				appItems = append(appItems, it)
			}
		}
		dataDomains := s.sweepDomains(providerKey, jsString(appID))
		domains := make([]any, len(dataDomains))
		for i, d := range dataDomains {
			domains[i] = d
		}
		supported := len(dataDomains) > 0
		connected := connectedFlag(app)
		status := "not_supported"
		if supported {
			status = "ready"
		}
		var refresh, errText *string
		appDocs := 0
		for _, it := range appItems {
			appDocs += it.coverage.DocumentCount
		}
		if len(appItems) > 0 {
			latest := appItems[0].coverage
			if latest.Status != "" {
				status = latest.Status
			}
			refresh, errText = latest.LastRefreshAt, latest.Error
		}
		decoratedApp := app.Clone()
		decoratedApp.Set("memorySweep", supported)
		decoratedApp.Set("memoryCoverage", jsx.O(
			"supported", supported, "contributesToMemory", supported && connected, "contributesToTaskExecution", connected,
			"status", status, "dataDomains", domains, "documentCount", appDocs,
			"lastRefreshAt", strPtr(refresh), "error", strPtr(errText)))

		accounts := []any{}
		for _, rawAccount := range asList(app.Value("accounts")) {
			account, ok := rawAccount.(*jsx.Obj)
			if !ok {
				accounts = append(accounts, rawAccount)
				continue
			}
			var coverage any
			accountID := jsx.ToNumber(account.Value("connectionId"))
			for _, it := range appItems {
				if float64(it.connectionID) == accountID {
					coverage = it.obj
					break
				}
			}
			if coverage == nil {
				accountStatus := "not_supported"
				if supported {
					accountStatus = "ready"
				}
				coverage = jsx.O("supported", supported, "contributesToMemory", false, "contributesToTaskExecution", connected,
					"status", accountStatus, "dataDomains", domains, "documentCount", 0, "lastRefreshAt", nil, "error", nil)
			}
			decoratedAccount := account.Clone()
			decoratedAccount.Set("memoryCoverage", coverage)
			accounts = append(accounts, decoratedAccount)
		}
		decoratedApp.Set("accounts", accounts)
		apps = append(apps, decoratedApp)
	}
	decorated.Set("apps", apps)
	return decorated, nil
}
