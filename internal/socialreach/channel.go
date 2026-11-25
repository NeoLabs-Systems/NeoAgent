package socialreach

import (
	"context"
	"strings"
)

// readArgs are the members of a read or search request. Values stay loosely
// typed because clients send whatever JavaScript would have accepted.
type readArgs struct {
	userID int64
	body   map[string]any
}

func (a readArgs) get(key string) any { return a.body[key] }

// channel reads one kind of source.
type channel interface {
	id() string
	label() string
	tier() int
	setupKind() string
	canHandleURL(url string) bool
	check(ctx context.Context, userID int64) (obj, error)
	read(ctx context.Context, a readArgs) (any, error)
	search(ctx context.Context, a readArgs) (any, error)
}

// base holds what every channel shares and the defaults Node's base class had.
type base struct{ platform }

func (b base) id() string        { return b.ID }
func (b base) label() string     { return b.Label }
func (b base) tier() int         { return b.Tier }
func (b base) setupKind() string { return b.SetupKind }

func (b base) canHandleURL(raw string) bool {
	if len(b.Hosts) == 0 {
		return false
	}
	u, err := assertAbsolute(raw)
	if err != nil {
		return false
	}
	host := strings.TrimPrefix(strings.ToLower(u.Hostname()), "www.")
	for _, candidate := range b.Hosts {
		c := strings.TrimPrefix(strings.ToLower(candidate), "www.")
		if host == c || strings.HasSuffix(host, "."+c) {
			return true
		}
	}
	return false
}

func (b base) baseStatus() obj {
	return obj{{"platform", b.ID}, {"label", b.Label}, {"ready", true}, {"status", "ok"}, {"activeBackend", "node"},
		{"tier", b.Tier}, {"setupKind", b.SetupKind}, {"message", "Ready."}}
}

func (b base) check(context.Context, int64) (obj, error) { return b.baseStatus(), nil }

func (b base) read(context.Context, readArgs) (any, error) {
	return nil, &reachError{400, b.Label + " reading is not available from this screen."}
}

func (b base) search(context.Context, readArgs) (any, error) {
	return nil, &reachError{400, b.Label + " search is not available from this screen."}
}

func requireQuery(a readArgs) (string, error) {
	q := jsTrim(str(a.get("query")))
	if q == "" {
		return "", badRequest("query is required.")
	}
	return q, nil
}
