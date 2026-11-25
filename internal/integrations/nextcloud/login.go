package nextcloud

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

const (
	loginTimeout = 5 * time.Minute
	loginPoll    = 1500 * time.Millisecond
)

type poll struct{ endpoint, token string }

type started struct {
	loginURL string
	poll     poll
}

func (p *Provider) postLogin(ctx context.Context, origin, path string) (map[string]any, error) {
	raw, err := p.svc.SelfHostedClient("Nextcloud login").JSON(ctx, oauthclient.Request{Method: "POST", URL: origin + path,
		Header: map[string]string{"User-Agent": userAgent, "Accept": "application/json"}})
	if err != nil {
		return nil, err
	}
	var m map[string]any
	_ = json.Unmarshal(raw, &m)
	return m, nil
}

// startLoginFlow opens a Login Flow v2 session on the instance.
func (p *Provider) startLoginFlow(ctx context.Context, baseURL string) (started, error) {
	origin, err := normalizeBaseURL(baseURL)
	if err != nil {
		return started{}, err
	}
	data, err := p.postLogin(ctx, origin, "/index.php/login/v2")
	if err != nil {
		if data, err = p.postLogin(ctx, origin, "/login/v2"); err != nil {
			return started{}, err
		}
	}
	login := text(data["login"])
	m, _ := data["poll"].(map[string]any)
	endpoint, token := text(m["endpoint"]), text(m["token"])
	if login == "" || endpoint == "" || token == "" {
		return started{}, errors.New("Nextcloud did not return a Login Flow v2 session.")
	}
	base, _ := url.Parse(origin)
	pollURL, err := base.Parse(endpoint)
	if err != nil || pollURL.Scheme+"://"+pollURL.Host != base.Scheme+"://"+base.Host {
		return started{}, errors.New("Nextcloud login poll endpoint must stay on the configured instance.")
	}
	loginURL, err := url.Parse(login)
	if err != nil || !loginURL.IsAbs() {
		return started{}, errors.New("Nextcloud returned an invalid login URL.")
	}
	if loginURL.Scheme != "http" && loginURL.Scheme != "https" {
		return started{}, errors.New("Nextcloud login URL must be HTTP or HTTPS.")
	}
	return started{loginURL: login, poll: poll{endpoint: pollURL.String(), token: token}}, nil
}

type issued struct{ loginName, appPassword string }

// pollLoginFlow waits until the person approves the login page.
func (p *Provider) pollLoginFlow(ctx context.Context, pl poll, timeout time.Duration) (issued, error) {
	endpoint, err := url.Parse(pl.endpoint)
	if err != nil || pl.endpoint == "" {
		return issued{}, errors.New("poll endpoint is required.")
	}
	if pl.token == "" {
		return issued{}, errors.New("poll token is required.")
	}
	deadline := p.svc.Now().Add(timeout)
	path := endpoint.EscapedPath()
	if endpoint.RawQuery != "" {
		path += "?" + endpoint.RawQuery
	}
	for p.svc.Now().Before(deadline) {
		res, err := p.instanceRequest(ctx, endpoint.Scheme+"://"+endpoint.Host, path, reqOpts{
			method:  "POST",
			headers: map[string]string{"User-Agent": userAgent, "Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"},
			body:    []byte(oauthclient.EncodeQuery([][2]string{{"token", pl.token}})),
			service: "Nextcloud login poll",
		})
		if err != nil {
			return issued{}, err
		}
		if res.status == 404 {
			if err := sleep(ctx, p.pollInterval); err != nil {
				return issued{}, err
			}
			continue
		}
		if !res.ok() {
			return issued{}, fmt.Errorf("Nextcloud login poll failed (%d).", res.status)
		}
		var data map[string]any
		_ = json.Unmarshal(res.body, &data)
		name, pass := text(data["loginName"]), text(data["appPassword"])
		if name == "" || pass == "" {
			return issued{}, errors.New("Nextcloud login did not return account credentials.")
		}
		return issued{loginName: name, appPassword: pass}, nil
	}
	return issued{}, errors.New("Nextcloud login timed out. Approve the login page and try again.")
}

func sleep(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}

// revokeAppPassword tells the instance to forget the app password; failures
// are ignored, as in Node.
func (p *Provider) revokeAppPassword(ctx context.Context, a account) {
	_, _ = p.instanceRequest(ctx, a.baseURL, "/ocs/v2.php/core/apppassword", reqOpts{
		method: "DELETE",
		headers: map[string]string{"Authorization": a.authorization(), "OCS-APIRequest": "true",
			"Accept": "application/json", "User-Agent": userAgent},
		prefix: "/ocs/v2.php/", label: "Nextcloud OCS path", service: "Nextcloud app password revoke",
	})
}
