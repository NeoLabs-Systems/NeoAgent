// Package browser is the guest's browser: Chromium on the computer's desktop,
// driven over DevTools for the agent's browser tools, with human-like input
// and a stable per-profile browser identity.
package browser

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"math"
	"math/rand/v2"
	"strings"
)

type userAgent struct{ ua, platform, webglVendor, webglRenderer string }

var userAgents = []userAgent{
	{"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36", "Win32", "Google Inc. (NVIDIA)", "ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)"},
	{"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", "Win32", "Google Inc. (Intel)", "ANGLE (Intel, Intel(R) UHD Graphics 770 Direct3D11 vs_5_0 ps_5_0, D3D11)"},
	{"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36", "MacIntel", "Google Inc. (Apple)", "ANGLE (Apple, Apple M2, OpenGL 4.1)"},
	{"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", "MacIntel", "Google Inc. (Apple)", "ANGLE (Apple, Apple M1, OpenGL 4.1)"},
	{"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36", "Linux x86_64", "Google Inc. (Intel)", "ANGLE (Intel, Mesa Intel(R) UHD Graphics 620, OpenGL 4.6)"},
}

type weightedViewport struct{ width, height, weight int }

var viewports = []weightedViewport{
	{1920, 1080, 35}, {1366, 768, 26}, {1536, 864, 16}, {1280, 720, 9}, {1440, 900, 9}, {1600, 900, 5},
}

// Viewport is a page size.
type Viewport struct {
	Width  int `json:"width"`
	Height int `json:"height"`
}

// Identity is the browser a profile presents to sites. It is derived from the
// profile key, so a profile keeps looking like the same machine.
type Identity struct {
	UserAgent           string   `json:"userAgent"`
	Platform            string   `json:"platform"`
	Viewport            Viewport `json:"viewport"`
	WebGLVendor         string   `json:"webglVendor"`
	WebGLRenderer       string   `json:"webglRenderer"`
	HardwareConcurrency int      `json:"hardwareConcurrency"`
	DeviceMemory        int      `json:"deviceMemory"`
}

// ChooseIdentity picks the identity of a profile.
func ChooseIdentity(profileKey string) Identity {
	if profileKey == "" {
		profileKey = "default"
	}
	sum := sha256.Sum256([]byte(profileKey))
	seed := binary.BigEndian.Uint32(sum[:4])
	profile := userAgents[seed%uint32(len(userAgents))]
	total := 0
	for _, v := range viewports {
		total += v.weight
	}
	cursor := int((seed >> 3) % uint32(total))
	chosen := viewports[0]
	for _, v := range viewports {
		cursor -= v.weight
		if cursor < 0 {
			chosen = v
			break
		}
	}
	return Identity{
		UserAgent: profile.ua, Platform: profile.platform,
		Viewport:    Viewport{chosen.width, chosen.height},
		WebGLVendor: profile.webglVendor, WebGLRenderer: profile.webglRenderer,
		HardwareConcurrency: []int{4, 6, 8, 12, 16}[seed%5],
		DeviceMemory:        []int{4, 8, 16}[(seed>>5)%3],
	}
}

// NormalizeReferrerMode is direct, google or current.
func NormalizeReferrerMode(value string) string {
	switch v := strings.ToLower(strings.TrimSpace(value)); v {
	case "direct", "google", "current":
		return v
	}
	return "direct"
}

// NormalizeWaitUntil maps Puppeteer and Playwright load states to Playwright's.
func NormalizeWaitUntil(value string) string {
	switch v := strings.ToLower(strings.TrimSpace(value)); v {
	case "networkidle0", "networkidle2":
		return "networkidle"
	case "load", "domcontentloaded", "networkidle", "commit":
		return v
	}
	return "domcontentloaded"
}

// BotDetection says whether a page is a bot challenge, and whose.
type BotDetection struct {
	Detected bool    `json:"detected"`
	Provider *string `json:"provider"`
}

func provider(name string) BotDetection { return BotDetection{Detected: true, Provider: &name} }

// ChallengeInput is what a page shows.
type ChallengeInput struct {
	Title, URL, HTML, Text string
}

func utf16Prefix(s string, n int) string {
	count := 0
	for i, r := range s {
		w := 1
		if r >= 0x10000 {
			w = 2
		}
		if count+w > n {
			return s[:i]
		}
		count += w
	}
	return s
}

// DetectBotChallenge recognises Cloudflare, PerimeterX, DataDome and generic
// "are you human" pages.
func DetectBotChallenge(in ChallengeInput) BotDetection {
	title := strings.TrimSpace(in.Title)
	haystack := strings.ToLower(title + "\n" + strings.TrimSpace(in.URL) + "\n" + utf16Prefix(in.HTML, 200000) + "\n" + utf16Prefix(in.Text, 50000))
	has := func(s string) bool { return strings.Contains(haystack, s) }
	switch {
	case title == "Just a moment..." || has("cf-turnstile-response") || has("/cdn-cgi/challenge-platform/"):
		return provider("cloudflare")
	case has("please verify you are a human") || has("press & hold to confirm"):
		return provider("perimeterx")
	case has("datadome") || has("geo.captcha-delivery.com"):
		return provider("datadome")
	case has("unusual traffic") || has("are you a robot") || has("verify that you are human") || has("complete the security check"):
		return provider("generic")
	}
	return BotDetection{}
}

// randInt is an integer in [min, max].
func randInt(lo, hi int) int { return lo + rand.IntN(hi-lo+1) }

// Point is a screen position.
type Point struct{ X, Y float64 }

func bezier(points []Point, t float64) Point {
	current := append([]Point(nil), points...)
	for len(current) > 1 {
		next := make([]Point, len(current)-1)
		for i := range next {
			next[i] = Point{current[i].X + (current[i+1].X-current[i].X)*t, current[i].Y + (current[i+1].Y-current[i].Y)*t}
		}
		current = next
	}
	return current[0]
}

func clamp(v, lo, hi float64) float64 { return math.Max(lo, math.Min(hi, v)) }

// HumanMousePath is a curved, eased path from one point to another with a
// little jitter, as a hand would move the mouse.
func HumanMousePath(from, to Point, viewport Viewport) []Point {
	distance := math.Hypot(to.X-from.X, to.Y-from.Y)
	if distance < 2 {
		return []Point{from, to}
	}
	width := math.Max(1, float64(viewport.Width))
	height := math.Max(1, float64(viewport.Height))
	if viewport.Width == 0 {
		width = 1440
	}
	if viewport.Height == 0 {
		height = 900
	}
	steps := int(math.Max(12, math.Min(90, math.Round(18+distance/18+float64(randInt(-5, 8))))))
	boundary := math.Min(90, math.Max(10, distance*0.12))
	controlCount := randInt(1, 3)
	curve := []Point{from}
	for i := 1; i <= controlCount; i++ {
		ratio := float64(i) / float64(controlCount+1)
		jx := float64(randInt(int(-boundary), int(boundary)))
		jy := float64(randInt(int(-boundary), int(boundary)))
		curve = append(curve, Point{
			clamp(from.X+(to.X-from.X)*ratio+jx, 0, width),
			clamp(from.Y+(to.Y-from.Y)*ratio+jy, 0, height),
		})
	}
	curve = append(curve, to)
	tweens := []func(float64) float64{
		func(t float64) float64 {
			if t < 0.5 {
				return 2 * t * t
			}
			return 1 - math.Pow(-2*t+2, 2)/2
		},
		func(t float64) float64 { return 1 - (1-t)*(1-t) },
		func(t float64) float64 { return -(math.Cos(math.Pi*t) - 1) / 2 },
	}
	tween := tweens[randInt(0, len(tweens)-1)]
	path := make([]Point, steps)
	for i := range path {
		p := bezier(curve, tween(float64(i)/float64(steps-1)))
		jitter := 0.0
		if i > 0 && i < steps-1 {
			jitter = float64(randInt(-1, 1))
		}
		path[i] = Point{math.Round(clamp(p.X, 0, width)), math.Round(clamp(p.Y+jitter, 0, height))}
	}
	path[0] = Point{math.Round(from.X), math.Round(from.Y)}
	path[steps-1] = Point{math.Round(to.X), math.Round(to.Y)}
	return path
}

// isolatedExpression evaluates a snippet in a fresh function scope, so
// top-level const/let bindings of one call do not leak into the next.
func isolatedExpression(script string) string {
	if script == "" {
		script = "undefined"
	}
	return "(() => eval(" + jsonString(script) + "))()"
}

// jsonString is JSON.stringify for a string: only quotes, backslashes and
// control characters are escaped.
func jsonString(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range s {
		switch {
		case r == '"':
			b.WriteString(`\"`)
		case r == '\\':
			b.WriteString(`\\`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\r':
			b.WriteString(`\r`)
		case r == '\t':
			b.WriteString(`\t`)
		case r == '\b':
			b.WriteString(`\b`)
		case r == '\f':
			b.WriteString(`\f`)
		case r < 0x20:
			fmt.Fprintf(&b, `\u%04x`, r)
		default:
			b.WriteRune(r)
		}
	}
	b.WriteByte('"')
	return b.String()
}
