package config

import (
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/testkit"
)

func load(t *testing.T, env map[string]string) (Config, error) {
	t.Helper()
	return Load(testkit.Env(env), "/home/u", "/app")
}

func TestDefaults(t *testing.T) {
	c, err := load(t, map[string]string{})
	if err != nil {
		t.Fatal(err)
	}
	if c.Port != 3333 || c.SecureCookie || c.TrustProxy || c.Production {
		t.Fatalf("%+v", c)
	}
	if c.WebDir != "/app/server/public" || c.Landing != "/app/landing" || c.Paths.Home != "/home/u/.neoagent" {
		t.Fatalf("paths: %+v", c)
	}
	if !c.EphemeralSessionSecret || len(c.SessionSecret) != 64 {
		t.Fatal("without SESSION_SECRET a random ephemeral secret is used outside production")
	}
	if c.HSTSMaxAgeSeconds != 86400 || !c.CSP.UnsafeEval || !c.CSP.ExternalScriptCDN || !c.CSP.ExternalConnect {
		t.Fatalf("csp defaults: %+v", c)
	}
}

func TestHTTPSPublicURLImpliesSecureCookiesAndProxyTrust(t *testing.T) {
	c, _ := load(t, map[string]string{"PUBLIC_URL": "https://agent.example.com", "SESSION_SECRET": "s3cure"})
	if !c.SecureCookie || !c.TrustProxy || c.EphemeralSessionSecret || c.SessionSecret != "s3cure" {
		t.Fatalf("%+v", c)
	}
	c, _ = load(t, map[string]string{"PUBLIC_URL": "https://x", "SECURE_COOKIES": "false", "TRUST_PROXY": "no"})
	if c.SecureCookie || c.TrustProxy {
		t.Fatal("explicit flags win")
	}
}

func TestProductionRefusesMissingOrPlaceholderSecret(t *testing.T) {
	for _, secret := range []string{"", "  ", "change-me-to-something-random", "neoagent-dev-secret-change-me"} {
		_, err := load(t, map[string]string{"NODE_ENV": "production", "SESSION_SECRET": secret})
		if err == nil || !strings.Contains(err.Error(), "SESSION_SECRET") {
			t.Fatalf("secret %q must be refused in production, got %v", secret, err)
		}
	}
	if _, err := load(t, map[string]string{"NEOAGENT_ENV": "production", "NEOAGENT_ALLOW_SESSION_SECRET_FALLBACK": "true"}); err != nil {
		t.Fatalf("explicit fallback allowed: %v", err)
	}
	if _, err := load(t, map[string]string{"NEOAGENT_ENV": "production", "SESSION_SECRET": "real"}); err != nil {
		t.Fatal(err)
	}
}

func TestInvalidValuesAreRejected(t *testing.T) {
	for k, v := range map[string]string{"PORT": "99999", "NEOAGENT_HSTS_MAX_AGE": "-5"} {
		if _, err := load(t, map[string]string{k: v}); err == nil {
			t.Errorf("%s=%s should be rejected", k, v)
		}
	}
	if c, err := load(t, map[string]string{"PORT": "8080"}); err != nil || c.Port != 8080 {
		t.Fatalf("%v %v", c.Port, err)
	}
}

func TestSecretBoxPrefersEncryptionKey(t *testing.T) {
	both, err := SecretBox(testkit.Env(map[string]string{"NEOAGENT_ENCRYPTION_KEY": "enc", "SESSION_SECRET": "sess"}))
	if err != nil {
		t.Fatal(err)
	}
	sealed, _ := both.Seal("x")
	onlyEnc, _ := SecretBox(testkit.Env(map[string]string{"NEOAGENT_ENCRYPTION_KEY": "enc"}))
	if got, err := onlyEnc.OpenSealed(sealed); err != nil || got != "x" {
		t.Fatal("rotating SESSION_SECRET must not invalidate stored credentials")
	}
	onlySess, _ := SecretBox(testkit.Env(map[string]string{"SESSION_SECRET": "sess"}))
	if _, err := onlySess.OpenSealed(sealed); err == nil {
		t.Fatal("different material must not open")
	}
	if _, err := SecretBox(testkit.Env(nil)); err == nil {
		t.Fatal("no key material must be an error")
	}
}
