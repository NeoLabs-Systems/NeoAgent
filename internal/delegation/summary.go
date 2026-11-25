package delegation

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

func (s *Service) setByUser(ctx context.Context, setBy int64) any {
	if setBy == 0 {
		return nil
	}
	return publicUser(ctx, s.db.R, setBy)
}

// Summary is everything the Team page shows for userID.
func (s *Service) Summary(ctx context.Context, userID int64, isAdmin bool) (*jsonobj.Object, error) {
	resolved, err := s.Resolve(ctx, userID)
	if err != nil {
		return nil, err
	}
	perms := make([]*jsonobj.Object, 0, len(Permissions))
	for _, k := range Permissions {
		g := resolved[k]
		perms = append(perms, jsonobj.New("key", k, "allowed", g.Allowed, "setBy", s.setByUser(ctx, g.SetBy)))
	}
	var managedBy any
	if d, err := getDelegation(ctx, s.db.R, userID); err != nil {
		return nil, err
	} else if d != nil {
		chain, err := s.managerChain(ctx, s.db.R, userID)
		if err != nil {
			return nil, err
		}
		hops := make([]any, 0, len(chain))
		for _, h := range chain {
			hops = append(hops, publicUser(ctx, s.db.R, h.manager))
		}
		managedBy = jsonobj.New("manager", publicUser(ctx, s.db.R, d.manager), "since", d.since, "chain", hops)
	}
	direct, err := listDirectlyManaged(ctx, s.db.R, userID)
	if err != nil {
		return nil, err
	}
	managing := make([]*jsonobj.Object, 0, len(direct))
	for _, row := range direct {
		theirs, err := s.Resolve(ctx, row.managed)
		if err != nil {
			return nil, err
		}
		// A manager can only change what they hold themselves; anything an
		// upstream manager took away from them is shown but read-only.
		list := make([]*jsonobj.Object, 0, len(Permissions))
		for _, k := range Permissions {
			g := theirs[k]
			list = append(list, jsonobj.New("key", k, "allowed", g.Allowed, "editable", resolved[k].Allowed, "setBy", s.setByUser(ctx, g.SetBy)))
		}
		managing = append(managing, jsonobj.New("user", publicUser(ctx, s.db.R, row.managed), "since", row.since, "permissions", list))
	}
	invites, err := s.ListInvites(ctx, userID)
	if err != nil {
		return nil, err
	}
	return jsonobj.New(
		"isAdmin", isAdmin,
		"catalog", Permissions,
		"maxDepth", MaxChainDepth,
		"permissions", perms,
		"managedBy", managedBy,
		"managing", managing,
		"invites", invites,
	), nil
}

// ManagerLocks are the categories a manager has turned off for userID.
func (s *Service) ManagerLocks(ctx context.Context, userID int64) (map[string]any, error) {
	resolved, err := s.Resolve(ctx, userID)
	if err != nil {
		return nil, err
	}
	locks := map[string]any{}
	for k, g := range resolved {
		if !g.Allowed {
			locks[k] = publicUser(ctx, s.db.R, g.SetBy)
		}
	}
	return locks, nil
}
