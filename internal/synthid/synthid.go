// Package synthid checks an image for Google's invisible SynthID watermark
// with the Vertex AI detector (integrated_tools/synthid.js).
package synthid

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/googleauth"
)

const (
	defaultLocation = "us-central1"
	modelID         = "imageverification@001"
	maxImageBytes   = 10 * 1024 * 1024
	requestTimeout  = 60 * time.Second
)

// Detector calls the Vertex AI SynthID detector.
type Detector struct {
	Getenv func(string) string
	Home   string
	Client *http.Client
	// Endpoint replaces https://<location>-aiplatform.googleapis.com in tests.
	Endpoint string
}

type auth struct {
	available               bool
	apiKey, file, projectID string
}

func (d *Detector) env(key string) string {
	if d.Getenv == nil {
		return ""
	}
	return strings.TrimSpace(d.Getenv(key))
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

func (d *Detector) configured() auth {
	getenv := d.Getenv
	if getenv == nil {
		getenv = func(string) string { return "" }
	}
	a := auth{apiKey: firstNonEmpty(d.env("GOOGLE_AI_KEY"), d.env("GOOGLE_API_KEY")), file: googleauth.DefaultFile(getenv, d.Home, runtime.GOOS)}
	fileProject := ""
	if a.file != "" {
		if c, err := googleauth.Load(a.file); err == nil {
			fileProject = firstNonEmpty(c.ProjectID, c.QuotaProject)
		}
	}
	a.projectID = firstNonEmpty(d.env("GOOGLE_CLOUD_PROJECT"), d.env("GCLOUD_PROJECT"), d.env("GCP_PROJECT"), fileProject)
	a.available = a.projectID != "" && (a.apiKey != "" || a.file != "")
	return a
}

// Available reports whether Google Cloud authentication is configured.
func (d *Detector) Available() bool { return d.configured().available }

var locationPattern = regexp.MustCompile(`^[a-z][a-z0-9-]*$`)

func mimeType(image []byte) error {
	switch {
	case len(image) >= 8 && bytes.Equal(image[:8], []byte{0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a}):
		return nil
	case len(image) >= 3 && image[0] == 0xff && image[1] == 0xd8 && image[2] == 0xff:
		return nil
	}
	return errors.New("SynthID detection supports PNG and JPEG images only.")
}

func (d *Detector) client() *http.Client {
	if d.Client != nil {
		return d.Client
	}
	return &http.Client{Timeout: requestTimeout}
}

func (d *Detector) headers(ctx context.Context, a auth) (http.Header, error) {
	if !a.available {
		return nil, errors.New("Google Cloud authentication for SynthID detection is not configured.")
	}
	h := http.Header{}
	if a.apiKey != "" && a.file == "" {
		h.Set("X-Goog-Api-Key", a.apiKey)
		return h, nil
	}
	creds, err := googleauth.Load(a.file)
	if err != nil {
		return nil, err
	}
	token, err := creds.AccessToken(ctx, d.client(), googleauth.CloudPlatformScope)
	if err != nil {
		return nil, err
	}
	if token == "" {
		return nil, errors.New("Google Application Default Credentials did not provide an access token.")
	}
	h.Set("Authorization", "Bearer "+token)
	return h, nil
}

// Detect checks an image file already resolved to a host path.
func (d *Detector) Detect(ctx context.Context, imagePath string) (map[string]any, error) {
	info, err := os.Stat(imagePath)
	if err != nil {
		return nil, err
	}
	if info.Size() > maxImageBytes {
		return nil, errors.New("SynthID detection supports images up to 10 MB.")
	}
	image, err := os.ReadFile(imagePath)
	if err != nil {
		return nil, err
	}
	if err := mimeType(image); err != nil {
		return nil, err
	}
	location := firstNonEmpty(d.env("GOOGLE_CLOUD_LOCATION"), d.env("VERTEX_AI_LOCATION"), defaultLocation)
	if !locationPattern.MatchString(location) {
		return nil, errors.New("Google Cloud location contains unsupported characters.")
	}
	a := d.configured()
	headers, err := d.headers(ctx, a)
	if err != nil {
		return nil, err
	}
	base := d.Endpoint
	if base == "" {
		base = "https://" + location + "-aiplatform.googleapis.com"
	}
	endpoint := base + "/v1/projects/" + url.PathEscape(a.projectID) + "/locations/" + location + "/publishers/google/models/" + modelID + ":predict"
	body, _ := json.Marshal(map[string]any{
		"instances":  []any{map[string]any{"image": map[string]any{"bytesBase64Encoded": base64.StdEncoding.EncodeToString(image)}}},
		"parameters": map[string]any{"watermarkVerification": true},
	})
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header = headers
	req.Header.Set("Content-Type", "application/json")
	resp, err := d.client().Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		var e struct {
			Error struct {
				Message any `json:"message"`
			} `json:"error"`
		}
		_ = json.Unmarshal(raw, &e)
		message := ""
		if s, ok := e.Error.Message.(string); ok {
			message = strings.TrimSpace(s)
		}
		if message != "" {
			return nil, fmt.Errorf("Google SynthID detector returned %d: %s", resp.StatusCode, message)
		}
		return nil, fmt.Errorf("Google SynthID detector returned %d.", resp.StatusCode)
	}
	var parsed struct {
		Predictions []struct {
			Decision any `json:"decision"`
		} `json:"predictions"`
	}
	if json.Unmarshal(raw, &parsed) != nil {
		return nil, errors.New("Google SynthID detector returned invalid JSON.")
	}
	decision := ""
	if len(parsed.Predictions) > 0 {
		if s, ok := parsed.Predictions[0].Decision.(string); ok {
			decision = strings.ToUpper(strings.TrimSpace(s))
		}
	}
	if decision != "ACCEPT" && decision != "REJECT" {
		return nil, errors.New("Google SynthID detector returned an unrecognized result.")
	}
	detected := decision == "ACCEPT"
	interpretation := "No SynthID watermark was detected. This does not prove the image was made by a human or by a non-Google model."
	if detected {
		interpretation = "A SynthID watermark was detected in this image."
	}
	return map[string]any{"detected": detected, "detector": "Google Vertex AI SynthID", "interpretation": interpretation}, nil
}
