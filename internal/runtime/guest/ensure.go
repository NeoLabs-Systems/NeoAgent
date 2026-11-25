package guest

import (
	"encoding/base64"
	"encoding/json"
	"net/http"
	"os"
	"path"
	"strings"
	"time"
)

const (
	ensureDesktopScript = "/usr/local/bin/neoagent-ensure-desktop"
	framebufferScript   = "/usr/local/bin/neoagent-framebuffer-desktop"
	displaySetupScript  = "/usr/local/bin/neoagent-display-setup"
	xorgDisplayConf     = "/etc/X11/xorg.conf.d/10-neoagent-display.conf"
)

// The text the ensure endpoint writes when the image's own desktop scripts
// are missing.
const (
	displaySetupBody = "#!/bin/sh\nchvt 1 >/dev/null 2>&1 || true\nexit 0\n"
	seatUnitBody     = `[Unit]
Description=Show the NeoAgent desktop on the VNC console
After=lightdm.service
Wants=lightdm.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'chvt 1 >/dev/null 2>&1 || true'
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
WantedBy=multi-user.target
`
	lightdmBody = `[LightDM]
start-default-seat=true
logind-check-graphical=false

[Seat:*]
autologin-user=neo
autologin-user-timeout=0
autologin-session=openbox
user-session=openbox
xserver-command=X -nolisten tcp vt1
display-setup-script=/usr/local/bin/neoagent-display-setup
`
	fbdevXorgConfig = `Section "Device"
    Identifier "NeoAgentGPU"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
    Option "ShadowFB" "true"
EndSection
Section "Screen"
    Identifier "NeoAgentScreen"
    Device "NeoAgentGPU"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
    EndSubSection
EndSection
Section "ServerFlags"
    Option "DontZap" "true"
    Option "AutoAddGPU" "false"
EndSection
`
)

func exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func (s *Server) sudo(timeout time.Duration, args ...string) cmdResult {
	if timeout == 0 {
		timeout = 30 * time.Second
	}
	return s.desktop.run("sudo", append([]string{"-n"}, args...), timeout, nil)
}

func jsQuote(v string) string {
	body, _ := json.Marshal(v)
	return string(body)
}

func (s *Server) writePrivilegedFile(filePath, content string) error {
	encoded := base64.StdEncoding.EncodeToString([]byte(content))
	res := s.sudo(0, "/bin/sh", "-c", "install -d -m 0755 "+jsQuote(path.Dir(filePath))+" && echo "+encoded+" | base64 -d > "+jsQuote(filePath))
	if res.Status != 0 {
		detail := strings.TrimSpace(res.Stderr)
		if detail == "" {
			detail = strings.TrimSpace(res.Stdout)
		}
		if detail == "" {
			detail = "Failed to write " + filePath
		}
		return &plainError{detail}
	}
	return nil
}

type plainError struct{ msg string }

func (e *plainError) Error() string { return e.msg }

func (s *Server) waitForDisplay(timeout time.Duration) bool {
	timeout = time.Duration(float64(timeout) * s.waitScale)
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if s.displayServerAlive() {
			return true
		}
		time.Sleep(400 * time.Millisecond)
	}
	return s.displayServerAlive()
}

func (s *Server) writeXorgConfig() error {
	if exists("/dev/dri/card0") {
		s.sudo(0, "rm", "-f", "/etc/X11/xorg.conf", xorgDisplayConf)
		return nil
	}
	if err := s.writePrivilegedFile(xorgDisplayConf, fbdevXorgConfig); err != nil {
		return err
	}
	return s.writePrivilegedFile("/etc/X11/xorg.conf", fbdevXorgConfig)
}

func (s *Server) unbindFramebufferConsole() {
	s.sudo(0, "/bin/sh", "-c", "echo 0 > /proc/sys/kernel/printk 2>/dev/null || true; "+
		"for cons in /sys/class/vtconsole/vtcon*; do "+
		`if grep -qi frame "$cons/name" 2>/dev/null; then echo 0 > "$cons/bind" 2>/dev/null || true; fi; `+
		"done")
}

func (s *Server) ensureDiagnostics() string {
	res := s.sudo(15*time.Second, "/bin/sh", "-c", "systemctl --no-pager --full status lightdm 2>&1 | tail -n 20; "+
		"journalctl -u lightdm -n 20 --no-pager 2>&1; "+
		"tail -n 20 /var/log/Xorg.0.log 2>/dev/null; "+
		"tail -n 20 /var/log/neoagent-xorg-direct.log 2>/dev/null")
	raw := res.Stdout
	if raw == "" {
		raw = res.Stderr
	}
	var lines []string
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || sysvNoise.MatchString(line) {
			continue
		}
		lines = append(lines, line)
	}
	if len(lines) > 8 {
		lines = lines[len(lines)-8:]
	}
	return strings.TrimSpace(strings.Join(lines, " "))
}

func (s *Server) desktopEnsure(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) { return s.ensureDesktop() })
}

// ensureDesktop brings the graphical session up, escalating from the image's
// own script to rewriting its units and finally starting Xorg directly.
func (s *Server) ensureDesktop() (any, error) {
	ready := func(extra map[string]any) object {
		out := obj("available", true, "display", defaultDisplay)
		if fallback, has := extra["fallback"]; has {
			out = append(out, kv{"fallback", fallback})
		}
		return out
	}
	if s.displayServerAlive() {
		return ready(nil), nil
	}
	if exists(ensureDesktopScript) {
		repaired := s.sudo(150*time.Second, ensureDesktopScript)
		output := repaired.Stdout + "\n" + repaired.Stderr
		if repaired.Status == 0 || strings.Contains(output, "DESKTOP_READY") || s.displayServerAlive() {
			return ready(nil), nil
		}
	}

	s.sudo(0, "rm", "-f", xorgDisplayConf)
	if err := s.writePrivilegedFile(displaySetupScript, displaySetupBody); err != nil {
		return nil, err
	}
	s.sudo(0, "chmod", "0755", displaySetupScript)
	if err := s.writePrivilegedFile("/etc/systemd/system/neoagent-desktop-seat.service", seatUnitBody); err != nil {
		return nil, err
	}
	if err := s.writePrivilegedFile("/etc/lightdm/lightdm.conf.d/50-neoagent.conf", lightdmBody); err != nil {
		return nil, err
	}
	hasDRI, hasFramebuffer := exists("/dev/dri/card0"), exists("/dev/fb0")
	s.sudo(0, "systemctl", "stop", "getty@tty1.service")
	s.sudo(0, "systemctl", "mask", "getty@tty1.service")
	s.sudo(0, "install", "-d", "-m", "0755", "/etc/systemd/system-generators")
	s.sudo(0, "ln", "-sfn", "/dev/null", "/etc/systemd/system-generators/systemd-ssh-generator")
	if err := s.writeXorgConfig(); err != nil {
		return nil, err
	}
	if !hasDRI && hasFramebuffer {
		s.unbindFramebufferConsole()
	}
	s.sudo(0, "systemctl", "stop", "lightdm.service")
	if exists(framebufferScript) {
		s.sudo(45*time.Second, "systemctl", "restart", "neoagent-framebuffer-desktop.service")
		if s.waitForDisplay(25 * time.Second) {
			s.sudo(0, "chvt", "1")
			fallback := "fbdev"
			if hasDRI {
				fallback = "modesetting"
			}
			return ready(map[string]any{"fallback": fallback}), nil
		}
	}
	s.sudo(0, "systemctl", "daemon-reload")
	s.sudo(0, "systemctl", "set-default", "graphical.target")
	s.sudo(0, "systemctl", "enable", "lightdm.service", "neoagent-desktop-seat.service")
	s.sudo(45*time.Second, "systemctl", "restart", "lightdm.service")
	s.sudo(0, "systemctl", "start", "neoagent-desktop-seat.service")
	if s.waitForDisplay(20 * time.Second) {
		s.sudo(0, "chvt", "1")
		var fallback any
		if hasFramebuffer {
			fallback = "fbdev"
		}
		return ready(map[string]any{"fallback": fallback}), nil
	}

	s.sudo(0, "systemctl", "stop", "lightdm.service")
	if hasFramebuffer {
		s.unbindFramebufferConsole()
	}
	xbin := ""
	for _, candidate := range []string{"/usr/bin/Xorg", "/usr/bin/X"} {
		if exists(candidate) {
			xbin = candidate
			break
		}
	}
	if xbin != "" && !exists("/tmp/.X11-unix/X0") {
		s.sudo(5*time.Second, "/bin/sh", "-c", jsQuote(xbin)+" :0 vt1 -nolisten tcp >/var/log/neoagent-xorg-direct.log 2>&1 &")
		if s.waitForDisplay(15 * time.Second) {
			s.sudo(0, "chvt", "1")
			s.sudo(5*time.Second, "/bin/sh", "-c", "su - neo -c 'DISPLAY=:0 openbox-session' >/tmp/neoagent-openbox.log 2>&1 &")
			return ready(map[string]any{"fallback": "xorg"}), nil
		}
	}
	message := s.ensureDiagnostics()
	if message == "" {
		message = "The Linux graphical session is not running."
	}
	return obj("available", false, "display", defaultDisplay, "error", message), nil
}
