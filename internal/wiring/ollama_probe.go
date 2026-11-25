package wiring

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"
)

const (
	ollamaProbeTimeout = 1500 * time.Millisecond
	ollamaProbeTTL     = 30 * time.Second
)

type ollamaProbe struct {
	healthy bool
	reason  string
}

type cachedProbe struct {
	probe   ollamaProbe
	expires time.Time
}

var ollamaProbes struct {
	sync.Mutex
	byURL map[string]cachedProbe
}

// probeOllama asks a local Ollama server for its models, cached briefly so a
// settings screen does not wait on an offline server for every request.
func probeOllama(ctx context.Context, baseURL string) ollamaProbe {
	ollamaProbes.Lock()
	if e, ok := ollamaProbes.byURL[baseURL]; ok && time.Now().Before(e.expires) {
		ollamaProbes.Unlock()
		return e.probe
	}
	ollamaProbes.Unlock()

	probe := fetchOllamaTags(ctx, baseURL)
	ollamaProbes.Lock()
	if ollamaProbes.byURL == nil {
		ollamaProbes.byURL = map[string]cachedProbe{}
	}
	ollamaProbes.byURL[baseURL] = cachedProbe{probe, time.Now().Add(ollamaProbeTTL)}
	ollamaProbes.Unlock()
	return probe
}

func fetchOllamaTags(ctx context.Context, baseURL string) ollamaProbe {
	ctx, cancel := context.WithTimeout(ctx, ollamaProbeTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/api/tags", nil)
	if err != nil {
		return ollamaProbe{reason: fmt.Sprintf("Could not reach Ollama at %s.", baseURL)}
	}
	resp, err := trustedModelHTTP.Do(req)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return ollamaProbe{reason: fmt.Sprintf("Ollama did not respond within %dms.", ollamaProbeTimeout.Milliseconds())}
		}
		return ollamaProbe{reason: fmt.Sprintf("Could not reach Ollama at %s.", baseURL)}
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return ollamaProbe{reason: fmt.Sprintf("Ollama returned HTTP %d.", resp.StatusCode)}
	}
	var data struct {
		Models []any `json:"models"`
	}
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	_ = json.Unmarshal(raw, &data)
	if n := len(data.Models); n > 0 {
		return ollamaProbe{healthy: true, reason: fmt.Sprintf("Connected to Ollama with %d local model(s).", n)}
	}
	return ollamaProbe{healthy: true, reason: "Connected to Ollama, but no local models were reported."}
}
