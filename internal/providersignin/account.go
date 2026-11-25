package providersignin

import (
	"context"
	"errors"
	"os"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
	"github.com/NeoLabs-Systems/neolabs-go/oauthlogin"
)

const accountSignInDisabled = "OpenRouter account sign-in is disabled by the administrator."
const accountSignInNeedsURL = "OpenRouter account sign-in requires an HTTPS or localhost server URL."

// OpenRouterAccount signs people in (and up) with OpenRouter: the PKCE flow
// ends with a user-controlled API key, saved as the account's own key.
type OpenRouterAccount struct {
	Flows *Flows
	// SaveKey stores the key for the account's main agent.
	SaveKey func(ctx context.Context, userID int64, apiKey string) error
}

var (
	_ oauthlogin.Provider        = OpenRouterAccount{}
	_ oauthlogin.Gated           = OpenRouterAccount{}
	_ oauthlogin.CredentialSaver = OpenRouterAccount{}
)

func (OpenRouterAccount) Key() string   { return "openrouter" }
func (OpenRouterAccount) Label() string { return "OpenRouter" }
func (OpenRouterAccount) Icon() string  { return "openrouter" }

// enabled reads NEOAGENT_OPENROUTER_SIGN_IN_ENABLED (on unless switched off).
func enabled() bool {
	switch strings.ToLower(strings.TrimSpace(os.Getenv("NEOAGENT_OPENROUTER_SIGN_IN_ENABLED"))) {
	case "false", "0", "no", "off":
		return false
	}
	return true
}

func (OpenRouterAccount) AssertEnabled() error {
	if !enabled() {
		return errors.New(accountSignInDisabled)
	}
	return nil
}

func (OpenRouterAccount) Status(baseURL string) (bool, string) {
	if !enabled() {
		return false, accountSignInDisabled
	}
	if callbackURL(baseURL) == "" {
		return false, accountSignInNeedsURL
	}
	return true, "OpenRouter sign-in is available."
}

func (o OpenRouterAccount) Begin(_ context.Context, state, codeVerifier, baseURL string) (string, error) {
	if err := o.AssertEnabled(); err != nil {
		return "", err
	}
	callback := callbackURL(baseURL)
	if callback == "" {
		return "", errors.New(accountSignInNeedsURL)
	}
	return oauthclient.SetParams(o.Flows.AuthURL, oauthclient.Query{
		{"callback_url", callback}, {"state", state},
		{"code_challenge", oauthclient.CodeChallenge(codeVerifier)}, {"code_challenge_method", "S256"}, {"key_label", "NeoAgent"},
	})
}

func (o OpenRouterAccount) Finish(ctx context.Context, code, codeVerifier string) (oauthlogin.Identity, error) {
	if err := o.AssertEnabled(); err != nil {
		return oauthlogin.Identity{}, err
	}
	key, userID, err := o.Flows.exchange(ctx, code, codeVerifier)
	if err != nil {
		return oauthlogin.Identity{}, err
	}
	if userID == "" {
		return oauthlogin.Identity{}, errors.New("OpenRouter did not return a usable account identity.")
	}
	return oauthlogin.Identity{ProviderUserID: userID, Secret: key}, nil
}

func (o OpenRouterAccount) SaveCredentials(ctx context.Context, userID int64, id oauthlogin.Identity) error {
	if err := o.AssertEnabled(); err != nil {
		return err
	}
	return o.SaveKey(ctx, userID, id.Secret)
}
