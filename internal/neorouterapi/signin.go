package neorouterapi

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	deviceClientID = "neoagent"
	flowTTL        = 10 * time.Minute
	deviceScopes   = "chat moderation transcription live embedding image search"
)

var liveProviderByProtocol = map[string]string{
	"openai_live": "neorouter_openai",
	"gemini_live": "neorouter_google",
}

type signInFlow struct {
	scope      string
	userID     int64
	agentID    string
	apiBase    string
	deviceCode string
	interval   time.Duration
	expiresAt  time.Time
	status     string
	trusted    bool
	errMsg     string
}

// BeginSignInInput configures a device-flow sign-in.
type BeginSignInInput struct {
	Scope   string
	UserID  int64
	AgentID string
	Address string
}

// BeginSignInResult is returned to the client to display the approval URL and code.
type BeginSignInResult struct {
	ID       string `json:"id"`
	URL      string `json:"url"`
	UserCode string `json:"userCode"`
}

// SignInStatus is returned when polling a device-flow sign-in.
type SignInStatus struct {
	Status string  `json:"status"`
	Error  *string `json:"error"`
}

func (s *Service) pruneExpiredFlows() {
	now := s.now()
	s.flowMu.Lock()
	defer s.flowMu.Unlock()
	for id, flow := range s.flows {
		if !flow.expiresAt.After(now) && flow.status == "pending" {
			delete(s.flows, id)
		}
	}
}

func (s *Service) postForm(ctx context.Context, targetURL string, fields url.Values, trusted bool) (ok bool, status int, data map[string]any, err error) {
	reqCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodPost, targetURL, strings.NewReader(fields.Encode()))
	if err != nil {
		return false, 0, nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	client := s.http
	if trusted {
		client = s.trustedHTTP
	}
	resp, err := client.Do(req)
	if err != nil {
		return false, 0, nil, err
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 64*1024+1))
	if err != nil {
		return false, resp.StatusCode, nil, err
	}
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &data)
	}
	return resp.StatusCode >= 200 && resp.StatusCode < 300, resp.StatusCode, data, nil
}

func liveProviderFor(offer *Offer) string {
	if offer == nil {
		return ""
	}
	for _, proto := range []string{"openai_live", "gemini_live"} {
		for _, p := range offer.LiveProtocols {
			if p == proto {
				return liveProviderByProtocol[proto]
			}
		}
	}
	return ""
}

func isNeoRouterLive(provider string) bool {
	for _, p := range liveProviderByProtocol {
		if p == provider {
			return true
		}
	}
	return false
}

// ApplyLiveChoice updates the live-voice provider preference when NeoRouter's
// live role or available live models change.
func (s *Service) ApplyLiveChoice(ctx context.Context, conn *Connection, scope string, userID int64, agentID string, onlyIfUnusable bool, offer *Offer) error {
	var current string
	if scope == "server" {
		current = s.env.Get("VOICE_LIVE_PROVIDER")
	} else if s.settings != nil {
		var err error
		current, err = s.settings.GetVoiceLiveProvider(ctx, userID, agentID)
		if err != nil {
			return err
		}
	}

	next := current
	if conn != nil && conn.HasRole("live") {
		known := offer
		if known == nil {
			known, _ = s.DescribeOffer(ctx, conn, false)
		}
		routed := liveProviderFor(known)
		usable := false
		if s.settings != nil && current != "" {
			usable, _ = s.settings.IsLiveProviderUsable(ctx, scope, userID, agentID, current)
		}
		keep := onlyIfUnusable && usable && (!isNeoRouterLive(current) || routed == current)
		if !keep && routed != "" {
			next = routed
		}
	} else if isNeoRouterLive(current) {
		next = ""
	}

	if next == current {
		return nil
	}
	if scope == "server" {
		return s.env.Set("VOICE_LIVE_PROVIDER", next)
	}
	if s.settings != nil {
		return s.settings.SetVoiceLiveProvider(ctx, userID, agentID, next)
	}
	return nil
}

func (s *Service) storeConnection(ctx context.Context, flow *signInFlow, apiKey string) error {
	if flow.scope == "server" {
		if err := s.env.Set(envBaseURL, flow.apiBase); err != nil {
			return err
		}
		if err := s.env.Set(envAPIKey, apiKey); err != nil {
			return err
		}
		if err := s.env.Set(envRoles, strings.Join(Roles, ",")); err != nil {
			return err
		}
		return s.ApplyLiveChoice(ctx, s.ServerConnection(), "server", flow.userID, flow.agentID, false, nil)
	}

	if s.settings == nil {
		return errors.New("settings store is not configured")
	}
	conn := build("user", flow.apiBase, apiKey, append([]string(nil), Roles...))
	offer, _ := s.DescribeOffer(ctx, conn, false)
	enableSystemOne := offer != nil && offer.Roles["system_one"] > 0
	if err := s.settings.SaveUserNeoRouter(ctx, flow.userID, flow.agentID, flow.apiBase, apiKey, append([]string(nil), Roles...), enableSystemOne); err != nil {
		return err
	}
	saved, _ := s.UserConnection(ctx, flow.userID, flow.agentID)
	if saved == nil {
		saved = conn
	}
	return s.ApplyLiveChoice(ctx, saved, "user", flow.userID, flow.agentID, false, offer)
}

func (s *Service) schedulePoll(id string, delay time.Duration) {
	ctx := s.bgContext()
	if ctx.Err() != nil {
		return
	}
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		timer := time.NewTimer(delay)
		defer timer.Stop()
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
		}
		s.pollFlow(ctx, id)
	}()
}

func (s *Service) pollFlow(ctx context.Context, id string) {
	s.flowMu.Lock()
	flow := s.flows[id]
	if flow == nil || flow.status != "pending" {
		s.flowMu.Unlock()
		return
	}
	if !s.now().Before(flow.expiresAt) {
		flow.status = "failed"
		flow.errMsg = "The sign-in expired. Start again."
		s.flowMu.Unlock()
		return
	}
	apiBase := flow.apiBase
	deviceCode := flow.deviceCode
	interval := flow.interval
	flowCopy := *flow
	s.flowMu.Unlock()

	origin, _ := strings.CutSuffix(apiBase, "/v1")
	ok, _, data, err := s.postForm(ctx, origin+"/oauth/token", url.Values{
		"grant_type":  {"urn:ietf:params:oauth:grant-type:device_code"},
		"device_code": {deviceCode},
		"client_id":   {deviceClientID},
	}, flowCopy.trusted)
	if err != nil {
		if ctx.Err() != nil {
			return
		}
		s.schedulePoll(id, interval)
		return
	}
	if ok {
		if token := strings.TrimSpace(stringOf(data["access_token"])); token != "" && data["access_token"] != nil {
			err := s.storeConnection(ctx, &flowCopy, token)
			s.flowMu.Lock()
			if cur := s.flows[id]; cur != nil && cur.status == "pending" {
				if err != nil {
					cur.status = "failed"
					cur.errMsg = err.Error()
				} else {
					cur.status = "completed"
				}
			}
			s.flowMu.Unlock()
			return
		}
	}

	code := stringOf(data["error"])
	if data["error"] == nil {
		code = ""
	}
	if code == "slow_down" {
		interval += 5 * time.Second
	}
	if code == "authorization_pending" || code == "slow_down" {
		s.flowMu.Lock()
		if cur := s.flows[id]; cur != nil {
			cur.interval = interval
		}
		s.flowMu.Unlock()
		s.schedulePoll(id, interval)
		return
	}

	errMsg := stringOf(data["error_description"])
	if data["error_description"] == nil || errMsg == "" {
		errMsg = "NeoRouter did not hand out a key."
	}
	if code == "access_denied" {
		errMsg = "The connection was declined in NeoRouter."
	}
	s.flowMu.Lock()
	if cur := s.flows[id]; cur != nil && cur.status == "pending" {
		cur.status = "failed"
		cur.errMsg = errMsg
	}
	s.flowMu.Unlock()
}

// BeginSignIn starts an OAuth 2.0 device authorization flow with a NeoRouter.
func (s *Service) BeginSignIn(ctx context.Context, in BeginSignInInput) (BeginSignInResult, error) {
	s.pruneExpiredFlows()
	apiBase := APIBaseFor(in.Address)
	if apiBase == "" {
		return BeginSignInResult{}, errors.New("Enter the address of your NeoRouter, for example https://router.example.com.")
	}
	origin, _ := strings.CutSuffix(apiBase, "/v1")
	host, _ := s.hostname()
	if host == "" {
		host = "localhost"
	}
	server := s.ServerConnection()
	trusted := in.Scope == "server" || (server != nil && server.APIBase == apiBase)
	ok, _, data, err := s.postForm(ctx, origin+"/oauth/device/code", url.Values{
		"client_id":   {deviceClientID},
		"client_name": {"NeoAgent (" + host + ")"},
		"scope":       {deviceScopes},
	}, trusted)
	if err != nil {
		return BeginSignInResult{}, errors.New("Could not reach NeoRouter at " + origin + ".")
	}
	deviceCode := ""
	if data != nil && data["device_code"] != nil {
		deviceCode = stringOf(data["device_code"])
	}
	if !ok || deviceCode == "" {
		return BeginSignInResult{}, errors.New(origin + " did not answer like a NeoRouter. Check the address.")
	}

	var idBytes [18]byte
	if _, err := rand.Read(idBytes[:]); err != nil {
		return BeginSignInResult{}, err
	}
	id := hex.EncodeToString(idBytes[:])

	intervalSec := 5.0
	if v, ok := data["interval"].(float64); ok && v >= 1 {
		intervalSec = v
	}
	expiresSec := 600.0
	if v, ok := data["expires_in"].(float64); ok && v > 0 {
		expiresSec = v
	}
	ttl := time.Duration(expiresSec) * time.Second
	if ttl > flowTTL {
		ttl = flowTTL
	}
	interval := time.Duration(intervalSec) * time.Second

	s.flowMu.Lock()
	s.flows[id] = &signInFlow{
		scope:      in.Scope,
		trusted:    trusted,
		userID:     in.UserID,
		agentID:    in.AgentID,
		apiBase:    apiBase,
		deviceCode: deviceCode,
		interval:   interval,
		expiresAt:  s.now().Add(ttl),
		status:     "pending",
	}
	s.flowMu.Unlock()

	s.schedulePoll(id, interval)

	verifyURL := ""
	if data["verification_uri_complete"] != nil {
		verifyURL = stringOf(data["verification_uri_complete"])
	} else if data["verification_uri"] != nil {
		verifyURL = stringOf(data["verification_uri"])
	}
	userCode := ""
	if data["user_code"] != nil {
		userCode = stringOf(data["user_code"])
	}
	return BeginSignInResult{
		ID:       id,
		URL:      verifyURL,
		UserCode: userCode,
	}, nil
}

// SignInStatus returns the current status of a device-flow sign-in, removing
// completed/failed flows once read.
func (s *Service) SignInStatus(id string, userID int64) (SignInStatus, bool) {
	s.pruneExpiredFlows()
	s.flowMu.Lock()
	defer s.flowMu.Unlock()
	flow, ok := s.flows[id]
	if !ok || flow.userID != userID {
		return SignInStatus{}, false
	}
	if flow.status != "pending" {
		delete(s.flows, id)
	}
	var errPtr *string
	if flow.errMsg != "" {
		msg := flow.errMsg
		errPtr = &msg
	}
	return SignInStatus{Status: flow.status, Error: errPtr}, true
}

// Disconnect removes the server or user NeoRouter connection.
func (s *Service) Disconnect(ctx context.Context, scope string, userID int64, agentID string) error {
	if scope == "server" {
		for _, key := range []string{envBaseURL, envAPIKey, envRoles} {
			if err := s.env.Set(key, ""); err != nil {
				return err
			}
		}
		return s.ApplyLiveChoice(ctx, nil, "server", userID, agentID, false, nil)
	}
	if s.settings != nil {
		if err := s.settings.ClearUserNeoRouter(ctx, userID, agentID); err != nil {
			return err
		}
	}
	return s.ApplyLiveChoice(ctx, nil, "user", userID, agentID, false, nil)
}

// UpdateRoles updates the allowed roles for the server or user NeoRouter connection.
func (s *Service) UpdateRoles(ctx context.Context, scope string, userID int64, agentID string, roles []string) ([]string, error) {
	raw := make([]any, len(roles))
	for i, r := range roles {
		raw[i] = r
	}
	list := NormalizeRoles(raw)
	if scope == "server" {
		if err := s.env.Set(envRoles, strings.Join(list, ",")); err != nil {
			return nil, err
		}
		_ = s.ApplyLiveChoice(ctx, s.ServerConnection(), "server", userID, agentID, false, nil)
		return list, nil
	}
	if s.settings != nil {
		if err := s.settings.UpdateUserRoles(ctx, userID, agentID, list); err != nil {
			return nil, err
		}
	}
	conn, _ := s.UserConnection(ctx, userID, agentID)
	_ = s.ApplyLiveChoice(ctx, conn, "user", userID, agentID, false, nil)
	return list, nil
}
