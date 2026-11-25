// Package android drives the per-account Android emulator through adb: SDK and
// AVD provisioning, emulator lifecycle, screen capture, UI automation and the
// /api/android routes.
package android

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neolabs-go/adbx"
)

const (
	adbPortBase  = 5554
	adbPortSlots = 64

	maxTextChars    = 8000
	maxIntentExtras = 100
	maxPackageBytes = 1 << 30
)

// BufferArtifact is a screenshot handed to the artifact store.
type BufferArtifact struct {
	Kind, Backend, Extension, ContentType, FilenameBase string
	Content                                             []byte
}

// ArtifactStore keeps screenshots and returns the URL clients fetch them from.
// The lead wires the artifacts service.
type ArtifactStore interface {
	CreateBufferArtifact(ctx context.Context, userID string, in BufferArtifact) (url string, err error)
}

// URLChecker decides whether a URL an intent may open is acceptable, with the
// reason shown to the user when it is not. The lead wires cloudsec.Checker.
type URLChecker func(ctx context.Context, rawURL string) (allowed bool, reason string, err error)

// HostConfig configures a Host.
type HostConfig struct {
	// DataDir and RuntimeHome are the Node DATA_DIR and RUNTIME_HOME.
	DataDir     string
	RuntimeHome string
	// SDKDir and AVDHome override the discovered SDK and the AVD directory
	// (default <RuntimeHome>/android/avd).
	SDKDir  string
	AVDHome string
	// LogoPath is the PNG used as wallpaper; empty skips the wallpaper.
	LogoPath  string
	Artifacts ArtifactStore
	URLCheck  URLChecker
	Log       *slog.Logger
}

// Host owns what every account's controller shares: the state directory, the
// ADB ports in use and in-flight SDK provisioning.
type Host struct {
	cfg    HostConfig
	states *stateStore

	mu           sync.Mutex
	reserved     map[int]bool
	provisioning map[string]*provision
	controllers  map[string]*Controller
}

// NewHost prepares the state directory.
func NewHost(cfg HostConfig) (*Host, error) {
	if cfg.AVDHome == "" {
		cfg.AVDHome = filepath.Join(cfg.RuntimeHome, "android", "avd")
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	dir := filepath.Join(cfg.DataDir, "android", "state")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	return &Host{
		cfg: cfg, states: &stateStore{dir: dir},
		reserved: map[int]bool{}, provisioning: map[string]*provision{}, controllers: map[string]*Controller{},
	}, nil
}

var userIDPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,64}$`)

func normalizeUserID(value string) (string, error) {
	id := strings.TrimSpace(value)
	if id == "" {
		id = "default"
	}
	if !userIDPattern.MatchString(id) {
		return "", errors.New("Android user ID contains unsupported characters.")
	}
	return id, nil
}

// hashCode is Java's String.hashCode over UTF-16 code units, which the Node
// server used to spread accounts over ADB ports.
func hashCode(s string) int32 {
	var h int32
	for _, u := range utf16.Encode([]rune(s)) {
		h = 31*h + int32(u)
	}
	return h
}

// Controller returns the (cached) controller of an account.
func (h *Host) Controller(userID string) (*Controller, error) {
	id, err := normalizeUserID(userID)
	if err != nil {
		return nil, err
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if c, ok := h.controllers[id]; ok {
		return c, nil
	}
	c := &Controller{host: h, userID: id, avdName: "neoagent_" + id, avdHome: h.cfg.AVDHome}
	c.adbPort = adbPortBase + int(uint32(hashCode(id))%adbPortSlots)*2
	c.adbSerial = fmt.Sprintf("emulator-%d", c.adbPort)
	c.sdkDir = h.cfg.SDKDir
	if c.sdkDir == "" {
		c.sdkDir = findExistingSdk(h.cfg.RuntimeHome)
	}
	if c.sdkDir == "" {
		c.sdkDir = filepath.Join(h.cfg.RuntimeHome, "android-sdk")
	}
	h.controllers[id] = c
	return c, nil
}

// CloseAll stops every emulator this process started.
func (h *Host) CloseAll() {
	h.mu.Lock()
	controllers := make([]*Controller, 0, len(h.controllers))
	for _, c := range h.controllers {
		controllers = append(controllers, c)
	}
	h.mu.Unlock()
	for _, c := range controllers {
		_ = c.Close()
	}
}

// Controller is one account's emulator.
type Controller struct {
	host      *Host
	userID    string
	avdName   string
	avdHome   string
	adbPort   int
	adbSerial string
	sdkDir    string

	mu          sync.Mutex
	startDone   chan struct{}
	startCancel context.CancelCauseFunc
	emulator    *emulatorProc
}

func (c *Controller) state() State { return c.host.states.read(c.userID) }

func (c *Controller) writeState(change func(*State)) {
	if err := c.host.states.update(c.userID, change); err != nil {
		c.host.cfg.Log.Warn("android: could not store emulator state", "user", c.userID, "error", err)
	}
}

func (c *Controller) adbBin() string { return adbx.BinPath(c.sdkDir) }

// liveAdbSerial is the serial this account actually started, only while that
// process is alive. The constructor serial is just a port guess.
func (c *Controller) LiveAdbSerial() string {
	st := c.state()
	if st.AdbSerial == nil || st.PID == nil || !adbx.PidAlive(*st.PID) {
		return ""
	}
	return *st.AdbSerial
}

func (c *Controller) requireSerial() (string, error) {
	serial := c.LiveAdbSerial()
	if serial == "" {
		return "", errors.New("No emulator running")
	}
	return serial, nil
}

func (c *Controller) adb(serial string) adbx.Client {
	return adbx.Client{Bin: c.adbBin(), Serial: serial}
}

// Device is an entry of the devices list.
type Device struct {
	Serial   string `json:"serial"`
	Status   string `json:"status"`
	Emulator bool   `json:"emulator"`
}

// Status is the GET /api/android/status body.
type Status struct {
	Bootstrapped   bool     `json:"bootstrapped"`
	Starting       bool     `json:"starting"`
	StartupPhase   *string  `json:"startupPhase"`
	LastStartError *string  `json:"lastStartError"`
	AdbSerial      *string  `json:"adbSerial"`
	Devices        []Device `json:"devices"`
}

// GetStatus reports the stored state, confirmed against the running emulator.
func (c *Controller) GetStatus(ctx context.Context) (Status, error) {
	st := c.state()
	base := Status{
		Bootstrapped: st.Bootstrapped, Starting: st.Starting, StartupPhase: st.StartupPhase,
		LastStartError: st.LastStartError, AdbSerial: st.AdbSerial, Devices: []Device{},
	}
	if st.AdbSerial == nil || *st.AdbSerial == "" {
		return base, nil
	}
	if st.PID == nil || !adbx.PidAlive(*st.PID) {
		base.Bootstrapped = false
		return base, nil
	}
	res, err := c.adb(*st.AdbSerial).Run(ctx, adbx.RunOptions{Timeout: 5 * time.Second, MaxOutputBytes: 64 << 10},
		"shell", "getprop", "sys.boot_completed")
	out := string(res.Stdout)
	if err != nil {
		if ctx.Err() != nil {
			return Status{}, ctx.Err()
		}
		return base, nil
	}
	booted := strings.TrimSpace(out) == "1"
	base.Bootstrapped = booted
	if booted {
		base.Devices = []Device{{Serial: *st.AdbSerial, Status: "device", Emulator: true}}
	}
	return base, nil
}

// ListDevices lists the emulator when it finished booting.
func (c *Controller) ListDevices(ctx context.Context) ([]Device, error) {
	s, err := c.GetStatus(ctx)
	if err != nil {
		return nil, err
	}
	if !s.Bootstrapped {
		return []Device{}, nil
	}
	return []Device{{Serial: c.adbSerial, Status: "device", Emulator: true}}, nil
}

var _ Service = (*Controller)(nil)
