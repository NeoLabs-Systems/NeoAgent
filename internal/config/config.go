// Package config turns the NeoAgent environment into one validated value.
// Names and defaults are the ones the Node server used, so existing `.env`
// files and service definitions keep working.
package config

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/oauthlogin"
	"github.com/NeoLabs-Systems/neolabs-go/runtimecfg"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/servicemail"
)

const (
	DefaultPort     = 3333 // setup contract defaultPort
	SecretPrefix    = "enc:v1:"
	CookieName      = "neoagent.sid"
	defaultHSTSSecs = 86400
)

var insecureSessionSecrets = map[string]bool{
	"neoagent-dev-secret-change-me":                true,
	"change-this-to-a-random-secret-in-production": true,
	"change-me-to-something-random":                true,
}

// Config is the resolved runtime configuration.
type Config struct {
	Paths   runtimecfg.Paths
	AppDir  string // root that holds public/ (web client) and landing/
	WebDir  string // Flutter web build
	Landing string

	Port         int
	PublicURL    string
	SecureCookie bool
	TrustProxy   bool
	Production   bool
	Origins      httpx.Origins

	SessionSecret string
	// EphemeralSessionSecret is true when no secure SESSION_SECRET was
	// configured: sessions then do not survive a restart.
	EphemeralSessionSecret bool

	HSTSMaxAgeSeconds int
	CSP               CSPFlags

	// AllowSignup is false when NEOAGENT_ALLOW_SIGNUP turns open registration
	// off: new accounts then need a one-time sign-up key.
	AllowSignup bool
	// AdminUsers are the usernames named in NEOAGENT_ADMIN_USERS. A name with
	// no account behind it is reserved so nobody can register it to take admin.
	AdminUsers []string

	// PublicBaseURL is how clients reach this server: PUBLIC_URL when set,
	// otherwise a localhost address.
	PublicBaseURL string
	// Mail is the service-email setup (confirmation, reset and notice emails).
	Mail servicemail.Config
	// Google is the OAuth client for "Sign in with Google".
	Google oauthlogin.GoogleConfig
}

// CSPFlags are the opt-out switches for the relaxed script/connect sources the
// Flutter web (CanvasKit) build needs. Hardened deployments turn them off.
type CSPFlags struct {
	UnsafeEval        bool
	ExternalScriptCDN bool
	ExternalConnect   bool
}

// Load reads and validates the configuration. getenv is os.Getenv in production.
func Load(getenv func(string) string, userHome, cwd string) (Config, error) {
	var c Config
	c.Paths = runtimecfg.Resolve("NEOAGENT", ".neoagent", getenv, userHome)

	c.AppDir = strings.TrimSpace(getenv("NEOAGENT_APP_DIR"))
	if c.AppDir == "" {
		c.AppDir = cwd
	}
	c.WebDir = firstNonEmpty(getenv("NEOAGENT_WEB_DIR"), c.AppDir+"/public")
	c.Landing = firstNonEmpty(getenv("NEOAGENT_LANDING_DIR"), c.AppDir+"/landing")

	c.Port = DefaultPort
	if raw := strings.TrimSpace(getenv("PORT")); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 || n > 65535 {
			return c, fmt.Errorf("config: PORT %q is not a valid port", raw)
		}
		c.Port = n
	}

	c.PublicURL = strings.TrimSpace(getenv("PUBLIC_URL"))
	httpsURL := strings.HasPrefix(c.PublicURL, "https://")
	c.SecureCookie = runtimecfg.Bool(getenv("SECURE_COOKIES"), httpsURL)
	c.TrustProxy = runtimecfg.Bool(getenv("TRUST_PROXY"), c.SecureCookie || httpsURL)
	c.Production = strings.EqualFold(strings.TrimSpace(firstNonEmpty(getenv("NEOAGENT_ENV"), getenv("NODE_ENV"))), "production")
	c.Origins = httpx.ParseOrigins(getenv("ALLOWED_ORIGINS"))

	secret, ephemeral, err := sessionSecret(getenv, c.Production)
	if err != nil {
		return c, err
	}
	c.SessionSecret, c.EphemeralSessionSecret = secret, ephemeral

	c.HSTSMaxAgeSeconds = defaultHSTSSecs
	if raw := strings.TrimSpace(getenv("NEOAGENT_HSTS_MAX_AGE")); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 0 {
			return c, fmt.Errorf("config: NEOAGENT_HSTS_MAX_AGE %q is not a non-negative number", raw)
		}
		c.HSTSMaxAgeSeconds = n
	}
	c.CSP = CSPFlags{
		UnsafeEval:        runtimecfg.Bool(getenv("NEOAGENT_CSP_ALLOW_UNSAFE_EVAL"), true),
		ExternalScriptCDN: runtimecfg.Bool(getenv("NEOAGENT_CSP_ALLOW_EXTERNAL_SCRIPT_CDN"), true),
		ExternalConnect:   runtimecfg.Bool(getenv("NEOAGENT_CSP_ALLOW_EXTERNAL_CONNECT"), true),
	}
	c.AllowSignup = allowSignup(getenv("NEOAGENT_ALLOW_SIGNUP"))
	for _, name := range strings.Split(getenv("NEOAGENT_ADMIN_USERS"), ",") {
		if name = strings.TrimSpace(name); name != "" {
			c.AdminUsers = append(c.AdminUsers, name)
		}
	}
	c.PublicBaseURL = publicBaseURL(getenv, c.Port)
	c.Mail = servicemail.LoadConfig("NEOAGENT", getenv, "NeoAgent", c.PublicBaseURL)
	c.Google = oauthlogin.GoogleConfig{
		ClientID:     strings.TrimSpace(getenv("GOOGLE_OAUTH_CLIENT_ID")),
		ClientSecret: strings.TrimSpace(getenv("GOOGLE_OAUTH_CLIENT_SECRET")),
		RedirectURI:  firstNonEmpty(getenv("GOOGLE_OAUTH_REDIRECT_URI"), c.PublicBaseURL+"/api/integrations/oauth/callback"),
	}
	return c, nil
}

// publicBaseURL mirrors the Node server: PUBLIC_URL, else localhost with the
// scheme from PUBLIC_URL_SCHEME (https unless running in development).
func publicBaseURL(getenv func(string) string, port int) string {
	if explicit := strings.TrimSpace(getenv("PUBLIC_URL")); explicit != "" {
		return strings.TrimRight(explicit, "/")
	}
	scheme := strings.ToLower(strings.TrimSpace(getenv("PUBLIC_URL_SCHEME")))
	if scheme == "" {
		scheme = "https"
		if strings.TrimSpace(getenv("NODE_ENV")) == "development" {
			scheme = "http"
		}
	}
	return scheme + "://localhost:" + strconv.Itoa(port)
}

// allowSignup mirrors the Node server: only an explicit false/0/no closes sign-up.
func allowSignup(raw string) bool {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "false", "0", "no":
		return false
	}
	return true
}

// sessionSecret enforces the secret rules of the Node server: a placeholder or
// missing SESSION_SECRET is refused in production, and otherwise replaced by a
// random per-process secret.
func sessionSecret(getenv func(string) string, production bool) (secret string, ephemeral bool, err error) {
	configured := strings.TrimSpace(getenv("SESSION_SECRET"))
	if configured != "" && !insecureSessionSecrets[configured] {
		return configured, false, nil
	}
	allowFallback := strings.EqualFold(strings.TrimSpace(getenv("NEOAGENT_ALLOW_SESSION_SECRET_FALLBACK")), "true")
	if production && !allowFallback {
		return "", false, errors.New("config: SESSION_SECRET must be configured with a secure value in production")
	}
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", false, fmt.Errorf("config: generate session secret: %w", err)
	}
	return hex.EncodeToString(buf), true, nil
}

// SecretBox returns the box that protects stored integration credentials. Like
// the Node server it prefers NEOAGENT_ENCRYPTION_KEY so rotating SESSION_SECRET
// does not invalidate stored credentials, and falls back to SESSION_SECRET for
// older installs.
func SecretBox(getenv func(string) string) (*secretbox.Box, error) {
	material := firstNonEmpty(getenv("NEOAGENT_ENCRYPTION_KEY"), getenv("SESSION_SECRET"))
	if material == "" {
		return nil, errors.New("config: NEOAGENT_ENCRYPTION_KEY (or SESSION_SECRET) must be configured")
	}
	return secretbox.New(SecretPrefix, material)
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v = strings.TrimSpace(v); v != "" {
			return v
		}
	}
	return ""
}
