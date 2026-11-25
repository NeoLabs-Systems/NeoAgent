package runtime

import (
	"context"
	"encoding/base64"
	"errors"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

// Artifact is a file a computer produced that the server keeps for the user.
type Artifact struct {
	Kind, Backend, Extension, ContentType, FilenameBase string
	Content                                             []byte
	Metadata                                            map[string]any
}

// StoredArtifact is where an artifact landed.
type StoredArtifact struct {
	ID, URL, StoragePath string
	ByteSize             int64
}

// ArtifactStore keeps artifacts (screenshots, command output).
type ArtifactStore interface {
	CreateBufferArtifact(ctx context.Context, userKey string, a Artifact) (StoredArtifact, error)
}

// ExecOptions are the options of a command run on a computer.
type ExecOptions struct {
	Cwd string
	// TimeoutMs is the command's own timeout; 0 leaves the guest default.
	TimeoutMs  float64
	StdinInput *string
	PTY        bool
	Inputs     []any
	Env        map[string]string
	RunID      string
	StepID     string
}

// BackendOptions configure a VMBackend.
type BackendOptions struct {
	Manager   VMManager
	Artifacts ArtifactStore
	Env       Env
	// IdleTimeout stops a computer nobody used for this long; 0 reads
	// NEOAGENT_VM_IDLE_TIMEOUT_MS (default 10 minutes), negative disables it.
	IdleTimeout time.Duration
}

// VMBackend runs commands, browser and desktop actions on the user's guest
// computer, starting it on first use and stopping it when idle.
type VMBackend struct {
	vm        VMManager
	artifacts ArtifactStore
	env       Env
	token     string
	idle      time.Duration

	mu            sync.Mutex
	lastActivity  map[string]time.Time
	active        map[string]int
	caching       map[string]bool
	shuttingDown  bool
	stopReaper    chan struct{}
	reaperRunning bool
	wg            sync.WaitGroup
	// IdleProtected keeps a computer someone is controlling awake.
	IdleProtected func(key string) bool
}

// NewVMBackend creates the backend and starts its idle reaper.
func NewVMBackend(o BackendOptions) *VMBackend {
	b := &VMBackend{
		vm: o.Manager, artifacts: o.Artifacts, env: o.Env,
		token:        trimmed(o.Env.get("NEOAGENT_VM_GUEST_TOKEN")),
		lastActivity: map[string]time.Time{}, active: map[string]int{}, caching: map[string]bool{},
		stopReaper: make(chan struct{}),
	}
	b.idle = o.IdleTimeout
	if b.idle == 0 {
		b.idle = 10 * time.Minute
		if ms, err := strconv.Atoi(trimmed(o.Env.get("NEOAGENT_VM_IDLE_TIMEOUT_MS"))); err == nil {
			b.idle = time.Duration(ms) * time.Millisecond
		}
	}
	if b.idle > 0 {
		b.reaperRunning = true
		go b.reap()
	}
	return b
}

// Manager is the VM manager behind the backend.
func (b *VMBackend) Manager() VMManager { return b.vm }

// TouchActivity records use of the user's computer.
func (b *VMBackend) TouchActivity(key string) {
	if key == "" {
		return
	}
	b.mu.Lock()
	b.lastActivity[key] = time.Now()
	b.mu.Unlock()
}

func (b *VMBackend) withActive(key string, work func() error) error {
	b.mu.Lock()
	b.active[key]++
	b.mu.Unlock()
	b.TouchActivity(key)
	defer func() {
		b.mu.Lock()
		if b.active[key] <= 1 {
			delete(b.active, key)
		} else {
			b.active[key]--
		}
		b.mu.Unlock()
		b.TouchActivity(key)
	}()
	return work()
}

func (b *VMBackend) reap() {
	interval := min(b.idle, time.Minute)
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-b.stopReaper:
			return
		case <-ticker.C:
		}
		now := time.Now()
		b.mu.Lock()
		var idle []string
		for key, last := range b.lastActivity {
			if b.active[key] > 0 || now.Sub(last) <= b.idle {
				continue
			}
			if b.IdleProtected != nil && b.IdleProtected(key) {
				continue
			}
			idle = append(idle, key)
			delete(b.lastActivity, key)
		}
		b.mu.Unlock()
		for _, key := range idle {
			b.env.logger().Info("Computer idle, shutting it down", "user", key)
			b.vm.Sleep(key)
		}
	}
}

func shuttingDownErr() error {
	return &CodedError{Message: "Local VM runtime is shutting down.", Code: "RUNTIME_SHUTTING_DOWN"}
}

// Client starts the user's computer if needed and waits for its agent.
func (b *VMBackend) Client(ctx context.Context, key string) (*GuestClient, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	b.mu.Lock()
	down := b.shuttingDown
	b.mu.Unlock()
	if down {
		return nil, shuttingDownErr()
	}
	session, err := b.vm.Ensure(ctx, key)
	if err != nil {
		return nil, err
	}
	b.mu.Lock()
	down = b.shuttingDown
	b.mu.Unlock()
	if down {
		return nil, shuttingDownErr()
	}
	b.TouchActivity(key)
	token := session.GuestToken
	if token == "" {
		token = b.token
	}
	client := NewGuestClient(session.BaseURL, token, func() { b.TouchActivity(key) })
	// A direct boot answers within seconds; a guest that still provisions its
	// desktop and packages takes far longer.
	timeout := GuestHealthTimeout
	if !session.DirectBoot {
		timeout = b.vm.BootTimeout()
	}
	if _, err := client.WaitForHealth(ctx, timeout, func() bool { return b.vm.Alive(key) }); err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		message := err.Error()
		if detail := session.FailureDetail(); detail != "" {
			message += " " + detail
		}
		code := "COMPUTER_START_FAILED"
		var coded *CodedError
		if errors.As(err, &coded) && coded.Code != "" {
			code = coded.Code
		}
		startErr := &CodedError{Message: message, Code: code, Status: 503}
		b.vm.Fail(key, startErr)
		return nil, startErr
	}
	session.MarkReadyIfStarting()
	b.cacheBootAssets(key, client)
	return client, nil
}

// cacheBootAssets shortens the next start; it runs off the request path and a
// failure never takes the running computer down.
func (b *VMBackend) cacheBootAssets(key string, client *GuestClient) {
	cacher, ok := b.vm.(bootAssetCacher)
	if !ok {
		return
	}
	b.mu.Lock()
	if b.caching[key] || b.shuttingDown {
		b.mu.Unlock()
		return
	}
	b.caching[key] = true
	b.wg.Add(1)
	b.mu.Unlock()
	go func() {
		defer b.wg.Done()
		if err := cacher.CacheDirectBootAssets(context.Background(), key, client); err != nil {
			b.env.logger().Warn("Direct-boot asset caching failed", "user", key, "error", err)
		}
		b.mu.Lock()
		delete(b.caching, key)
		b.mu.Unlock()
	}()
}

// RequestGuest sends one request to the user's guest agent.
func (b *VMBackend) RequestGuest(ctx context.Context, key, method, path string, body any, o RequestOptions) (*Object, error) {
	client, err := b.Client(ctx, key)
	if err != nil {
		return nil, err
	}
	if o.Timeout <= 0 {
		o.Timeout = 2 * time.Minute
	}
	if o.MaxResponseBytes <= 0 {
		o.MaxResponseBytes = 32 << 20
	}
	return client.Request(ctx, method, path, body, o)
}

// ImportWorkspaceArchive uploads a gzip tarball into the guest's workspace.
func (b *VMBackend) ImportWorkspaceArchive(ctx context.Context, key, archivePath, sha256 string) (*Object, error) {
	client, err := b.Client(ctx, key)
	if err != nil {
		return nil, err
	}
	f, err := os.Open(archivePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil {
		return nil, err
	}
	return client.RequestStream(ctx, http.MethodPost, "/workspace/import", f, "application/gzip", info.Size(),
		map[string]string{"x-neoagent-sha256": sha256}, RequestOptions{Timeout: 30 * time.Minute, MaxResponseBytes: 1 << 20})
}

// ExecuteCommand runs a shell command in the guest. Output too large for the
// answer is kept as a command-output artifact.
func (b *VMBackend) ExecuteCommand(ctx context.Context, key, command string, o ExecOptions) (*Object, error) {
	var result *Object
	err := b.withActive(key, func() error {
		client, err := b.Client(ctx, key)
		if err != nil {
			return err
		}
		transport := 16 * time.Minute
		if o.TimeoutMs > 0 {
			transport = min(30*time.Minute, time.Duration(o.TimeoutMs)*time.Millisecond+30*time.Second)
		}
		body := map[string]any{"command": command, "pty": o.PTY, "inputs": o.Inputs}
		if o.Inputs == nil {
			body["inputs"] = []any{}
		}
		if o.Cwd != "" {
			body["cwd"] = o.Cwd
		}
		if o.TimeoutMs > 0 {
			body["timeout"] = o.TimeoutMs
		}
		if o.StdinInput != nil {
			body["stdin_input"] = *o.StdinInput
		}
		if len(o.Env) > 0 {
			body["env"] = o.Env
		}
		raw, err := client.Request(ctx, http.MethodPost, "/exec", body, RequestOptions{Timeout: transport, Retries: Retries(0)})
		if err != nil {
			return err
		}
		result, err = b.materializeOutput(ctx, client, key, raw, o)
		return err
	})
	return result, err
}

func (b *VMBackend) materializeOutput(ctx context.Context, client *GuestClient, key string, result *Object, o ExecOptions) (*Object, error) {
	outputPath := result.String("outputFilePath")
	if outputPath == "" {
		return result, nil
	}
	complete := !isFalse(result, "outputFileComplete")
	sanitized := result.Clone()
	for _, k := range []string{"outputFilePath", "outputFileByteSize", "outputFileComplete"} {
		sanitized.Delete(k)
	}
	if b.artifacts == nil {
		return sanitized.Set("artifactError", "Artifact store is unavailable."), nil
	}
	file, err := client.Request(ctx, http.MethodPost, "/files/read", map[string]any{"path": outputPath, "encoding": "base64", "delete_after_read": true},
		RequestOptions{Timeout: 30 * time.Second, MaxResponseBytes: 24 << 20, Retries: Retries(0)})
	var content []byte
	if err == nil {
		content, _ = base64.StdEncoding.DecodeString(file.String("content"))
		if len(content) == 0 {
			err = errors.New("Guest command output artifact was empty.")
		}
	}
	var stored StoredArtifact
	if err == nil {
		stored, err = b.artifacts.CreateBufferArtifact(ctx, key, Artifact{
			Kind: "command-output", Backend: "vm", Extension: "log", ContentType: "text/plain; charset=utf-8",
			FilenameBase: "command-output", Content: content,
			Metadata: map[string]any{
				"runId": nullable(o.RunID), "stepId": nullable(o.StepID),
				"stdoutBytes": result.Float("stdoutBytes"), "stderrBytes": result.Float("stderrBytes"),
				"complete": complete,
			},
		})
	}
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return sanitized.Set("artifactError", err.Error()), nil
	}
	return sanitized.Set("outputArtifact", obj("artifactId", stored.ID, "url", stored.URL, "byteSize", stored.ByteSize, "complete", complete)), nil
}

// isFalse reports a key that holds exactly false.
func isFalse(o *Object, key string) bool {
	var b bool
	return o.Has(key) && o.Decode(key, &b) && !b
}

// KillCommand stops a running command in the guest.
func (b *VMBackend) KillCommand(ctx context.Context, key string, pid any, reason string) (*Object, error) {
	client, err := b.Client(ctx, key)
	if err != nil {
		return nil, err
	}
	if reason == "" {
		reason = "aborted"
	}
	return client.Request(ctx, http.MethodPost, "/exec/kill", map[string]any{"pid": pid, "reason": reason}, RequestOptions{})
}

// Browser returns the browser of the user's computer, starting it if needed.
func (b *VMBackend) Browser(ctx context.Context, key string) (*BrowserProvider, error) {
	client, err := b.Client(ctx, key)
	if err != nil {
		return nil, err
	}
	return &BrowserProvider{client: client, userKey: key, artifacts: b.artifacts}, nil
}

// RunningGuest is where the agent of an already running computer answers.
// It never boots one.
func (b *VMBackend) RunningGuest(key string) (baseURL, token string, ok bool) {
	b.mu.Lock()
	down := b.shuttingDown
	b.mu.Unlock()
	if key == "" || down || !b.vm.Alive(key) {
		return "", "", false
	}
	s := b.vm.Instance(key)
	if s == nil || s.BaseURL == "" || s.State() != StateReady {
		return "", "", false
	}
	token = s.GuestToken
	if token == "" {
		token = b.token
	}
	return s.BaseURL, token, true
}

// GuestReady reports whether the agent of the user's computer answers now.
func (b *VMBackend) GuestReady(ctx context.Context, key string, timeout time.Duration) bool {
	s := b.vm.Instance(key)
	if s == nil || s.BaseURL == "" {
		return false
	}
	token := s.GuestToken
	if token == "" {
		token = b.token
	}
	_, err := NewGuestClient(s.BaseURL, token, nil).Request(ctx, http.MethodGet, "/health", nil, RequestOptions{Timeout: timeout})
	return err == nil
}

// Shutdown stops every computer.
func (b *VMBackend) Shutdown() {
	b.mu.Lock()
	if b.shuttingDown {
		b.mu.Unlock()
		return
	}
	b.shuttingDown = true
	b.active = map[string]int{}
	running := b.reaperRunning
	b.mu.Unlock()
	b.wg.Wait()
	if running {
		close(b.stopReaper)
	}
	b.vm.Shutdown()
}
