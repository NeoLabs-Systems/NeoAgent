package credentials

import (
	"context"
	"errors"
	"fmt"
)

// Browsers finds the browser a user's agent drives
// (runtimeManager.getBrowserProviderForUser).
type Browsers interface {
	BrowserForUser(ctx context.Context, userID int64) (Browser, error)
}

// FillRequest asks the browser to fill a form in protected mode: the page
// keeps the values, and the model never reads them back.
type FillRequest struct {
	UsernameSelector string
	PasswordSelector string
	Username         string
	Password         string
	AllowedOrigin    string
}

// Browser is the part of a browser provider the broker uses. It reports
// ErrFillUnsupported when its backend cannot fill protected credentials.
type Browser interface {
	// PageURL is the address of the page the browser shows.
	PageURL(ctx context.Context) (string, error)
	// FillCredential fills the form and returns the id of the protected fill,
	// or "" when the browser did not name one.
	FillCredential(ctx context.Context, req FillRequest) (string, error)
	// SubmitProtected submits the filled form and returns the page state.
	SubmitProtected(ctx context.Context, fillID string) (map[string]any, error)
	// CancelProtected clears the filled form.
	CancelProtected(ctx context.Context, fillID string) (map[string]any, error)
}

// ErrFillUnsupported is what a browser answers when it cannot fill
// credentials in protected mode.
var ErrFillUnsupported = errors.New("The selected browser backend does not support protected credential fill.")

// FillResult is what the model learns of a protected fill.
type FillResult struct {
	Success         bool   `json:"success"`
	ProtectedFillID string `json:"protected_fill_id"`
	Binding         string `json:"binding"`
	Origin          string `json:"origin"`
	Protected       bool   `json:"protected"`
	Message         string `json:"message"`
}

func (b *Broker) browserProvider(ctx context.Context, userID int64) (Browser, error) {
	b.mu.Lock()
	browsers := b.browsers
	b.mu.Unlock()
	if browsers == nil {
		return nil, errors.New("Browser runtime is unavailable.")
	}
	return browsers.BrowserForUser(ctx, userID)
}

// FillBrowser fills the bound credentials into the form on the current page,
// which must be on one of the binding's origins. input carries binding_id,
// stage (username, password or both) and the two selectors.
func (b *Broker) FillBrowser(ctx context.Context, userID int64, agentID string, input map[string]any, rc RunContext) (*FillResult, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	r, err := b.bindingRow(ctx, sc, jsString(input["binding_id"]))
	if err != nil {
		return nil, err
	}
	bd, err := b.decode(r)
	if err != nil {
		return nil, err
	}
	if bd == nil || bd.usageType != "browser" {
		return nil, errors.New("Browser credential binding not found.")
	}
	provider, err := b.browserProvider(ctx, sc.userID)
	if err != nil {
		return nil, err
	}
	if provider == nil {
		return nil, ErrFillUnsupported
	}
	pageURL, err := provider.PageURL(ctx)
	if err != nil {
		return nil, err
	}
	pageOrigin := ""
	if pageURL != "" {
		u, err := parseURL(pageURL)
		if err != nil {
			return nil, err
		}
		pageOrigin = origin(u)
	}
	if !contains(bd.targetConfig.Origins, pageOrigin) {
		return nil, fmt.Errorf("Credential binding %s is not allowed on the current browser origin.", bd.alias)
	}

	fillID, err := useItem(b, ctx, sc, bd, func(item Item) (string, error) {
		username := readItemField(item, derefString(bd.fields.UsernameField))
		password := readItemField(item, bd.fields.PasswordField)
		stage := "both"
		if truthy(input["stage"]) {
			stage = jsString(input["stage"])
		}
		if stage != "username" && stage != "password" && stage != "both" {
			return "", errors.New("Credential stage must be username, password, or both.")
		}
		usernameSelector := trimText(input["username_selector"])
		passwordSelector := trimText(input["password_selector"])
		if stage != "password" && usernameSelector == "" {
			return "", errors.New("Username selector is required for this credential stage.")
		}
		if stage != "username" && passwordSelector == "" {
			return "", errors.New("Password selector is required for this credential stage.")
		}
		if stage != "username" && password == "" {
			return "", errors.New("The bound Bitwarden password is empty.")
		}
		req := FillRequest{AllowedOrigin: pageOrigin}
		if stage != "password" {
			req.UsernameSelector, req.Username = usernameSelector, username
		}
		if stage != "username" {
			req.PasswordSelector, req.Password = passwordSelector, password
		}
		return provider.FillCredential(ctx, req)
	})
	if err != nil {
		_ = b.audit(ctx, sc, bd.id, "browser_fill", pageOrigin, "failed", err, rc.RunID)
		return nil, err
	}
	if fillID == "" {
		fillID = newUUID()
	}
	b.rememberFill(fillID, protectedFill{userID: sc.userID, agentID: sc.agentID, bindingID: bd.id})
	if err := b.audit(ctx, sc, bd.id, "browser_fill", pageOrigin, "success", nil, rc.RunID); err != nil {
		return nil, err
	}
	return &FillResult{
		Success: true, ProtectedFillID: fillID, Binding: bd.alias, Origin: pageOrigin, Protected: true,
		Message: "Credentials filled in protected mode. Submit or cancel the protected form.",
	}, nil
}

func derefString(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func (b *Broker) rememberFill(id string, f protectedFill) {
	b.mu.Lock()
	defer b.mu.Unlock()
	now := b.now()
	for k, e := range b.fills {
		if !e.expiresAt.After(now) {
			delete(b.fills, k)
		}
	}
	f.expiresAt = now.Add(protectedFillTTL)
	b.fills[id] = f
}

var errNoFill = errors.New("Protected browser fill is missing or expired.")

// findFill finds a fill that belongs to the caller. It stays registered until
// the caller has finished with it.
func (b *Broker) findFill(sc scope, id string) (protectedFill, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	f, ok := b.fills[id]
	if !ok || f.userID != sc.userID || f.agentID != sc.agentID {
		return protectedFill{}, errNoFill
	}
	return f, nil
}

func (b *Broker) forgetFill(id string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	delete(b.fills, id)
}

// SubmitProtected submits a protected form filled earlier.
func (b *Broker) SubmitProtected(ctx context.Context, userID int64, agentID, fillID string, rc RunContext) (map[string]any, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	fill, err := b.findFill(sc, fillID)
	if err != nil {
		return nil, err
	}
	provider, err := b.browserProvider(ctx, sc.userID)
	if err != nil {
		return nil, err
	}
	if !fill.expiresAt.After(b.now()) {
		_, _ = provider.CancelProtected(ctx, fillID)
		b.forgetFill(fillID)
		return nil, errors.New("Protected browser fill expired and was cleared.")
	}
	result, err := provider.SubmitProtected(ctx, fillID)
	if err != nil {
		return nil, err
	}
	b.forgetFill(fillID)
	target, _ := result["url"].(string)
	if err := b.audit(ctx, sc, fill.bindingID, "browser_submit", target, "success", nil, rc.RunID); err != nil {
		return nil, err
	}
	return result, nil
}

// CancelProtected clears a protected form without submitting it.
func (b *Broker) CancelProtected(ctx context.Context, userID int64, agentID, fillID string, rc RunContext) (map[string]any, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	fill, err := b.findFill(sc, fillID)
	if err != nil {
		return nil, err
	}
	provider, err := b.browserProvider(ctx, sc.userID)
	if err != nil {
		return nil, err
	}
	result, err := provider.CancelProtected(ctx, fillID)
	if err != nil {
		return nil, err
	}
	b.forgetFill(fillID)
	if err := b.audit(ctx, sc, fill.bindingID, "browser_cancel", "", "success", nil, rc.RunID); err != nil {
		return nil, err
	}
	return result, nil
}
