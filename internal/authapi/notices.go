package authapi

import (
	"context"
	"net/url"
	"strconv"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/servicemail"
)

const noticeTimeout = 30 * time.Second

// async runs a best-effort task (an email) without holding the response. A
// failure is logged and never reaches the person.
func (a *API) async(what string, fn func(ctx context.Context) error) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), noticeTimeout)
		defer cancel()
		if err := fn(ctx); err != nil {
			a.Log.Warn(what+" failed", "error", err)
		}
	}()
}

// sendMail delivers one message; with email switched off it does nothing.
func (a *API) sendMail(ctx context.Context, to string, m servicemail.Message) error {
	if !a.Cfg.Mail.Enabled || a.Mail == nil {
		return nil
	}
	return a.Mail.Send(ctx, to, m)
}

func (a *API) ttlText() string {
	return strconv.FormatFloat(a.Cfg.Mail.TokenTTLHours, 'f', -1, 64) + " hours"
}

func now() string { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }

func (a *API) mailURL(path, token string) string {
	base, err := url.Parse(a.Cfg.Mail.PublicURL)
	if err != nil {
		return a.Cfg.Mail.PublicURL + path + "?token=" + url.QueryEscape(token)
	}
	u := base.ResolveReference(&url.URL{Path: path})
	q := url.Values{}
	q.Set("token", token)
	u.RawQuery = q.Encode()
	return u.String()
}

func (a *API) sendSignupConfirmation(ctx context.Context, username, email, token string) error {
	return a.sendMail(ctx, email, servicemail.Message{
		Subject: "Confirm your NeoAgent email", Title: "Confirm your email",
		Intro:     "Confirm this email address to finish creating the NeoAgent account " + username + ".",
		ActionURL: a.mailURL("/api/auth/email/confirm", token), ActionLabel: "Confirm email",
		Details: []servicemail.Detail{{Label: "Account", Value: username}, {Label: "Expires", Value: a.ttlText()}},
	})
}

func (a *API) sendEmailChangeConfirmation(ctx context.Context, username, newEmail, token string) error {
	return a.sendMail(ctx, newEmail, servicemail.Message{
		Subject: "Confirm your new NeoAgent email", Title: "Confirm your new email",
		Intro:     "Confirm this address before NeoAgent changes the account email for " + username + ".",
		ActionURL: a.mailURL("/api/auth/email/confirm", token), ActionLabel: "Confirm new email",
		Details: []servicemail.Detail{{Label: "Account", Value: username}, {Label: "New email", Value: newEmail}},
	})
}

func (a *API) sendPasswordResetEmail(ctx context.Context, username, email, token string) error {
	return a.sendMail(ctx, email, servicemail.Message{
		Subject: "Reset your NeoAgent password", Title: "Reset your password",
		Intro:     "Use this link to set a new password for " + username + ". Ignore this email if you did not request a reset.",
		ActionURL: a.mailURL("/api/auth/password/reset", token), ActionLabel: "Reset password",
		Details: []servicemail.Detail{{Label: "Account", Value: username}, {Label: "Expires", Value: a.ttlText()}},
	})
}

func orUnknown(s string) string {
	if s == "" {
		return "Unknown"
	}
	return s
}

func (a *API) sendUnusualLoginNotice(ctx context.Context, u *accounts.User, info *accounts.Info) error {
	if !a.Cfg.Mail.Enabled || !a.Cfg.Mail.NotifyUnusualLogin || !u.Email.Valid || u.Email.String == "" {
		return nil
	}
	return a.sendMail(ctx, u.Email.String, servicemail.Message{
		Subject: "New NeoAgent sign-in", Title: "New sign-in detected",
		Intro: "A sign-in to your NeoAgent account used a new device or network pattern.",
		Details: []servicemail.Detail{
			{Label: "Account", Value: u.Username}, {Label: "Location", Value: orUnknown(info.Location)},
			{Label: "IP address", Value: orUnknown(info.IPAddress)}, {Label: "Device", Value: orUnknown(info.UserAgent)},
			{Label: "Time", Value: now()},
		},
	})
}

func (a *API) sendPasswordChangedNotice(ctx context.Context, username, email string) error {
	if !a.Cfg.Mail.Enabled || !a.Cfg.Mail.NotifyAccountChanges || email == "" {
		return nil
	}
	return a.sendMail(ctx, email, servicemail.Message{
		Subject: "NeoAgent password changed", Title: "Your password was changed",
		Intro:   "The password for " + username + " was changed. If this was not you, rotate your password and revoke unknown sessions.",
		Details: []servicemail.Detail{{Label: "Account", Value: username}, {Label: "Time", Value: now()}},
	})
}

func (a *API) sendEmailChangedNotice(ctx context.Context, username, previous, next string) error {
	if !a.Cfg.Mail.Enabled || !a.Cfg.Mail.NotifyAccountChanges {
		return nil
	}
	details := []servicemail.Detail{{Label: "Account", Value: username}, {Label: "New email", Value: next}, {Label: "Time", Value: now()}}
	if previous != "" {
		if err := a.sendMail(ctx, previous, servicemail.Message{
			Subject: "NeoAgent email changed", Title: "Your account email was changed",
			Intro: "The email address for " + username + " was changed.", Details: details,
		}); err != nil {
			return err
		}
	}
	if next != "" && next != previous {
		return a.sendMail(ctx, next, servicemail.Message{
			Subject: "NeoAgent email changed", Title: "This email is now linked",
			Intro: "This address is now linked to the NeoAgent account " + username + ".", Details: details,
		})
	}
	return nil
}

func (a *API) sendEmailChangeRequestedNotice(ctx context.Context, username, current, requested string) error {
	if !a.Cfg.Mail.Enabled || !a.Cfg.Mail.NotifyAccountChanges || current == "" {
		return nil
	}
	return a.sendMail(ctx, current, servicemail.Message{
		Subject: "NeoAgent email change requested", Title: "Email change requested",
		Intro:   "A request was made to change the email for " + username + ". The change will not apply until the new address is confirmed.",
		Details: []servicemail.Detail{{Label: "Account", Value: username}, {Label: "Requested email", Value: requested}, {Label: "Time", Value: now()}},
	})
}
