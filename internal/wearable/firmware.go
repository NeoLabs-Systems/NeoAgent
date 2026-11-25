package wearable

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

const (
	defaultGithubRepository = "NeoLabs-Systems/NeoAgent"
	defaultAssetName        = "neoagent-wearable-firmware.bin"
	manifestCacheTTL        = 5 * time.Minute
	// Every platform build is a release asset, so one release entry runs to
	// ~50 KB: the list is read a page at a time instead of one response over
	// the size limit.
	releasesPageSize         = 10
	releasesMaxPages         = 5
	firmwareHTTPTimeout      = 15 * time.Second
	releasesMaxResponseBytes = 2 * 1024 * 1024
	checksumMaxResponseBytes = 64 * 1024
)

// FirmwareEnv is the server configuration the firmware manifest reads.
type FirmwareEnv struct {
	// Channel is NEOAGENT_WEARABLE_FIRMWARE_CHANNEL, used when a request names none.
	Channel string
	// Repository and AssetName override the GitHub repository and the asset
	// (NEOAGENT_WEARABLE_FIRMWARE_GITHUB_REPOSITORY / _ASSET_NAME).
	Repository string
	AssetName  string
	// Token reads private releases and avoids rate limits
	// (NEOAGENT_WEARABLE_GITHUB_TOKEN, GITHUB_TOKEN or GH_TOKEN).
	Token string
	// MinServerVersion is NEOAGENT_WEARABLE_MIN_SERVER_VERSION.
	MinServerVersion string
	// Mandatory is NEOAGENT_WEARABLE_FIRMWARE_MANDATORY.
	Mandatory bool
	// RolloutJSON is NEOAGENT_WEARABLE_FIRMWARE_ROLLOUT_JSON.
	RolloutJSON string
}

// FirmwareEnvFrom reads the manifest settings from the environment.
func FirmwareEnvFrom(getenv func(string) string) FirmwareEnv {
	first := func(keys ...string) string {
		for _, key := range keys {
			if v := strings.TrimSpace(getenv(key)); v != "" {
				return v
			}
		}
		return ""
	}
	return FirmwareEnv{
		Channel:          getenv("NEOAGENT_WEARABLE_FIRMWARE_CHANNEL"),
		Repository:       trimString(getenv("NEOAGENT_WEARABLE_FIRMWARE_GITHUB_REPOSITORY"), 256),
		AssetName:        trimString(getenv("NEOAGENT_WEARABLE_FIRMWARE_ASSET_NAME"), 128),
		Token:            trimString(first("NEOAGENT_WEARABLE_GITHUB_TOKEN", "GITHUB_TOKEN", "GH_TOKEN"), 2048),
		MinServerVersion: trimString(getenv("NEOAGENT_WEARABLE_MIN_SERVER_VERSION"), 120),
		Mandatory:        parseBool(getenv("NEOAGENT_WEARABLE_FIRMWARE_MANDATORY")),
		RolloutJSON:      getenv("NEOAGENT_WEARABLE_FIRMWARE_ROLLOUT_JSON"),
	}
}

func parseBool(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "on":
		return true
	}
	return false
}

func trimString(value string, max int) string {
	return truncateUnits(livevoice.TrimJS(value), max)
}

// NormalizeChannel maps a channel name to "beta" or "stable".
func NormalizeChannel(value string) string {
	if strings.ToLower(trimString(value, 512)) == "beta" {
		return "beta"
	}
	return "stable"
}

var (
	slugPattern = regexp.MustCompile(`^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$`)
	urlPattern  = regexp.MustCompile(`(?i)github\.com[/:]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?(?:/.*)?$`)
	betaTag     = regexp.MustCompile(`(?i)-beta(?:\.\d+)?$`)
	hash64      = regexp.MustCompile(`(?i)^[a-f0-9]{64}$`)
	lineBreak   = regexp.MustCompile(`\r?\n`)
	whitespace  = regexp.MustCompile(`\s+`)
)

// ParseRepositorySlug reads "owner/name" from a slug or a GitHub URL.
func ParseRepositorySlug(value string) string {
	raw := trimString(value, 256)
	if raw == "" {
		return ""
	}
	if m := slugPattern.FindStringSubmatch(raw); m != nil {
		return strings.TrimSuffix(m[1], ".git")
	}
	if m := urlPattern.FindStringSubmatch(raw); m != nil {
		return strings.TrimSuffix(m[1], ".git")
	}
	return ""
}

func stripHashPrefix(value string) string {
	text := trimString(value, 512)
	if text == "" {
		return ""
	}
	if len(text) >= 7 && strings.EqualFold(text[:7], "sha256:") {
		text = text[7:]
	}
	return strings.ToLower(text)
}

// Release is a GitHub release as the manifest reads it.
type Release struct {
	TagName     string  `json:"tag_name"`
	Name        string  `json:"name"`
	HTMLURL     string  `json:"html_url"`
	Prerelease  bool    `json:"prerelease"`
	Draft       bool    `json:"draft"`
	PublishedAt string  `json:"published_at"`
	CreatedAt   string  `json:"created_at"`
	Assets      []Asset `json:"assets"`
}

// Asset is a file of a release.
type Asset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

// SelectReleaseAsset finds the firmware file in a release.
func SelectReleaseAsset(release *Release, assetName string) *Asset {
	if release == nil || len(release.Assets) == 0 {
		return nil
	}
	expected := trimString(assetName, 128)
	if expected == "" {
		expected = defaultAssetName
	}
	for i := range release.Assets {
		if release.Assets[i].Name == expected {
			return &release.Assets[i]
		}
	}
	return nil
}

// selectChecksumAsset finds the file that carries the firmware's SHA-256.
func selectChecksumAsset(release *Release, assetName string) *Asset {
	if release == nil || len(release.Assets) == 0 {
		return nil
	}
	expected := trimString(assetName, 128)
	if expected == "" {
		expected = defaultAssetName
	}
	lowerExpected := strings.ToLower(expected)
	for i := range release.Assets {
		name := release.Assets[i].Name
		if name == "" || name == expected {
			continue
		}
		lower := strings.ToLower(name)
		if lower == lowerExpected+".sha256" || lower == lowerExpected+".sha256sum" ||
			strings.Contains(lower, "checksum") || strings.HasSuffix(lower, ".sha256") || strings.HasSuffix(lower, ".sha256sum") {
			return &release.Assets[i]
		}
	}
	return nil
}

func releaseHasAsset(release *Release, assetName string) bool {
	return SelectReleaseAsset(release, assetName) != nil
}

func publishedMillis(r Release) int64 {
	text := r.PublishedAt
	if text == "" {
		text = r.CreatedAt
	}
	t, err := time.Parse(time.RFC3339, text)
	if err != nil {
		return 0
	}
	return t.UnixMilli()
}

// SelectGithubRelease picks the release a channel serves: the newest stable one
// (the first in GitHub's order), or the newest beta by publish time, preferring
// one that carries the firmware asset.
func SelectGithubRelease(releases []Release, channel, assetName string) *Release {
	var candidates []Release
	if NormalizeChannel(channel) == "stable" {
		for _, r := range releases {
			if !r.Prerelease && !r.Draft {
				candidates = append(candidates, r)
			}
		}
	} else {
		for _, r := range releases {
			if r.Prerelease && betaTag.MatchString(r.TagName) {
				candidates = append(candidates, r)
			}
		}
		sort.SliceStable(candidates, func(i, j int) bool { return publishedMillis(candidates[i]) > publishedMillis(candidates[j]) })
	}
	for i := range candidates {
		if assetName == "" || releaseHasAsset(&candidates[i], assetName) {
			return &candidates[i]
		}
	}
	if len(candidates) > 0 {
		return &candidates[0]
	}
	return nil
}

// parseChecksumBody finds the SHA-256 for assetName in a checksum file.
func parseChecksumBody(body, assetName string) string {
	var lines []string
	for _, line := range lineBreak.Split(body, -1) {
		if line = livevoice.TrimJS(line); line != "" {
			lines = append(lines, line)
		}
	}
	name := livevoice.TrimJS(assetName)
	for _, line := range lines {
		first := whitespace.Split(line, 2)[0]
		normalized := stripHashPrefix(first)
		if normalized != "" && hash64.MatchString(normalized) {
			if name == "" || strings.Contains(line, name) || len(lines) == 1 {
				return normalized
			}
		}
	}
	return ""
}

// Manifest is the firmware manifest as the firmware and the app read it, with
// Node's key order.
type Manifest = fields

type manifestEntry struct {
	manifest  Manifest
	expiresAt time.Time
}

// FirmwareResolver finds the firmware release a channel serves.
type FirmwareResolver struct {
	// Client reaches GitHub; it should refuse internal addresses.
	Client *http.Client
	// APIBase is GitHub's API, overridable for tests.
	APIBase string
	Now     func() time.Time

	mu    sync.Mutex
	cache map[string]manifestEntry
}

func (r *FirmwareResolver) now() time.Time {
	if r.Now != nil {
		return r.Now()
	}
	return time.Now()
}

func (r *FirmwareResolver) apiBase() string {
	if r.APIBase != "" {
		return r.APIBase
	}
	return "https://api.github.com"
}

type limitError struct{ message string }

func (e limitError) Error() string { return e.message }

// fetchText reads a bounded response; the status is the caller's to judge, as
// the body is read first.
func (r *FirmwareResolver) fetchText(ctx context.Context, target string, accept, token, service string, maxBytes int64) (int, string, error) {
	ctx, cancel := context.WithTimeout(ctx, firmwareHTTPTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		return 0, "", err
	}
	req.Header.Set("Accept", accept)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := r.Client.Do(req)
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return 0, "", fmt.Errorf("%s request timed out after %dms.", service, firmwareHTTPTimeout.Milliseconds())
		}
		return 0, "", err
	}
	defer resp.Body.Close()
	tooLarge := limitError{fmt.Sprintf("%s response exceeded the %d-byte safety limit.", service, maxBytes)}
	if resp.ContentLength > maxBytes {
		return 0, "", tooLarge
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBytes+1))
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return 0, "", fmt.Errorf("%s request timed out after %dms.", service, firmwareHTTPTimeout.Milliseconds())
		}
		return 0, "", err
	}
	if int64(len(body)) > maxBytes {
		return 0, "", tooLarge
	}
	return resp.StatusCode, string(body), nil
}

func (r *FirmwareResolver) fetchReleases(ctx context.Context, repository string, page int, token string) ([]Release, error) {
	target := fmt.Sprintf("%s/repos/%s/releases?per_page=%d&page=%d", r.apiBase(), repository, releasesPageSize, page)
	status, body, err := r.fetchText(ctx, target, "application/vnd.github+json", token, "GitHub firmware release lookup", releasesMaxResponseBytes)
	if err != nil {
		return nil, err
	}
	if status < 200 || status > 299 {
		return nil, fmt.Errorf("GitHub API request failed with %d", status)
	}
	var releases []Release
	if err := json.Unmarshal([]byte(body), &releases); err != nil {
		var generic any
		if json.Unmarshal([]byte(body), &generic) == nil {
			// Valid JSON that is not a list has no releases in it.
			return nil, nil
		}
		return nil, errors.New("GitHub firmware release lookup returned malformed JSON.")
	}
	return releases, nil
}

// fetchRelease reads the releases a page at a time until one carries the
// asset.
func (r *FirmwareResolver) fetchRelease(ctx context.Context, repository, channel, token, assetName string) (*Release, error) {
	var withoutAsset *Release
	for page := 1; page <= releasesMaxPages; page++ {
		releases, err := r.fetchReleases(ctx, repository, page, token)
		if err != nil {
			return nil, err
		}
		release := SelectGithubRelease(releases, channel, assetName)
		if release != nil && releaseHasAsset(release, assetName) {
			return release, nil
		}
		if withoutAsset == nil {
			withoutAsset = release
		}
		if len(releases) < releasesPageSize {
			break
		}
	}
	if withoutAsset != nil {
		return withoutAsset, nil
	}
	return nil, fmt.Errorf("No %s firmware release found for %s", NormalizeChannel(channel), repository)
}

func (r *FirmwareResolver) generatedAt() string { return isoTime(r.now()) }

func (r *FirmwareResolver) failure(channel, repository, assetName, message string) Manifest {
	var repo any
	if repository != "" {
		repo = repository
	}
	return Manifest{
		{"configured", false}, {"source", "github"}, {"manifestVersion", 2}, {"channel", channel},
		{"downloadUrl", nil}, {"releaseNotesUrl", nil}, {"sha256", nil}, {"assetName", assetName},
		{"repository", repo}, {"generatedAt", r.generatedAt()}, {"error", message}, {"mandatory", false},
	}
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// Resolve is the firmware manifest of a channel. A good answer is cached for
// five minutes; a failure is reported in the manifest itself (configured false
// with an error), never as an error, so a wearable always gets a manifest.
func (r *FirmwareResolver) Resolve(ctx context.Context, channel string, env FirmwareEnv) Manifest {
	channel = NormalizeChannel(channel)
	repository := ParseRepositorySlug(env.Repository)
	if repository == "" {
		repository = defaultGithubRepository
	}
	assetName := env.AssetName
	if assetName == "" {
		assetName = defaultAssetName
	}
	key := strings.Join([]string{repository, channel, assetName, ""}, "|")
	r.mu.Lock()
	if cached, ok := r.cache[key]; ok {
		if cached.expiresAt.After(r.now()) {
			r.mu.Unlock()
			return cached.manifest
		}
		delete(r.cache, key)
	}
	r.mu.Unlock()

	release, err := r.fetchRelease(ctx, repository, channel, env.Token, assetName)
	if err != nil {
		return r.failure(channel, repository, assetName, err.Error())
	}
	tag := trimString(release.TagName, 120)
	releaseName := trimString(release.Name, 128)
	if releaseName == "" {
		releaseName = tag
	}
	asset := SelectReleaseAsset(release, assetName)
	if asset == nil || asset.BrowserDownloadURL == "" {
		return Manifest{
			{"configured", false}, {"source", "github"}, {"manifestVersion", 2}, {"channel", channel},
			{"currentVersion", nullIfEmpty(tag)}, {"releaseName", nullIfEmpty(releaseName)}, {"releaseTag", nullIfEmpty(tag)},
			{"minimumServerVersion", nullIfEmpty(env.MinServerVersion)}, {"downloadUrl", nil},
			{"releaseNotesUrl", nullIfEmpty(trimString(release.HTMLURL, 2000))}, {"sha256", nil},
			{"assetName", assetName}, {"repository", repository}, {"generatedAt", r.generatedAt()},
			{"error", fmt.Sprintf("Release asset %s was not found.", assetName)}, {"mandatory", false},
			{"prerelease", release.Prerelease},
		}
	}

	var checksum string
	if sum := selectChecksumAsset(release, asset.Name); sum != nil && sum.BrowserDownloadURL != "" {
		status, body, err := r.fetchText(ctx, sum.BrowserDownloadURL, "text/plain, application/octet-stream;q=0.9, */*;q=0.1",
			env.Token, "Firmware checksum download", checksumMaxResponseBytes)
		switch {
		case ctx.Err() != nil:
			return r.failure(channel, repository, assetName, ctx.Err().Error())
		case err == nil && status >= 200 && status <= 299:
			checksum = parseChecksumBody(body, asset.Name)
		}
	}
	manifest := Manifest{
		{"configured", true}, {"source", "github"}, {"manifestVersion", 2}, {"channel", channel},
		{"currentVersion", nullIfEmpty(tag)}, {"releaseName", nullIfEmpty(releaseName)}, {"releaseTag", nullIfEmpty(tag)},
		{"minimumServerVersion", nullIfEmpty(env.MinServerVersion)}, {"downloadUrl", asset.BrowserDownloadURL},
		{"releaseNotesUrl", nullIfEmpty(trimString(release.HTMLURL, 2000))}, {"sha256", nullIfEmpty(checksum)},
		{"assetName", asset.Name}, {"repository", repository}, {"generatedAt", r.generatedAt()},
		{"mandatory", env.Mandatory}, {"prerelease", release.Prerelease},
	}
	r.mu.Lock()
	if r.cache == nil {
		r.cache = map[string]manifestEntry{}
	}
	r.cache[key] = manifestEntry{manifest: manifest, expiresAt: r.now().Add(manifestCacheTTL)}
	r.mu.Unlock()
	return manifest
}
