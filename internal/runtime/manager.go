package runtime

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/proc"
	"github.com/NeoLabs-Systems/neolabs-go/vm"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

const (
	displaySessionTTL = 5 * time.Minute
	controlLeaseTTL   = 35 * time.Minute
	// ProviderCloud is the user's computer on this server; ProviderLocal the
	// user's own device through the desktop companion.
	ProviderCloud = "cloud"
	ProviderLocal = "local"
)

// ManagerOptions configure a Manager.
type ManagerOptions struct {
	// Backend runs guest computers; nil when TERMINAL_ENV=host.
	Backend *VMBackend
	// Host is the cloud computer when TERMINAL_ENV=host: this server itself.
	Host *LocalBackend
	// Local is the user's own device through the desktop app; nil without a
	// companion registry.
	Local       *LocalBackend
	TerminalEnv TerminalEnv
	Artifacts   ArtifactStore
	DB          *dbx.DB
	// WorkspaceRoot is the user's host workspace, imported into a new computer once.
	WorkspaceRoot func(ctx context.Context, userKey string) (string, error)
	// EmitStatus sends computer:status to the user's clients.
	EmitStatus func(userKey string, status any)
	Env        Env
}

// Lease is who controls a computer: an agent run, the user or Teach Mode.
type Lease struct {
	OwnerType string
	OwnerID   string
	OwnerIDs  []string
	Provider  string
	ExpiresAt time.Time
}

// DisplaySession grants a viewer access to the user's running computer.
type DisplaySession struct {
	userKey   string
	viewOnly  bool
	expiresAt time.Time
}

// ViewOnly reports a session that may only watch.
func (d *DisplaySession) ViewOnly() bool { return d.viewOnly }

// Manager is every user's computer: provider choice, control leases, display
// sessions, start and stop, and access to its shell, browser and desktop.
type Manager struct {
	o       ManagerOptions
	backend *VMBackend
	cloud   computer
	local   *LocalBackend

	mu       sync.Mutex
	leases   map[string]*Lease
	displays map[string]*DisplaySession
	startups map[string]chan struct{}
	modes    map[string]string
}

// NewManager creates the manager.
func NewManager(o ManagerOptions) *Manager {
	m := &Manager{o: o, backend: o.Backend, local: o.Local, leases: map[string]*Lease{}, displays: map[string]*DisplaySession{}, startups: map[string]chan struct{}{}, modes: map[string]string{}}
	switch {
	case o.Backend != nil:
		m.cloud = o.Backend
	case o.Host != nil:
		m.cloud = o.Host
	}
	if m.backend != nil {
		m.backend.IdleProtected = func(key string) bool { return m.ControlLease(key, ProviderCloud) != nil }
		// A viewer of a stopped computer watches an address that no longer
		// answers; dropping its session makes the page reconnect.
		m.backend.vm.OnStopped(func(key string) { m.RevokeDisplaySessions(key) })
	}
	return m
}

// Backend is the guest backend, or nil.
func (m *Manager) Backend() *VMBackend { return m.backend }

func unavailable() error {
	return &CodedError{Message: "Computer runtime is unavailable.", Code: "COMPUTER_RUNTIME_UNAVAILABLE", Status: 503}
}

// Settings are the runtime settings reported to admins.
func (m *Manager) Settings() *omap {
	s := RuntimeSettings(string(m.o.TerminalEnv))
	out := obj("runtime_profile", s.RuntimeProfile, "computer_backend", "unified", "android_backend", "host", "mcp_backend", "host-remote", "runtime_backend", s.RuntimeBackend)
	return out
}

// ComputerProvider is the user's default computer: local when they chose it
// and the desktop companion exists on this server, else cloud.
func (m *Manager) ComputerProvider(key string) string {
	m.mu.Lock()
	cached, ok := m.modes[key]
	m.mu.Unlock()
	if ok {
		return cached
	}
	provider := ProviderCloud
	if m.o.DB != nil && m.local != nil {
		var stored string
		_ = m.o.DB.R.QueryRow(`SELECT value FROM user_settings WHERE user_id = ? AND key = 'computer_provider'`, key).Scan(&stored)
		if stored == ProviderLocal {
			provider = ProviderLocal
		}
	}
	m.mu.Lock()
	m.modes[key] = provider
	m.mu.Unlock()
	return provider
}

func localUnavailable() error {
	return &CodedError{Message: "Local computer control is unavailable on this server.", Code: "LOCAL_COMPUTER_UNAVAILABLE", Status: 503}
}

// ResolveProvider validates an explicit device target.
func (m *Manager) ResolveProvider(key, override string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(override)) {
	case "":
		return m.ComputerProvider(key), nil
	case ProviderCloud:
		return ProviderCloud, nil
	case ProviderLocal:
		if m.local == nil {
			return "", localUnavailable()
		}
		return ProviderLocal, nil
	}
	return "", &CodedError{Message: "Computer provider must be cloud or local.", Status: 400}
}

// computerFor is the computer a request goes to.
func (m *Manager) computerFor(key, deviceTarget string) (computer, string, error) {
	provider, err := m.ResolveProvider(key, deviceTarget)
	if err != nil {
		return nil, "", err
	}
	if provider == ProviderLocal {
		return m.local, provider, nil
	}
	if m.cloud == nil {
		return nil, provider, unavailable()
	}
	return m.cloud, provider, nil
}

// SetComputerProvider stores the user's default computer.
func (m *Manager) SetComputerProvider(ctx context.Context, key, provider string) (*omap, error) {
	normalized := strings.ToLower(strings.TrimSpace(provider))
	if normalized != ProviderCloud && normalized != ProviderLocal {
		return nil, &CodedError{Message: "Computer provider must be cloud or local.", Status: 400}
	}
	if normalized == ProviderLocal && m.local == nil {
		return nil, localUnavailable()
	}
	for _, p := range []string{ProviderCloud, ProviderLocal} {
		if lease := m.ControlLease(key, p); lease != nil && (lease.OwnerType == "agent" || lease.OwnerType == "teach") {
			return nil, &CodedError{Message: fmt.Sprintf("Cannot switch computers while %s control is active on the %s.", lease.OwnerType, strings.ToLower(computerLabel(lease.Provider))), Code: "COMPUTER_PROVIDER_IN_USE", Status: 409}
		}
	}
	if m.o.DB != nil {
		if _, err := m.o.DB.W.ExecContext(ctx, `INSERT INTO user_settings (user_id, key, value) VALUES (?, 'computer_provider', ?)
       ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`, key, normalized); err != nil {
			return nil, err
		}
	}
	m.mu.Lock()
	m.modes[key] = normalized
	m.mu.Unlock()
	m.ReleaseControl(key, "", "")
	m.RevokeDisplaySessions(key)
	m.emit(key)
	return m.Status(key, "")
}

func computerLabel(provider string) string {
	if provider == ProviderLocal {
		return "Local computer"
	}
	return "Cloud computer"
}

// EmitStatus sends the user's computer status to their clients.
func (m *Manager) EmitStatus(key string) { m.emit(key) }

func (m *Manager) emit(key string) {
	if key == "" || m.o.EmitStatus == nil {
		return
	}
	if status, err := m.Status(key, ""); err == nil {
		m.o.EmitStatus(key, status)
	}
}

func (m *Manager) statusOf(key, provider string) *omap {
	c := m.cloud
	if provider == ProviderLocal {
		c = m.local
	}
	if c == nil {
		return obj("state", StateStopped, "capabilities", []string{}, "readiness", nil)
	}
	return c.Status(context.Background(), key)
}

// Status is the user's computer as clients see it.
func (m *Manager) Status(key, deviceTarget string) (*omap, error) {
	provider, err := m.ResolveProvider(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	status := m.statusOf(key, provider).Clone()
	lease := m.ControlLease(key, provider)
	state := status.String("state")
	if state == StateReady && lease != nil {
		switch lease.OwnerType {
		case "teach":
			state = "teaching"
		case "agent":
			state = "agent_control"
		default:
			state = "user_control"
		}
	}
	var control any
	if lease != nil {
		control = obj("ownerType", lease.OwnerType, "ownerId", lease.OwnerID, "ownerIds", append([]string{}, lease.OwnerIDs...), "provider", lease.Provider, "expiresAt", lease.ExpiresAt.UnixMilli())
	}
	return status.
		Set("provider", provider).
		Set("defaultProvider", m.ComputerProvider(key)).
		Set("providers", obj("cloud", obj("available", true), "local", obj("available", m.local != nil, "connected", m.local != nil && m.local.connected(key)))).
		Set("state", state).
		Set("control", control), nil
}

// CapabilitySnapshot is what the agent's computer offers right now.
func (m *Manager) CapabilitySnapshot(key, deviceTarget string) (*omap, error) {
	provider, err := m.ResolveProvider(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	computer := m.statusOf(key, provider)
	active := "cloud-computer"
	c := m.cloud
	if provider == ProviderLocal {
		active, c = "local-computer", m.local
	}
	tracked := c != nil && c.Tracked(key)
	return obj(
		"computer", computer,
		"browser", obj("activeBackend", active, "vmInitialized", tracked),
		"desktop", computer,
		"android", obj("initialized", false, "status", nil),
	), nil
}

// EnsureDisplay boots the computer far enough to show its screen. Viewing must
// not re-run startup, which would restart X and close the user's tabs.
func (m *Manager) EnsureDisplay(ctx context.Context, key, deviceTarget string) (*omap, error) {
	m.emit(key)
	defer m.emit(key)
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	if err := c.Wake(ctx, key); err != nil {
		return nil, err
	}
	return m.Status(key, deviceTarget)
}

// EnsureComputer starts the computer and brings up its desktop session,
// repairing it when the guest reports it down.
func (m *Manager) EnsureComputer(ctx context.Context, key, deviceTarget string) (*omap, error) {
	m.emit(key)
	defer m.emit(key)
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	if err := c.Prepare(ctx, key); err != nil {
		return nil, err
	}
	// Only a guest has a Linux desktop session to bring up; a person's own
	// machine is already sitting in one and must not be "repaired".
	b, isGuest := c.(*VMBackend)
	if isGuest && contains(b.vm.Capabilities(), "desktop") {
		session := b.vm.Instance(key)
		ensured, err := b.RequestGuest(ctx, key, http.MethodPost, "/desktop/ensure", map[string]any{}, RequestOptions{Timeout: 3 * time.Minute})
		if err != nil {
			m.o.Env.logger().Warn("Desktop ensure endpoint failed", "user", key, "error", err)
			ensured = obj("available", false, "error", err.Error())
		}
		if ensured.Bool("available") {
			if session != nil {
				session.SetDesktop(obj("available", true, "error", nil))
			}
		} else {
			fallback := ensured.String("error")
			repaired, err := b.ExecuteCommand(ctx, key, GuestDesktopRepairCommand(), ExecOptions{TimeoutMs: float64(10 * time.Minute / time.Millisecond)})
			var summary *omap
			if err != nil {
				msg := err.Error()
				if msg == "" {
					msg = fallback
				}
				summary = SummarizeDesktopRepairOutput("", "", msg)
			} else {
				summary = SummarizeDesktopRepairOutput(repaired.String("stdout"), repaired.String("stderr"), "The Linux graphical session is not running.")
			}
			if session != nil {
				session.SetDesktop(summary)
			}
			if !summary.Bool("available") {
				m.o.Env.logger().Warn("Desktop repair failed", "user", key, "error", summary.String("error"))
			}
		}
		if session != nil {
			if ms, first := session.RecordStartup(); first && session.DirectBoot && ms >= startupTargetMs {
				m.o.Env.logger().Warn("Startup SLA exceeded", "user", key, "ms", ms)
			}
		}
	}
	return m.Status(key, deviceTarget)
}

// Start shows the computer at once and finishes its startup in the background.
func (m *Manager) Start(ctx context.Context, key, deviceTarget string) (*omap, error) {
	status, err := m.EnsureDisplay(ctx, key, deviceTarget)
	if err != nil {
		return nil, err
	}
	m.queueStartup(key, deviceTarget)
	return status, nil
}

func (m *Manager) queueStartup(key, deviceTarget string) {
	c, provider, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return
	}
	jobKey := key + ":" + provider
	m.mu.Lock()
	if _, running := m.startups[jobKey]; running {
		m.mu.Unlock()
		return
	}
	done := make(chan struct{})
	m.startups[jobKey] = done
	m.mu.Unlock()
	go func() {
		defer func() {
			m.mu.Lock()
			delete(m.startups, jobKey)
			m.mu.Unlock()
			close(done)
		}()
		ctx := context.Background()
		guest, isGuest := c.(*VMBackend)
		if isGuest && !guest.Alive(key) {
			return
		}
		if _, err := m.EnsureComputer(ctx, key, deviceTarget); err != nil {
			m.o.Env.logger().Warn("Computer startup completion failed", "user", key, "error", err)
			return
		}
		if isGuest {
			if !guest.Alive(key) {
				return
			}
			if err := m.migrateWorkspace(ctx, key); err != nil {
				m.o.Env.logger().Warn("Workspace import failed", "user", key, "error", err)
			}
			if !guest.Alive(key) {
				return
			}
		}
		m.emit(key)
	}()
}

// migrateWorkspace copies the user's host workspace into a new computer once.
func (m *Manager) migrateWorkspace(ctx context.Context, key string) error {
	if m.o.WorkspaceRoot == nil {
		return nil
	}
	session := m.backend.vm.Instance(key)
	if session == nil || session.InstanceDir == "" {
		return nil
	}
	marker := filepath.Join(session.InstanceDir, "workspace-migration.json")
	if fileExists(marker) {
		return nil
	}
	root, err := m.o.WorkspaceRoot(ctx, key)
	if err != nil {
		return err
	}
	archive := filepath.Join(session.InstanceDir, fmt.Sprintf("workspace-import-%d.tar.gz", os.Getpid()))
	defer os.Remove(archive)
	res, err := proc.Run(ctx, 30*time.Minute, proc.Spec{Path: "tar", Args: []string{"-czf", archive, "-C", root, "."}}, 64*1024)
	if err != nil {
		return err
	}
	if res.Code != 0 {
		msg := strings.TrimSpace(res.Stderr)
		if msg == "" {
			msg = fmt.Sprintf("Workspace archive failed with exit %d.", res.Code)
		}
		return errors.New(msg)
	}
	digest, err := hashFile(archive, sha256.New())
	if err != nil {
		return err
	}
	imported, err := m.backend.ImportWorkspaceArchive(ctx, key, archive, digest)
	if err != nil {
		return err
	}
	if imported.String("sha256") != digest {
		return errors.New("Workspace migration did not return the verified checksum.")
	}
	entries := imported.Float("entries")
	raw, _ := json.MarshalIndent(map[string]any{"migratedAt": isoNow(), "sha256": digest, "entries": entries}, "", "  ")
	return writePrivate(marker, string(raw)+"\n")
}

// Stop releases control, closes viewers and stops the computer.
func (m *Manager) Stop(ctx context.Context, key, deviceTarget string) (*omap, error) {
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	m.ReleaseControl(key, "", deviceTarget)
	m.RevokeDisplaySessions(key)
	c.Stop(ctx, key)
	status, err := m.Status(key, deviceTarget)
	m.emit(key)
	return status, err
}

// ExecuteCommand runs a shell command on the user's computer.
func (m *Manager) ExecuteCommand(ctx context.Context, key, command, deviceTarget string, o ExecOptions) (*Object, error) {
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	return c.ExecuteCommand(ctx, key, command, o)
}

// ExecuteCLICommand is ExecuteCommand tagged with the backend that ran it.
func (m *Manager) ExecuteCLICommand(ctx context.Context, key, command, deviceTarget string, o ExecOptions) (*Object, error) {
	result, err := m.ExecuteCommand(ctx, key, command, deviceTarget, o)
	if err != nil {
		return nil, err
	}
	backend := "cloud-computer"
	if provider, _ := m.ResolveProvider(key, deviceTarget); provider == ProviderLocal {
		backend = "local-computer"
	}
	return result.Clone().Set("backend", backend), nil
}

// KillCommand stops a running command.
func (m *Manager) KillCommand(ctx context.Context, key string, pid any, reason, deviceTarget string) (*Object, error) {
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	return c.KillCommand(ctx, key, pid, reason)
}

// GuestHostAddress is how the user's guest computer reaches this server; ""
// when commands run on a person's own machine.
func (m *Manager) GuestHostAddress() string {
	if m.backend == nil {
		return ""
	}
	return m.backend.vm.GuestHostAddress()
}

// Browser is the browser of the user's computer.
func (m *Manager) Browser(ctx context.Context, key, deviceTarget string) (Browser, error) {
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	return c.OpenBrowser(ctx, key)
}

// Desktop is the desktop of the user's computer.
func (m *Manager) Desktop(key, deviceTarget string) (Desktop, error) {
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	return c.OpenDesktop(key), nil
}

// HasVM reports a running computer.
func (m *Manager) HasVM(key string) bool { return m.backend != nil && m.backend.vm.Alive(key) }

// RunningGuest is the agent of a running computer, never booting one.
func (m *Manager) RunningGuest(key string) (baseURL, token string, ok bool) {
	if m.backend == nil {
		return "", "", false
	}
	return m.backend.RunningGuest(key)
}

// GuestReady reports whether the computer's agent answers now.
func (m *Manager) GuestReady(ctx context.Context, key string, timeout time.Duration) bool {
	return m.backend != nil && m.backend.GuestReady(ctx, key, timeout)
}

// RequestComputer sends one request to the user's guest agent.
func (m *Manager) RequestComputer(ctx context.Context, key, method, path string, body any, deviceTarget string, o RequestOptions) (*Object, error) {
	c, _, err := m.computerFor(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	return c.RequestGuest(ctx, key, method, path, body, o)
}

func randomToken() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

// CreateDisplaySession hands out a short-lived token for the noVNC viewer.
func (m *Manager) CreateDisplaySession(key, deviceTarget string) (*omap, error) {
	provider, err := m.ResolveProvider(key, deviceTarget)
	if err != nil {
		return nil, err
	}
	if provider == ProviderLocal {
		if !m.local.connected(key) {
			return nil, &CodedError{Message: "This device is not connected to NeoAgent.", Code: "LOCAL_COMPUTER_NOT_CONNECTED", Status: 409}
		}
		return obj("provider", ProviderLocal, "local", true, "viewUrl", nil, "viewOnly", false), nil
	}
	if _, ok := m.DisplayTarget(key); !ok {
		return nil, &CodedError{Message: "Cloud computer display is not running.", Code: "COMPUTER_DISPLAY_UNAVAILABLE", Status: 409}
	}
	lease := m.ControlLease(key, ProviderCloud)
	viewOnly := lease == nil || lease.OwnerType == "agent"
	token := randomToken()
	expires := time.Now().Add(displaySessionTTL)
	m.mu.Lock()
	m.purgeDisplaysLocked()
	// The session grants whichever computer the user has running, never an
	// address: a restarted computer listens somewhere else.
	m.displays[token] = &DisplaySession{userKey: key, viewOnly: viewOnly, expiresAt: expires}
	m.mu.Unlock()
	return obj(
		"token", token,
		"expiresAt", isoTime(expires),
		"viewUrl", "/api/computer/display/"+token,
		"websocketPath", "/api/computer/display-ws?token="+token,
		"viewOnly", viewOnly,
	), nil
}

// DisplayTarget is where the user's live computer serves its screen.
func (m *Manager) DisplayTarget(key string) (vm.Address, bool) {
	if m.backend == nil || !m.backend.vm.Alive(key) {
		return vm.Address{}, false
	}
	s := m.backend.vm.Instance(key)
	if s == nil || s.Display.IsZero() {
		return vm.Address{}, false
	}
	return s.Display, true
}

// ResolveDisplaySession returns the user's live display session for token.
func (m *Manager) ResolveDisplaySession(key, token string) *DisplaySession {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.purgeDisplaysLocked()
	s := m.displays[token]
	if s == nil || s.userKey != key {
		return nil
	}
	return s
}

// DisplaySessionActive reports whether session is still the one for token.
func (m *Manager) DisplaySessionActive(key, token string, session *DisplaySession) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	current := m.displays[token]
	return current != nil && current == session && current.userKey == key
}

// TouchDisplaySession keeps a session alive while frames flow.
func (m *Manager) TouchDisplaySession(session *DisplaySession) {
	if session == nil {
		return
	}
	m.mu.Lock()
	session.expiresAt = time.Now().Add(displaySessionTTL)
	m.mu.Unlock()
}

// TouchComputerActivity records use and extends the control lease.
func (m *Manager) TouchComputerActivity(key string) {
	if m.cloud != nil {
		m.cloud.TouchActivity(key)
	}
	m.mu.Lock()
	if lease := m.leases[key+":"+ProviderCloud]; lease != nil {
		lease.ExpiresAt = time.Now().Add(controlLeaseTTL)
	}
	m.mu.Unlock()
}

// RevokeDisplaySessions closes every viewer of the user's computer.
func (m *Manager) RevokeDisplaySessions(key string) {
	m.mu.Lock()
	m.revokeDisplaysLocked(key)
	m.mu.Unlock()
}

func (m *Manager) revokeDisplaysLocked(key string) {
	for token, s := range m.displays {
		if s.userKey == key {
			delete(m.displays, token)
		}
	}
}

func (m *Manager) purgeDisplaysLocked() {
	now := time.Now()
	for token, s := range m.displays {
		if !s.expiresAt.After(now) {
			delete(m.displays, token)
		}
	}
}

func leaseKey(key, provider string) string { return key + ":" + provider }

func (m *Manager) leaseProvider(key, provider string) string {
	if provider == ProviderLocal || provider == ProviderCloud {
		return provider
	}
	return m.ComputerProvider(key)
}

// AcquireControl gives the computer to an owner. An agent may take over from
// the user; anything else conflicts with a different owner type.
func (m *Manager) AcquireControl(key, ownerType, ownerID, provider string) (*omap, error) {
	provider = m.leaseProvider(key, provider)
	ownerType = strings.TrimSpace(ownerType)
	ownerID = strings.TrimSpace(ownerID)
	if (ownerType != "agent" && ownerType != "user" && ownerType != "teach") || ownerID == "" {
		return nil, errors.New("A valid computer control owner is required.")
	}
	existing := m.ControlLease(key, provider)
	agentOverUser := existing != nil && ownerType == "agent" && existing.OwnerType == "user"
	if existing != nil && existing.OwnerType != ownerType && !agentOverUser {
		return nil, &CodedError{Message: fmt.Sprintf("%s is controlled by %s.", computerLabel(provider), existing.OwnerType), Code: "COMPUTER_CONTROL_CONFLICT", Status: 409}
	}
	if existing != nil && existing.OwnerType != "agent" && existing.OwnerID != ownerID && !agentOverUser {
		return nil, &CodedError{Message: fmt.Sprintf("%s is controlled by %s.", computerLabel(provider), existing.OwnerType), Code: "COMPUTER_CONTROL_CONFLICT", Status: 409}
	}
	sameType := existing != nil && existing.OwnerType == ownerType
	var ids []string
	if sameType {
		for _, id := range existing.OwnerIDs {
			if id != ownerID {
				ids = append(ids, id)
			}
		}
	}
	ids = append(ids, ownerID)
	lease := &Lease{OwnerType: ownerType, OwnerID: ownerID, OwnerIDs: ids, Provider: provider, ExpiresAt: time.Now().Add(controlLeaseTTL)}
	m.mu.Lock()
	if !sameType && provider == ProviderCloud {
		m.revokeDisplaysLocked(key)
	}
	m.leases[leaseKey(key, provider)] = lease
	m.mu.Unlock()
	if existing == nil || existing.OwnerType != ownerType {
		m.emit(key)
	}
	return obj("ownerType", ownerType, "ownerId", ownerID, "ownerIds", append([]string{}, ids...), "provider", provider, "expiresAt", isoTime(lease.ExpiresAt)), nil
}

// ControlLease is the live lease of the user's computer, or nil.
func (m *Manager) ControlLease(key, provider string) *Lease {
	provider = m.leaseProvider(key, provider)
	m.mu.Lock()
	defer m.mu.Unlock()
	k := leaseKey(key, provider)
	lease := m.leases[k]
	if lease == nil {
		return nil
	}
	if !lease.ExpiresAt.After(time.Now()) {
		delete(m.leases, k)
		if provider == ProviderCloud {
			m.revokeDisplaysLocked(key)
		}
		return nil
	}
	copied := *lease
	copied.OwnerIDs = append([]string{}, lease.OwnerIDs...)
	return &copied
}

// ReleaseControl frees the computer: all owners when ownerID is empty, or one.
// An empty provider releases both computers.
func (m *Manager) ReleaseControl(key, ownerID, provider string) bool {
	providers := []string{ProviderCloud, ProviderLocal}
	if provider != "" {
		providers = []string{m.leaseProvider(key, provider)}
	}
	released := false
	m.mu.Lock()
	for _, p := range providers {
		k := leaseKey(key, p)
		lease := m.leases[k]
		if lease == nil {
			continue
		}
		if ownerID == "" {
			delete(m.leases, k)
			if p == ProviderCloud {
				m.revokeDisplaysLocked(key)
			}
			released = true
			continue
		}
		var rest []string
		found := false
		for _, id := range lease.OwnerIDs {
			if id == ownerID {
				found = true
			} else {
				rest = append(rest, id)
			}
		}
		if !found {
			continue
		}
		released = true
		if len(rest) == 0 {
			delete(m.leases, k)
			if p == ProviderCloud {
				m.revokeDisplaysLocked(key)
			}
			continue
		}
		lease.OwnerIDs = rest
		lease.OwnerID = rest[len(rest)-1]
	}
	m.mu.Unlock()
	if released {
		m.emit(key)
	}
	return released
}

// Shutdown stops every computer.
func (m *Manager) Shutdown() {
	m.mu.Lock()
	m.displays = map[string]*DisplaySession{}
	m.leases = map[string]*Lease{}
	m.mu.Unlock()
	if m.cloud != nil {
		m.cloud.Shutdown()
	}
	if m.local != nil {
		m.local.Shutdown()
	}
}

// WorkspaceDir is where interactive commands run unless the caller pins one.
const WorkspaceDir = guestproto.WorkspaceDir

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}
