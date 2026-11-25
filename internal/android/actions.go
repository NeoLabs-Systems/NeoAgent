package android

import (
	"archive/zip"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"maps"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neolabs-go/adbx"
)

// ShotResult carries the stored screenshot's URL, null without an artifact
// store.
type ShotResult struct {
	ScreenshotPath *string `json:"screenshotPath"`
}

func jsLen(s string) int { return len(utf16.Encode([]rune(s))) }

// shellEscape quotes text for a single-quoted Android shell string.
func shellEscape(s string) string { return strings.ReplaceAll(s, "'", `'\''`) }

var (
	safeIdentifier = regexp.MustCompile(`^[\w.]+$`)
	safeActivity   = regexp.MustCompile(`^[\w.$]+$`)
	safeComponent  = regexp.MustCompile(`^[\w.$]+/[\w.$]+$`)
	safeMime       = regexp.MustCompile(`^[\w.+-]+/[\w.+*-]+$`)
	keycodePattern = regexp.MustCompile(`^KEYCODE_[A-Z0-9_]+$`)
	digitsPattern  = regexp.MustCompile(`^\d+$`)
)

func requireCoordinate(v float64, ok bool, label string) (int, error) {
	if !ok || v < 0 {
		return 0, fmt.Errorf("%s must be a non-negative number.", label)
	}
	return roundHalfUp(v), nil
}

func (c *Controller) shellRun(ctx context.Context, serial, command string, timeout time.Duration) (string, error) {
	return c.adb(serial).Shell(ctx, command, adbx.RunOptions{Timeout: timeout, MaxOutputBytes: 4 << 20})
}

// ShellRequest is POST /shell.
type ShellRequest struct {
	Command    string
	Timeout    time.Duration
	Screenshot bool
}

// ShellResult is the answer for a shell command that also took a screenshot.
type ShellResult struct {
	Output         string  `json:"output"`
	ScreenshotPath *string `json:"screenshotPath"`
}

// Shell runs a command in the device shell. The result is the output text, or
// a ShellResult when a screenshot was requested.
func (c *Controller) Shell(ctx context.Context, req ShellRequest) (any, error) {
	if strings.TrimSpace(req.Command) == "" {
		return nil, errors.New("Android shell command is required.")
	}
	serial, err := c.requireSerial()
	if err != nil {
		return nil, err
	}
	out, err := c.shellRun(ctx, serial, req.Command, req.Timeout)
	if err != nil {
		return nil, err
	}
	if req.Screenshot {
		shot, err := c.Screenshot(ctx)
		if err != nil {
			return nil, err
		}
		return ShellResult{Output: out, ScreenshotPath: shot.ScreenshotPath}, nil
	}
	return out, nil
}

func (c *Controller) sh(ctx context.Context, command string) error {
	serial, err := c.requireSerial()
	if err != nil {
		return err
	}
	_, err = c.shellRun(ctx, serial, command, 0)
	return err
}

// CapturePNG grabs the screen with screencap.
func (c *Controller) CapturePNG(ctx context.Context) ([]byte, error) {
	serial, err := c.requireSerial()
	if err != nil {
		return nil, err
	}
	png, err := c.adb(serial).ExecOut(ctx, adbx.RunOptions{Timeout: 15 * time.Second, MaxOutputBytes: 20 << 20}, "screencap", "-p")
	if err != nil {
		return nil, err
	}
	if len(png) == 0 {
		return nil, errors.New("ADB capture returned no data.")
	}
	return png, nil
}

// Screenshot captures the screen and stores it.
func (c *Controller) Screenshot(ctx context.Context) (ShotResult, error) {
	png, err := c.CapturePNG(ctx)
	if err != nil {
		return ShotResult{}, err
	}
	if len(png) == 0 {
		return ShotResult{}, errors.New("screencap returned no data")
	}
	url, err := c.saveArtifact(ctx, png)
	return ShotResult{ScreenshotPath: url}, err
}

func (c *Controller) saveArtifact(ctx context.Context, png []byte) (*string, error) {
	if len(png) == 0 || c.host.cfg.Artifacts == nil {
		return nil, nil
	}
	if err := validatePNG(png); err != nil {
		return nil, err
	}
	url, err := c.host.cfg.Artifacts.CreateBufferArtifact(ctx, c.userID, BufferArtifact{
		Kind: "android-screenshot", Backend: "android-emulator", Extension: "png",
		ContentType: "image/png", FilenameBase: "android-emulator-screenshot", Content: png,
	})
	if err != nil {
		return nil, err
	}
	return &url, nil
}

// UIDump is the result of dumping the view hierarchy.
type UIDump struct {
	XML        string        `json:"xml"`
	DevicePath string        `json:"devicePath"`
	NodeCount  int           `json:"nodeCount"`
	Nodes      []NodeSummary `json:"nodes,omitempty"`
	nodes      []Node
}

// DumpUI dumps the view hierarchy; includeNodes adds up to 200 node summaries.
func (c *Controller) DumpUI(ctx context.Context, includeNodes bool) (UIDump, error) {
	serial, err := c.requireSerial()
	if err != nil {
		return UIDump{}, err
	}
	const devicePath = "/sdcard/window_dump.xml"
	if _, err := c.shellRun(ctx, serial, "uiautomator dump "+devicePath, 0); err != nil {
		return UIDump{}, err
	}
	xml, err := c.shellRun(ctx, serial, "cat '"+devicePath+"'", 10*time.Second)
	if err != nil {
		return UIDump{}, err
	}
	nodes := ParseUIDump(xml)
	d := UIDump{XML: xml, DevicePath: devicePath, NodeCount: len(nodes), nodes: nodes}
	if includeNodes {
		d.Nodes = make([]NodeSummary, 0, min(len(nodes), 200))
		for _, n := range nodes[:min(len(nodes), 200)] {
			d.Nodes = append(d.Nodes, n.Summarize())
		}
	}
	return d, nil
}

// Observation is a screenshot plus the UI dump.
type Observation struct {
	ScreenshotPath *string       `json:"screenshotPath"`
	UIDumpPath     string        `json:"uiDumpPath"`
	NodeCount      int           `json:"nodeCount"`
	Nodes          []NodeSummary `json:"nodes,omitempty"`
}

// Observe takes a screenshot and a UI dump.
func (c *Controller) Observe(ctx context.Context, includeNodes bool) (Observation, error) {
	shot, err := c.Screenshot(ctx)
	if err != nil {
		return Observation{}, err
	}
	dump, err := c.DumpUI(ctx, includeNodes)
	if err != nil {
		return Observation{}, err
	}
	return Observation{ScreenshotPath: shot.ScreenshotPath, UIDumpPath: dump.DevicePath, NodeCount: dump.NodeCount, Nodes: dump.Nodes}, nil
}

// findUINode returns the best match for the selector. shown is what an error
// message prints for the request, as the Node server printed the options.
func (c *Controller) findUINode(ctx context.Context, sel Selector, shown any) (*Node, error) {
	if !sel.any() {
		return nil, errors.New("Provide x and y coordinates or a UI selector.")
	}
	dump, err := c.DumpUI(ctx, true)
	if err != nil {
		return nil, err
	}
	node := FindBestNode(dump.nodes, sel)
	if node == nil {
		raw, _ := json.Marshal(shown)
		return nil, fmt.Errorf("No Android UI element matched %s.", raw)
	}
	return node, nil
}

type target struct {
	x, y int
	node *Node
}

func (t target) json() any {
	if t.node != nil {
		return t.node.Summarize()
	}
	return map[string]int{"x": t.x, "y": t.y}
}

// resolvePoint turns request fields into a screen point: explicit x/y, or the
// centre of the UI element a selector finds.
func (c *Controller) resolvePoint(ctx context.Context, p Params, sel Selector, shown any) (target, error) {
	hasX, hasY := p.finite("x"), p.finite("y")
	if hasX || hasY {
		if !hasX || !hasY {
			return target{}, errors.New("Both x and y coordinates are required.")
		}
		xv, xok := p.number("x")
		yv, yok := p.number("y")
		x, err := requireCoordinate(xv, xok, "x")
		if err != nil {
			return target{}, err
		}
		y, err := requireCoordinate(yv, yok, "y")
		if err != nil {
			return target{}, err
		}
		return target{x: x, y: y}, nil
	}
	node, err := c.findUINode(ctx, sel, shown)
	if err != nil {
		return target{}, err
	}
	if node.Bounds.Width <= 0 || node.Bounds.Height <= 0 {
		return target{}, errors.New("The matched Android UI element has no tappable bounds.")
	}
	return target{x: node.Bounds.CenterX, y: node.Bounds.CenterY, node: node}, nil
}

// TapResult is the tap answer.
type TapResult struct {
	Success        bool    `json:"success"`
	Target         any     `json:"target"`
	ScreenshotPath *string `json:"screenshotPath"`
}

// Tap taps a point or a matched UI element and returns a screenshot.
func (c *Controller) Tap(ctx context.Context, p Params) (TapResult, error) {
	t, err := c.resolvePoint(ctx, p, p.selector("text"), p)
	if err != nil {
		return TapResult{}, err
	}
	if err := c.sh(ctx, fmt.Sprintf("input tap %d %d", t.x, t.y)); err != nil {
		return TapResult{}, err
	}
	shot, err := c.Screenshot(ctx)
	return TapResult{Success: true, Target: t.json(), ScreenshotPath: shot.ScreenshotPath}, err
}

// LongPressResult is the long-press answer.
type LongPressResult struct {
	Success bool `json:"success"`
	Target  any  `json:"target"`
}

// LongPress holds a point or matched element.
func (c *Controller) LongPress(ctx context.Context, p Params) (LongPressResult, error) {
	t, err := c.resolvePoint(ctx, p, p.selector("text"), p)
	if err != nil {
		return LongPressResult{}, err
	}
	d := p.clamped("durationMs", 650, 100, 30_000)
	err = c.sh(ctx, fmt.Sprintf("input swipe %d %d %d %d %d", t.x, t.y, t.x, t.y, d))
	return LongPressResult{Success: true, Target: t.json()}, err
}

// SwipeResult is the swipe answer.
type SwipeResult struct {
	Success        bool    `json:"success"`
	ScreenshotPath *string `json:"screenshotPath"`
}

// Swipe drags between two points.
func (c *Controller) Swipe(ctx context.Context, p Params) (SwipeResult, error) {
	var pts [4]int
	for i, key := range []string{"x1", "y1", "x2", "y2"} {
		v, ok := p.number(key)
		n, err := requireCoordinate(v, ok, key)
		if err != nil {
			return SwipeResult{}, err
		}
		pts[i] = n
	}
	d := p.clamped("durationMs", 300, 50, 30_000)
	if err := c.sh(ctx, fmt.Sprintf("input swipe %d %d %d %d %d", pts[0], pts[1], pts[2], pts[3], d)); err != nil {
		return SwipeResult{}, err
	}
	shot, err := c.Screenshot(ctx)
	return SwipeResult{Success: true, ScreenshotPath: shot.ScreenshotPath}, err
}

// TypeResult is the type answer; Target is omitted when no selector was used.
type TypeResult struct {
	Success bool         `json:"success"`
	Target  *NodeSummary `json:"target,omitempty"`
}

// Type enters text, optionally tapping a field first, clearing it, and
// pressing Enter afterwards.
func (c *Controller) Type(ctx context.Context, p Params) (TypeResult, error) {
	raw, present := p["text"]
	if !present || raw == nil {
		return TypeResult{}, errors.New("Text is required.")
	}
	text := jsString(raw)
	if jsLen(text) > maxTextChars {
		return TypeResult{}, fmt.Errorf("Text exceeds the %d-character limit.", maxTextChars)
	}
	sel := p.selector("textSelector")
	sel.PackageName, sel.Clickable = "", false
	var node *Node
	if sel.any() {
		pt, err := c.resolvePoint(ctx, nil, sel, sel.defined())
		if err != nil {
			return TypeResult{}, err
		}
		node = pt.node
		if err := c.sh(ctx, fmt.Sprintf("input tap %d %d", pt.x, pt.y)); err != nil {
			return TypeResult{}, err
		}
	}
	if p["clear"] == true {
		if err := c.sh(ctx, "input keyevent KEYCODE_MOVE_END; for i in $(seq 1 200); do input keyevent KEYCODE_DEL; done"); err != nil {
			return TypeResult{}, err
		}
	}
	// ADB input text encoding: %% is a literal %, %s a space.
	encoded := strings.ReplaceAll(strings.ReplaceAll(text, "%", "%%"), " ", "%s")
	if encoded != "" {
		if err := c.sh(ctx, "input text '"+shellEscape(encoded)+"'"); err != nil {
			return TypeResult{}, err
		}
	}
	if truthy(p["pressEnter"]) {
		if err := c.sh(ctx, "input keyevent KEYCODE_ENTER"); err != nil {
			return TypeResult{}, err
		}
	}
	res := TypeResult{Success: true}
	if node != nil {
		s := node.Summarize()
		res.Target = &s
	}
	return res, nil
}

var keyMap = map[string]string{
	"back": "KEYCODE_BACK", "home": "KEYCODE_HOME", "app_switch": "KEYCODE_APP_SWITCH",
	"enter": "KEYCODE_ENTER", "del": "KEYCODE_DEL", "escape": "KEYCODE_ESCAPE",
	"menu": "KEYCODE_MENU", "power": "KEYCODE_POWER",
	"volume_up": "KEYCODE_VOLUME_UP", "volume_down": "KEYCODE_VOLUME_DOWN",
}

// SuccessResult is the plain {"success": true} answer.
type SuccessResult struct {
	Success bool `json:"success"`
}

// PressKey sends a key event, by name (back, home, ...), number or KEYCODE_*.
func (c *Controller) PressKey(ctx context.Context, key string) (SuccessResult, error) {
	normalized := strings.TrimSpace(key)
	code, ok := keyMap[strings.ToLower(normalized)]
	if !ok {
		code = strings.ToUpper(normalized)
		if digitsPattern.MatchString(normalized) {
			code = normalized
		}
	}
	if !digitsPattern.MatchString(code) && !keycodePattern.MatchString(code) {
		shown := normalized
		if shown == "" {
			shown = "(empty)"
		}
		return SuccessResult{}, fmt.Errorf("Unsupported Android key: %s", shown)
	}
	return SuccessResult{Success: true}, c.sh(ctx, "input keyevent "+code)
}

// AppsResult is the installed packages list.
type AppsResult struct {
	Packages []string `json:"packages"`
}

// ListApps lists installed packages (user apps unless includeSystem).
func (c *Controller) ListApps(ctx context.Context, includeSystem bool) (AppsResult, error) {
	serial, err := c.requireSerial()
	if err != nil {
		return AppsResult{}, err
	}
	cmd := "pm list packages -3"
	if includeSystem {
		cmd = "pm list packages"
	}
	out, err := c.shellRun(ctx, serial, cmd, 0)
	if err != nil {
		return AppsResult{}, err
	}
	packages := []string{}
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line != "" {
			packages = append(packages, strings.TrimSpace(strings.Replace(line, "package:", "", 1)))
		}
	}
	return AppsResult{Packages: packages}, nil
}

// OpenApp launches an app, by its launcher or an explicit activity, and
// returns a screenshot.
func (c *Controller) OpenApp(ctx context.Context, p Params) (ShotResult, error) {
	pkg, activity := p.text("packageName"), p.text("activity")
	if !safeIdentifier.MatchString(pkg) {
		return ShotResult{}, errors.New("Invalid package name")
	}
	if activity != "" {
		if !safeActivity.MatchString(activity) {
			return ShotResult{}, errors.New("Invalid Android activity name")
		}
		if err := c.sh(ctx, "am start -n '"+shellEscape(pkg+"/"+activity)+"'"); err != nil {
			return ShotResult{}, err
		}
	} else if err := c.sh(ctx, "monkey -p '"+shellEscape(pkg)+"' -c android.intent.category.LAUNCHER 1"); err != nil {
		return ShotResult{}, err
	}
	if err := sleep(ctx, 1500*time.Millisecond); err != nil {
		return ShotResult{}, err
	}
	return c.Screenshot(ctx)
}

// OpenIntent starts an activity with an action, data URI, package, component,
// MIME type and string extras, and returns a screenshot.
func (c *Controller) OpenIntent(ctx context.Context, p Params) (ShotResult, error) {
	action := p.text("action")
	if !safeIdentifier.MatchString(action) {
		action = "android.intent.action.VIEW"
	}
	cmd := "am start -a '" + shellEscape(action) + "'"
	var data string
	for _, key := range []string{"dataUri", "data", "url", "uri"} {
		if truthy(p[key]) {
			data = jsString(p[key])
			break
		}
	}
	if data != "" {
		if jsLen(data) > maxTextChars {
			return ShotResult{}, errors.New("Android intent URI is too long.")
		}
		if err := c.ValidateIntentURL(ctx, data); err != nil {
			return ShotResult{}, err
		}
		cmd += " -d '" + shellEscape(data) + "'"
	}
	if pkg := p.text("packageName"); pkg != "" {
		if !safeIdentifier.MatchString(pkg) {
			return ShotResult{}, errors.New("Invalid Android package name")
		}
		cmd += " -p '" + shellEscape(pkg) + "'"
	}
	if comp := p.text("component"); comp != "" {
		if !safeComponent.MatchString(comp) {
			return ShotResult{}, errors.New("Invalid Android component name")
		}
		cmd += " -n '" + shellEscape(comp) + "'"
	}
	if mime := p.text("mimeType"); mime != "" {
		if !safeMime.MatchString(mime) {
			return ShotResult{}, errors.New("Invalid Android MIME type")
		}
		cmd += " -t '" + shellEscape(mime) + "'"
	}
	extras, _ := p["extras"].(map[string]any)
	if len(extras) > maxIntentExtras {
		return ShotResult{}, fmt.Errorf("Android intent extras exceed the %d-item limit.", maxIntentExtras)
	}
	for _, k := range slices.Sorted(maps.Keys(extras)) {
		v := jsString(extras[k])
		if !safeIdentifier.MatchString(k) {
			return ShotResult{}, fmt.Errorf("Invalid Android intent extra name: %s", k)
		}
		if jsLen(v) > maxTextChars {
			return ShotResult{}, fmt.Errorf("Android intent extra is too long: %s", k)
		}
		cmd += " --es '" + shellEscape(k) + "' '" + shellEscape(v) + "'"
	}
	if err := c.sh(ctx, cmd); err != nil {
		return ShotResult{}, err
	}
	if err := sleep(ctx, 2*time.Second); err != nil {
		return ShotResult{}, err
	}
	return c.Screenshot(ctx)
}

// WaitResult is the wait-for answer.
type WaitResult struct {
	Found          bool         `json:"found"`
	Ready          bool         `json:"ready"`
	Node           *NodeSummary `json:"node,omitempty"`
	ScreenshotPath *string      `json:"screenshotPath,omitempty"`
	TimeoutMs      *int         `json:"timeoutMs,omitempty"`
}

// WaitFor polls the UI until an element matching the selector appears.
func (c *Controller) WaitFor(ctx context.Context, p Params) (WaitResult, error) {
	sel := p.selector("text")
	if !sel.any() {
		return WaitResult{}, errors.New("android_wait_for requires at least one UI selector.")
	}
	tv, tok := p.number("timeoutMs")
	if !tok {
		tv, tok = p.number("timeout")
	}
	timeout := clamp(tv, tok, 20_000, 100, 120_000)
	interval := p.clamped("intervalMs", 1500, 100, 5000)
	deadline := time.Now().Add(time.Duration(timeout) * time.Millisecond)
	for time.Now().Before(deadline) {
		dump, err := c.DumpUI(ctx, true)
		if err != nil {
			return WaitResult{}, err
		}
		if node := FindBestNode(dump.nodes, sel); node != nil {
			s := node.Summarize()
			res := WaitResult{Found: true, Ready: true, Node: &s}
			if p["screenshot"] != false {
				shot, err := c.Screenshot(ctx)
				if err != nil {
					return WaitResult{}, err
				}
				res.ScreenshotPath = shot.ScreenshotPath
			}
			return res, nil
		}
		if err := sleep(ctx, time.Duration(interval)*time.Millisecond); err != nil {
			return WaitResult{}, err
		}
	}
	return WaitResult{TimeoutMs: &timeout}, nil
}

// InstallResult is the adb install answer.
type InstallResult struct {
	Success bool   `json:"success"`
	Output  string `json:"output"`
}

// InstallAPK installs an .apk, or the universal.apk of an .apks bundle.
func (c *Controller) InstallAPK(ctx context.Context, apkPath string) (InstallResult, error) {
	if apkPath == "" {
		return InstallResult{}, errors.New("apkPath required")
	}
	resolved, err := filepath.EvalSymlinks(apkPath)
	if err != nil {
		return InstallResult{}, err
	}
	info, err := os.Stat(resolved)
	if err != nil {
		return InstallResult{}, err
	}
	if !info.Mode().IsRegular() {
		return InstallResult{}, errors.New("Android package path must be a file.")
	}
	if info.Size() > maxPackageBytes {
		return InstallResult{}, errors.New("Android package exceeds the 1GB installation limit.")
	}
	ext := strings.ToLower(filepath.Ext(resolved))
	if ext != ".apk" && ext != ".apks" {
		return InstallResult{}, errors.New("Android package must be an .apk or universal .apks bundle.")
	}
	serial, err := c.requireSerial()
	if err != nil {
		return InstallResult{}, err
	}
	installPath := resolved
	if ext == ".apks" {
		dir, err := os.MkdirTemp("", "neoagent-apks-")
		if err != nil {
			return InstallResult{}, err
		}
		defer os.RemoveAll(dir)
		if installPath, err = extractUniversalAPK(resolved, dir); err != nil {
			return InstallResult{}, err
		}
	}
	res, err := c.adb(serial).Run(ctx, adbx.RunOptions{Timeout: 5 * time.Minute, MaxOutputBytes: 4 << 20}, "install", "-r", installPath)
	if err != nil {
		return InstallResult{}, err
	}
	if !strings.Contains(string(res.Stdout), "Success") {
		msg := string(res.Stderr)
		if msg == "" {
			msg = string(res.Stdout)
		}
		if msg == "" {
			msg = "adb install did not report success"
		}
		return InstallResult{}, errors.New(msg)
	}
	return InstallResult{Success: true, Output: string(res.Stdout)}, nil
}

func extractUniversalAPK(bundle, dir string) (string, error) {
	r, err := zip.OpenReader(bundle)
	if err != nil {
		return "", err
	}
	defer r.Close()
	for _, f := range r.File {
		if !strings.EqualFold(f.Name, "universal.apk") {
			continue
		}
		if f.UncompressedSize64 > maxPackageBytes {
			return "", errors.New("The universal APK exceeds the 1GB installation limit.")
		}
		src, err := f.Open()
		if err != nil {
			return "", err
		}
		defer src.Close()
		out := filepath.Join(dir, "universal.apk")
		dst, err := os.OpenFile(out, os.O_CREATE|os.O_WRONLY|os.O_EXCL, 0o600)
		if err != nil {
			return "", err
		}
		_, err = io.Copy(dst, io.LimitReader(src, maxPackageBytes+1))
		if cerr := dst.Close(); err == nil {
			err = cerr
		}
		return out, err
	}
	return "", errNoUniversalAPK
}
