package android

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/adbx"
)

// provision is one in-flight SDK installation shared by every account that
// asked for the same SDK directory. It is abandoned when its last waiter
// leaves before it finishes.
type provision struct {
	cancel  context.CancelCauseFunc
	ctx     context.Context
	done    chan struct{}
	err     error
	waiters int
	settled bool
}

func (h *Host) ensureSdkProvisioned(ctx context.Context, c *Controller, progress func(string)) error {
	key, err := absPath(c.sdkDir)
	if err != nil {
		return err
	}
	h.mu.Lock()
	entry := h.provisioning[key]
	for entry != nil && entry.ctx.Err() != nil && !entry.settled {
		h.mu.Unlock()
		<-entry.done
		h.mu.Lock()
		entry = h.provisioning[key]
	}
	if entry == nil {
		pctx, cancel := context.WithCancelCause(context.Background())
		entry = &provision{cancel: cancel, ctx: pctx, done: make(chan struct{})}
		h.provisioning[key] = entry
		go func() {
			err := c.provisionSdk(pctx, progress)
			h.mu.Lock()
			entry.err, entry.settled = err, true
			if h.provisioning[key] == entry {
				delete(h.provisioning, key)
			}
			h.mu.Unlock()
			close(entry.done)
		}()
	}
	entry.waiters++
	h.mu.Unlock()

	defer func() {
		h.mu.Lock()
		entry.waiters--
		abandon := entry.waiters == 0 && !entry.settled && entry.ctx.Err() == nil
		h.mu.Unlock()
		if abandon {
			entry.cancel(errors.New("Android SDK provisioning no longer has an active startup request."))
		}
	}()
	select {
	case <-entry.done:
		return entry.err
	case <-ctx.Done():
		return context.Cause(ctx)
	}
}

func absPath(p string) (string, error) {
	return strings.TrimRight(p, string(os.PathSeparator)), nil
}

// provisionSdk installs the command-line tools, then platform-tools, the
// emulator and a system image when any is missing.
func (c *Controller) provisionSdk(ctx context.Context, progress func(string)) error {
	if err := c.ensureSdk(ctx, progress); err != nil {
		return err
	}
	if !fileExists(c.adbBin()) || !fileExists(emulatorBin(c.sdkDir)) || pickSystemImage(c.sdkDir) == "" {
		return c.ensurePackages(ctx, progress)
	}
	return nil
}

// emulatorProc is the emulator process this controller started.
type emulatorProc struct {
	cmd  *exec.Cmd
	pid  int
	done chan struct{}
}

func (p *emulatorProc) exited() bool {
	select {
	case <-p.done:
		return true
	default:
		return false
	}
}

// StartOptions are the POST /start fields.
type StartOptions struct {
	// Headless runs the emulator without a window; nil means headless.
	Headless *bool
}

// RunningStart is the answer when the emulator already runs.
type RunningStart struct {
	Success      bool    `json:"success"`
	Pending      bool    `json:"pending"`
	Bootstrapped bool    `json:"bootstrapped"`
	AdbSerial    *string `json:"adbSerial"`
}

// PendingStart is the answer while the emulator is being set up.
type PendingStart struct {
	Success      bool    `json:"success"`
	Pending      bool    `json:"pending"`
	Bootstrapped bool    `json:"bootstrapped"`
	Starting     bool    `json:"starting"`
	StartupPhase *string `json:"startupPhase"`
}

// RequestStartEmulator starts provisioning and booting in the background and
// returns at once. A second call while one runs joins it.
func (c *Controller) RequestStartEmulator(ctx context.Context, opts StartOptions) (any, error) {
	log := c.host.cfg.Log
	log.Info("android: requestStartEmulator", "user", c.userID)
	st := c.state()
	if st.AdbSerial != nil && st.PID != nil && adbx.PidAlive(*st.PID) {
		status, err := c.GetStatus(ctx)
		if err != nil {
			return nil, err
		}
		return RunningStart{Success: true, Pending: !status.Bootstrapped, Bootstrapped: status.Bootstrapped, AdbSerial: st.AdbSerial}, nil
	}
	c.mu.Lock()
	if c.startDone == nil {
		c.writeState(func(s *State) {
			s.Starting, s.StartupPhase, s.LastStartError = true, ptr("Initializing"), nil
		})
		sctx, cancel := context.WithCancelCause(context.Background())
		done := make(chan struct{})
		c.startDone, c.startCancel = done, cancel
		go func() {
			if err := c.setup(sctx, opts); err != nil {
				log.Warn("android: emulator setup failed", "user", c.userID, "error", err)
			}
			c.mu.Lock()
			c.startDone, c.startCancel = nil, nil
			c.mu.Unlock()
			cancel(nil)
			close(done)
		}()
	}
	c.mu.Unlock()
	return PendingStart{Success: true, Pending: true, Starting: true, StartupPhase: c.state().StartupPhase}, nil
}

// StartEmulator starts the emulator and waits until it has booted.
func (c *Controller) StartEmulator(ctx context.Context, opts StartOptions, timeout time.Duration) (any, error) {
	res, err := c.RequestStartEmulator(ctx, opts)
	if err != nil {
		return nil, err
	}
	if r, ok := res.(RunningStart); ok && r.Bootstrapped {
		return r, nil
	}
	if timeout <= 0 {
		timeout = 240 * time.Second
	}
	serial, err := c.WaitForDevice(ctx, timeout)
	if err != nil {
		return nil, err
	}
	return RunningStart{Success: true, Bootstrapped: true, AdbSerial: &serial}, nil
}

// WaitForDevice polls until the emulator finished booting.
func (c *Controller) WaitForDevice(ctx context.Context, timeout time.Duration) (string, error) {
	if timeout <= 0 {
		timeout = 10 * time.Minute
	}
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		s, err := c.GetStatus(ctx)
		if err != nil {
			return "", err
		}
		if s.Bootstrapped {
			return c.adbSerial, nil
		}
		if !s.Starting && s.LastStartError != nil {
			return "", errors.New(*s.LastStartError)
		}
		if err := sleep(ctx, 2*time.Second); err != nil {
			return "", err
		}
	}
	return "", errors.New("Android emulator did not become ready in time")
}

// EnsureBootstrapped starts the emulator if it is not up yet.
func (c *Controller) EnsureBootstrapped(ctx context.Context, opts StartOptions) (string, error) {
	s, err := c.GetStatus(ctx)
	if err != nil {
		return "", err
	}
	if !s.Bootstrapped {
		if _, err := c.StartEmulator(ctx, opts, 0); err != nil {
			return "", err
		}
	}
	return c.adbSerial, nil
}

func sleep(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
		return nil
	case <-ctx.Done():
		return context.Cause(ctx)
	}
}

// StopResult is the POST /stop body.
type StopResult struct {
	Success bool `json:"success"`
}

// StopEmulator ends a startup in progress and the running emulator.
func (c *Controller) StopEmulator(ctx context.Context) (StopResult, error) {
	c.mu.Lock()
	cancel, done := c.startCancel, c.startDone
	c.mu.Unlock()
	if cancel != nil {
		cancel(errors.New("Android emulator startup was stopped."))
	}
	if done != nil {
		<-done
	}
	st := c.state()
	var adbStopErr error
	if serial := c.LiveAdbSerial(); serial != "" {
		_, adbStopErr = c.adb(serial).Run(ctx, adbx.RunOptions{Timeout: 5 * time.Second, MaxOutputBytes: 64 << 10}, "emu", "kill")
	}
	c.terminateOwnedEmulator()
	if st.PID != nil {
		c.waitForPidExit(*st.PID, 5*time.Second)
		if adbx.PidAlive(*st.PID) {
			if ctx.Err() != nil {
				return StopResult{}, ctx.Err()
			}
			if adbStopErr != nil {
				return StopResult{}, adbStopErr
			}
			return StopResult{}, errors.New("Android emulator did not exit after the stop request.")
		}
	}
	c.host.release(portOfSerial(deref(st.AdbSerial)))
	c.host.release(c.adbPort)
	c.writeState(func(s *State) {
		s.Bootstrapped, s.Starting, s.PID, s.AdbSerial, s.StartupPhase, s.LastStartError = false, false, nil, nil, nil, nil
	})
	if ctx.Err() != nil {
		return StopResult{}, ctx.Err()
	}
	c.host.cfg.Log.Info("android: emulator stopped", "user", c.userID)
	return StopResult{Success: true}, nil
}

// Close stops the emulator, ignoring failures.
func (c *Controller) Close() error {
	_, err := c.StopEmulator(context.Background())
	return err
}

func portOfSerial(serial string) int {
	n, _ := strconv.Atoi(strings.TrimPrefix(serial, "emulator-"))
	return n
}

func (h *Host) release(port int) {
	h.mu.Lock()
	delete(h.reserved, port)
	h.mu.Unlock()
}

func (c *Controller) waitForPidExit(pid int, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for adbx.PidAlive(pid) && time.Now().Before(deadline) {
		time.Sleep(100 * time.Millisecond)
	}
	return !adbx.PidAlive(pid)
}

func (c *Controller) terminateOwnedEmulator() {
	c.mu.Lock()
	p := c.emulator
	c.mu.Unlock()
	if p == nil {
		return
	}
	if !p.exited() {
		terminatePID(p.pid)
		c.waitForPidExit(p.pid, 3*time.Second)
	}
	if adbx.PidAlive(p.pid) && !p.exited() {
		killPID(p.pid)
		c.waitForPidExit(p.pid, 2*time.Second)
	}
	c.mu.Lock()
	if c.emulator == p {
		c.emulator = nil
	}
	c.mu.Unlock()
}

// resolveAdbPort picks the first free console/ADB port pair, starting at this
// account's own slot.
func (c *Controller) resolveAdbPort() error {
	base := int(uint32(hashCode(c.userID)) % adbPortSlots)
	for i := 0; i < adbPortSlots; i++ {
		port := adbPortBase + ((base+i)%adbPortSlots)*2
		c.host.mu.Lock()
		taken := c.host.reserved[port]
		c.host.mu.Unlock()
		if taken || !portPairFree(port) {
			continue
		}
		c.host.mu.Lock()
		c.host.reserved[port] = true
		c.host.mu.Unlock()
		c.adbPort, c.adbSerial = port, fmt.Sprintf("emulator-%d", port)
		return nil
	}
	return fmt.Errorf("No free ADB port pair in range %d–%d", adbPortBase, adbPortBase+adbPortSlots*2-1)
}

func portPairFree(console int) bool {
	var listeners []net.Listener
	defer func() {
		for _, l := range listeners {
			l.Close()
		}
	}()
	for _, port := range []int{console, console + 1} {
		l, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", port))
		if err != nil {
			return false
		}
		listeners = append(listeners, l)
	}
	return true
}

// setup provisions the SDK and AVD and boots the emulator, recording progress
// and failure in the state file.
func (c *Controller) setup(ctx context.Context, opts StartOptions) (err error) {
	log := c.host.cfg.Log
	progress := func(msg string) {
		log.Info("android: " + msg)
		c.writeState(func(s *State) { s.StartupPhase = ptr(msg) })
	}
	defer func() {
		if err == nil {
			return
		}
		c.terminateOwnedEmulator()
		c.host.release(c.adbPort)
		c.writeState(func(s *State) {
			s.Bootstrapped, s.Starting, s.StartupPhase = false, false, ptr("Failed")
			s.LastStartError, s.PID, s.AdbSerial = ptr(err.Error()), nil, nil
		})
	}()
	if err = c.resolveAdbPort(); err != nil {
		return err
	}
	if existing := findExistingSdk(c.host.cfg.RuntimeHome); existing != "" {
		c.sdkDir = existing
		progress("Found existing Android SDK at " + existing)
	} else {
		progress("Preparing Android SDK…")
	}
	if err = c.host.ensureSdkProvisioned(ctx, c, progress); err != nil {
		return err
	}
	if err = c.ensureAvd(ctx, progress); err != nil {
		return err
	}
	return c.startEmulatorProcess(ctx, progress, opts)
}

// cappedBuffer keeps the first limit bytes written to it.
type cappedBuffer struct {
	mu    sync.Mutex
	buf   bytes.Buffer
	limit int
}

func (b *cappedBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if room := b.limit - b.buf.Len(); room > 0 {
		b.buf.Write(p[:min(room, len(p))])
	}
	return len(p), nil
}

func (b *cappedBuffer) tail(n int) string {
	b.mu.Lock()
	defer b.mu.Unlock()
	s := strings.TrimSpace(b.buf.String())
	if len(s) > n {
		return s[len(s)-n:]
	}
	return s
}

func (c *Controller) startEmulatorProcess(ctx context.Context, progress func(string), opts StartOptions) error {
	log := c.host.cfg.Log
	progress("Starting Android emulator…")
	args := []string{"-avd", c.avdName, "-no-audio", "-no-boot-anim", "-port", strconv.Itoa(c.adbPort), "-partition-size", "800"}
	if opts.Headless == nil || *opts.Headless {
		args = append(args[:2], append([]string{"-no-window"}, args[2:]...)...)
	}
	cmd := exec.Command(emulatorBin(c.sdkDir), args...)
	cmd.Env = append(c.sdkEnv(), "ANDROID_AVD_HOME="+c.avdHome)
	launch := &cappedBuffer{limit: 64 << 10}
	cmd.Stdout, cmd.Stderr = launch, launch
	if err := cmd.Start(); err != nil {
		return err
	}
	proc := &emulatorProc{cmd: cmd, pid: cmd.Process.Pid, done: make(chan struct{})}
	c.mu.Lock()
	c.emulator = proc
	c.mu.Unlock()
	c.writeState(func(s *State) { s.PID, s.AdbSerial = ptr(proc.pid), ptr(c.adbSerial) })

	var bootReady bool
	var readyMu sync.Mutex
	failure := make(chan error, 1)
	go func() {
		waitErr := cmd.Wait()
		close(proc.done)
		log.Info("android: emulator exited", "user", c.userID, "code", cmd.ProcessState.ExitCode())
		c.mu.Lock()
		if c.emulator == proc {
			c.emulator = nil
		}
		c.mu.Unlock()
		c.host.release(c.adbPort)
		if cur := c.state(); cur.PID != nil && *cur.PID == proc.pid {
			c.writeState(func(s *State) { s.Bootstrapped, s.Starting, s.PID, s.AdbSerial = false, false, nil, nil })
		}
		readyMu.Lock()
		ready := bootReady
		readyMu.Unlock()
		if !ready {
			how := "unknown"
			if ws, ok := cmd.ProcessState.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
				how = ws.Signal().String()
			} else if waitErr != nil || cmd.ProcessState != nil {
				how = strconv.Itoa(cmd.ProcessState.ExitCode())
			}
			msg := fmt.Sprintf("Android emulator exited before boot completed (%s).", how)
			if details := launch.tail(4000); details != "" {
				msg += " " + details
			}
			failure <- errors.New(msg)
		}
	}()

	progress("Waiting for Android to boot (can take 2–5 min on first run)…")
	stopOnCancel := context.AfterFunc(ctx, func() { terminatePID(proc.pid) })
	defer stopOnCancel()
	bootErr := make(chan error, 1)
	go func() {
		bootErr <- c.waitForBoot(ctx, 10*time.Minute, func() bool { return adbx.PidAlive(proc.pid) && !proc.exited() })
	}()
	select {
	case err := <-bootErr:
		if err != nil {
			return err
		}
	case err := <-failure:
		return err
	}
	readyMu.Lock()
	bootReady = true
	readyMu.Unlock()

	c.writeState(func(s *State) { s.Bootstrapped, s.Starting, s.StartupPhase, s.LastStartError = true, false, nil, nil })
	log.Info("android: emulator ready", "user", c.userID, "serial", c.adbSerial)
	if err := c.setWallpaper(ctx, c.adbSerial); err != nil {
		if ctx.Err() != nil {
			return context.Cause(ctx)
		}
		log.Warn("android: wallpaper not set", "error", err)
	}
	if !adbx.PidAlive(proc.pid) {
		return errors.New("Android emulator exited immediately after boot completed.")
	}
	return nil
}

func (c *Controller) waitForBoot(ctx context.Context, timeout time.Duration, alive func() bool) error {
	client := c.adb(c.adbSerial)
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if !alive() {
			return errors.New("Emulator process exited before Android finished booting (check virtualization/KVM support and the system image).")
		}
		res, err := client.Run(ctx, adbx.RunOptions{Timeout: 5 * time.Second, MaxOutputBytes: 64 << 10},
			"shell", "getprop", "sys.boot_completed")
		if err == nil && strings.TrimSpace(string(res.Stdout)) == "1" {
			return nil
		}
		if err != nil && ctx.Err() != nil {
			return context.Cause(ctx)
		}
		if err := sleep(ctx, 3*time.Second); err != nil {
			return err
		}
	}
	return errors.New("Emulator did not boot within timeout")
}

// setWallpaper installs the NeoAgent logo as wallpaper. Best effort: callers
// ignore its failure.
func (c *Controller) setWallpaper(ctx context.Context, serial string) error {
	logo := c.host.cfg.LogoPath
	if logo == "" || !fileExists(logo) {
		return nil
	}
	client := c.adb(serial)
	quick := adbx.RunOptions{Timeout: 5 * time.Second, MaxOutputBytes: 64 << 10}
	// Root access works on AOSP default images; ignore refusal.
	_, _ = client.Run(ctx, quick, "root")
	if err := sleep(ctx, 1500*time.Millisecond); err != nil {
		return err
	}
	if _, err := client.Run(ctx, adbx.RunOptions{Timeout: 15 * time.Second, MaxOutputBytes: 1 << 20}, "push", logo, "/sdcard/neoagent-wallpaper.png"); err != nil {
		return err
	}
	data, err := os.ReadFile(logo)
	if err != nil {
		return err
	}
	// cmd wallpaper set-stream reads the PNG from stdin (Android 7.1+).
	if _, err := client.Run(ctx, adbx.RunOptions{Stdin: data, Timeout: 15 * time.Second, MaxOutputBytes: 1 << 20}, "shell", "cmd", "wallpaper", "set-stream"); err == nil {
		c.host.cfg.Log.Info("android: wallpaper set")
		return nil
	}
	// Direct file copy for rooted images (Android 11 AOSP).
	for _, command := range []string{
		"cp /sdcard/neoagent-wallpaper.png /data/system/users/0/wallpaper",
		"chmod 600 /data/system/users/0/wallpaper",
		"chown system:system /data/system/users/0/wallpaper",
		"am broadcast -a android.intent.action.WALLPAPER_CHANGED",
	} {
		if _, err := client.Shell(ctx, command, quick); err != nil {
			return err
		}
	}
	c.host.cfg.Log.Info("android: wallpaper set via direct copy")
	return nil
}
