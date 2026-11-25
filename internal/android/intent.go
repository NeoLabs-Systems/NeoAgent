package android

import (
	"context"
	"fmt"
	"net/url"
	"regexp"
	"strings"
)

var blockedIntentSchemes = map[string]bool{
	"about": true, "chrome": true, "chrome-extension": true, "content": true,
	"data": true, "file": true, "javascript": true, "vbscript": true,
}

var schemePattern = regexp.MustCompile(`^[a-z][a-z0-9+.-]*$`)

// ValidateIntentURL decides whether an Android intent may open a URI (the
// Node validateAndroidIntentUrl). web URLs go through the shared URL checker;
// app schemes such as geo: or market: pass unless explicitly blocked. When not
// allowed, reason is the text to show.
func (h *Host) ValidateIntentURL(ctx context.Context, raw string) (allowed bool, reason string, err error) {
	if raw == "" {
		return false, "No URI was given.", nil
	}
	u, perr := url.Parse(raw)
	if perr != nil || u.Scheme == "" {
		return false, fmt.Sprintf(`"%s" is not a valid URI. Include a scheme, e.g. https:// or geo:`, raw), nil
	}
	scheme := strings.ToLower(u.Scheme)
	if blockedIntentSchemes[scheme] {
		return false, fmt.Sprintf("The %s: scheme is not allowed for Android intents.", scheme), nil
	}
	if scheme == "http" || scheme == "https" {
		if h.cfg.URLCheck == nil {
			return false, "URL validation is unavailable.", nil
		}
		return h.cfg.URLCheck(ctx, raw)
	}
	if !schemePattern.MatchString(scheme) {
		return false, fmt.Sprintf(`"%s" is not a valid URI scheme.`, scheme), nil
	}
	return true, "", nil
}

// ValidateIntentURL is the controller's view of Host.ValidateIntentURL; it
// returns the reason as an error.
func (c *Controller) ValidateIntentURL(ctx context.Context, raw string) error {
	allowed, reason, err := c.host.ValidateIntentURL(ctx, raw)
	if err != nil {
		return err
	}
	if !allowed {
		return fmt.Errorf("%s", reason)
	}
	return nil
}
