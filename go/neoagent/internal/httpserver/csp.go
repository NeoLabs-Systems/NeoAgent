package httpserver

import (
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neolabs-go/secheaders"
)

// permissionsPolicy is what the Node server declared but never sent (helmet has
// no such option). Camera, microphone and location are used by the voice and
// device features; everything else is denied.
const permissionsPolicy = "camera=(self), geolocation=(self), microphone=(self), payment=(), usb=()"

// SecurityHeaders builds the response-header policy. The CSP directive order
// and values reproduce the policy the Node server sent through helmet.
func SecurityHeaders(cfg config.Config, analyticsOrigin string) secheaders.Config {
	scriptSrc := []string{"'self'", "'unsafe-inline'", "blob:"}
	if cfg.CSP.UnsafeEval {
		scriptSrc = append(scriptSrc, "'unsafe-eval'", "'wasm-unsafe-eval'")
	}
	if cfg.CSP.ExternalScriptCDN {
		scriptSrc = append(scriptSrc, "https://cdn.jsdelivr.net", "https://www.gstatic.com")
	}

	connectSrc := []string{"'self'"}
	if cfg.SecureCookie {
		connectSrc = append(connectSrc, "wss:")
	} else {
		connectSrc = append(connectSrc, "ws:", "wss:")
	}
	if analyticsOrigin != "" {
		connectSrc = append(connectSrc, analyticsOrigin)
	}
	if cfg.CSP.ExternalConnect {
		connectSrc = append(connectSrc,
			"https://fonts.googleapis.com", "https://fonts.gstatic.com",
			"https://www.gstatic.com", "https://cdn.jsdelivr.net")
	}

	hsts := 0
	if cfg.SecureCookie {
		hsts = cfg.HSTSMaxAgeSeconds
	}
	return secheaders.Config{
		HSTSMaxAgeSeconds: hsts,
		PermissionsPolicy: permissionsPolicy,
		CSP: secheaders.Policy{
			{Name: "default-src", Values: []string{"'self'"}},
			{Name: "base-uri", Values: []string{"'self'"}},
			{Name: "font-src", Values: []string{"'self'", "data:", "https://fonts.gstatic.com"}},
			{Name: "form-action", Values: []string{"'self'"}},
			{Name: "frame-ancestors", Values: []string{"'self'"}},
			{Name: "img-src", Values: []string{"'self'", "data:", "blob:"}},
			{Name: "object-src", Values: []string{"'none'"}},
			{Name: "script-src", Values: scriptSrc},
			{Name: "script-src-attr", Values: []string{"'unsafe-inline'"}},
			{Name: "style-src", Values: []string{"'self'", "'unsafe-inline'", "https://fonts.googleapis.com"}},
			{Name: "media-src", Values: []string{"'self'", "data:", "blob:"}},
			{Name: "connect-src", Values: connectSrc},
			{Name: "worker-src", Values: []string{"'self'", "blob:"}},
		},
	}
}
