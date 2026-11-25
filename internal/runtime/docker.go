package runtime

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	goruntime "runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/proc"
	"github.com/NeoLabs-Systems/neolabs-go/vm"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

const (
	dockerManagedLabel   = "neoagent.managed=1"
	dockerStopSeconds    = 10
	dockerRemoveTimeout  = 30 * time.Second
	dockerLogTailLines   = 40
	guestImageRepo       = "neoagent-guest-agent"
	browserReadyMarker   = "/var/lib/neoagent/browser-runtime-ready"
	defaultGuestBase     = "debian:trixie-slim"
	defaultDockerBoot    = 5 * time.Minute
	defaultImageBuildMax = 20 * time.Minute
)

// docker runs a docker CLI command and returns its stdout.
func docker(ctx context.Context, timeout time.Duration, args ...string) (proc.Result, error) {
	return proc.Run(ctx, timeout, proc.Spec{Path: "docker", Args: args}, 1<<20)
}

func dockerAvailable(ctx context.Context) bool {
	res, err := docker(ctx, 5*time.Second, "info", "--format", "{{.ServerVersion}}")
	return err == nil && res.Code == 0
}

// DockerContainerName names a user's computer container from a hash.
func DockerContainerName(key string) string { return "neoagent-guest-" + UserDirectoryKey(key) }

// DockerHomeVolume names the volume that keeps a user's home across containers.
func DockerHomeVolume(key string) string { return "neoagent-home-" + UserDirectoryKey(key) }

// GuestImageDockerfile is the Dockerfile of the guest image: the static guest
// agent on Debian with Chromium baked in, so a start never installs anything.
func GuestImageDockerfile(baseImage, profile string) string {
	browser := profile == "browser" || profile == "browser_cli"
	packages := "ca-certificates curl"
	if browser {
		packages += " chromium fonts-liberation xdg-utils xvfb"
	}
	lines := []string{
		"FROM " + baseImage,
		"ENV NEOAGENT_GUEST_PROFILE=" + profile,
		"ENV HOME=" + guestproto.Home,
		"RUN apt-get update && apt-get install -y --no-install-recommends " + packages + " && rm -rf /var/lib/apt/lists/*",
		"RUN set -eu; " + strings.Join(strings.Split(TailscaleInstallScript(), "\n"), " "),
		"COPY neoagent-guest " + guestproto.BinaryPath,
		"RUN chmod 0755 " + guestproto.BinaryPath,
		// The agent runs as the host uid:gid on Linux, so its home must be
		// writable by an arbitrary uid.
		"RUN mkdir -p " + guestproto.WorkspaceDir + " && chmod -R 0777 " + guestproto.Home,
	}
	if browser {
		lines = append(lines, "RUN mkdir -p "+filepath.ToSlash(filepath.Dir(browserReadyMarker))+" && touch "+browserReadyMarker)
	}
	lines = append(lines, `CMD ["`+guestproto.BinaryPath+`"]`, "")
	return strings.Join(lines, "\n")
}

// guestImage builds and caches the per-profile guest image. Its tag is content
// addressed over the agent binary and the Dockerfile.
type guestImage struct {
	env     Env
	dirs    Dirs
	profile string
	arch    string

	mu       sync.Mutex
	building chan struct{}
	buildErr error
	tag      string
}

func (g *guestImage) baseImage() string {
	if v := trimmed(g.env.get("NEOAGENT_GUEST_BASE_IMAGE")); v != "" {
		return v
	}
	return defaultGuestBase
}

func (g *guestImage) resolveTag() (string, []byte, error) {
	agent, err := readGuestAgent(g.env, g.dirs, g.arch)
	if err != nil {
		return "", nil, err
	}
	h := sha256.New()
	h.Write([]byte(guestPayloadDigest(agent)))
	h.Write([]byte(GuestImageDockerfile(g.baseImage(), g.profile)))
	tag := guestImageRepo + ":" + g.profile + "-" + hex.EncodeToString(h.Sum(nil))[:12]
	g.mu.Lock()
	g.tag = tag
	g.mu.Unlock()
	return tag, agent, nil
}

func (g *guestImage) exists(ctx context.Context, tag string) bool {
	res, err := docker(ctx, 10*time.Second, "image", "inspect", tag)
	return err == nil && res.Code == 0
}

// state is a side-effect-free snapshot for readiness polling.
func (g *guestImage) state(ctx context.Context) (available, built bool, image any) {
	if !dockerAvailable(ctx) {
		g.mu.Lock()
		defer g.mu.Unlock()
		return false, false, nullable(g.tag)
	}
	tag, _, err := g.resolveTag()
	if err != nil {
		return true, false, nil
	}
	return true, g.exists(ctx, tag), tag
}

// ensure returns the image tag, building the image once when it is missing.
func (g *guestImage) ensure(ctx context.Context) (string, error) {
	tag, agent, err := g.resolveTag()
	if err != nil {
		return "", err
	}
	if g.exists(ctx, tag) {
		return tag, nil
	}
	g.mu.Lock()
	if g.building != nil {
		wait := g.building
		g.mu.Unlock()
		<-wait
		g.mu.Lock()
		defer g.mu.Unlock()
		return tag, g.buildErr
	}
	g.building = make(chan struct{})
	g.mu.Unlock()
	err = g.build(ctx, tag, agent)
	g.mu.Lock()
	g.buildErr = err
	close(g.building)
	g.building = nil
	g.mu.Unlock()
	return tag, err
}

func (g *guestImage) build(ctx context.Context, tag string, agent []byte) error {
	log := g.env.logger()
	started := time.Now()
	log.Info("Building guest image (one-time)", "tag", tag)
	contextDir := filepath.Join(g.dirs.containerRoot(), "guest-image", g.profile)
	if err := ensurePrivateDir(contextDir); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(contextDir, "neoagent-guest"), agent, 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(contextDir, "Dockerfile"), []byte(GuestImageDockerfile(g.baseImage(), g.profile)), 0o644); err != nil {
		return err
	}
	timeout := defaultImageBuildMax
	if ms, err := strconv.Atoi(trimmed(g.env.get("NEOAGENT_GUEST_IMAGE_BUILD_TIMEOUT_MS"))); err == nil && ms > 0 {
		timeout = time.Duration(ms) * time.Millisecond
	}
	res, err := proc.Run(ctx, timeout, proc.Spec{Path: "docker", Args: []string{"build", "-t", tag, contextDir}}, 64*1024)
	if err != nil {
		return err
	}
	if res.Code != 0 {
		return fmt.Errorf("Guest image build failed (docker build exited %d). %s", res.Code, strings.TrimSpace(res.Stderr))
	}
	log.Info("Built guest image", "tag", tag, "seconds", int(time.Since(started).Seconds()))
	return nil
}

// DockerOptions configure a DockerManager.
type DockerOptions struct {
	Dirs        Dirs
	Env         Env
	Profile     *ResourceProfile
	BootTimeout time.Duration
	PidsLimit   int
}

// DockerManager runs each user's computer as a Docker container.
type DockerManager struct {
	o           DockerOptions
	image       *guestImage
	profile     ResourceProfile
	bootTimeout time.Duration
	pidsLimit   int

	mu             sync.Mutex
	instances      map[string]*Session
	starts         *startTracker
	orphansRemoved bool
	onStopped      func(string)
}

// NewDockerManager prepares the container directories; it never touches Docker.
func NewDockerManager(o DockerOptions) *DockerManager {
	m := &DockerManager{o: o, instances: map[string]*Session{}, starts: newStartTracker()}
	m.image = &guestImage{env: o.Env, dirs: o.Dirs, profile: "browser_cli", arch: hostArchitecture()}
	if o.Profile != nil {
		m.profile = *o.Profile
	} else {
		m.profile = ComputerResourceProfile(ProfileOptions{Getenv: o.Env.get})
	}
	m.bootTimeout = o.BootTimeout
	if m.bootTimeout <= 0 {
		m.bootTimeout = defaultDockerBoot
		if ms, err := strconv.Atoi(trimmed(o.Env.get("NEOAGENT_VM_BOOT_TIMEOUT_MS"))); err == nil && ms > 0 {
			m.bootTimeout = time.Duration(ms) * time.Millisecond
		}
	}
	m.pidsLimit = o.PidsLimit
	if m.pidsLimit <= 0 {
		m.pidsLimit = 512
		if n, err := strconv.Atoi(trimmed(o.Env.get("NEOAGENT_VM_PIDS_LIMIT"))); err == nil && n > 0 {
			m.pidsLimit = n
		}
	}
	_ = ensurePrivateDir(o.Dirs.containerRoot())
	_ = ensurePrivateDir(filepath.Join(o.Dirs.containerRoot(), "instances"))
	return m
}

// Readiness implements VMManager.
func (m *DockerManager) Readiness() *omap {
	available, built, image := m.image.state(context.Background())
	missing := []string{}
	if !available {
		missing = append(missing, "docker")
	}
	agentOK := resolveGuestAgent(m.o.Env, m.o.Dirs, m.image.arch) != ""
	if !agentOK {
		missing = append(missing, GuestAgentFileName(m.image.arch))
	}
	return obj(
		"ready", available && agentOK,
		"dockerAvailable", available,
		"imageReady", built,
		"image", image,
		"runtimeProfile", m.image.profile,
		"missing", missing,
		"resources", m.profile,
	)
}

func dockerUnavailable() error {
	return &CodedError{
		Message: "Docker computer runtime is unavailable: the Docker daemon did not respond. Start Docker, then run neoagent repair.",
		Code:    "COMPUTER_RUNTIME_UNAVAILABLE", Status: 503,
	}
}

// PrepareRuntime makes sure Docker answers and builds the guest image.
func (m *DockerManager) PrepareRuntime(ctx context.Context, buildImage bool) (*omap, error) {
	r := m.Readiness()
	if !r.Bool("dockerAvailable") {
		return nil, dockerUnavailable()
	}
	if !buildImage {
		return r, nil
	}
	if _, err := m.image.ensure(ctx); err != nil {
		return nil, err
	}
	return m.Readiness(), nil
}

// Capabilities implements VMManager.
func (m *DockerManager) Capabilities() []string { return capabilityList("browser", "shell", "files") }

// BootTimeout implements VMManager.
func (m *DockerManager) BootTimeout() time.Duration { return m.bootTimeout }

// GuestHostAddress implements VMManager.
func (m *DockerManager) GuestHostAddress() string { return "host.docker.internal" }

// OnStopped implements VMManager.
func (m *DockerManager) OnStopped(fn func(string)) { m.mu.Lock(); m.onStopped = fn; m.mu.Unlock() }

// Instance implements VMManager.
func (m *DockerManager) Instance(key string) *Session {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.instances[key]
}

// Alive implements VMManager.
func (m *DockerManager) Alive(key string) bool { return m.Instance(key).Alive() }

// Tracked implements VMManager.
func (m *DockerManager) Tracked(key string) bool { return m.Instance(key) != nil }

// Status implements VMManager.
func (m *DockerManager) Status(key string) *omap {
	return sessionStatus(m.Instance(key), m.starts.status(key), m.Capabilities(), m.Readiness(), nil, func(*Session) string { return "container" })
}

// removeOrphans drops containers a previous server left behind, once, before
// the first start (never while only reporting status).
func (m *DockerManager) removeOrphans(ctx context.Context) {
	m.mu.Lock()
	done := m.orphansRemoved
	m.orphansRemoved = true
	m.mu.Unlock()
	if done {
		return
	}
	res, err := docker(ctx, 30*time.Second, "container", "ls", "--all", "--quiet", "--filter", "label="+dockerManagedLabel)
	if err != nil || res.Code != 0 {
		m.o.Env.logger().Warn("Could not clean up orphaned computer containers", "error", strings.TrimSpace(res.Stderr))
		return
	}
	ids := strings.Fields(res.Stdout)
	if len(ids) == 0 {
		return
	}
	_, _ = docker(ctx, time.Minute, append([]string{"container", "rm", "--force"}, ids...)...)
	m.o.Env.logger().Info("Removed orphaned computer containers", "count", len(ids))
}

// Ensure implements VMManager.
func (m *DockerManager) Ensure(ctx context.Context, key string) (*Session, error) {
	if key == "" {
		return nil, errors.New("Cloud computer requires a user ID.")
	}
	m.mu.Lock()
	existing := m.instances[key]
	if existing != nil && existing.Alive() {
		m.mu.Unlock()
		return existing, nil
	}
	if existing != nil {
		delete(m.instances, key)
	}
	m.mu.Unlock()
	return m.starts.begin(ctx, key, func() (*Session, error) { return m.start(context.Background(), key) })
}

func (m *DockerManager) activeAllocations() []Allocation {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Allocation
	for _, s := range m.instances {
		if s.Alive() {
			out = append(out, s.Resources)
		}
	}
	return out
}

// tailWriter keeps the last bytes written to it.
type tailWriter struct {
	mu  sync.Mutex
	buf []byte
	max int
}

func (t *tailWriter) Write(p []byte) (int, error) {
	t.mu.Lock()
	t.buf = append(t.buf, p...)
	if len(t.buf) > t.max {
		t.buf = t.buf[len(t.buf)-t.max:]
	}
	t.mu.Unlock()
	return len(p), nil
}

func (t *tailWriter) String() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return strings.TrimSpace(string(t.buf))
}

func (m *DockerManager) start(ctx context.Context, key string) (*Session, error) {
	log := m.o.Env.logger()
	if !m.Readiness().Bool("ready") {
		err := dockerUnavailable()
		log.Error(err.Error())
		return nil, err
	}
	m.removeOrphans(ctx)
	resources, err := AllocateComputerResources(m.profile, m.activeAllocations())
	if err != nil {
		return nil, err
	}
	image, err := m.image.ensure(ctx)
	if err != nil {
		return nil, err
	}
	name := DockerContainerName(key)
	_, _ = docker(ctx, dockerRemoveTimeout, "container", "rm", "--force", name)
	instanceDir := filepath.Join(m.o.Dirs.containerRoot(), "instances", UserDirectoryKey(key))
	if err := ensurePrivateDir(instanceDir); err != nil {
		return nil, err
	}
	hostPort, err := vm.FreePort()
	if err != nil {
		return nil, err
	}
	token := randomHex(32)
	port := strconv.Itoa(guestproto.DefaultPort)
	args := []string{"run", "--name", name,
		"--memory", fmt.Sprintf("%dm", resources.MemoryMb),
		"--cpus", strconv.Itoa(resources.CPUs),
		"--pids-limit", strconv.Itoa(m.pidsLimit),
		"--shm-size", "1g"}
	if goruntime.GOOS == "linux" {
		args = append(args, "--user", fmt.Sprintf("%d:%d", os.Getuid(), os.Getgid()))
	}
	args = append(args,
		"--publish", fmt.Sprintf("127.0.0.1:%d:%s", hostPort, port),
		"--add-host", "host.docker.internal:host-gateway",
		"--volume", DockerHomeVolume(key)+":"+guestproto.Home,
		"--env", guestproto.EnvPort+"="+port,
		"--env", guestproto.EnvToken+"="+token,
		"--env", guestproto.EnvProfile+"="+m.image.profile,
		"--env", "HOME="+guestproto.Home,
		"--security-opt", "no-new-privileges",
		"--cap-drop", "NET_RAW", "--cap-drop", "NET_ADMIN", "--cap-drop", "SYS_ADMIN",
		"--cap-drop", "SYS_MODULE", "--cap-drop", "SYS_PTRACE",
		"--label", dockerManagedLabel,
		"--label", "neoagent.profile="+m.image.profile,
		image)
	stderr := &tailWriter{max: 4096}
	// `docker run` stays attached, so its process tracks the container's life.
	process, err := proc.Start(proc.Spec{Path: "docker", Args: args, Stderr: stderr})
	if err != nil {
		return nil, &CodedError{Message: "Docker failed to start the computer: " + err.Error(), Code: "COMPUTER_START_FAILED", Status: 503}
	}
	session := NewSession()
	session.InstanceDir = instanceDir
	session.BaseURL = fmt.Sprintf("http://127.0.0.1:%d", hostPort)
	session.GuestToken = token
	session.ContainerName = name
	session.Process = process
	session.Resources = resources
	session.StartedAt = time.Now()
	session.DirectBoot = true
	session.LogTail = func() string {
		res, err := docker(context.Background(), 5*time.Second, "logs", "--tail", strconv.Itoa(dockerLogTailLines), name)
		if err == nil {
			if out := strings.TrimSpace(res.Stdout); out != "" {
				return out
			}
			if out := strings.TrimSpace(res.Stderr); out != "" {
				return out
			}
		}
		return stderr.String()
	}
	m.mu.Lock()
	m.instances[key] = session
	m.mu.Unlock()
	go func() {
		exit := process.Wait()
		if session.State() != StateStopping {
			code := strconv.Itoa(exit.Code)
			if exit.Signal != "" {
				code = exit.Signal
			}
			session.FailWith(strings.TrimSpace(fmt.Sprintf("Computer container exited (%s). %s", code, stderr.String())))
			log.Error("Computer process ended", "user", key, "error", session.LastError())
		}
		m.mu.Lock()
		stopped := m.onStopped
		m.mu.Unlock()
		if stopped != nil {
			stopped(key)
		}
	}()
	log.Info("Started computer", "user", key, "memoryMb", resources.MemoryMb, "cpus", resources.CPUs)
	return session, nil
}

// Kill implements VMManager.
func (m *DockerManager) Kill(key string) {
	m.starts.clear(key)
	m.mu.Lock()
	session := m.instances[key]
	delete(m.instances, key)
	m.mu.Unlock()
	if session == nil {
		return
	}
	session.SetState(StateStopping)
	ctx := context.Background()
	_, _ = docker(ctx, (dockerStopSeconds+5)*time.Second, "stop", "--time", strconv.Itoa(dockerStopSeconds), session.ContainerName)
	select {
	case <-session.Process.Done():
	case <-time.After(5 * time.Second):
	}
	_, _ = docker(ctx, dockerRemoveTimeout, "container", "rm", "--force", session.ContainerName)
	if session.Alive() {
		session.Process.Kill()
		select {
		case <-session.Process.Done():
		case <-time.After(2 * time.Second):
		}
	}
}

// RemoveUserData implements VMManager: the home volume holds the user's data.
func (m *DockerManager) RemoveUserData(key string) {
	if key == "" {
		return
	}
	_, _ = docker(context.Background(), dockerRemoveTimeout, "volume", "rm", "--force", DockerHomeVolume(key))
	_ = os.RemoveAll(filepath.Join(m.o.Dirs.containerRoot(), "instances", UserDirectoryKey(key)))
}

// Fail implements VMManager.
func (m *DockerManager) Fail(key string, err error) { m.Kill(key); m.starts.fail(key, err) }

// Sleep implements VMManager.
func (m *DockerManager) Sleep(key string) { m.Kill(key); m.starts.sleep(key) }

// Shutdown implements VMManager.
func (m *DockerManager) Shutdown() {
	m.starts.settled()
	m.mu.Lock()
	keys := make([]string, 0, len(m.instances))
	for k := range m.instances {
		keys = append(keys, k)
	}
	m.mu.Unlock()
	var wg sync.WaitGroup
	for _, k := range keys {
		wg.Add(1)
		go func() { defer wg.Done(); m.Kill(k) }()
	}
	wg.Wait()
	m.starts.clearAll()
}
