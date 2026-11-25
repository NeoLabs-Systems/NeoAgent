package wearable

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"reflect"
	"regexp"
	"strings"
	"testing"
)

type firmwareVectors struct {
	Helpers struct {
		Slugs    []struct{ Input, Slug string } `json:"slugs"`
		Channels []struct {
			Input   *string `json:"input"`
			Channel string  `json:"channel"`
		} `json:"channels"`
		StripHash   []struct{ Input, Out string }      `json:"stripHash"`
		Checksums   []struct{ Body, Name, Out string } `json:"checksums"`
		SelectAsset []struct {
			Release Release `json:"release"`
			Name    string  `json:"name"`
			Out     *string `json:"out"`
		} `json:"selectAsset"`
		ChecksumAsset []struct {
			Release Release `json:"release"`
			Name    string  `json:"name"`
			Out     *string `json:"out"`
		} `json:"checksumAsset"`
		Select []struct {
			Releases  []Release `json:"releases"`
			Channel   string    `json:"channel"`
			AssetName *string   `json:"assetName"`
			Out       *string   `json:"out"`
		} `json:"select"`
	} `json:"helpers"`
	Scenarios []struct {
		Name      string            `json:"name"`
		Repo      string            `json:"repo"`
		Channel   string            `json:"channel"`
		AssetName string            `json:"assetName"`
		Env       map[string]string `json:"env"`
		Routes    map[string]struct {
			Status int             `json:"status"`
			Text   *string         `json:"text"`
			Body   json.RawMessage `json:"body"`
		} `json:"routes"`
		ManifestText string `json:"manifestText"`
		Requests     []struct {
			URL           string  `json:"url"`
			Authorization *string `json:"authorization"`
			Accept        *string `json:"accept"`
		} `json:"requests"`
	} `json:"scenarios"`
}

func loadFirmware(t *testing.T) firmwareVectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/firmware.json")
	if err != nil {
		t.Fatal(err)
	}
	var v firmwareVectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestFirmwareHelpersMatchNode(t *testing.T) {
	h := loadFirmware(t).Helpers
	for _, c := range h.Slugs {
		if got := ParseRepositorySlug(c.Input); got != c.Slug {
			t.Errorf("ParseRepositorySlug(%q) = %q, Node %q", c.Input, got, c.Slug)
		}
	}
	for _, c := range h.Channels {
		in := ""
		if c.Input != nil {
			in = *c.Input
		}
		if got := NormalizeChannel(in); got != c.Channel {
			t.Errorf("NormalizeChannel(%q) = %q, Node %q", in, got, c.Channel)
		}
	}
	for _, c := range h.StripHash {
		if got := stripHashPrefix(c.Input); got != c.Out {
			t.Errorf("stripHashPrefix(%q) = %q, Node %q", c.Input, got, c.Out)
		}
	}
	for _, c := range h.Checksums {
		if got := parseChecksumBody(c.Body, c.Name); got != c.Out {
			t.Errorf("parseChecksumBody(%q, %q) = %q, Node %q", c.Body, c.Name, got, c.Out)
		}
	}
	name := func(a *Asset) *string {
		if a == nil {
			return nil
		}
		return &a.Name
	}
	for i, c := range h.SelectAsset {
		if got := name(SelectReleaseAsset(&c.Release, c.Name)); !reflect.DeepEqual(got, c.Out) {
			t.Errorf("SelectReleaseAsset case %d = %v, Node %v", i, got, c.Out)
		}
	}
	for i, c := range h.ChecksumAsset {
		if got := name(selectChecksumAsset(&c.Release, c.Name)); !reflect.DeepEqual(got, c.Out) {
			t.Errorf("selectChecksumAsset case %d = %v, Node %v", i, got, c.Out)
		}
	}
	for i, c := range h.Select {
		asset := ""
		if c.AssetName != nil {
			asset = *c.AssetName
		}
		var got *string
		if r := SelectGithubRelease(c.Releases, c.Channel, asset); r != nil {
			got = &r.TagName
		}
		if !reflect.DeepEqual(got, c.Out) {
			t.Errorf("SelectGithubRelease case %d (%s, %q) = %v, Node %v", i, c.Channel, asset, got, c.Out)
		}
	}
}

type routeTransport func(*http.Request) *http.Response

func (f routeTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r), nil }

var generatedAt = regexp.MustCompile(`"generatedAt":"[^"]*"`)

// Whole manifests, key order included, for the same scripted GitHub.
func TestFirmwareManifestMatchesNode(t *testing.T) {
	for _, sc := range loadFirmware(t).Scenarios {
		t.Run(sc.Name, func(t *testing.T) {
			var seen []string
			client := &http.Client{Transport: routeTransport(func(r *http.Request) *http.Response {
				auth, accept := "", r.Header.Get("Accept")
				if a := r.Header.Get("Authorization"); a != "" {
					auth = a
				}
				seen = append(seen, r.URL.String()+"|"+auth+"|"+accept)
				route, ok := sc.Routes[r.URL.String()]
				status, text := 404, "not found"
				if ok {
					status = route.Status
					if status == 0 {
						status = 200
					}
					if route.Text != nil {
						text = *route.Text
					} else {
						text = string(route.Body)
					}
				}
				return &http.Response{StatusCode: status, Body: io.NopCloser(strings.NewReader(text)), Header: http.Header{}, ContentLength: -1}
			})}
			getenv := func(key string) string { return sc.Env[key] }
			env := FirmwareEnvFrom(getenv)
			env.Repository, env.AssetName = trimString(sc.Repo, 256), trimString(sc.AssetName, 128)
			resolver := &FirmwareResolver{Client: client}
			manifest := resolver.Resolve(context.Background(), sc.Channel, env)
			raw, err := json.Marshal(manifest)
			if err != nil {
				t.Fatal(err)
			}
			got := generatedAt.ReplaceAllString(string(raw), `"generatedAt":"T"`)
			if got != sc.ManifestText {
				t.Errorf("manifest differs\n go:   %s\n node: %s", got, sc.ManifestText)
			}
			var want []string
			for _, r := range sc.Requests {
				auth, accept := "", ""
				if r.Authorization != nil {
					auth = *r.Authorization
				}
				if r.Accept != nil {
					accept = *r.Accept
				}
				if auth != "" {
					auth = "Bearer " + strings.TrimPrefix(auth, "Bearer ")
				}
				want = append(want, r.URL+"|"+auth+"|"+accept)
			}
			if !reflect.DeepEqual(seen, want) {
				t.Errorf("requests differ\n go:   %q\n node: %q", seen, want)
			}
		})
	}
}

func TestFirmwareManifestIsCached(t *testing.T) {
	calls := 0
	client := &http.Client{Transport: routeTransport(func(r *http.Request) *http.Response {
		calls++
		return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(`[]`)), Header: http.Header{}, ContentLength: -1}
	})}
	resolver := &FirmwareResolver{Client: client}
	resolver.Resolve(context.Background(), "stable", FirmwareEnv{Repository: "o/cache"})
	resolver.Resolve(context.Background(), "stable", FirmwareEnv{Repository: "o/cache"})
	// A failure is not cached: the next wearable asks GitHub again.
	if calls != 2 {
		t.Fatalf("%d requests for two failures, want 2", calls)
	}
}
