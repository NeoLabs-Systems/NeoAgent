package browser

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	goruntime "runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/browserx"
	"github.com/NeoLabs-Systems/neolabs-go/webextract"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

// ReadyMarker is written once the guest image has its browser installed.
const ReadyMarker = "/var/lib/neoagent/browser-runtime-ready"

// Config configures a Controller.
type Config struct {
	// DataDir holds screenshots/ and browser-profiles/default.
	DataDir string
	// ReadyMarker overrides the provisioning marker (tests).
	ReadyMarker string
	// CDPPort overrides the DevTools port (tests); 0 is the guest's 9222.
	CDPPort int
	// ExtraArgs are added to Chromium's command line (tests run headless).
	ExtraArgs []string
	// Validate decides whether a URL may be opened; nil uses cloudsec.
	Validate func(ctx context.Context, raw string) (cloudsec.Result, error)
	Getenv   func(string) string
	Log      *slog.Logger
	// Sleep paces the human-like delays; nil sleeps for real.
	Sleep func(ctx context.Context, d time.Duration) error
}

// Controller is the browser of one guest computer.
type Controller struct {
	cfg        Config
	profileDir string
	shotsDir   string
	endpoint   string

	launchMu sync.Mutex
	mu       sync.Mutex
	browser  *browserx.Browser
	page     *browserx.Page
	identity Identity
	mouse    Point
	display  string
	xvfb     *exec.Cmd
	fill     *protectedFill
}

type protectedFill struct {
	id                                              string
	page                                            *browserx.Page
	allowedOrigin                                   string
	usernameSelector, passwordSelector, submitField string
	expiresAt                                       time.Time
	clearing                                        bool
}

// New creates the controller; Chromium starts on first use.
func New(cfg Config) (*Controller, error) {
	if cfg.Getenv == nil {
		cfg.Getenv = os.Getenv
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	if cfg.ReadyMarker == "" {
		cfg.ReadyMarker = ReadyMarker
	}
	if cfg.Validate == nil {
		cfg.Validate = cloudsec.Checker{}.Validate
	}
	if cfg.Sleep == nil {
		cfg.Sleep = sleepCtx
	}
	port := cfg.CDPPort
	if port == 0 {
		port = guestproto.ChromiumCDPPort
	}
	c := &Controller{
		cfg:        cfg,
		profileDir: filepath.Join(cfg.DataDir, "browser-profiles", "default"),
		shotsDir:   filepath.Join(cfg.DataDir, "screenshots"),
		endpoint:   "http://127.0.0.1:" + strconv.Itoa(port),
		display:    cfg.Getenv("DISPLAY"),
	}
	for _, dir := range []string{c.profileDir, c.shotsDir} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			return nil, err
		}
	}
	c.identity = ChooseIdentity(c.profileDir)
	c.mouse = Point{math.Round(float64(c.identity.Viewport.Width) / 2), math.Round(float64(c.identity.Viewport.Height) / 2)}
	return c, nil
}

func sleepCtx(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}

func (c *Controller) pause(ctx context.Context, lo, hi int) error {
	return c.cfg.Sleep(ctx, time.Duration(randInt(lo, hi))*time.Millisecond)
}

// executable finds Chromium: the environment first, then the usual places.
func (c *Controller) executable() string {
	for _, name := range []string{"PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH", "PUPPETEER_EXECUTABLE_PATH", "CHROME_BIN", "CHROMIUM_BIN"} {
		if p := c.cfg.Getenv(name); p != "" {
			if _, err := os.Stat(p); err == nil {
				return p
			}
		}
	}
	var candidates []string
	switch goruntime.GOOS {
	case "darwin":
		candidates = []string{"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "/Applications/Chromium.app/Contents/MacOS/Chromium", "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"}
	case "windows":
		candidates = []string{`C:\Program Files\Google\Chrome\Application\chrome.exe`, `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`, `C:\Program Files\Microsoft\Edge\Application\msedge.exe`, `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`}
	default:
		candidates = []string{"/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/usr/bin/chromium", "/usr/bin/chromium-browser", "/snap/bin/chromium", "/usr/bin/microsoft-edge"}
	}
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

func (c *Controller) contextOpen() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.browser != nil && c.browser.Connected()
}

// ensureBrowser attaches to the desktop's Chromium, starting it when needed.
// An attached browser is never closed: the user's tabs stay.
func (c *Controller) ensureBrowser(ctx context.Context) error {
	if c.contextOpen() {
		return nil
	}
	c.launchMu.Lock()
	defer c.launchMu.Unlock()
	if c.contextOpen() {
		return nil
	}
	c.disconnect()
	if !c.waitForFile(ctx, c.cfg.ReadyMarker, 10*time.Minute) {
		if err := ctx.Err(); err != nil {
			return err
		}
		return errors.New("Browser runtime provisioning is still in progress inside the VM. Retry shortly.")
	}
	if err := c.ensureVirtualDisplay(ctx); err != nil {
		return err
	}
	c.mu.Lock()
	c.identity = ChooseIdentity(c.profileDir)
	c.mouse = Point{math.Round(float64(c.identity.Viewport.Width) / 2), math.Round(float64(c.identity.Viewport.Height) / 2)}
	c.mu.Unlock()
	if browserx.EndpointAvailable(ctx, c.endpoint) {
		return c.attach(ctx)
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if guestproto.IsChromiumProfileInUse(c.profileDir) {
		if browserx.EndpointAvailable(ctx, c.endpoint) {
			return c.attach(ctx)
		}
		return errors.New("Chromium is already running. Tabs and cookies were left intact.")
	}
	executable := c.executable()
	if executable == "" {
		return errors.New("No chromium executable found for the VM browser runtime.")
	}
	clearSingletonLocks(c.profileDir)
	guestproto.MarkChromiumSessionClean(c.profileDir)
	args := append([]string{"--start-maximized"}, c.desktopArgs()...)
	args = append(args, "--disable-dev-shm-usage", "--no-service-autorun", "--disable-crash-reporter",
		"--disable-search-engine-choice-screen", "--password-store=basic",
		"--disable-features=WebBluetooth,WebUSB,WebSerial,WebOTP,DirectSockets")
	args = append(args, c.cfg.ExtraArgs...)
	env := os.Environ()
	if c.display != "" {
		env = append(env, "DISPLAY="+c.display)
	}
	if err := browserx.StartDetached(executable, args, env); err != nil {
		return err
	}
	if ok, err := browserx.WaitForEndpoint(ctx, c.endpoint, 45*time.Second); err != nil {
		return err
	} else if !ok {
		return errors.New("Chromium started without a debugging session.")
	}
	return c.attach(ctx)
}

func (c *Controller) desktopArgs() []string {
	args := guestproto.ChromiumDesktopArgs(c.profileDir)
	if c.cfg.CDPPort != 0 {
		for i, a := range args {
			if strings.HasPrefix(a, "--remote-debugging-port=") {
				args[i] = "--remote-debugging-port=" + strconv.Itoa(c.cfg.CDPPort)
			}
		}
	}
	return args
}

func clearSingletonLocks(profileDir string) {
	if guestproto.IsChromiumProfileInUse(profileDir) {
		return
	}
	for _, name := range []string{"SingletonLock", "SingletonSocket", "SingletonCookie", "SingletonStartupLock", "DevToolsActivePort"} {
		_ = os.RemoveAll(filepath.Join(profileDir, name))
	}
}

func (c *Controller) waitForFile(ctx context.Context, path string, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for {
		if _, err := os.Stat(path); err == nil {
			return true
		}
		if time.Now().After(deadline) || sleepCtx(ctx, time.Second) != nil {
			_, err := os.Stat(path)
			return err == nil
		}
	}
}

func (c *Controller) attach(ctx context.Context) error {
	b, err := browserx.Connect(ctx, c.endpoint)
	if err != nil {
		return err
	}
	stealth := stealthScript(c.identity)
	b.OnNewPage(func(p *browserx.Page) {
		_ = p.AddInitScript(context.Background(), stealth)
		c.mu.Lock()
		if c.browser == b {
			c.page = p
		}
		c.mu.Unlock()
	})
	c.mu.Lock()
	c.browser = b
	c.page = nil
	c.mu.Unlock()
	if p := c.reuseOpenPage(ctx); p != nil {
		c.mu.Lock()
		c.page = p
		c.mu.Unlock()
	}
	return nil
}

func (c *Controller) disconnect() {
	c.mu.Lock()
	b := c.browser
	c.browser, c.page = nil, nil
	c.mu.Unlock()
	if b != nil {
		b.Close()
	}
}

// reuseOpenPage prefers the last tab that shows a real page.
func (c *Controller) reuseOpenPage(ctx context.Context) *browserx.Page {
	c.mu.Lock()
	b := c.browser
	c.mu.Unlock()
	if b == nil {
		return nil
	}
	pages, err := b.Pages(ctx)
	if err != nil || len(pages) == 0 {
		return nil
	}
	for i := len(pages) - 1; i >= 0; i-- {
		u, err := pages[i].URL(ctx)
		if err == nil && u != "" && u != "about:blank" && !strings.HasPrefix(u, "chrome://") {
			return pages[i]
		}
	}
	return pages[len(pages)-1]
}

func (c *Controller) ensurePage(ctx context.Context) (*browserx.Page, error) {
	if err := c.ensureBrowser(ctx); err != nil {
		return nil, err
	}
	c.mu.Lock()
	p, b := c.page, c.browser
	c.mu.Unlock()
	if p != nil && !p.Closed() {
		return p, nil
	}
	if p := c.reuseOpenPage(ctx); p != nil {
		c.mu.Lock()
		c.page = p
		c.mu.Unlock()
		return p, nil
	}
	p, err := b.NewPage(ctx)
	if err != nil {
		return nil, err
	}
	c.mu.Lock()
	c.page = p
	c.mu.Unlock()
	return p, nil
}

// ensureVirtualDisplay starts Xvfb on Linux when there is no desktop.
func (c *Controller) ensureVirtualDisplay(ctx context.Context) error {
	if goruntime.GOOS != "linux" {
		return nil
	}
	c.mu.Lock()
	running := c.xvfb != nil && c.xvfb.ProcessState == nil
	display := c.display
	c.mu.Unlock()
	if running || strings.TrimSpace(display) != "" {
		return nil
	}
	chosen := ""
	for n := 90; n < 200; n++ {
		_, e1 := os.Stat(fmt.Sprintf("/tmp/.X11-unix/X%d", n))
		_, e2 := os.Stat(fmt.Sprintf("/tmp/.X%d-lock", n))
		if os.IsNotExist(e1) && os.IsNotExist(e2) {
			chosen = fmt.Sprintf(":%d", n)
			break
		}
	}
	if chosen == "" {
		return errors.New("No free X11 display is available for the browser.")
	}
	var stderr bytes.Buffer
	cmd := exec.Command("Xvfb", chosen, "-screen", "0", "1440x900x24", "-ac", "-nolisten", "tcp")
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("Failed to start Xvfb: %s", err.Error())
	}
	exited := make(chan struct{})
	go func() {
		_ = cmd.Wait()
		close(exited)
		c.mu.Lock()
		if c.xvfb == cmd {
			c.xvfb = nil
			if c.display == chosen {
				c.display = c.cfg.Getenv("DISPLAY")
			}
		}
		c.mu.Unlock()
	}()
	select {
	case <-exited:
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = fmt.Sprintf("exit code %d", cmd.ProcessState.ExitCode())
		}
		return fmt.Errorf("Failed to start Xvfb: %s", msg)
	case <-ctx.Done():
		_ = cmd.Process.Kill()
		return ctx.Err()
	case <-time.After(time.Second):
	}
	c.mu.Lock()
	c.xvfb, c.display = cmd, chosen
	c.mu.Unlock()
	return nil
}

// ScreenshotResult is where a screenshot was saved.
type ScreenshotResult struct {
	ScreenshotPath string  `json:"screenshotPath"`
	ArtifactID     *string `json:"artifactId"`
	Filename       string  `json:"filename"`
	FullPath       string  `json:"fullPath"`
}

func (c *Controller) takeScreenshot(ctx context.Context, fullPage bool, selector string) (*ScreenshotResult, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	data, err := p.Screenshot(ctx, browserx.ScreenshotOptions{Format: "png", FullPage: fullPage, Selector: selector})
	if err != nil {
		return nil, err
	}
	name := fmt.Sprintf("screenshot_%d.png", time.Now().UnixMilli())
	path := filepath.Join(c.shotsDir, name)
	if err := os.WriteFile(path, data, 0o600); err != nil {
		return nil, err
	}
	return &ScreenshotResult{ScreenshotPath: "/screenshots/" + name, Filename: name, FullPath: path}, nil
}

// shot is the screenshot fields every action result ends with.
type shot struct {
	ScreenshotPath *string `json:"screenshotPath"`
	ArtifactID     *string `json:"artifactId"`
	FullPath       *string `json:"fullPath"`
}

func shotOf(s *ScreenshotResult) shot {
	if s == nil {
		return shot{}
	}
	return shot{ScreenshotPath: &s.ScreenshotPath, FullPath: &s.FullPath}
}

func (c *Controller) maybeShot(ctx context.Context, want bool) (shot, error) {
	if !want {
		return shot{}, nil
	}
	s, err := c.takeScreenshot(ctx, false, "")
	return shotOf(s), err
}

// ErrorResult is a failed action, reported in the answer rather than as an
// HTTP error.
type ErrorResult struct {
	Error string `json:"error"`
}

func failed(ctx context.Context, err error) (any, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	return ErrorResult{Error: err.Error()}, nil
}

// Screenshot captures the page.
func (c *Controller) Screenshot(ctx context.Context, fullPage bool, selector string) (any, error) {
	return c.takeScreenshot(ctx, fullPage, selector)
}

// ScreenshotJPEG captures the page as JPEG.
func (c *Controller) ScreenshotJPEG(ctx context.Context, quality any, fullPage bool, selector string) ([]byte, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	q := 80
	if f, ok := quality.(float64); ok && f != 0 && !math.IsNaN(f) {
		q = int(math.Floor(f))
	}
	q = min(95, max(30, q))
	return p.Screenshot(ctx, browserx.ScreenshotOptions{Format: "jpeg", Quality: q, FullPage: fullPage, Selector: selector})
}

func (c *Controller) assertNavigationAllowed(ctx context.Context, raw string) error {
	result, err := c.cfg.Validate(ctx, raw)
	if err != nil && ctx.Err() != nil {
		return ctx.Err()
	}
	if err != nil || !result.Allowed {
		reason := result.Reason
		if reason == "" {
			reason = "This URL is not permitted."
		}
		return errors.New(reason)
	}
	return nil
}

func (c *Controller) navigatePage(ctx context.Context, p *browserx.Page, target, referrerMode, waitUntil string) (int, error) {
	current, _ := p.URL(ctx)
	if referrerMode == "current" && current != "" && current != "about:blank" {
		if _, err := p.Eval(ctx, "window.location.href = "+jsonString(target)+", undefined"); err != nil {
			return 0, err
		}
		deadline := time.Now().Add(30 * time.Second)
		for {
			now, _ := p.URL(ctx)
			if now != current {
				break
			}
			if time.Now().After(deadline) {
				return 0, errors.New("page.waitForURL: Timeout 30000ms exceeded.")
			}
			if err := sleepCtx(ctx, 50*time.Millisecond); err != nil {
				return 0, err
			}
		}
		return 0, p.WaitForLoadState(ctx, waitUntil, 30*time.Second)
	}
	o := browserx.GotoOptions{WaitUntil: waitUntil, Timeout: 30 * time.Second}
	if referrerMode == "google" {
		o.Referer = "https://www.google.com/"
	} else if referrerMode == "current" && current != "" && current != "about:blank" {
		o.Referer = current
	}
	return p.Goto(ctx, target, o)
}

func (c *Controller) botDetection(ctx context.Context, p *browserx.Page, html, content string) BotDetection {
	title, _ := p.Title(ctx)
	u, _ := p.URL(ctx)
	return DetectBotChallenge(ChallengeInput{Title: title, URL: u, HTML: html, Text: content})
}

// NavigateOptions tune Navigate.
type NavigateOptions struct {
	WaitFor        string
	WaitUntil      string
	ReferrerMode   string
	ChallengeRetry bool
	Screenshot     bool
	FullPage       bool
}

// NavigateResult is an opened page.
type NavigateResult struct {
	Title            string       `json:"title"`
	URL              string       `json:"url"`
	Status           int          `json:"status"`
	PageContent      string       `json:"pageContent"`
	BotDetection     BotDetection `json:"botDetection"`
	ReferrerMode     string       `json:"referrerMode"`
	ChallengeRetried bool         `json:"challengeRetried"`
	shot
}

// NavigateError is a navigation that failed.
type NavigateError struct {
	Error        string       `json:"error"`
	URL          string       `json:"url"`
	BotDetection BotDetection `json:"botDetection"`
	shot
}

// Navigate opens a URL, reads it like a person would and returns its content
// as Markdown. A bot challenge on a direct visit is retried once as a visit
// from a search result.
func (c *Controller) Navigate(ctx context.Context, target string, o NavigateOptions) (any, error) {
	var p *browserx.Page
	result, err := func() (any, error) {
		if err := c.assertNavigationAllowed(ctx, target); err != nil {
			return nil, err
		}
		var err error
		if p, err = c.ensurePage(ctx); err != nil {
			return nil, err
		}
		requested := NormalizeReferrerMode(o.ReferrerMode)
		mode := requested
		waitUntil := NormalizeWaitUntil(o.WaitUntil)
		load := func() (int, error) {
			status, err := c.navigatePage(ctx, p, target, mode, waitUntil)
			if err != nil {
				return 0, err
			}
			if o.WaitFor != "" {
				if err := p.WaitForSelector(ctx, o.WaitFor, 10*time.Second); err != nil {
					return 0, err
				}
			}
			return status, nil
		}
		read := func() (string, webextract.Result, BotDetection, error) {
			html, err := p.Content(ctx)
			if err != nil {
				return "", webextract.Result{}, BotDetection{}, err
			}
			u, _ := p.URL(ctx)
			extraction := webextract.Extract(html, u)
			return html, extraction, c.botDetection(ctx, p, html, extraction.Markdown), nil
		}
		status, err := load()
		if err != nil {
			return nil, err
		}
		if err := c.pause(ctx, 700, 1800); err != nil {
			return nil, err
		}
		_, extraction, detection, err := read()
		if err != nil {
			return nil, err
		}
		retried := false
		if detection.Detected && o.ChallengeRetry && requested == "direct" {
			retried = true
			mode = "google"
			if err := c.pause(ctx, 1200, 2600); err != nil {
				return nil, err
			}
			if status, err = load(); err != nil {
				return nil, err
			}
			if err := c.pause(ctx, 900, 2200); err != nil {
				return nil, err
			}
			if _, extraction, detection, err = read(); err != nil {
				return nil, err
			}
		}
		title, err := p.Title(ctx)
		if err != nil {
			return nil, err
		}
		current, _ := p.URL(ctx)
		var s *ScreenshotResult
		if o.Screenshot {
			if s, err = c.takeScreenshot(ctx, o.FullPage, ""); err != nil {
				return nil, err
			}
		}
		return NavigateResult{Title: title, URL: current, Status: status, PageContent: extraction.Markdown,
			BotDetection: detection, ReferrerMode: mode, ChallengeRetried: retried, shot: shotOf(s)}, nil
	}()
	if err == nil {
		return result, nil
	}
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	var s *ScreenshotResult
	if p != nil && !p.Closed() {
		s, _ = c.takeScreenshot(ctx, false, "")
	}
	return NavigateError{Error: err.Error(), URL: target, shot: shotOf(s)}, nil
}

func (c *Controller) viewport() Viewport {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.identity.Viewport
}

func (c *Controller) moveMouseTo(ctx context.Context, p *browserx.Page, x, y float64, fast bool) error {
	vp := c.viewport()
	target := Point{clamp(math.Round(x), 0, float64(vp.Width)), clamp(math.Round(y), 0, float64(vp.Height))}
	c.mu.Lock()
	from := c.mouse
	c.mu.Unlock()
	for _, pt := range HumanMousePath(from, target, vp) {
		if err := p.Mouse.Move(ctx, pt.X, pt.Y); err != nil {
			return err
		}
		if !fast {
			if err := c.pause(ctx, 2, 10); err != nil {
				return err
			}
		}
	}
	c.mu.Lock()
	c.mouse = target
	c.mu.Unlock()
	return nil
}

// pointIn picks a spot inside an element, as a person rarely clicks the exact centre.
func pointIn(box *browserx.Box) (Point, bool) {
	if box == nil || box.Width <= 0 || box.Height <= 0 {
		return Point{}, false
	}
	return Point{box.X + box.Width*float64(randInt(25, 75))/100, box.Y + box.Height*float64(randInt(30, 70))/100}, true
}

func (c *Controller) press(ctx context.Context, p *browserx.Page, beforeDown, held [2]int) error {
	if err := c.pause(ctx, beforeDown[0], beforeDown[1]); err != nil {
		return err
	}
	if err := p.Mouse.Down(ctx); err != nil {
		return err
	}
	if err := c.pause(ctx, held[0], held[1]); err != nil {
		return err
	}
	return p.Mouse.Up(ctx)
}

// ActionResult is a completed page action.
type ActionResult struct {
	Success bool   `json:"success"`
	URL     string `json:"url"`
	Title   string `json:"title"`
	shot
}

const clickableByText = `Array.from(document.querySelectorAll('a, button, [role="button"], input[type="submit"], [onclick]')).find((e) => String(e.innerText || e.value || e.getAttribute('aria-label') || '').toLowerCase().includes(args[0]))`

// Click clicks an element found by selector, or by its visible text.
func (c *Controller) Click(ctx context.Context, selector, text string, screenshot bool) (any, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	var box *browserx.Box
	var found bool
	switch {
	case text != "" && selector == "":
		var res struct {
			Found bool          `json:"found"`
			Box   *browserx.Box `json:"box"`
		}
		body := `const el = ` + clickableByText + `;
if (!el) return { found: false, box: null };
if (el.scrollIntoViewIfNeeded) el.scrollIntoViewIfNeeded(true);
const r = L.box(el);
return { found: true, box: r ? { X: r.x, Y: r.y, Width: r.width, Height: r.height } : null };`
		if err := p.EvalWithSelectors(ctx, body, &res, strings.ToLower(text)); err != nil {
			return failed(ctx, err)
		}
		if !res.Found {
			return ErrorResult{Error: "No clickable element found with text: " + text}, nil
		}
		box, found = res.Box, true
	case selector != "":
		if box, found, err = p.ScrollAndBox(ctx, selector); err != nil {
			return failed(ctx, err)
		}
		if !found {
			return ErrorResult{Error: "Element not found: " + selector}, nil
		}
	default:
		return ErrorResult{Error: "Either selector or text required"}, nil
	}
	point, ok := pointIn(box)
	if !ok {
		return ErrorResult{Error: "Element has no visible clickable area"}, nil
	}
	if err := c.moveMouseTo(ctx, p, point.X, point.Y, false); err != nil {
		return failed(ctx, err)
	}
	if err := c.press(ctx, p, [2]int{170, 320}, [2]int{80, 260}); err != nil {
		return failed(ctx, err)
	}
	if err := c.pause(ctx, 800, 1800); err != nil {
		return nil, err
	}
	return c.actionResult(ctx, p, screenshot)
}

func (c *Controller) actionResult(ctx context.Context, p *browserx.Page, screenshot bool) (any, error) {
	s, err := c.maybeShot(ctx, screenshot)
	if err != nil {
		return failed(ctx, err)
	}
	u, _ := p.URL(ctx)
	title, err := p.Title(ctx)
	if err != nil {
		return failed(ctx, err)
	}
	return ActionResult{Success: true, URL: u, Title: title, shot: s}, nil
}

// coordinate reads a required, finite click coordinate.
func coordinate(v any, label string) (float64, error) {
	switch t := v.(type) {
	case nil:
		return 0, fmt.Errorf("%s coordinate is required.", label)
	case string:
		if strings.TrimSpace(t) == "" {
			if t == "" {
				return 0, fmt.Errorf("%s coordinate is required.", label)
			}
			return 0, nil
		}
		f, err := strconv.ParseFloat(strings.TrimSpace(t), 64)
		if err != nil || math.IsInf(f, 0) {
			return 0, fmt.Errorf("%s coordinate must be a finite number.", label)
		}
		return math.Round(f), nil
	case float64:
		return math.Round(t), nil
	case bool:
		if t {
			return 1, nil
		}
		return 0, nil
	}
	return 0, fmt.Errorf("%s coordinate must be a finite number.", label)
}

// PointResult is a click at coordinates.
type PointResult struct {
	Success bool    `json:"success"`
	X       float64 `json:"x"`
	Y       float64 `json:"y"`
	URL     string  `json:"url"`
	Title   string  `json:"title"`
	shot
}

// ClickPoint clicks page coordinates.
func (c *Controller) ClickPoint(ctx context.Context, x, y any, screenshot bool) (any, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	px, err := coordinate(x, "x")
	if err != nil {
		return ErrorResult{Error: err.Error()}, nil
	}
	py, err := coordinate(y, "y")
	if err != nil {
		return ErrorResult{Error: err.Error()}, nil
	}
	px, py = math.Max(0, px), math.Max(0, py)
	if err := c.moveMouseTo(ctx, p, px, py, false); err != nil {
		return failed(ctx, err)
	}
	if err := c.press(ctx, p, [2]int{90, 220}, [2]int{70, 240}); err != nil {
		return failed(ctx, err)
	}
	if err := c.pause(ctx, 500, 1200); err != nil {
		return nil, err
	}
	s, err := c.maybeShot(ctx, screenshot)
	if err != nil {
		return failed(ctx, err)
	}
	u, _ := p.URL(ctx)
	title, err := p.Title(ctx)
	if err != nil {
		return failed(ctx, err)
	}
	return PointResult{Success: true, X: px, Y: py, URL: u, Title: title, shot: s}, nil
}

func number(v any) float64 {
	switch t := v.(type) {
	case float64:
		if math.IsNaN(t) || math.IsInf(t, 0) {
			return 0
		}
		return t
	case string:
		f, err := strconv.ParseFloat(strings.TrimSpace(t), 64)
		if err != nil || math.IsInf(f, 0) {
			return 0
		}
		return f
	case bool:
		if t {
			return 1
		}
	}
	return 0
}

// Scroll scrolls the page in a few wheel turns from near the pointer.
func (c *Controller) Scroll(ctx context.Context, deltaX, deltaY any, screenshot bool) (any, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	vp := c.viewport()
	c.mu.Lock()
	m := c.mouse
	c.mu.Unlock()
	x := clamp(m.X+float64(randInt(-80, 80)), 10, float64(vp.Width-10))
	y := clamp(m.Y+float64(randInt(-80, 80)), 10, float64(vp.Height-10))
	if err := c.moveMouseTo(ctx, p, x, y, false); err != nil {
		return failed(ctx, err)
	}
	totalX, totalY := math.Round(number(deltaX)), math.Round(number(deltaY))
	chunks := int(math.Max(1, math.Min(6, math.Ceil(math.Max(math.Abs(totalX), math.Abs(totalY))/450))))
	for i := 0; i < chunks; i++ {
		if err := p.Mouse.Wheel(ctx, math.Round(totalX/float64(chunks)), math.Round(totalY/float64(chunks))); err != nil {
			return failed(ctx, err)
		}
		if err := c.pause(ctx, 120, 360); err != nil {
			return nil, err
		}
	}
	return c.actionResult(ctx, p, screenshot)
}

// TypedResult is text that was typed.
type TypedResult struct {
	Success bool   `json:"success"`
	Typed   string `json:"typed"`
	shot
}

// FillOptions tune Fill.
type FillOptions struct {
	Clear, PressEnter, Screenshot bool
}

// Fill types into the element matching selector, key by key, after clearing it.
func (c *Controller) Fill(ctx context.Context, selector, value string, o FillOptions) (any, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	box, found, err := p.ScrollAndBox(ctx, selector)
	if err != nil {
		return failed(ctx, err)
	}
	if !found {
		return ErrorResult{Error: "Element not found: " + selector}, nil
	}
	if point, ok := pointIn(box); ok {
		if err := c.moveMouseTo(ctx, p, point.X, point.Y, false); err != nil {
			return failed(ctx, err)
		}
		if err := c.pause(ctx, 120, 260); err != nil {
			return nil, err
		}
	}
	if o.Clear {
		if err := p.Fill(ctx, selector, "", 30*time.Second); err != nil {
			return failed(ctx, err)
		}
	}
	if err := p.PressSequentially(ctx, selector, value, time.Duration(randInt(45, 140))*time.Millisecond, 30*time.Second); err != nil {
		return failed(ctx, err)
	}
	if o.PressEnter {
		if err := p.PressOn(ctx, selector, "Enter", 30*time.Second); err != nil {
			return failed(ctx, err)
		}
		if err := c.cfg.Sleep(ctx, time.Second); err != nil {
			return nil, err
		}
	}
	s, err := c.maybeShot(ctx, o.Screenshot)
	if err != nil {
		return failed(ctx, err)
	}
	return TypedResult{Success: true, Typed: value, shot: s}, nil
}

// TypeText types into whatever has focus.
func (c *Controller) TypeText(ctx context.Context, value string, pressEnter, screenshot bool) (any, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	if err := p.Keyboard.Type(ctx, value, time.Duration(randInt(45, 140))*time.Millisecond); err != nil {
		return failed(ctx, err)
	}
	if pressEnter {
		if err := p.Keyboard.Press(ctx, "Enter", 0); err != nil {
			return failed(ctx, err)
		}
		if err := c.cfg.Sleep(ctx, 800*time.Millisecond); err != nil {
			return nil, err
		}
	}
	s, err := c.maybeShot(ctx, screenshot)
	if err != nil {
		return failed(ctx, err)
	}
	return TypedResult{Success: true, Typed: value, shot: s}, nil
}

// KeyResult is a pressed key.
type KeyResult struct {
	Success bool   `json:"success"`
	Key     string `json:"key"`
	shot
}

// PressKey presses a key or combination such as Control+A.
func (c *Controller) PressKey(ctx context.Context, key string, screenshot bool) (any, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	key = strings.TrimSpace(key)
	if key == "" {
		return ErrorResult{Error: "key required"}, nil
	}
	if err := p.Keyboard.Press(ctx, key, 0); err != nil {
		return failed(ctx, err)
	}
	if err := c.pause(ctx, 250, 700); err != nil {
		return nil, err
	}
	s, err := c.maybeShot(ctx, screenshot)
	if err != nil {
		return failed(ctx, err)
	}
	return KeyResult{Success: true, Key: key, shot: s}, nil
}

// ExtractAllResult is text or attributes of up to 100 elements.
type ExtractAllResult struct {
	Results      []string     `json:"results"`
	BotDetection BotDetection `json:"botDetection"`
}

// ExtractResult is text or an attribute of one element.
type ExtractResult struct {
	Result       json.RawMessage `json:"result"`
	BotDetection BotDetection    `json:"botDetection"`
}

const extractValue = `const v = attr === 'innerHTML' ? el.innerHTML : attr === 'outerHTML' ? el.outerHTML : attr ? (el.getAttribute(attr) || '') : (el.innerText || '');`

// Extract reads text, HTML or an attribute of the first (or every) element
// matching selector; the whole body without one.
func (c *Controller) Extract(ctx context.Context, selector, attribute string, all bool) (any, error) {
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	if selector == "" {
		selector = "body"
	}
	html, _ := p.Content(ctx)
	detection := c.botDetection(ctx, p, html, "")
	if all {
		var results []string
		body := `const attr = args[1]; return L.queryAll(args[0]).slice(0, 100).map((el) => { ` + extractValue + ` return String(v).slice(0, 50000); });`
		if err := p.EvalWithSelectors(ctx, body, &results, selector, attribute); err != nil {
			return failed(ctx, err)
		}
		if results == nil {
			results = []string{}
		}
		return ExtractAllResult{Results: results, BotDetection: detection}, nil
	}
	var res struct {
		Missing bool            `json:"missing"`
		Value   json.RawMessage `json:"value"`
	}
	body := `const attr = args[1]; const el = L.queryAll(args[0])[0]; if (!el) return { missing: true }; ` + extractValue + ` return { value: typeof v === 'string' ? v.slice(0, 50000) : v };`
	if err := p.EvalWithSelectors(ctx, body, &res, selector, attribute); err != nil {
		return failed(ctx, err)
	}
	if res.Missing {
		return ErrorResult{Error: "page.$eval: Failed to find element matching selector \"" + selector + "\""}, nil
	}
	return ExtractResult{Result: res.Value, BotDetection: detection}, nil
}

// EvaluateResult is what a script returned, as text.
type EvaluateResult struct {
	Result    string `json:"result"`
	Truncated bool   `json:"truncated"`
}

const maxEvaluateChars = 1024 * 1024

// Evaluate runs JavaScript in the page and returns its value as text: objects
// as JSON, everything else as String(value).
func (c *Controller) Evaluate(ctx context.Context, script string) (any, error) {
	if script == "" {
		return ErrorResult{Error: "script required"}, nil
	}
	if utf16Len(script) > 10000 {
		return ErrorResult{Error: "script exceeds maximum length (10000)"}, nil
	}
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	expr := `(async () => { const v = await ` + isolatedExpression(script) + `;
if (typeof v === 'object' && v !== null) { try { const s = JSON.stringify(v); return s === undefined ? 'undefined' : s; } catch (e) { return String(v); } }
return String(v); })()`
	var out string
	if err := p.EvalJSON(ctx, expr, &out); err != nil {
		var ex *browserx.ExceptionError
		if errors.As(err, &ex) {
			return ErrorResult{Error: "page.evaluate: " + ex.Message}, nil
		}
		return failed(ctx, err)
	}
	truncated := utf16Len(out) > maxEvaluateChars
	if truncated {
		out = utf16Prefix(out, maxEvaluateChars)
	}
	return EvaluateResult{Result: out, Truncated: truncated}, nil
}

func utf16Len(s string) int {
	n := 0
	for _, r := range s {
		if r >= 0x10000 {
			n += 2
		} else {
			n++
		}
	}
	return n
}

// Launch makes sure the browser runs.
func (c *Controller) Launch(ctx context.Context) (any, error) {
	if err := c.ensureBrowser(ctx); err != nil {
		return nil, err
	}
	return struct {
		Success bool `json:"success"`
	}{true}, nil
}

// PageInfo is the active tab.
type PageInfo struct {
	URL                     *string `json:"url"`
	Title                   *string `json:"title"`
	ProtectedCredentialFill *bool   `json:"protectedCredentialFill,omitempty"`
}

// Status is what /browser/status reports.
type Status struct {
	Launched bool     `json:"launched"`
	Pages    int      `json:"pages"`
	Headless bool     `json:"headless"`
	PageInfo PageInfo `json:"pageInfo"`
}

// Status reports the browser without starting it.
func (c *Controller) Status(ctx context.Context) (Status, error) {
	st := Status{Launched: c.contextOpen()}
	c.mu.Lock()
	b, p := c.browser, c.page
	c.mu.Unlock()
	if st.Launched {
		if pages, err := b.Pages(ctx); err == nil {
			st.Pages = len(pages)
		}
	}
	if p == nil || p.Closed() {
		return st, nil
	}
	u, err := p.URL(ctx)
	if err != nil {
		return st, err
	}
	title, err := p.Title(ctx)
	if err != nil {
		return st, err
	}
	protected := c.HasProtectedFill()
	st.PageInfo = PageInfo{URL: &u, Title: &title, ProtectedCredentialFill: &protected}
	return st, nil
}

// HasProtectedFill reports an active protected credential fill; an expired
// one is cleared from the page.
func (c *Controller) HasProtectedFill() bool {
	c.mu.Lock()
	f := c.fill
	if f != nil && !f.expiresAt.After(time.Now()) && !f.clearing {
		f.clearing = true
		go func() {
			c.clearFill(context.Background(), f)
			c.mu.Lock()
			if c.fill == f {
				c.fill = nil
			}
			c.mu.Unlock()
		}()
	}
	active := c.fill != nil
	c.mu.Unlock()
	return active
}

func (c *Controller) clearFill(ctx context.Context, f *protectedFill) {
	if f.page == nil {
		return
	}
	// After a submit the form is usually gone; there is nothing to wait for.
	for _, sel := range []string{f.usernameSelector, f.passwordSelector} {
		if sel != "" {
			_ = f.page.Fill(ctx, sel, "", 2*time.Second)
		}
	}
}

func origin(raw string) (string, error) {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme == "" {
		return "", fmt.Errorf("Invalid URL: %s", raw)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "null", nil
	}
	host := strings.ToLower(u.Host)
	if (u.Scheme == "https" && u.Port() == "443") || (u.Scheme == "http" && u.Port() == "80") {
		host = strings.ToLower(u.Hostname())
	}
	return u.Scheme + "://" + host, nil
}

func newID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b)
	return h[:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:]
}

// CredentialInput is a login to fill without the model seeing it.
type CredentialInput struct {
	AllowedOrigin, UsernameSelector, PasswordSelector, Username, Password string
}

// FillCredential reloads the page, checks it is still the expected site and
// fills the login fields. Further browser control is blocked until the fill is
// submitted or cancelled.
func (c *Controller) FillCredential(ctx context.Context, in CredentialInput) (any, error) {
	if c.HasProtectedFill() {
		return nil, errors.New("A protected credential fill is already active.")
	}
	p, err := c.ensurePage(ctx)
	if err != nil {
		return nil, err
	}
	allowed, err := origin(in.AllowedOrigin)
	if err != nil {
		return nil, err
	}
	current := func() string { u, _ := p.URL(ctx); o, _ := origin(u); return o }
	if current() != allowed {
		return nil, errors.New("The browser origin changed before credential fill.")
	}
	if err := p.Reload(ctx, browserx.GotoOptions{WaitUntil: "domcontentloaded", Timeout: 30 * time.Second}); err != nil {
		return nil, err
	}
	if current() != allowed {
		return nil, errors.New("The browser origin changed while preparing credential fill.")
	}
	user, pass := strings.TrimSpace(in.UsernameSelector), strings.TrimSpace(in.PasswordSelector)
	if user == "" && pass == "" {
		return nil, errors.New("At least one credential field selector is required.")
	}
	for _, field := range [][2]string{{user, in.Username}, {pass, in.Password}} {
		if field[0] == "" {
			continue
		}
		if err := p.WaitForSelector(ctx, field[0], 10*time.Second); err != nil {
			return nil, err
		}
		if err := p.Fill(ctx, field[0], field[1], 30*time.Second); err != nil {
			return nil, err
		}
	}
	submit := pass
	if submit == "" {
		submit = user
	}
	id := newID()
	c.mu.Lock()
	c.fill = &protectedFill{id: id, page: p, allowedOrigin: allowed, usernameSelector: user, passwordSelector: pass, submitField: submit, expiresAt: time.Now().Add(5 * time.Minute)}
	c.mu.Unlock()
	return struct {
		Success         bool   `json:"success"`
		ProtectedFillID string `json:"protectedFillId"`
		Origin          string `json:"origin"`
	}{true, id, allowed}, nil
}

// SubmitProtectedCredential submits the filled form and clears the fields.
func (c *Controller) SubmitProtectedCredential(ctx context.Context, id string) (any, error) {
	c.mu.Lock()
	f := c.fill
	c.mu.Unlock()
	if !c.HasProtectedFill() || f == nil || f.id != id {
		return nil, errors.New("Protected credential fill is missing or expired.")
	}
	p := f.page
	u, _ := p.URL(ctx)
	if o, _ := origin(u); p.Closed() || o != f.allowedOrigin {
		c.mu.Lock()
		c.fill = nil
		c.mu.Unlock()
		return nil, errors.New("The protected credential page changed before submission.")
	}
	defer func() {
		c.clearFill(ctx, f)
		c.mu.Lock()
		c.fill = nil
		c.mu.Unlock()
	}()
	body := `const input = L.queryAll(args[0])[0]; if (!input) throw new Error('No element matches ' + args[0]);
const form = input.form;
if (form && typeof form.requestSubmit === 'function') form.requestSubmit();
else input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
return true;`
	var before float64
	_ = p.EvalJSON(ctx, `performance.timeOrigin`, &before)
	var ok bool
	if err := p.EvalWithSelectors(ctx, body, &ok, f.submitField); err != nil {
		return nil, err
	}
	// A submit that navigates replaces the document; give it a moment to
	// start before waiting for it, so the result describes the new page.
	for deadline := time.Now().Add(2 * time.Second); time.Now().Before(deadline); {
		var now float64
		if p.EvalJSON(ctx, `performance.timeOrigin`, &now) == nil && now != before {
			break
		}
		if sleepCtx(ctx, 50*time.Millisecond) != nil {
			break
		}
	}
	_ = p.WaitForLoadState(ctx, "domcontentloaded", 10*time.Second)
	after, _ := p.URL(ctx)
	title, _ := p.Title(ctx)
	return struct {
		Success   bool   `json:"success"`
		URL       string `json:"url"`
		Title     string `json:"title"`
		Protected bool   `json:"protected"`
	}{true, after, title, false}, nil
}

// CancelProtectedCredential clears the filled fields.
func (c *Controller) CancelProtectedCredential(ctx context.Context, id string) (any, error) {
	c.mu.Lock()
	f := c.fill
	c.mu.Unlock()
	if f == nil || f.id != id {
		return nil, errors.New("Protected credential fill is missing or expired.")
	}
	c.clearFill(ctx, f)
	c.mu.Lock()
	c.fill = nil
	c.mu.Unlock()
	return struct {
		Success   bool `json:"success"`
		Protected bool `json:"protected"`
	}{true, false}, nil
}

// Close detaches from Chromium; the desktop browser and its tabs keep running.
func (c *Controller) Close() {
	c.launchMu.Lock()
	defer c.launchMu.Unlock()
	c.mu.Lock()
	c.fill = nil
	c.mu.Unlock()
	c.disconnect()
}

// Shutdown detaches and stops a virtual display the controller started.
func (c *Controller) Shutdown() {
	c.Close()
	c.mu.Lock()
	x := c.xvfb
	c.xvfb = nil
	c.mu.Unlock()
	if x != nil && x.Process != nil {
		_ = x.Process.Kill()
	}
}
