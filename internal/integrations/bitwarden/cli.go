package bitwarden

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	defaultIdleMinutes = 30
	minIdleMinutes     = 5
	maxIdleMinutes     = 120
	maxOutputBytes     = 16 * 1024 * 1024
	sessionFile        = "neoagent-session.enc"
	maxCLIMessage      = 300
	passwordEnv        = "NEOAGENT_BITWARDEN_MASTER_PASSWORD"
)

// CodedError is an error with the code the routes report.
type CodedError struct {
	code, message, cliMessage string
}

func (e *CodedError) Error() string { return e.message }

// Code is the error's code.
func (e *CodedError) Code() string { return e.code }

func coded(code, message string) *CodedError { return &CodedError{code: code, message: message} }

var (
	ansi       = regexp.MustCompile(`\x1b\[[0-9;]*[A-Za-z]`)
	lineBreaks = regexp.MustCompile(`[\r\n]+`)
	unsafeName = regexp.MustCompile(`[^a-zA-Z0-9_-]`)
)

// cliMessage is the last meaningful line the CLI printed (never the password).
func cliMessage(out ...[]byte) string {
	all := ansi.ReplaceAllString(string(bytes.Join(out, nil)), "")
	last := ""
	for _, line := range lineBreaks.Split(all, -1) {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "?") {
			last = line
		}
	}
	if len(last) > maxCLIMessage {
		last = last[:maxCLIMessage]
	}
	return last
}

func normalizeIdle(v any) int {
	f, ok := v.(float64)
	if n, isInt := v.(int); isInt {
		f, ok = float64(n), true
	}
	if !ok || math.IsNaN(f) || math.IsInf(f, 0) {
		return defaultIdleMinutes
	}
	return int(math.Max(minIdleMinutes, math.Min(maxIdleMinutes, math.Round(f))))
}

type session struct {
	key         string
	lastUsed    time.Time
	idleMinutes int
	persistent  bool
}

// Sealer seals the persisted session key like the integration secrets.
type Sealer interface {
	Seal(plain string) (string, error)
	Open(stored string) (string, error)
}

// CLI drives the Bitwarden CLI (`bw`) per account and agent, each with its
// own app data folder, and keeps unlocked session keys in memory (or sealed
// on disk when the person chose to stay signed in).
type CLI struct {
	// Binary is the bw executable; empty looks it up as BITWARDEN_CLI_PATH or
	// "bw" on PATH.
	Binary  string
	DataDir string
	Sealer  Sealer
	Now     func() time.Time
	// Run executes a command; tests replace it.
	Run func(ctx context.Context, name string, args []string, env []string, input string, timeout time.Duration) (string, error)

	mu       sync.Mutex
	sessions map[string]*session
	stop     context.CancelFunc
}

func (c *CLI) now() time.Time {
	if c.Now != nil {
		return c.Now()
	}
	return time.Now()
}

func (c *CLI) binary() (string, error) {
	if c.Binary != "" {
		return c.Binary, nil
	}
	if p := strings.TrimSpace(os.Getenv("BITWARDEN_CLI_PATH")); p != "" {
		return p, nil
	}
	path, err := exec.LookPath("bw")
	if err != nil {
		return "", coded("BITWARDEN_CLI_MISSING", "Bitwarden CLI is not installed. Install the bw command (or set BITWARDEN_CLI_PATH) and try again.")
	}
	return path, nil
}

func scopeKey(userID int64, agentID string) string { return fmt.Sprintf("%d:%s", userID, agentID) }

func (c *CLI) appDir(userID int64, agentID string) string {
	return filepath.Join(c.DataDir, "integrations", "bitwarden",
		unsafeName.ReplaceAllString(fmt.Sprint(userID), "_"), unsafeName.ReplaceAllString(agentID, "_"))
}

func (c *CLI) sessionPath(userID int64, agentID string) string {
	return filepath.Join(c.appDir(userID, agentID), sessionFile)
}

func (c *CLI) readPersisted(userID int64, agentID string) *session {
	raw, err := os.ReadFile(c.sessionPath(userID, agentID))
	if err != nil || c.Sealer == nil {
		return nil
	}
	plain, err := c.Sealer.Open(string(raw))
	if err != nil {
		return nil
	}
	var stored struct {
		SessionKey string `json:"sessionKey"`
	}
	if json.Unmarshal([]byte(plain), &stored) != nil || strings.TrimSpace(stored.SessionKey) == "" {
		return nil
	}
	return &session{key: strings.TrimSpace(stored.SessionKey), lastUsed: c.now(), idleMinutes: defaultIdleMinutes, persistent: true}
}

func (c *CLI) writePersisted(userID int64, agentID, key string) error {
	dir := c.appDir(userID, agentID)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	_ = os.Chmod(dir, 0o700)
	payload, _ := json.Marshal(map[string]string{"sessionKey": key, "savedAt": c.now().UTC().Format("2006-01-02T15:04:05.000Z")})
	sealed, err := c.Sealer.Seal(string(payload))
	if err != nil {
		return err
	}
	return os.WriteFile(c.sessionPath(userID, agentID), []byte(sealed), 0o600)
}

func (c *CLI) deletePersisted(userID int64, agentID string) {
	_ = os.Remove(c.sessionPath(userID, agentID))
}

// sessionLocked is the scope's session; the caller holds mu.
func (c *CLI) sessionLocked(userID int64, agentID string) *session {
	if c.sessions == nil {
		c.sessions = map[string]*session{}
	}
	k := scopeKey(userID, agentID)
	if s, ok := c.sessions[k]; ok {
		return s
	}
	if s := c.readPersisted(userID, agentID); s != nil {
		c.sessions[k] = s
		return s
	}
	return nil
}

func (c *CLI) environment(userID int64, agentID string, extra map[string]string) ([]string, error) {
	dir := c.appDir(userID, agentID)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	_ = os.Chmod(dir, 0o700)
	var env []string
	for _, name := range []string{"PATH", "HOME", "TMPDIR", "TMP", "TEMP", "LANG", "LC_ALL", "HTTPS_PROXY", "HTTP_PROXY", "NO_PROXY", "NODE_EXTRA_CA_CERTS"} {
		if v := os.Getenv(name); v != "" {
			env = append(env, name+"="+v)
		}
	}
	env = append(env, "BITWARDENCLI_APPDATA_DIR="+dir)
	for k, v := range extra {
		env = append(env, k+"="+v)
	}
	return env, nil
}

type runOpts struct {
	env     map[string]string
	input   *string
	timeout time.Duration
}

func (c *CLI) run(ctx context.Context, userID int64, agentID string, args []string, o runOpts) (string, error) {
	bin, err := c.binary()
	if err != nil {
		return "", err
	}
	env, err := c.environment(userID, agentID, o.env)
	if err != nil {
		return "", err
	}
	timeout := o.timeout
	if timeout <= 0 {
		timeout = time.Minute
	}
	input := ""
	if o.input != nil {
		input = *o.input
	}
	runner := c.Run
	if runner == nil {
		runner = runProcess
	}
	return runner(ctx, bin, args, env, input, timeout)
}

// limited keeps at most maxOutputBytes and remembers whether more came.
type limited struct {
	buf      bytes.Buffer
	overflow bool
	written  bool
}

func (l *limited) Write(p []byte) (int, error) {
	l.written = l.written || len(p) > 0
	if l.buf.Len()+len(p) > maxOutputBytes {
		l.overflow = true
		return len(p), nil
	}
	return l.buf.Write(p)
}

func runProcess(ctx context.Context, name string, args, env []string, input string, timeout time.Duration) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = env
	if input != "" {
		cmd.Stdin = strings.NewReader(input)
	}
	var stdout, stderr limited
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	err := cmd.Run()
	if ctx.Err() == context.DeadlineExceeded {
		return "", coded("BITWARDEN_CLI_TIMEOUT", "Bitwarden CLI timed out.")
	}
	if ctx.Err() != nil {
		return "", coded("ABORT_ERR", "Bitwarden operation was aborted.")
	}
	if err != nil {
		var exit *exec.ExitError
		if !errors.As(err, &exit) {
			return "", err
		}
		msg := cliMessage(stdout.buf.Bytes(), stderr.buf.Bytes())
		e := coded("BITWARDEN_CLI_FAILED", "Bitwarden rejected the operation.")
		if msg != "" {
			e.message = "Bitwarden: " + msg
		}
		e.cliMessage = msg
		return "", e
	}
	if stdout.overflow || stderr.overflow {
		return "", coded("BITWARDEN_CLI_OUTPUT_TOO_LARGE", "Bitwarden CLI returned too much data.")
	}
	return strings.TrimSpace(stdout.buf.String()), nil
}

// Status is what the routes show about the CLI and the session.
type Status struct {
	CLIAvailable bool
	Unlocked     bool
	Persistent   bool
	IdleMinutes  any
	LastUsedAt   any
}

// GetStatus reports the session of a scope.
func (c *CLI) GetStatus(userID int64, agentID string) Status {
	c.mu.Lock()
	s := c.sessionLocked(userID, agentID)
	c.mu.Unlock()
	_, err := c.binary()
	out := Status{CLIAvailable: err == nil, IdleMinutes: defaultIdleMinutes}
	if s != nil {
		out.Unlocked = s.key != ""
		out.Persistent = s.persistent
		if s.persistent {
			out.IdleMinutes = nil
		} else if s.idleMinutes > 0 {
			out.IdleMinutes = s.idleMinutes
		}
		out.LastUsedAt = s.lastUsed.UTC().Format("2006-01-02T15:04:05.000Z")
	}
	return out
}

// UnlockOptions are the sign-in details beyond the password.
type UnlockOptions struct {
	ServerURL, Email, ClientID, ClientSecret string
	Persist                                  bool
	TwoStepMethod                            any
	TwoStepCode                              any
}

func twoStepMethod(v any) (string, error) {
	m := strings.TrimSpace(strOf(v))
	if m == "" {
		return "", nil
	}
	if m != "0" && m != "1" && m != "3" {
		return "", coded("BITWARDEN_TWO_STEP_METHOD_INVALID", "Choose Authenticator, Email, or YubiKey for two-step login.")
	}
	return m, nil
}

func twoStepCode(v any) (string, error) {
	code := strings.TrimSpace(strOf(v))
	if strings.ContainsAny(code, "\r\n\x00") || len(code) > 256 {
		return "", coded("BITWARDEN_TWO_STEP_CODE_INVALID", "The Bitwarden two-step login code is invalid.")
	}
	return code, nil
}

func strOf(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return t
	case float64:
		return fmt.Sprint(t)
	}
	return fmt.Sprint(v)
}

var codeRequired = regexp.MustCompile(`(?i)code is required`)

func (c *CLI) unlockRaw(ctx context.Context, userID int64, agentID, password string) (string, error) {
	return c.run(ctx, userID, agentID, []string{"unlock", "--passwordenv", passwordEnv, "--raw"}, runOpts{env: map[string]string{passwordEnv: password}})
}

func (c *CLI) createSession(ctx context.Context, userID int64, agentID, password string, o UnlockOptions) (string, error) {
	serverURL := strings.TrimRight(strings.TrimSpace(o.ServerURL), "/")
	if serverURL == "" {
		serverURL = "https://vault.bitwarden.com"
	}
	email := strings.TrimSpace(o.Email)
	if email == "" {
		return "", coded("BITWARDEN_EMAIL_REQUIRED", "Bitwarden account email is required.")
	}
	if _, err := c.run(ctx, userID, agentID, []string{"config", "server", serverURL}, runOpts{}); err != nil {
		return "", err
	}
	raw, err := c.run(ctx, userID, agentID, []string{"status"}, runOpts{})
	if err != nil {
		return "", err
	}
	var status map[string]any
	_ = json.Unmarshal([]byte(raw), &status)
	userEmail := strings.ToLower(strings.TrimSpace(strOf(status["userEmail"])))
	state := strOf(status["status"])
	if !(state == "unauthenticated" || (userEmail != "" && userEmail != strings.ToLower(email))) {
		return c.unlockRaw(ctx, userID, agentID, password)
	}
	if state != "unauthenticated" {
		if _, err := c.run(ctx, userID, agentID, []string{"logout"}, runOpts{timeout: 15 * time.Second}); err != nil {
			return "", err
		}
		if _, err := c.run(ctx, userID, agentID, []string{"config", "server", serverURL}, runOpts{}); err != nil {
			return "", err
		}
	}
	if id, secret := strings.TrimSpace(o.ClientID), strings.TrimSpace(o.ClientSecret); id != "" && secret != "" {
		if _, err := c.run(ctx, userID, agentID, []string{"login", "--apikey"}, runOpts{env: map[string]string{"BW_CLIENTID": id, "BW_CLIENTSECRET": secret}}); err != nil {
			return "", err
		}
		return c.unlockRaw(ctx, userID, agentID, password)
	}
	method, err := twoStepMethod(o.TwoStepMethod)
	if err != nil {
		return "", err
	}
	code, err := twoStepCode(o.TwoStepCode)
	if err != nil {
		return "", err
	}
	args := []string{"login", email, "--passwordenv", passwordEnv, "--raw"}
	if method != "" {
		args = append(args, "--method", method)
		if code != "" {
			args = append(args, "--code", code)
		}
	}
	// The CLI takes the new-device code (and a two-step code without a
	// method) only on its prompt, so the code is answered on stdin; an empty
	// answer fails fast with "Code is required.".
	answer := code + "\n"
	key, err := c.run(ctx, userID, agentID, args, runOpts{env: map[string]string{passwordEnv: password}, input: &answer})
	if err != nil {
		var ce *CodedError
		if code == "" && errors.As(err, &ce) && codeRequired.MatchString(ce.cliMessage) {
			return "", coded("BITWARDEN_VERIFICATION_CODE_REQUIRED", "Bitwarden needs a verification code to finish signing in. Check your email (or authenticator app if two-step login is on), enter the code, and connect again.")
		}
		return "", err
	}
	return key, nil
}

// Unlock signs in (when needed) and unlocks the vault.
func (c *CLI) Unlock(ctx context.Context, userID int64, agentID, password string, idleMinutes any, o UnlockOptions) (Status, error) {
	if password == "" {
		return Status{}, coded("BITWARDEN_MASTER_PASSWORD_REQUIRED", "Bitwarden master password is required.")
	}
	var key string
	var err error
	if o.Email != "" {
		key, err = c.createSession(ctx, userID, agentID, password, o)
	} else {
		key, err = c.unlockRaw(ctx, userID, agentID, password)
	}
	if err != nil {
		return Status{}, err
	}
	if key == "" {
		return Status{}, coded("BITWARDEN_UNLOCK_FAILED", "Bitwarden did not return an unlock session.")
	}
	c.mu.Lock()
	if c.sessions == nil {
		c.sessions = map[string]*session{}
	}
	c.sessions[scopeKey(userID, agentID)] = &session{key: key, lastUsed: c.now(), idleMinutes: normalizeIdle(idleMinutes), persistent: o.Persist}
	c.mu.Unlock()
	if o.Persist {
		if err := c.writePersisted(userID, agentID, key); err != nil {
			return Status{}, err
		}
	} else {
		c.deletePersisted(userID, agentID)
	}
	return c.GetStatus(userID, agentID), nil
}

func (c *CLI) requireSession(userID int64, agentID string) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	s := c.sessionLocked(userID, agentID)
	if s == nil || s.key == "" {
		return "", coded("BITWARDEN_LOCKED", "Bitwarden is locked. Unlock it in Official Integrations.")
	}
	s.lastUsed = c.now()
	return s.key, nil
}

// Sync refreshes the local vault copy.
func (c *CLI) Sync(ctx context.Context, userID int64, agentID string) error {
	key, err := c.requireSession(userID, agentID)
	if err != nil {
		return err
	}
	_, err = c.run(ctx, userID, agentID, []string{"sync"}, runOpts{env: map[string]string{"BW_SESSION": key}})
	return err
}

// ListItems lists the vault items.
func (c *CLI) ListItems(ctx context.Context, userID int64, agentID string) ([]map[string]any, error) {
	key, err := c.requireSession(userID, agentID)
	if err != nil {
		return nil, err
	}
	raw, err := c.run(ctx, userID, agentID, []string{"list", "items"}, runOpts{env: map[string]string{"BW_SESSION": key}})
	if err != nil {
		return nil, err
	}
	if raw == "" {
		raw = "[]"
	}
	var items []any
	if err := json.Unmarshal([]byte(raw), &items); err != nil {
		return nil, err
	}
	out := make([]map[string]any, 0, len(items))
	for _, it := range items {
		if m, ok := it.(map[string]any); ok {
			out = append(out, m)
		}
	}
	return out, nil
}

// GetItem reads one item.
func (c *CLI) GetItem(ctx context.Context, userID int64, agentID, ref string) (map[string]any, error) {
	key, err := c.requireSession(userID, agentID)
	if err != nil {
		return nil, err
	}
	raw, err := c.run(ctx, userID, agentID, []string{"get", "item", ref}, runOpts{env: map[string]string{"BW_SESSION": key}})
	if err != nil {
		return nil, err
	}
	if raw == "" {
		raw = "{}"
	}
	var item map[string]any
	if json.Unmarshal([]byte(raw), &item) != nil || item == nil {
		return nil, errors.New("Bitwarden returned an invalid item.")
	}
	return item, nil
}

// Lock forgets the session key.
func (c *CLI) Lock(ctx context.Context, userID int64, agentID string) {
	c.mu.Lock()
	s := c.sessionLocked(userID, agentID)
	delete(c.sessions, scopeKey(userID, agentID))
	c.mu.Unlock()
	c.deletePersisted(userID, agentID)
	if s == nil || s.key == "" {
		return
	}
	// The in-memory key is already gone; a failed lock changes nothing.
	_, _ = c.run(ctx, userID, agentID, []string{"lock"}, runOpts{env: map[string]string{"BW_SESSION": s.key}, timeout: 15 * time.Second})
}

// Logout locks, signs out and removes the scope's CLI data.
func (c *CLI) Logout(ctx context.Context, userID int64, agentID string) {
	c.Lock(ctx, userID, agentID)
	_, _ = c.run(ctx, userID, agentID, []string{"logout"}, runOpts{timeout: 15 * time.Second})
	_ = os.RemoveAll(c.appDir(userID, agentID))
}

// LockExpired locks sessions idle past their timeout; Start runs it.
func (c *CLI) LockExpired(ctx context.Context) {
	c.mu.Lock()
	var expired [][2]string
	now := c.now()
	for k, s := range c.sessions {
		if s.persistent || now.Sub(s.lastUsed) < time.Duration(s.idleMinutes)*time.Minute {
			continue
		}
		user, agent, _ := strings.Cut(k, ":")
		expired = append(expired, [2]string{user, agent})
	}
	c.mu.Unlock()
	for _, e := range expired {
		var id int64
		fmt.Sscan(e[0], &id)
		c.Lock(ctx, id, e[1])
	}
}

// Start locks idle sessions every 30 seconds until Close.
func (c *CLI) Start() {
	ctx, cancel := context.WithCancel(context.Background())
	c.mu.Lock()
	c.stop = cancel
	c.mu.Unlock()
	go func() {
		t := time.NewTicker(30 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				c.LockExpired(ctx)
			}
		}
	}()
}

// Close stops the idle check and locks every session that does not persist.
func (c *CLI) Close() {
	c.mu.Lock()
	stop := c.stop
	c.mu.Unlock()
	if stop != nil {
		stop()
	}
	c.lockEphemeral()
}

func (c *CLI) lockEphemeral() {
	c.mu.Lock()
	var scopes [][2]string
	for k, s := range c.sessions {
		if !s.persistent {
			user, agent, _ := strings.Cut(k, ":")
			scopes = append(scopes, [2]string{user, agent})
		}
	}
	c.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	for _, s := range scopes {
		var id int64
		fmt.Sscan(s[0], &id)
		c.Lock(ctx, id, s[1])
	}
}
