package synthid

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func png(t *testing.T) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "a.png")
	if err := os.WriteFile(p, []byte{0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2}, 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestDetectWithAPIKey(t *testing.T) {
	var gotPath, gotKey string
	var answer string
	status := 200
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath, gotKey = r.URL.Path, r.Header.Get("X-Goog-Api-Key")
		body, _ := io.ReadAll(r.Body)
		var req map[string]any
		_ = json.Unmarshal(body, &req)
		if req["parameters"].(map[string]any)["watermarkVerification"] != true {
			t.Error("watermarkVerification missing")
		}
		w.WriteHeader(status)
		_, _ = io.WriteString(w, answer)
	}))
	defer srv.Close()
	env := map[string]string{"GOOGLE_API_KEY": " key ", "GOOGLE_CLOUD_PROJECT": "proj x"}
	d := &Detector{Getenv: func(k string) string { return env[k] }, Endpoint: srv.URL}
	if !d.Available() {
		t.Fatal("should be available")
	}
	img := png(t)
	answer = `{"predictions":[{"decision":"accept"}]}`
	got, err := d.Detect(context.Background(), img)
	if err != nil || got["detected"] != true || got["interpretation"] != "A SynthID watermark was detected in this image." {
		t.Fatalf("%v %v", got, err)
	}
	if gotKey != "key" || gotPath != "/v1/projects/proj%20x/locations/us-central1/publishers/google/models/imageverification@001:predict" && gotPath != "/v1/projects/proj x/locations/us-central1/publishers/google/models/imageverification@001:predict" {
		t.Fatalf("path %q key %q", gotPath, gotKey)
	}
	answer = `{"predictions":[{"decision":"maybe"}]}`
	if _, err := d.Detect(context.Background(), img); err == nil || err.Error() != "Google SynthID detector returned an unrecognized result." {
		t.Fatal(err)
	}
	status, answer = 403, `{"error":{"message":" denied "}}`
	if _, err := d.Detect(context.Background(), img); err == nil || err.Error() != "Google SynthID detector returned 403: denied" {
		t.Fatal(err)
	}
	gif := filepath.Join(t.TempDir(), "a.gif")
	_ = os.WriteFile(gif, []byte("GIF89a"), 0o600)
	if _, err := d.Detect(context.Background(), gif); err == nil || !strings.Contains(err.Error(), "PNG and JPEG") {
		t.Fatal(err)
	}
	env["GOOGLE_CLOUD_LOCATION"] = "Bad_Loc"
	if _, err := d.Detect(context.Background(), img); err == nil || err.Error() != "Google Cloud location contains unsupported characters." {
		t.Fatal(err)
	}
}

func TestUnavailableWithoutProject(t *testing.T) {
	d := &Detector{Getenv: func(k string) string {
		if k == "GOOGLE_API_KEY" {
			return "k"
		}
		return ""
	}}
	if d.Available() {
		t.Fatal("a key without a project is not enough")
	}
	if _, err := d.Detect(context.Background(), png(t)); err == nil || err.Error() != "Google Cloud authentication for SynthID detection is not configured." {
		t.Fatal(err)
	}
}
