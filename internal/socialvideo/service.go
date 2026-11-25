// Package socialvideo reads YouTube, TikTok, Instagram and X video links: the
// page's title and description, a transcript (captions first, speech to text
// otherwise) and a still frame, using yt-dlp and ffmpeg on the server.
package socialvideo

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

const (
	healthCacheTTL   = 5 * time.Minute
	maxPageHTMLBytes = 2 * 1024 * 1024
	maxThumbnailSize = 10 * 1024 * 1024
	browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

// networkFlags harden every yt-dlp run against transient failures.
var networkFlags = []string{
	"--retries", "5", "--fragment-retries", "5", "--extractor-retries", "3",
	"--socket-timeout", "30", "--user-agent", browserUserAgent,
}

// Cookie is a browser cookie exported from the user's cloud computer.
type Cookie struct {
	Name, Value, Domain, Path string
	Secure, HTTPOnly          bool
	Expires                   float64
}

// NavResult is what the cloud browser reports after opening a page.
type NavResult struct{ Title, URL, Error string }

// Browser is the user's cloud computer browser.
type Browser interface {
	GetCookies(ctx context.Context) ([]Cookie, error)
	Navigate(ctx context.Context, pageURL string) (NavResult, error)
	Extract(ctx context.Context, selector, attribute string) (string, error)
}

// BrowserSource finds the running browser of an account.
type BrowserSource interface {
	BrowserForUser(ctx context.Context, userID int64) (Browser, error)
}

// Transcriber turns an audio file into text with the account's STT provider.
type Transcriber interface {
	Transcribe(ctx context.Context, audioPath string, userID int64, agentID, mimeType string) (string, error)
}

// ArtifactSpec describes a file to store.
type ArtifactSpec struct {
	Kind, Extension, ContentType, FilenameBase string
	Metadata                                   map[string]any
}

// Allocation is where a new artifact's bytes go.
type Allocation struct {
	ArtifactID  string
	StoragePath string
}

// Finalized is a stored artifact.
type Finalized struct {
	ArtifactID string
	URL        string
	ByteSize   int64
}

// ArtifactStore keeps the stills the extractor produces.
type ArtifactStore interface {
	AllocateFile(ctx context.Context, userID int64, spec ArtifactSpec) (Allocation, error)
	FinalizeFile(ctx context.Context, artifactID, storagePath string) (Finalized, error)
}

// Config wires the extractor. Browser, Transcriber and Artifacts are optional.
type Config struct {
	Browser     BrowserSource
	Transcriber Transcriber
	Artifacts   ArtifactStore
	// HTTP fetches public pages and thumbnails. The default refuses internal
	// addresses; tests may pass their own.
	HTTP *http.Client
	// TempDir holds per-request working folders (default: the OS temp dir).
	TempDir string
	// YtDlp and Ffmpeg name the binaries (defaults: YT_DLP_BIN / FFMPEG_BIN, then
	// yt-dlp / ffmpeg).
	YtDlp, Ffmpeg string
}

// Service extracts video details.
type Service struct {
	cfg    Config
	client *http.Client
	mu     sync.Mutex
	health *Health
	at     time.Time
}

// New builds the service.
func New(cfg Config) *Service {
	if cfg.YtDlp = jsTrim(firstNonEmpty(cfg.YtDlp, os.Getenv("YT_DLP_BIN"))); cfg.YtDlp == "" {
		cfg.YtDlp = "yt-dlp"
	}
	if cfg.Ffmpeg = jsTrim(firstNonEmpty(cfg.Ffmpeg, os.Getenv("FFMPEG_BIN"))); cfg.Ffmpeg == "" {
		cfg.Ffmpeg = "ffmpeg"
	}
	client := cfg.HTTP
	if client == nil {
		client = ssrf.NewClient(ssrf.Options{Timeout: 30 * time.Second})
	}
	return &Service{cfg: cfg, client: client}
}

// Dependency is one tool the extractor needs.
type Dependency struct {
	Name        string  `json:"name"`
	Available   bool    `json:"available"`
	Version     *string `json:"version"`
	InstallHint *string `json:"installHint"`
	Error       *string `json:"error"`
	Required    bool    `json:"required"`
}

// Health reports whether the tools are installed.
type Health struct {
	Ready        bool         `json:"ready"`
	Dependencies []Dependency `json:"dependencies"`
	SpeechToText struct {
		Note string `json:"note"`
	} `json:"speechToText"`
	CheckedAt string `json:"checkedAt"`
}

func installHint(binary string) string {
	name := strings.ToLower(jsTrim(binary))
	ytdlp := name == "yt-dlp" || name == "yt_dlp"
	switch runtime.GOOS {
	case "darwin":
		if name == "ffmpeg" {
			return "Install with: brew install ffmpeg"
		}
		if ytdlp {
			return "Install with: brew install yt-dlp"
		}
	case "linux":
		if name == "ffmpeg" {
			return "Install with your package manager, for example: sudo apt-get install -y ffmpeg"
		}
		if ytdlp {
			return "Install with your package manager or pipx, for example: pipx install yt-dlp"
		}
	case "windows":
		if name == "ffmpeg" {
			return "Install ffmpeg and ensure ffmpeg.exe is on PATH."
		}
		if ytdlp {
			return "Install yt-dlp and ensure yt-dlp.exe is on PATH."
		}
	}
	return "Install " + binary + " and ensure it is available on PATH."
}

// workerEnv is the environment the tools run in: enough to find binaries and
// proxies, none of the server's secrets.
func workerEnv() []string {
	var env []string
	for _, key := range []string{"PATH", "HOME", "LANG", "LC_ALL", "TMPDIR", "SYSTEMROOT", "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy"} {
		if v, ok := os.LookupEnv(key); ok {
			env = append(env, key+"="+v)
		}
	}
	return env
}

type commandResult struct {
	stdout, stderr string
	exitCode       int
}

// run starts a program with an argument vector (never a shell).
func run(ctx context.Context, dir string, timeout time.Duration, name string, args ...string) (commandResult, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = dir
	cmd.Env = workerEnv()
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	err := cmd.Run()
	res := commandResult{stdout: stdout.String(), stderr: stderr.String()}
	var exit *exec.ExitError
	switch {
	case err == nil:
	case errors.As(err, &exit):
		res.exitCode = exit.ExitCode()
	default:
		return res, err
	}
	return res, nil
}

func (s *Service) probe(ctx context.Context, binary, flag string) Dependency {
	dep := Dependency{Name: binary, Required: false}
	hint := installHint(binary)
	fail := func(msg string) Dependency {
		dep.InstallHint, dep.Error = &hint, &msg
		return dep
	}
	if binary == "" {
		return fail("Binary name is empty.")
	}
	res, err := run(ctx, "", 8*time.Second, binary, flag)
	switch {
	case err != nil:
		return fail(err.Error())
	case res.exitCode != 0:
		return fail(firstNonEmpty(res.stderr, res.stdout, fmt.Sprintf("Exit code %d", res.exitCode)))
	}
	first := strings.SplitN(jsTrim(firstNonEmpty(res.stdout, res.stderr)), "\n", 2)[0]
	first = strings.TrimSuffix(first, "\r")
	dep.Available = true
	if first != "" {
		dep.Version = &first
	}
	return dep
}

// HealthStatus checks yt-dlp and ffmpeg, caching the answer for five minutes.
func (s *Service) HealthStatus(ctx context.Context, forceRefresh bool) (Health, error) {
	if err := ctx.Err(); err != nil {
		return Health{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if !forceRefresh && s.health != nil && time.Since(s.at) < healthCacheTTL {
		return *s.health, nil
	}
	ytdlp, ffmpeg := s.probe(ctx, s.cfg.YtDlp, "--version"), s.probe(ctx, s.cfg.Ffmpeg, "-version")
	if err := ctx.Err(); err != nil {
		return Health{}, err
	}
	ytdlp.Required, ffmpeg.Required = true, false
	h := &Health{Ready: ytdlp.Available, Dependencies: []Dependency{ytdlp, ffmpeg}}
	h.SpeechToText.Note = "Captions are downloaded directly with yt-dlp without social platform API keys. If captions are unavailable, the configured voice STT provider transcribes the media."
	h.CheckedAt = time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	s.health, s.at = h, time.Now()
	return *h, nil
}

// Options are the per-request switches of Extract.
type Options struct {
	IncludeFrame bool
	ForceSTT     bool
	AgentID      string
}

func classifyError(err error) ResultError {
	message := jsTrim(err.Error())
	n := strings.ToLower(message)
	has := func(pattern string) bool { return matchLower(pattern, n) }
	switch {
	case has(`unsupported social video url|unsupported url`):
		return ResultError{"unsupported_url", message}
	case has(`private|login required|sign in to confirm|requested content is not available|account is private`):
		return ResultError{"private_or_auth_required", message}
	case has(`\b429\b|rate.?limit|too many requests`):
		return ResultError{"rate_limited", message}
	case has(`\b403\b|forbidden|blocked|not a bot`):
		return ResultError{"blocked_or_unavailable", message}
	case has(`timed out|timeout|etimedout|socket hang up|network is unreachable`):
		return ResultError{"network_error", message}
	case has(`this video is unavailable|video unavailable|removed|404|not found`):
		return ResultError{"content_unavailable", message}
	}
	return ResultError{"social_video_extract_failed", message}
}

type mediaInfo struct {
	ID                string          `json:"id"`
	Title             string          `json:"title"`
	Description       string          `json:"description"`
	WebpageURL        string          `json:"webpage_url"`
	Duration          float64         `json:"-"`
	RawDuration       json.RawMessage `json:"duration"`
	Subtitles         json.RawMessage `json:"subtitles"`
	AutomaticCaptions json.RawMessage `json:"automatic_captions"`
	Thumbnails        []thumbnail     `json:"thumbnails"`
}

type thumbnail struct {
	URL    string        `json:"url"`
	Width  lenientNumber `json:"width"`
	Height lenientNumber `json:"height"`
}

// lenientNumber reads a JSON number, or anything else as 0, like Number(x) || 0.
type lenientNumber float64

func (n *lenientNumber) UnmarshalJSON(raw []byte) error {
	v, err := strconv.ParseFloat(strings.Trim(string(raw), `"`), 64)
	if err != nil {
		v = 0
	}
	*n = lenientNumber(v)
	return nil
}

// job is the state of one extraction.
type job struct {
	userID   int64
	agentID  string
	dir      string
	cookies  string
	warnings *[]string
}

func (j *job) warn(format string, args ...any) {
	*j.warnings = append(*j.warnings, fmt.Sprintf(format, args...))
}

// Extract reads a video link. A failure that is about the video, not the
// request, comes back inside the Result; only a cancelled context is an error.
func (s *Service) Extract(ctx context.Context, userID int64, sourceURL string, opts Options) (Result, error) {
	var warnings []string
	source := jsTrim(sourceURL)
	res, err := s.extract(ctx, userID, source, opts, &warnings)
	if ctx.Err() != nil {
		return Result{}, ctx.Err()
	}
	if err == nil {
		return res, nil
	}
	health, herr := s.HealthStatus(ctx, false)
	var setup *Health
	if herr == nil {
		setup = &health
	}
	return shape(Result{
		SourceURL: source, ResolvedURL: source, Platform: "unknown", Setup: setup,
		Warnings: warnings, Errors: []ResultError{classifyError(err)},
	}), nil
}

func (s *Service) extract(ctx context.Context, userID int64, source string, opts Options, warnings *[]string) (Result, error) {
	health, err := s.HealthStatus(ctx, false)
	if err != nil {
		return Result{}, err
	}
	if !health.Ready {
		var missing []string
		for _, d := range health.Dependencies {
			if d.Required && !d.Available {
				missing = append(missing, d.Name)
			}
		}
		return Result{}, fmt.Errorf("Missing required dependency: %s", strings.Join(missing, ", "))
	}
	detected, err := NormalizeAndDetect(source)
	if err != nil {
		return Result{}, err
	}
	j := &job{userID: userID, agentID: opts.AgentID, warnings: warnings}
	page, err := s.pageMetadata(ctx, userID, detected.NormalizedURL)
	if ctx.Err() != nil {
		return Result{}, ctx.Err()
	}
	if err != nil {
		j.warn("Public page metadata was unavailable: %s", err)
		page = pageInfo{}
	}
	j.dir, err = os.MkdirTemp(s.cfg.TempDir, detected.Platform+"-")
	if err != nil {
		return Result{}, err
	}
	defer os.RemoveAll(j.dir)
	j.cookies = s.cookieFile(ctx, j, detected.Platform)

	info, err := s.readMediaInfo(ctx, j, detected.NormalizedURL)
	if err != nil {
		return Result{}, err
	}
	prefs := captionLanguages(detected.Platform)
	track := PickCaptionTrack(decodeCaptionGroups(info.Subtitles), prefs)
	if track == nil {
		track = PickCaptionTrack(decodeCaptionGroups(info.AutomaticCaptions), prefs)
	}
	decision := decideTranscriptPath(opts.ForceSTT, track)
	text, textSource := s.transcript(ctx, j, detected.NormalizedURL, track, prefs, decision)

	var frame *FrameImage
	if opts.IncludeFrame {
		if frame, err = s.frameImage(ctx, j, detected.NormalizedURL, info); err != nil {
			return Result{}, err
		}
	}
	if ctx.Err() != nil {
		return Result{}, ctx.Err()
	}
	canonical := firstNonEmpty(page.CanonicalURL, info.WebpageURL, detected.NormalizedURL)
	meta := Metadata{Provider: "yt-dlp"}
	if info.Duration > 0 {
		meta.DurationSeconds = &info.Duration
	}
	if info.ID != "" {
		meta.VideoID = &info.ID
	}
	return shape(Result{
		SourceURL:        source,
		ResolvedURL:      firstNonEmpty(page.ResolvedURL, info.WebpageURL, detected.NormalizedURL),
		CanonicalURL:     &canonical,
		Platform:         detected.Platform,
		Title:            firstNonEmpty(page.Title, info.Title),
		Description:      firstNonEmpty(page.Description, info.Description),
		Transcript:       text,
		TranscriptSource: textSource,
		FrameImage:       frame,
		Metadata:         meta,
		Setup:            &health,
		Warnings:         *warnings,
	}), nil
}

type pageInfo struct{ Title, Description, CanonicalURL, ResolvedURL string }

// pageMetadata asks the cloud browser first, then reads the public page.
func (s *Service) pageMetadata(ctx context.Context, userID int64, pageURL string) (pageInfo, error) {
	if info, err := s.browserMetadata(ctx, userID, pageURL); err == nil {
		return info, nil
	} else if ctx.Err() != nil {
		return pageInfo{}, ctx.Err()
	}
	body, final, _, err := s.fetch(ctx, pageURL, "text/html,*/*", maxPageHTMLBytes, nil)
	if err != nil {
		return pageInfo{}, err
	}
	meta := extractPublicMetadata(string(body), final)
	return pageInfo{meta.Title, meta.Description, meta.CanonicalURL, final}, nil
}

func (s *Service) browserMetadata(ctx context.Context, userID int64, pageURL string) (pageInfo, error) {
	if s.cfg.Browser == nil {
		return pageInfo{}, errors.New("Runtime browser provider is unavailable.")
	}
	browser, err := s.cfg.Browser.BrowserForUser(ctx, userID)
	if err != nil || browser == nil {
		return pageInfo{}, errors.New("Runtime browser provider is unavailable.")
	}
	nav, err := browser.Navigate(ctx, pageURL)
	if err != nil {
		return pageInfo{}, err
	}
	if nav.Error != "" {
		return pageInfo{}, errors.New(nav.Error)
	}
	get := func(selector, attr string) string {
		v, _ := browser.Extract(ctx, selector, attr)
		return v
	}
	canonical, description := get(`link[rel="canonical"]`, "href"), get(`meta[name="description"]`, "content")
	ogDescription, ogTitle := get(`meta[property="og:description"]`, "content"), get(`meta[property="og:title"]`, "content")
	return pageInfo{
		Title:        jsTrim(firstNonEmpty(ogTitle, nav.Title)),
		Description:  jsTrim(firstNonEmpty(description, ogDescription)),
		CanonicalURL: jsTrim(firstNonEmpty(canonical, nav.URL, pageURL)),
		ResolvedURL:  jsTrim(firstNonEmpty(nav.URL, pageURL)),
	}, nil
}

// fetch downloads a public resource through the SSRF-safe client.
func (s *Service) fetch(ctx context.Context, rawURL, accept string, limit int64, headers map[string]string) (body []byte, finalURL string, header http.Header, err error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, "", nil, err
	}
	req.Header.Set("User-Agent", browserUserAgent)
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("Accept", accept)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, "", nil, err
	}
	defer resp.Body.Close()
	body, err = io.ReadAll(io.LimitReader(resp.Body, limit+1))
	switch {
	case err != nil:
		return nil, "", nil, err
	case int64(len(body)) > limit:
		return nil, "", nil, errors.New("Social video response exceeded its safety limit.")
	case resp.StatusCode < 200 || resp.StatusCode >= 300:
		return nil, "", nil, fmt.Errorf("Social video request failed (%d).", resp.StatusCode)
	}
	return body, resp.Request.URL.String(), resp.Header, nil
}

func netscapeJar(cookies []Cookie) string {
	lines := []string{"# Netscape HTTP Cookie File"}
	clean := strings.NewReplacer("\r", " ", "\n", " ", "\t", " ")
	for _, c := range cookies {
		domain, name := jsTrim(c.Domain), jsTrim(c.Name)
		if domain == "" || name == "" {
			continue
		}
		include, secure, expires, prefix := "FALSE", "FALSE", "0", ""
		if strings.HasPrefix(domain, ".") {
			include = "TRUE"
		}
		if c.Secure {
			secure = "TRUE"
		}
		if c.Expires > 0 {
			expires = strconv.FormatInt(int64(c.Expires), 10)
		}
		if c.HTTPOnly {
			prefix = "#HttpOnly_"
		}
		path := firstNonEmpty(jsTrim(c.Path), "/")
		lines = append(lines, strings.Join([]string{prefix + domain, include, path, secure, expires, name, clean.Replace(c.Value)}, "\t"))
	}
	return strings.Join(lines, "\n") + "\n"
}

// cookieFile writes the browser's cookies for yt-dlp; no file means yt-dlp
// tries without a session.
func (s *Service) cookieFile(ctx context.Context, j *job, platform string) string {
	if s.cfg.Browser == nil {
		return ""
	}
	browser, err := s.cfg.Browser.BrowserForUser(ctx, j.userID)
	if err != nil || browser == nil {
		return ""
	}
	cookies, err := browser.GetCookies(ctx)
	if err != nil {
		j.warn("Browser cookie export failed: %s", err)
		return ""
	}
	if len(cookies) == 0 {
		j.warn("Browser cookie export returned no cookies for %s.", platform)
		return ""
	}
	path := filepath.Join(j.dir, "browser.cookies.txt")
	if err := os.WriteFile(path, []byte(netscapeJar(cookies)), 0o600); err != nil {
		return ""
	}
	return path
}

// ytdlp runs yt-dlp with the shared flags, the cookie file and the extra args.
func (s *Service) ytdlp(ctx context.Context, j *job, timeout time.Duration, args ...string) error {
	full := append([]string{"--quiet", "--no-warnings", "--no-playlist"}, networkFlags...)
	if j.cookies != "" {
		full = append(full, "--cookies", j.cookies)
	}
	return s.command(ctx, j.dir, timeout, s.cfg.YtDlp, append(full, args...)...)
}

func (s *Service) command(ctx context.Context, dir string, timeout time.Duration, name string, args ...string) error {
	res, err := run(ctx, dir, timeout, name, args...)
	if err != nil {
		return err
	}
	if res.exitCode != 0 {
		return errors.New(firstNonEmpty(res.stderr, res.stdout, "Command failed: "+name))
	}
	return nil
}

func (s *Service) readMediaInfo(ctx context.Context, j *job, pageURL string) (mediaInfo, error) {
	template := filepath.Join(j.dir, "media.%(ext)s")
	if err := s.ytdlp(ctx, j, 4*time.Minute, "--skip-download", "--write-info-json", "--no-clean-infojson", "-o", template, "--", pageURL); err != nil {
		return mediaInfo{}, err
	}
	raw, err := os.ReadFile(filepath.Join(j.dir, "media.info.json"))
	if err != nil {
		return mediaInfo{}, errors.New("yt-dlp did not produce an info JSON artifact.")
	}
	var info mediaInfo
	if err := json.Unmarshal(bytes.TrimSpace(raw), &info); err != nil {
		return mediaInfo{}, fmt.Errorf("Failed to parse media metadata JSON: %s", err)
	}
	info.Duration, _ = strconv.ParseFloat(string(info.RawDuration), 64)
	return info, nil
}

func (s *Service) transcript(ctx context.Context, j *job, pageURL string, track *CaptionTrack, prefs []string, d TranscriptDecision) (string, string) {
	if !(d.Mode == "stt" && d.Reason == "forced") {
		text, err := s.captionTranscript(ctx, j, pageURL, track, prefs)
		if err != nil && ctx.Err() == nil {
			j.warn("Caption transcript failed: %s", err)
		}
		if text != "" {
			return text, "captions"
		}
		if d.Mode == "captions" {
			j.warn("Caption extraction did not yield usable text. Falling back to speech-to-text.")
		}
	}
	text, err := s.sttTranscript(ctx, j, pageURL)
	if err != nil && ctx.Err() == nil {
		j.warn("Speech-to-text fallback failed: %s", err)
	}
	if text == "" {
		return "", "unavailable"
	}
	return text, "stt"
}

func (s *Service) captionTranscript(ctx context.Context, j *job, pageURL string, track *CaptionTrack, prefs []string) (string, error) {
	if track != nil {
		body, _, _, err := s.fetch(ctx, track.URL, "text/vtt,text/plain,application/json,application/xml,*/*", MaxVTTBytes, map[string]string{"Referer": pageURL})
		if err == nil {
			if text, perr := ParseCaptionText(string(body), track.Ext); perr == nil && text != "" {
				return text, nil
			}
		} else if ctx.Err() != nil {
			return "", ctx.Err()
		} else {
			j.warn("Direct caption fetch failed: %s", err)
		}
	}
	hints := "en.*,en"
	if len(prefs) > 0 {
		hints = strings.Join(prefs, ",")
	}
	err := s.ytdlp(ctx, j, 4*time.Minute, "--skip-download", "--write-subs", "--write-auto-subs",
		"--sub-langs", hints+",all,-live_chat", "--sub-format", "vtt/srt/ttml/json3/best",
		"-o", filepath.Join(j.dir, "captions"), "--", pageURL)
	if err != nil {
		return "", err
	}
	file, ok := downloadedCaption(j.dir, prefs)
	if !ok {
		return "", errors.New("yt-dlp did not produce a usable caption file.")
	}
	raw, err := os.ReadFile(file.URL)
	if err != nil {
		return "", err
	}
	text, err := ParseCaptionText(string(raw), file.Ext)
	if err != nil {
		return "", err
	}
	if text == "" {
		return "", fmt.Errorf("Caption file %s parsed to empty text.", filepath.Base(file.URL))
	}
	return text, nil
}

// downloadedCaption picks among the caption files yt-dlp wrote to dir.
func downloadedCaption(dir string, prefs []string) (CaptionTrack, bool) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return CaptionTrack{}, false
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	var groups []CaptionGroup
	index := map[string]int{}
	for _, name := range names {
		ext := strings.ToLower(filepath.Ext(name))
		switch ext {
		case ".vtt", ".webvtt", ".srt", ".ttml", ".xml", ".json3", ".json":
		default:
			continue
		}
		if !strings.HasPrefix(name, "captions.") || !isFile(filepath.Join(dir, name)) {
			continue
		}
		lang := strings.ToLower(strings.TrimPrefix(strings.TrimSuffix(name, filepath.Ext(name)), "captions."))
		i, ok := index[lang]
		if !ok {
			i = len(groups)
			index[lang] = i
			groups = append(groups, CaptionGroup{Language: lang})
		}
		groups[i].Items = append(groups[i].Items, CaptionTrack{URL: filepath.Join(dir, name), Ext: strings.TrimPrefix(ext, ".")})
	}
	if t := PickCaptionTrack(groups, prefs); t != nil {
		return *t, true
	}
	return CaptionTrack{}, false
}

func isFile(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.Mode().IsRegular()
}

func firstFileWithPrefix(dir, prefix string) string {
	entries, _ := os.ReadDir(dir)
	var names []string
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), prefix) {
			names = append(names, e.Name())
		}
	}
	if len(names) == 0 {
		return ""
	}
	sort.Strings(names)
	return filepath.Join(dir, names[0])
}

func audioMime(path string) string {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".mp3":
		return "audio/mpeg"
	case ".m4a":
		return "audio/mp4"
	case ".wav":
		return "audio/wav"
	case ".webm":
		return "audio/webm"
	case ".opus":
		return "audio/opus"
	case ".ogg":
		return "audio/ogg"
	}
	return "application/octet-stream"
}

func (s *Service) sttTranscript(ctx context.Context, j *job, pageURL string) (string, error) {
	if s.cfg.Transcriber == nil {
		return "", errors.New("Speech-to-text is not available.")
	}
	template := filepath.Join(j.dir, "audio.%(ext)s")
	err := s.ytdlp(ctx, j, 10*time.Minute, "-o", template, "-f", "bestaudio/best", "--extract-audio", "--audio-format", "mp3", "--audio-quality", "0", "--", pageURL)
	if err != nil {
		if ctx.Err() != nil {
			return "", ctx.Err()
		}
		j.warn("Audio extract-audio path failed (%s). Retrying raw media download.", err)
		if err := s.ytdlp(ctx, j, 10*time.Minute, "-o", template, "-f", "bestaudio/best", "--", pageURL); err != nil {
			return "", err
		}
	}
	audio := firstFileWithPrefix(j.dir, "audio.")
	if audio == "" || !isFile(audio) {
		return "", errors.New("Audio download succeeded but no audio file was created.")
	}
	prepared, err := s.prepareAudio(ctx, j, audio)
	if err != nil {
		return "", err
	}
	return s.cfg.Transcriber.Transcribe(ctx, prepared, j.userID, j.agentID, audioMime(prepared))
}

// prepareAudio converts anything an STT provider might refuse to mono mp3.
func (s *Service) prepareAudio(ctx context.Context, j *job, audio string) (string, error) {
	ext := strings.ToLower(filepath.Ext(audio))
	if audioMime(audio) != "application/octet-stream" && ext != ".mp4" && ext != ".mkv" && ext != ".mov" && ext != ".avi" {
		return audio, nil
	}
	out := filepath.Join(j.dir, "audio.stt.mp3")
	err := s.command(ctx, j.dir, 3*time.Minute, s.cfg.Ffmpeg, "-hwaccel", "none", "-y", "-hide_banner", "-loglevel", "error",
		"-i", audio, "-vn", "-ac", "1", "-ar", "16000", "-b:a", "64k", out)
	if err != nil {
		return "", err
	}
	if !isFile(out) {
		return "", errors.New("ffmpeg did not produce a normalized audio file for transcription.")
	}
	return out, nil
}

// frameImage grabs a still from the video, or the best thumbnail when that
// fails. A thumbnail that cannot be fetched fails the extraction, as in Node.
func (s *Service) frameImage(ctx context.Context, j *job, pageURL string, info mediaInfo) (*FrameImage, error) {
	frame, err := s.frameFromVideo(ctx, j, pageURL, info)
	if err == nil {
		return frame, nil
	}
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	j.warn("Frame extraction failed: %s", err)
	best := bestThumbnail(info.Thumbnails)
	if best == nil {
		j.warn("No thumbnail fallback was available after frame extraction failed.")
		return nil, nil
	}
	return s.thumbnailArtifact(ctx, j.userID, best.URL)
}

func bestThumbnail(thumbs []thumbnail) *thumbnail {
	var best *thumbnail
	for i := range thumbs {
		t := &thumbs[i]
		if t.URL == "" {
			continue
		}
		if best == nil || float64(t.Width*t.Height) > float64(best.Width*best.Height) {
			best = t
		}
	}
	return best
}

func (s *Service) frameFromVideo(ctx context.Context, j *job, pageURL string, info mediaInfo) (*FrameImage, error) {
	template := filepath.Join(j.dir, "video.%(ext)s")
	err := s.ytdlp(ctx, j, 14*time.Minute, "-o", template, "-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/best", "--merge-output-format", "mp4", "--", pageURL)
	if err != nil {
		return nil, err
	}
	video := firstFileWithPrefix(j.dir, "video.")
	if video == "" || !isFile(video) {
		return nil, errors.New("Video download succeeded but no playable file was created.")
	}
	frame := filepath.Join(j.dir, "frame.jpg")
	err = s.command(ctx, j.dir, 2*time.Minute, s.cfg.Ffmpeg, "-hwaccel", "none", "-y", "-hide_banner", "-loglevel", "error",
		"-ss", strconv.Itoa(frameSecond(info.Duration)), "-i", video, "-frames:v", "1", "-q:v", "2", frame)
	if err != nil {
		return nil, err
	}
	if !isFile(frame) {
		return nil, errors.New("ffmpeg did not produce a frame image.")
	}
	return s.saveImage(ctx, j.userID, frame)
}

func strPtr(s string) *string { return &s }

func (s *Service) saveImage(ctx context.Context, userID int64, path string) (*FrameImage, error) {
	mime := imageContentType(path)
	if s.cfg.Artifacts == nil {
		st, err := os.Stat(path)
		if err != nil {
			return nil, err
		}
		size := st.Size()
		return &FrameImage{URL: strPtr(path), MimeType: &mime, ByteSize: &size, Source: "frame"}, nil
	}
	ext := firstNonEmpty(strings.TrimPrefix(filepath.Ext(path), "."), "jpg")
	alloc, err := s.cfg.Artifacts.AllocateFile(ctx, userID, ArtifactSpec{
		Kind: "social-video-frame", Extension: ext, ContentType: mime, FilenameBase: "social-video-frame",
		Metadata: map[string]any{"source": "frame"},
	})
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(alloc.StoragePath, data, 0o600); err != nil {
		return nil, err
	}
	fin, err := s.cfg.Artifacts.FinalizeFile(ctx, alloc.ArtifactID, alloc.StoragePath)
	if err != nil {
		return nil, err
	}
	return &FrameImage{URL: &fin.URL, ArtifactID: &fin.ArtifactID, MimeType: &mime, ByteSize: &fin.ByteSize, Source: "frame"}, nil
}

func (s *Service) thumbnailArtifact(ctx context.Context, userID int64, thumbURL string) (*FrameImage, error) {
	body, final, header, err := s.fetch(ctx, thumbURL, "image/*,*/*", maxThumbnailSize, nil)
	if err != nil {
		return nil, err
	}
	ext := "jpg"
	if u, err := url.Parse(final); err == nil {
		if e := strings.TrimPrefix(filepath.Ext(u.Path), "."); e != "" {
			ext = e
		}
	}
	mime := firstNonEmpty(jsTrim(header.Get("Content-Type")), "image/"+ext)
	if s.cfg.Artifacts == nil {
		size := int64(len(body))
		return &FrameImage{MimeType: &mime, ByteSize: &size, Source: "thumbnail"}, nil
	}
	alloc, err := s.cfg.Artifacts.AllocateFile(ctx, userID, ArtifactSpec{
		Kind: "social-video-frame", Extension: ext, ContentType: mime,
		FilenameBase: "social-video-thumbnail", Metadata: map[string]any{"source": "social-video-thumbnail"},
	})
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(alloc.StoragePath, body, 0o600); err != nil {
		return nil, err
	}
	fin, err := s.cfg.Artifacts.FinalizeFile(ctx, alloc.ArtifactID, alloc.StoragePath)
	if err != nil {
		return nil, err
	}
	return &FrameImage{URL: &fin.URL, ArtifactID: &fin.ArtifactID, MimeType: &mime, ByteSize: &fin.ByteSize, Source: "thumbnail"}, nil
}
