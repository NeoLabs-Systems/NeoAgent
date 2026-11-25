// Package socialreach reads public sources the agent can look at (GitHub,
// Reddit, V2EX, RSS, X posts, Xueqiu, social videos) and keeps the cookies an
// account imported from its cloud computer's browser for the two platforms
// that need them.
package socialreach

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/socialvideo"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

const (
	maxImportedCookies = 80
	maxCookieName      = 256
	maxCookieValue     = 4096
)

// CloudBrowser is the browser of an account's cloud computer.
type CloudBrowser interface {
	// GetCookies returns the browser's cookies as objects with name, value,
	// domain, path, secure, httpOnly, sameSite and expirationDate / expires.
	GetCookies(ctx context.Context) ([]map[string]any, error)
}

// Runtime finds the cloud browser of an account.
type Runtime interface {
	BrowserForUser(ctx context.Context, userID int64) (CloudBrowser, error)
}

// Config wires the service. Runtime and Video are optional.
type Config struct {
	DB  *dbx.DB
	Box *secretbox.Box
	// Runtime lets an account import cookies from its cloud computer.
	Runtime Runtime
	// Video answers social video links.
	Video socialvideo.Extractor
	// HTTP reaches the public APIs. The default refuses internal addresses;
	// tests may pass their own.
	HTTP *http.Client
}

// Service reads sources and manages cookies.
type Service struct {
	cfg      Config
	cookies  *cookieStore
	channels []channel
}

// New builds the service.
func New(cfg Config) *Service {
	client := cfg.HTTP
	if client == nil {
		client = ssrf.NewClient(ssrf.Options{Timeout: fetchTimeout})
	}
	f := fetcher{client: client}
	store := &cookieStore{db: cfg.DB, box: cfg.Box}
	s := &Service{cfg: cfg, cookies: store}
	// The order decides which channel claims a link first.
	s.channels = []channel{newGithub(f), newX(f, store), newVideo(cfg.Video), newReddit(f), newRSS(f), newV2ex(f), newXueqiu(f, store)}
	return s
}

func (s *Service) channel(platform string) channel {
	id := normalizePlatformID(platform)
	for _, c := range s.channels {
		if c.id() == id {
			return c
		}
	}
	return nil
}

func (s *Service) channelForURL(value any) (channel, error) {
	u, err := assertHTTPURL(value)
	if err != nil {
		return nil, err
	}
	if u.Path == "" {
		u.Path = "/"
	}
	for _, c := range s.channels {
		if c.canHandleURL(u.String()) {
			return c, nil
		}
	}
	return nil, nil
}

// Status reports, per platform, whether it can be used.
func (s *Service) Status(ctx context.Context, userID int64) (any, error) {
	statuses := []any{}
	for _, c := range s.channels {
		status, err := c.check(ctx, userID)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			status = obj{{"platform", c.id()}, {"label", c.label()}, {"ready", false}, {"status", "error"}, {"activeBackend", nil},
				{"tier", c.tier()}, {"setupKind", c.setupKind()}, {"message", err.Error()}}
		} else if c.setupKind() == "cookies" && !hasKey(status, "cookie") {
			status.set("cookie", s.cookies.summary(ctx, userID, c.id()))
		}
		statuses = append(statuses, status)
	}
	return obj{{"platforms", statuses}, {"generatedAt", time.Now().UTC().Format("2006-01-02T15:04:05.000Z")}}, nil
}

func hasKey(o obj, key string) bool {
	for _, f := range o {
		if f.K == key {
			return true
		}
	}
	return false
}

// Read reads a link or a symbol from the platform named in the request, or
// the one that owns the link.
func (s *Service) Read(ctx context.Context, userID int64, body map[string]any) (any, error) {
	platform := normalizePlatformID(str(body["platform"]))
	var c channel
	if platform != "" {
		c = s.channel(platform)
	} else {
		var err error
		if c, err = s.channelForURL(body["url"]); err != nil {
			return nil, err
		}
	}
	if c == nil {
		if platform != "" {
			return nil, badRequest(platform + " is not available in Social Reach.")
		}
		return nil, badRequest("This link is not available in Social Reach. Use the browser reader for general web pages.")
	}
	return c.read(ctx, readArgs{userID, body})
}

// Search searches the platform named in the request.
func (s *Service) Search(ctx context.Context, userID int64, body map[string]any) (any, error) {
	c := s.channel(str(body["platform"]))
	if c == nil {
		return nil, badRequest("Choose a searchable Social Reach platform.")
	}
	return c.search(ctx, readArgs{userID, body})
}

// ImportCookies copies the cloud browser's cookies for a platform.
func (s *Service) ImportCookies(ctx context.Context, userID int64, platform string) (any, error) {
	id := normalizePlatformID(platform)
	def, known := platformDefinition(id)
	if !known || (id != "xueqiu" && id != "x") {
		label := def.Label
		if label == "" {
			label = id
		}
		if label == "" {
			label = "Platform"
		}
		return nil, badRequest(label + " does not support cookie import yet.")
	}
	if s.cfg.Runtime == nil {
		return nil, &reachError{503, "Cloud computer browser is unavailable."}
	}
	browser, err := s.cfg.Runtime.BrowserForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	raw, err := browser.GetCookies(ctx)
	if err != nil {
		return nil, err
	}
	cookies := sanitizeCookies(raw, def.Domains)
	if len(cookies) == 0 {
		return nil, &reachError{422, "No " + def.Label + " cookies were found in the cloud computer browser profile. Log in first, then import again."}
	}
	bundle, err := s.cookies.write(ctx, userID, id, cookies)
	if err != nil {
		return nil, err
	}
	return obj{{"platform", id}, {"configured", true}, {"count", len(cookies)}, {"importedAt", bundle.ImportedAt}}, nil
}

// ClearCookies forgets a platform's cookies.
func (s *Service) ClearCookies(ctx context.Context, userID int64, platform string) (any, error) {
	id := normalizePlatformID(platform)
	if err := s.cookies.delete(ctx, userID, id); err != nil {
		return nil, err
	}
	return obj{{"platform", id}, {"configured", false}, {"count", 0}}, nil
}

// sanitizeCookies keeps well-formed cookies of the allowed domains.
func sanitizeCookies(cookies []map[string]any, allowed []string) []map[string]any {
	out := []map[string]any{}
	for _, c := range cookies {
		if len(out) == maxImportedCookies {
			break
		}
		if c == nil || !truthy(c["name"]) || c["value"] == nil {
			continue
		}
		if len(units(text(c["name"]))) > maxCookieName || len(units(text(c["value"]))) > maxCookieValue {
			continue
		}
		domain := strings.ToLower(strings.TrimPrefix(str(c["domain"]), "."))
		match := false
		for _, a := range allowed {
			if domain == a || strings.HasSuffix(domain, "."+a) {
				match = true
			}
		}
		if !match {
			continue
		}
		path := str(c["path"])
		if path == "" {
			path = "/"
		}
		out = append(out, map[string]any{
			"name": text(c["name"]), "value": text(c["value"]), "domain": str(c["domain"]), "path": path,
			"secure": c["secure"] == true, "httpOnly": c["httpOnly"] == true,
			"sameSite":       or(c["sameSite"], nil),
			"expirationDate": or(c["expirationDate"], c["expires"], nil),
		})
	}
	return out
}
