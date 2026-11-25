package runtime

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"hash"
	"io"
	"net/http"
	"os"
	"path/filepath"
	goruntime "runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/proc"
	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

const (
	pinnedDebianBuild = "20260810-2566"
	// The genericcloud images ship Debian's "cloud" kernel without DRM drivers,
	// so the guest could never program a scanout; the generic images carry them.
	guestImageVariant = "generic"
	// GuestImageRevision is bumped whenever the guest image changes, so
	// existing system disks are rebuilt from it.
	GuestImageRevision  = pinnedDebianBuild + "-" + guestImageVariant
	maxBootAssetBytes   = 128 << 20
	startupTargetMs     = 10_000
	defaultQemuBootTime = 20 * time.Minute
)

type pinnedImage struct{ Filename, URL, SHA512 string }

// PinnedImages are the digest-verified Debian images computers boot from.
var PinnedImages = map[string]pinnedImage{
	"x64": {
		Filename: "debian-13-" + GuestImageRevision + "-amd64.qcow2",
		URL:      "https://cloud.debian.org/images/cloud/trixie/" + pinnedDebianBuild + "/debian-13-" + guestImageVariant + "-amd64-" + pinnedDebianBuild + ".qcow2",
		SHA512:   "f6978100d8031c266d55d7815ceea7fcdeacf28e1e5834fdb9c94ac96880a054a6e6f8681c2d3b0584e0057eaf3ef7353856b85212d04134744faa9b3bb1f24f",
	},
	"arm64": {
		Filename: "debian-13-" + GuestImageRevision + "-arm64.qcow2",
		URL:      "https://cloud.debian.org/images/cloud/trixie/" + pinnedDebianBuild + "/debian-13-" + guestImageVariant + "-arm64-" + pinnedDebianBuild + ".qcow2",
		SHA512:   "60a2cc628f0dd114c25d70ce8388631c3f165f25c8932bc9f147987467680bcc39bda38c471c31d35056ae3eb089d22ab295583a7cbff323f21caabb467b0656",
	},
}

// QemuOptions configure a QemuManager; zero values are discovered.
type QemuOptions struct {
	Dirs         Dirs
	Env          Env
	Architecture string
	// QemuBinary and QemuImgBinary override discovery; "-" means "none".
	QemuBinary, QemuImgBinary string
	Accelerators              []string
	Profile                   *ResourceProfile
	BootTimeout               time.Duration
	GuestAgentPort            int
	// ServerPort is the port of this server, reachable from the guest.
	ServerPort int
	// Download fetches the pinned guest image; nil uses HTTPS.
	Download func(ctx context.Context, url, destination string) error
}

// QemuManager runs each user's computer as a QEMU micro-VM.
type QemuManager struct {
	o              QemuOptions
	arch           string
	qemuBinary     string
	qemuImg        string
	qemuData       string
	accelerators   []string
	profile        ResourceProfile
	bootTimeout    time.Duration
	guestAgentPort int
	baseImagePath  string

	mu        sync.Mutex
	instances map[string]*Session
	starting  map[string]bool
	starts    *startTracker
	imageMu   sync.Mutex
	onStopped func(string)
}

// NewQemuManager discovers QEMU and prepares the computer directories.
func NewQemuManager(o QemuOptions) *QemuManager {
	m := &QemuManager{o: o, instances: map[string]*Session{}, starting: map[string]bool{}, starts: newStartTracker()}
	m.arch = normalizeArchitecture(o.Architecture)
	if o.Architecture == "" {
		m.arch = hostArchitecture()
	}
	m.qemuBinary = discovered(o.QemuBinary, func() string { return m.resolveExecutable(vm.SystemBinaryName(m.arch), "NEOAGENT_QEMU_SYSTEM_BINARY") })
	m.qemuImg = discovered(o.QemuImgBinary, func() string { return m.resolveExecutable("qemu-img", "NEOAGENT_QEMU_IMG_BINARY") })
	m.qemuData = m.resolveDataDirectory()
	if m.qemuBinary != "" && goruntime.GOOS == "darwin" && m.ownedBinary(m.qemuBinary) {
		vm.EnsureHypervisorSignature(context.Background(), m.qemuBinary)
	}
	m.accelerators = o.Accelerators
	if m.accelerators == nil && m.qemuBinary != "" {
		m.accelerators = vm.SelectAccelerators(context.Background(), m.qemuBinary, goruntime.GOOS, func(a string) bool {
			switch a {
			case "kvm":
				return vm.KVMUsable()
			case "hvf":
				return vm.HasHypervisorEntitlement(context.Background(), m.qemuBinary)
			}
			return true
		})
	}
	if o.Profile != nil {
		m.profile = *o.Profile
	} else {
		opts := storedResourceOptions(o.Dirs.RuntimeHome, o.Env)
		opts.Accelerator = m.accelerator()
		m.profile = ComputerResourceProfile(opts)
	}
	m.bootTimeout = o.BootTimeout
	if m.bootTimeout <= 0 {
		if ms, err := strconv.Atoi(trimmed(o.Env.get("NEOAGENT_VM_BOOT_TIMEOUT_MS"))); err == nil && ms > 0 {
			m.bootTimeout = time.Duration(ms) * time.Millisecond
		} else {
			m.bootTimeout = defaultQemuBootTime
		}
	}
	m.guestAgentPort = o.GuestAgentPort
	if m.guestAgentPort <= 0 {
		m.guestAgentPort = 8421
	}
	m.baseImagePath = trimmed(o.Env.get("NEOAGENT_VM_BASE_IMAGE"))
	for _, dir := range []string{o.Dirs.computerRoot(), o.Dirs.imageRoot(), o.Dirs.instanceRoot()} {
		_ = ensurePrivateDir(dir)
	}
	return m
}

func discovered(explicit string, discover func() string) string {
	switch explicit {
	case "-":
		return ""
	case "":
		return discover()
	}
	return explicit
}

func (m *QemuManager) bundledCandidates(name string) []string {
	file := vm.ExecutableName(name)
	return []string{
		filepath.Join(m.o.Dirs.AppDir, "computer-runtime", "qemu", "bin", file),
		filepath.Join(m.o.Dirs.RuntimeHome, "computer-runtime", "qemu", "bin", file),
		filepath.Join(m.o.Dirs.RuntimeHome, "runtime", "qemu", "bin", file),
	}
}

func wellKnownCandidates(name string) []string {
	file := vm.ExecutableName(name)
	if goruntime.GOOS == "windows" {
		root := os.Getenv("ProgramFiles")
		if root == "" {
			root = `C:\Program Files`
		}
		return []string{filepath.Join(root, "qemu", file)}
	}
	return []string{filepath.Join("/opt/homebrew/bin", file), filepath.Join("/usr/local/bin", file), filepath.Join("/usr/bin", file)}
}

func (m *QemuManager) searchedCandidates(name string) []string {
	out := append([]string{}, m.bundledCandidates(name)...)
	out = append(out, packagedQemuExecutableCandidates(m.o.Dirs.RuntimeHome, name)...)
	return append(out, wellKnownCandidates(name)...)
}

func (m *QemuManager) resolveExecutable(name, envName string) string {
	candidates := append([]string{trimmed(m.o.Env.get(envName))}, m.searchedCandidates(name)...)
	return vm.ResolveExecutable(name, candidates)
}

func (m *QemuManager) resolveDataDirectory() string {
	var candidates []string
	candidates = append(candidates, trimmed(m.o.Env.get("NEOAGENT_QEMU_DATA_DIR")))
	if m.qemuBinary != "" && strings.ContainsRune(m.qemuBinary, filepath.Separator) {
		candidates = append(candidates, filepath.Join(filepath.Dir(m.qemuBinary), "..", "share", "qemu"))
	}
	candidates = append(candidates,
		filepath.Join(m.o.Dirs.AppDir, "computer-runtime", "qemu", "share", "qemu"),
		filepath.Join(m.o.Dirs.RuntimeHome, "computer-runtime", "qemu", "share", "qemu"))
	if packaged := PackagedQemuRuntimeDirectory(m.o.Dirs.RuntimeHome); packaged != "" {
		candidates = append(candidates, filepath.Join(packaged, "share", "qemu"))
	}
	if found := vm.FirstExisting(candidates); found != "" {
		return filepath.Clean(found)
	}
	return ""
}

func (m *QemuManager) firmware(envName, appFile string, system ...string) string {
	candidates := []string{trimmed(m.o.Env.get(envName))}
	for _, root := range []string{m.o.Dirs.AppDir, m.o.Dirs.RuntimeHome} {
		candidates = append(candidates, filepath.Join(root, "computer-runtime", "qemu", "share", "qemu", appFile))
	}
	if packaged := PackagedQemuRuntimeDirectory(m.o.Dirs.RuntimeHome); packaged != "" {
		candidates = append(candidates, filepath.Join(packaged, "share", "qemu", appFile))
	}
	candidates = append(candidates, "/opt/homebrew/share/qemu/"+appFile, "/usr/local/share/qemu/"+appFile)
	return vm.FirstExisting(append(candidates, system...))
}

func (m *QemuManager) ownedBinary(binary string) bool {
	resolved, err := filepath.EvalSymlinks(binary)
	if err != nil {
		return false
	}
	for _, root := range []string{m.o.Dirs.AppDir, m.o.Dirs.RuntimeHome} {
		if root == "" {
			continue
		}
		prefix, _ := filepath.Abs(root)
		if resolved == prefix || strings.HasPrefix(resolved, prefix+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

func (m *QemuManager) accelerator() string {
	if len(m.accelerators) > 0 {
		return m.accelerators[0]
	}
	return ""
}

// storedResourceOptions reads the limits `neoagent setup` stored in
// computer-runtime/profile.json; an environment variable wins over them.
func storedResourceOptions(runtimeHome string, env Env) ProfileOptions {
	opts := ProfileOptions{Getenv: env.get}
	raw, err := os.ReadFile(filepath.Join(runtimeHome, "computer-runtime", "profile.json"))
	if err != nil {
		return opts
	}
	var stored map[string]any
	if json.Unmarshal(raw, &stored) != nil {
		return opts
	}
	pick := func(key, envName string) *float64 {
		if env.get(envName) != "" {
			return nil
		}
		switch v := stored[key].(type) {
		case float64:
			return &v
		case string:
			if f, err := strconv.ParseFloat(strings.TrimSpace(v), 64); err == nil {
				return &f
			}
		}
		return nil
	}
	opts.ReservePercent = pick("reservePercent", "NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_PERCENT")
	opts.MinimumReserveMb = pick("minimumReserveMb", "NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_MB")
	opts.MinimumGuestMemoryMb = pick("minimumGuestMemoryMb", "NEOAGENT_COMPUTER_MIN_MEMORY_MB")
	opts.MaximumGuestMemoryMb = pick("maximumGuestMemoryMb", "NEOAGENT_COMPUTER_MAX_MEMORY_MB")
	opts.MaximumGuestCPUs = pick("maximumGuestCpus", "NEOAGENT_COMPUTER_MAX_CPUS")
	opts.MinimumDiskGiB = pick("minimumDiskGiB", "NEOAGENT_COMPUTER_MIN_DISK_GIB")
	opts.MaximumDiskGiB = pick("maximumDiskGiB", "NEOAGENT_COMPUTER_MAX_DISK_GIB")
	opts.StorageReservePercent = pick("storageReservePercent", "NEOAGENT_COMPUTER_STORAGE_RESERVE_PERCENT")
	return opts
}

func (m *QemuManager) imagePath() string {
	if m.baseImagePath != "" {
		return m.baseImagePath
	}
	return filepath.Join(m.o.Dirs.imageRoot(), PinnedImages[m.arch].Filename)
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// Readiness implements VMManager.
func (m *QemuManager) Readiness() *omap {
	qemuOK := vm.IsRunnableCommand(m.qemuBinary)
	imgOK := vm.IsRunnableCommand(m.qemuImg)
	agentOK := resolveGuestAgent(m.o.Env, m.o.Dirs, m.arch) != ""
	missing := []string{}
	if !qemuOK {
		missing = append(missing, vm.SystemBinaryName(m.arch))
	}
	if !imgOK {
		missing = append(missing, "qemu-img")
	}
	if !agentOK {
		missing = append(missing, GuestAgentFileName(m.arch))
	}
	image := m.imagePath()
	_, imageErr := os.Stat(image)
	return obj(
		"ready", qemuOK && imgOK && agentOK,
		"qemuAvailable", qemuOK && imgOK,
		"qemuBinary", nullable(m.qemuBinary),
		"qemuImgBinary", nullable(m.qemuImg),
		"qemuDataDirectory", nullable(m.qemuData),
		"architecture", m.arch,
		"accelerator", nullable(m.accelerator()),
		"compatibilityMode", m.accelerator() == "tcg",
		"imageReady", imageErr == nil,
		"image", image,
		"missing", missing,
		"resources", m.profile,
	)
}

func (m *QemuManager) unavailableError() error {
	r := m.Readiness()
	var missing []string
	r.Decode("missing", &missing)
	searched := m.searchedCandidates(vm.SystemBinaryName(m.arch))
	return &CodedError{
		Message: fmt.Sprintf("QEMU computer runtime is unavailable (missing %s). Searched: %s. Run neoagent repair.", strings.Join(missing, " and "), strings.Join(searched, ", ")),
		Code:    "COMPUTER_RUNTIME_UNAVAILABLE",
		Status:  503,
	}
}

// Capabilities implements VMManager.
func (m *QemuManager) Capabilities() []string {
	return capabilityList("desktop", "browser", "shell", "files", "teach")
}

// BootTimeout implements VMManager.
func (m *QemuManager) BootTimeout() time.Duration { return m.bootTimeout }

// GuestHostAddress implements VMManager: QEMU user networking forwards it to
// the host's loopback.
func (m *QemuManager) GuestHostAddress() string { return "10.0.2.2" }

// OnStopped implements VMManager.
func (m *QemuManager) OnStopped(fn func(string)) { m.mu.Lock(); m.onStopped = fn; m.mu.Unlock() }

// Instance implements VMManager.
func (m *QemuManager) Instance(key string) *Session {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.instances[key]
}

// Alive implements VMManager.
func (m *QemuManager) Alive(key string) bool { return m.Instance(key).Alive() }

// Tracked implements VMManager.
func (m *QemuManager) Tracked(key string) bool { return m.Instance(key) != nil }

// Status implements VMManager.
func (m *QemuManager) Status(key string) *omap {
	return sessionStatus(m.Instance(key), m.starts.status(key), m.Capabilities(), m.Readiness(), func(s *Session) *omap {
		return obj("accelerator", nullable(s.Accelerator), "compatibilityMode", s.Accelerator == "tcg")
	}, func(s *Session) string {
		if s.DirectBoot {
			return "direct"
		}
		return "provisioning"
	})
}

// sessionStatus is the status shape both managers report.
func sessionStatus(s *Session, transient *omap, capabilities []string, readiness *omap, extra func(*Session) *omap, mode func(*Session) string) *omap {
	if s == nil {
		out := obj("state", StateStopped)
		if transient != nil {
			out = transient
		}
		return out.Set("capabilities", capabilities).Set("readiness", readiness)
	}
	state := s.State()
	if !s.Alive() {
		state = StateError
	}
	out := obj("state", state, "capabilities", capabilities)
	if extra != nil {
		out.Merge(extra(s))
	}
	measured := s.StartupDurationMs()
	var met any
	var measuredAny any
	if measured != nil {
		measuredAny = *measured
		met = *measured < startupTargetMs
	}
	var desktop any
	if d := s.Desktop(); d != nil {
		desktop = d
	}
	last := nullable(s.LastError())
	return out.Set("resources", s.Resources).
		Set("startedAt", isoTime(s.StartedAt)).
		Set("startup", obj("targetMs", startupTargetMs, "measuredMs", measuredAny, "met", met, "mode", mode(s))).
		Set("lastError", last).
		Set("error", last).
		Set("desktop", desktop).
		Set("readiness", readiness)
}

// PrepareRuntime makes sure QEMU is present and the base image downloaded.
func (m *QemuManager) PrepareRuntime(ctx context.Context, downloadImage bool) (*omap, error) {
	if !m.Readiness().Bool("ready") {
		return nil, m.unavailableError()
	}
	image := m.imagePath()
	if downloadImage {
		var err error
		if image, err = m.ensureBaseImage(ctx); err != nil {
			return nil, err
		}
	}
	_, statErr := os.Stat(image)
	return m.Readiness().Set("image", image).Set("imageReady", statErr == nil), nil
}

func hashFile(path string, h hash.Hash) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (m *QemuManager) ensureBaseImage(ctx context.Context) (string, error) {
	m.imageMu.Lock()
	defer m.imageMu.Unlock()
	if m.baseImagePath != "" {
		if _, err := os.Stat(m.baseImagePath); err != nil {
			return "", errors.New("Configured cloud computer base image does not exist.")
		}
		return m.baseImagePath, nil
	}
	pinned := PinnedImages[m.arch]
	destination := filepath.Join(m.o.Dirs.imageRoot(), pinned.Filename)
	if _, err := os.Stat(destination); err == nil {
		if digest, _ := hashFile(destination, sha512.New()); digest == pinned.SHA512 {
			return destination, nil
		}
		_ = os.Remove(destination)
	}
	temporary := fmt.Sprintf("%s.%d.%s.download", destination, os.Getpid(), randomHex(6))
	defer os.Remove(temporary)
	m.o.Env.logger().Info("Downloading digest-verified Debian guest image", "architecture", m.arch)
	download := m.o.Download
	if download == nil {
		download = downloadFile
	}
	if err := download(ctx, pinned.URL, temporary); err != nil {
		return "", err
	}
	if digest, _ := hashFile(temporary, sha512.New()); digest != pinned.SHA512 {
		return "", &CodedError{Message: "Downloaded cloud computer image failed SHA-512 verification.", Code: "COMPUTER_IMAGE_HASH_MISMATCH"}
	}
	if err := os.Rename(temporary, destination); err != nil {
		return "", err
	}
	ensurePrivateFile(destination)
	return destination, nil
}

// downloadFile fetches a pinned, digest-checked image from a fixed HTTPS URL.
func downloadFile(ctx context.Context, url, destination string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "NeoAgent-Computer-Runtime/1")
	client := &http.Client{CheckRedirect: func(_ *http.Request, via []*http.Request) error {
		if len(via) > 5 {
			return errors.New("Too many redirects while downloading the guest image.")
		}
		return nil
	}}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Guest image download returned HTTP %d.", resp.StatusCode)
	}
	out, err := os.OpenFile(destination, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, resp.Body); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func (m *QemuManager) activeAllocations() []Allocation {
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

// Ensure implements VMManager.
func (m *QemuManager) Ensure(ctx context.Context, key string) (*Session, error) {
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
	return m.starts.begin(ctx, key, func() (*Session, error) {
		dir := filepath.Join(m.o.Dirs.instanceRoot(), UserDirectoryKey(key))
		m.mu.Lock()
		m.starting[dir] = true
		m.mu.Unlock()
		defer func() { m.mu.Lock(); delete(m.starting, dir); m.mu.Unlock() }()
		// The start outlives the request that asked for it.
		return m.start(context.Background(), key)
	})
}

func fileExists(path string) bool { _, err := os.Stat(path); return err == nil }

func readTrimmed(path string) string {
	raw, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(raw))
}

func writePrivate(path, content string) error {
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		return err
	}
	ensurePrivateFile(path)
	return nil
}

func (m *QemuManager) start(ctx context.Context, key string) (*Session, error) {
	log := m.o.Env.logger()
	if !m.Readiness().Bool("ready") {
		err := m.unavailableError()
		log.Error(err.Error())
		return nil, err
	}
	agent, err := readGuestAgent(m.o.Env, m.o.Dirs, m.arch)
	if err != nil {
		return nil, err
	}
	resources, err := AllocateComputerResources(m.profile, m.activeAllocations())
	if err != nil {
		return nil, err
	}
	baseImage, err := m.ensureBaseImage(ctx)
	if err != nil {
		return nil, err
	}
	img := vm.Img{Binary: m.qemuImg}
	instanceDir := filepath.Join(m.o.Dirs.instanceRoot(), UserDirectoryKey(key))
	if err := ensurePrivateDir(instanceDir); err != nil {
		return nil, err
	}
	if orphans := vm.FindOrphanedPIDs(ctx, instanceDir); len(orphans) > 0 {
		log.Warn("Reclaiming computer from orphaned QEMU processes", "user", key, "pids", orphans)
		for _, pid := range orphans {
			if !vm.TerminatePID(pid) {
				return nil, &CodedError{Message: "A previous computer process is still holding this computer. Restart NeoAgent to release it.", Code: "COMPUTER_DISK_LOCKED", Status: 409}
			}
		}
	}
	systemDisk := filepath.Join(instanceDir, "system.qcow2")
	dataDisk := filepath.Join(instanceDir, "data.qcow2")
	buildMarker := filepath.Join(instanceDir, "base-build")
	previousBuild := GuestImageRevision
	if fileExists(buildMarker) {
		previousBuild = readTrimmed(buildMarker)
	}
	replaceSystem := fileExists(systemDisk) && previousBuild != GuestImageRevision
	createsSystem := !fileExists(systemDisk) || replaceSystem
	available, _ := vm.DiskCapacity(m.o.Dirs.instanceRoot())
	m.mu.Lock()
	admitted := map[string]bool{}
	for dir := range m.starting {
		admitted[dir] = true
	}
	for _, s := range m.instances {
		if s.Alive() {
			admitted[s.InstanceDir] = true
		}
	}
	m.mu.Unlock()
	dirs := make([]string, 0, len(admitted))
	for dir := range admitted {
		dirs = append(dirs, dir)
	}
	liability := img.SparseLiability(ctx, dirs, func(p string) bool {
		return filepath.Base(p) == "system.previous.qcow2" || (replaceSystem && p == systemDisk)
	})
	if createsSystem {
		liability += 8 * gib
	}
	storage := Storage{AvailableBytes: available, SparseLiabilityBytes: liability}
	if available <= 0 || StorageHeadroomBytes(m.profile, storage) < 0 {
		toGiB := func(b int64) string { return strconv.FormatFloat(float64(b)/gib, 'f', 1, 64) }
		return nil, &CodedError{
			Message: fmt.Sprintf("Starting this cloud computer needs more free storage: %s GiB free, %d%% held back for the host, and %s GiB reserved for disk growth in running and starting computers.", toGiB(available), m.profile.StorageReservePercent, toGiB(liability)),
			Code:    CodeStorageCapacity, Status: 507,
		}
	}
	if replaceSystem {
		previous := filepath.Join(instanceDir, "system.previous.qcow2")
		_ = os.Remove(previous)
		if err := os.Rename(systemDisk, previous); err != nil {
			return nil, err
		}
		discardDirectBootCache(instanceDir)
	}
	if !fileExists(systemDisk) {
		if err := img.CreateOverlay(ctx, systemDisk, baseImage, "qcow2"); err != nil {
			return nil, err
		}
	}
	if err := img.EnsureSize(ctx, systemDisk, 8); err != nil {
		return nil, err
	}
	if err := writePrivate(buildMarker, GuestImageRevision+"\n"); err != nil {
		return nil, err
	}
	if !fileExists(dataDisk) {
		size, err := ChooseDataDiskGiB(m.profile, storage)
		if err != nil {
			return nil, err
		}
		if err := img.Create(ctx, dataDisk, fmt.Sprintf("%dG", size)); err != nil {
			return nil, err
		}
	}
	hostAgentPort, err := vm.FreePort()
	if err != nil {
		return nil, err
	}
	windows := goruntime.GOOS == "windows"
	vnc, err := vm.InstanceSocket(instanceDir, "vnc.sock", vm.FreeVNCPort, "/tmp", windows)
	if err != nil {
		return nil, err
	}
	qmp, err := vm.InstanceSocket(instanceDir, "qmp.sock", vm.FreePort, "/tmp", windows)
	if err != nil {
		return nil, err
	}
	tokenPath := filepath.Join(instanceDir, "guest-token")
	token := readTrimmed(tokenPath)
	if token == "" {
		token = randomHex(32)
		if err := writePrivate(tokenPath, token+"\n"); err != nil {
			return nil, err
		}
	}
	seed, err := EnsureGuestBootstrapSeed(m.o.Dirs.vmRoot(), instanceDir, GuestBootstrap{
		GuestToken: token, GuestAgentPort: m.guestAgentPort, Agent: agent, ServerPort: m.o.ServerPort,
	}, m.arch)
	if err != nil {
		return nil, err
	}
	var kernel, initrd string
	if marker := m.readDirectBootMarker(instanceDir); marker != nil {
		k, i := filepath.Join(instanceDir, "vmlinuz"), filepath.Join(instanceDir, "initrd.img")
		kd, _ := hashFile(k, sha256.New())
		id, _ := hashFile(i, sha256.New())
		if kd != "" && kd == marker.KernelSHA256 && id != "" && id == marker.InitrdSHA256 {
			kernel, initrd = k, i
		} else {
			discardDirectBootCache(instanceDir)
			log.Warn("Discarded invalid direct-boot cache", "user", key)
		}
	}
	var armCode, armVars string
	if m.arch == "arm64" {
		armCode = m.firmware("NEOAGENT_QEMU_EFI_FIRMWARE", "edk2-aarch64-code.fd", "/usr/share/AAVMF/AAVMF_CODE.fd", "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd")
		template := m.firmware("NEOAGENT_QEMU_EFI_VARIABLES", "edk2-arm-vars.fd", "/usr/share/AAVMF/AAVMF_VARS.fd", "/usr/share/qemu-efi-aarch64/QEMU_VARS.fd")
		if template == "" {
			return nil, &CodedError{Message: "ARM64 QEMU variable firmware is unavailable. Run neoagent repair to restore the computer runtime.", Code: "COMPUTER_FIRMWARE_MISSING"}
		}
		armVars = filepath.Join(instanceDir, "uefi-vars.qcow2")
		varsMarker := filepath.Join(instanceDir, "uefi-vars-base.sha512")
		digest, err := hashFile(template, sha512.New())
		if err != nil {
			return nil, err
		}
		if !fileExists(armVars) || readTrimmed(varsMarker) != digest {
			_ = os.Remove(armVars)
			if err := img.CreateOverlay(ctx, armVars, template, "raw"); err != nil {
				return nil, err
			}
			if err := writePrivate(varsMarker, digest+"\n"); err != nil {
				return nil, err
			}
		}
	}
	args, err := BuildQEMUArgs(QEMUArgsConfig{
		Architecture: m.arch, Accelerators: m.accelerators, MemoryMB: int(resources.MemoryMb), CPUs: resources.CPUs,
		SystemDisk: systemDisk, DataDisk: dataDisk, SeedImage: seed.ImagePath,
		GuestAgentPort: m.guestAgentPort, HostAgentPort: hostAgentPort, VNC: vnc, QMP: qmp,
		QEMUDataDirectory: m.qemuData, ARMFirmwareCode: armCode, ARMFirmwareVariables: armVars,
		KernelImage: kernel, InitrdImage: initrd,
	})
	if err != nil {
		return nil, err
	}
	logPath := filepath.Join(instanceDir, "qemu.log")
	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return nil, err
	}
	process, err := proc.Start(proc.Spec{Path: m.qemuBinary, Args: args, Dir: instanceDir, Stdout: logFile, Stderr: logFile})
	logFile.Close()
	session := NewSession()
	session.InstanceDir = instanceDir
	session.BaseURL = fmt.Sprintf("http://127.0.0.1:%d", hostAgentPort)
	session.GuestToken = token
	session.Resources = resources
	session.Accelerator = m.accelerator()
	session.Display = vnc
	session.QMP = qmp
	session.StartedAt = time.Now()
	session.DirectBoot = kernel != "" && initrd != ""
	session.LogTail = func() string { return readLogTail(logPath, 32*1024) }
	if err != nil {
		message := composeFailure("QEMU failed to start: "+err.Error(), logPath)
		session.FailWith(message)
		log.Error("Computer failed to spawn", "user", key, "error", message)
		return nil, &CodedError{Message: message, Code: "COMPUTER_START_FAILED", Status: 503}
	}
	session.Process = process
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
			session.FailWith(composeFailure("QEMU exited ("+code+").", logPath))
			log.Error("Computer process ended", "user", key, "error", session.LastError())
		}
		m.mu.Lock()
		stopped := m.onStopped
		m.mu.Unlock()
		if stopped != nil {
			stopped(key)
		}
	}()
	if !vm.WaitForSocket(vnc, 10*time.Second, func() bool { return !process.Alive() }) {
		reason := session.LastError()
		if reason == "" {
			reason = "QEMU exited before the display was reachable."
			if process.Alive() {
				reason = "QEMU display did not become reachable."
			}
		}
		message := composeFailure(reason, logPath)
		session.FailWith(message)
		log.Error("Computer failed to start", "user", key, "error", message)
		m.Kill(key)
		return nil, &CodedError{Message: message, Code: "COMPUTER_START_FAILED", Status: 503}
	}
	session.SetLastError("")
	log.Info("Started computer", "user", key, "memoryMb", resources.MemoryMb, "cpus", resources.CPUs)
	return session, nil
}

func readLogTail(path string, limit int) string {
	raw, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	text := strings.TrimSpace(string(raw))
	if len(text) > limit {
		text = text[len(text)-limit:]
	}
	return text
}

func composeFailure(reason, logPath string) string {
	if tail := readLogTail(logPath, 32*1024); tail != "" {
		return reason + "\n" + tail
	}
	return reason
}

type directBootMarker struct {
	Version      int    `json:"version"`
	Architecture string `json:"architecture"`
	BootProfile  string `json:"bootProfile"`
	Release      string `json:"release"`
	KernelSHA256 string `json:"kernelSha256"`
	InitrdSHA256 string `json:"initrdSha256"`
	CachedAt     string `json:"cachedAt"`
}

// bootProfileDigest ties a cached kernel to the image, display device and
// kernel command line it was cached for.
func bootProfileDigest(architecture string) string {
	sum := sha256.Sum256([]byte(strings.Join([]string{GuestImageRevision, displayDeviceArgument(architecture), directBootCommandLine(architecture)}, "\n")))
	return hex.EncodeToString(sum[:])[:16]
}

func (m *QemuManager) readDirectBootMarker(instanceDir string) *directBootMarker {
	raw, err := os.ReadFile(filepath.Join(instanceDir, "direct-boot.json"))
	if err != nil {
		return nil
	}
	var marker directBootMarker
	if json.Unmarshal(raw, &marker) != nil || marker.Version != 1 || marker.Architecture != m.arch || marker.BootProfile != bootProfileDigest(m.arch) {
		return nil
	}
	return &marker
}

func discardDirectBootCache(instanceDir string) {
	for _, name := range []string{"direct-boot.json", "vmlinuz", "initrd.img"} {
		_ = os.Remove(filepath.Join(instanceDir, name))
	}
}

// CacheDirectBootAssets stores the guest's kernel and initramfs so the next
// start skips the firmware and bootloader.
func (m *QemuManager) CacheDirectBootAssets(ctx context.Context, key string, client *GuestClient) error {
	session := m.Instance(key)
	if session == nil || session.InstanceDir == "" || client == nil {
		return nil
	}
	dir := session.InstanceDir
	kernelPath, initrdPath := filepath.Join(dir, "vmlinuz"), filepath.Join(dir, "initrd.img")
	if m.readDirectBootMarker(dir) != nil && fileExists(kernelPath) && fileExists(initrdPath) {
		return nil
	}
	payload, err := client.Request(ctx, http.MethodGet, "/system/boot-assets", nil, RequestOptions{Timeout: 2 * time.Minute, MaxResponseBytes: maxBootAssetBytes * 2, Retries: Retries(0)})
	if err != nil {
		return err
	}
	decode := func(key, label string) ([]byte, string, error) {
		var asset struct {
			Content string  `json:"content"`
			Size    float64 `json:"size"`
			SHA256  string  `json:"sha256"`
		}
		payload.Decode(key, &asset)
		data, _ := base64.StdEncoding.DecodeString(asset.Content)
		if len(data) == 0 || len(data) > maxBootAssetBytes || float64(len(data)) != asset.Size {
			return nil, "", fmt.Errorf("%s boot asset has an invalid size.", label)
		}
		sum := sha256.Sum256(data)
		digest := hex.EncodeToString(sum[:])
		if digest != asset.SHA256 {
			return nil, "", fmt.Errorf("%s boot asset failed checksum verification.", label)
		}
		return data, digest, nil
	}
	kernel, kernelDigest, err := decode("kernel", "Kernel")
	if err != nil {
		return err
	}
	initrd, initrdDigest, err := decode("initrd", "Initramfs")
	if err != nil {
		return err
	}
	write := func(target string, data []byte) error {
		temporary := fmt.Sprintf("%s.%d.%s.tmp", target, os.Getpid(), randomHex(4))
		if err := os.WriteFile(temporary, data, 0o600); err != nil {
			return err
		}
		return os.Rename(temporary, target)
	}
	if err := write(kernelPath, kernel); err != nil {
		return err
	}
	if err := write(initrdPath, initrd); err != nil {
		return err
	}
	release := payload.String("release")
	marker, _ := json.MarshalIndent(directBootMarker{
		Version: 1, Architecture: m.arch, BootProfile: bootProfileDigest(m.arch), Release: release,
		KernelSHA256: kernelDigest, InitrdSHA256: initrdDigest, CachedAt: isoNow(),
	}, "", "  ")
	return writePrivate(filepath.Join(dir, "direct-boot.json"), string(marker)+"\n")
}

// Kill implements VMManager: an ACPI power-down first, then SIGTERM, SIGKILL.
func (m *QemuManager) Kill(key string) {
	m.starts.clear(key)
	m.mu.Lock()
	session := m.instances[key]
	delete(m.instances, key)
	m.mu.Unlock()
	if session == nil || !session.Alive() {
		return
	}
	session.SetState(StateStopping)
	vm.Powerdown(context.Background(), session.QMP)
	wait := func(d time.Duration) bool {
		select {
		case <-session.Process.Done():
			return true
		case <-time.After(d):
			return false
		}
	}
	if wait(10 * time.Second) {
		return
	}
	_ = session.Process.Signal(syscall.SIGTERM)
	if wait(3 * time.Second) {
		return
	}
	session.Process.Kill()
	wait(2 * time.Second)
}

// RemoveUserData implements VMManager. The computer must be stopped.
func (m *QemuManager) RemoveUserData(key string) {
	if key == "" {
		return
	}
	if err := os.RemoveAll(filepath.Join(m.o.Dirs.instanceRoot(), UserDirectoryKey(key))); err != nil {
		m.o.Env.logger().Warn("Failed to remove computer data", "user", key, "error", err)
	}
}

// Fail implements VMManager.
func (m *QemuManager) Fail(key string, err error) { m.Kill(key); m.starts.fail(key, err) }

// Sleep implements VMManager.
func (m *QemuManager) Sleep(key string) { m.Kill(key); m.starts.sleep(key) }

// Shutdown implements VMManager.
func (m *QemuManager) Shutdown() {
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
