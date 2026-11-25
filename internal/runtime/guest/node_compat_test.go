package guest

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"
)

type recordedCall struct {
	Method   string `json:"method"`
	URL      string `json:"url"`
	Body     any    `json:"body"`
	Status   int    `json:"status"`
	Response string `json:"response"`
}

// buildFixture creates the workspace the Node recording was made over.
func buildFixture(t *testing.T, h *harness) {
	files := map[string]string{
		"README.md": "hello\nworld\n", "zeta.txt": "z", "Alpha.txt": "A",
		"beta.txt": "needle in beta\nsecond line\nneedle again", "_under.txt": "u", "2nd.txt": "two",
		"src/main.go": "package main\n// needle\n", "src/nested/deep.txt": "deep needle", "node_modules/x/skip.txt": "needle",
	}
	for name, body := range files {
		h.write(name, body)
	}
	os.MkdirAll(filepath.Join(h.workspace, "Docs"), 0o755)
	if err := os.Symlink("beta.txt", filepath.Join(h.workspace, "link.txt")); err != nil {
		t.Fatal(err)
	}
	when := time.Date(2026, 1, 2, 3, 4, 5, 678_000_000, time.UTC)
	filepath.Walk(h.workspace, func(p string, info os.FileInfo, err error) error {
		if info.Mode()&os.ModeSymlink == 0 {
			os.Chtimes(p, when, when)
		}
		return nil
	})
}

func TestResponsesMatchTheNodeGuestAgent(t *testing.T) {
	raw, err := os.ReadFile("testdata/node_responses.json")
	if err != nil {
		t.Fatal(err)
	}
	var recording struct {
		Recorded []recordedCall `json:"recorded"`
	}
	if err := json.Unmarshal(raw, &recording); err != nil {
		t.Fatal(err)
	}
	h := newHarness(t, nil)
	buildFixture(t, h)
	volatile := regexp.MustCompile(`"modifiedAt":"2026-11[^"]*"`)
	for _, c := range recording.Recorded {
		t.Run(c.Method+" "+c.URL, func(t *testing.T) {
			var body any
			if c.Body != nil {
				body = c.Body
			}
			got := h.do(c.Method, c.URL, body, nil)
			if got.status != c.Status {
				t.Fatalf("status %d, Node %d (%s)", got.status, c.Status, got.body)
			}
			if strings.HasPrefix(c.URL, "/proxy/") {
				return // the connection error text is the runtime's own
			}
			// a link's own time is not set by the fixture, so it is not compared
			link := regexp.MustCompile(`("type":"symlink","size":null,"modifiedAt":)"[^"]*"`)
			norm := func(s string) string {
				return link.ReplaceAllString(volatile.ReplaceAllString(s, `"modifiedAt":"<now>"`), `$1"<link>"`)
			}
			want, have := norm(c.Response), norm(got.body)
			if have != want {
				t.Fatalf("body differs\n got: %s\nNode: %s", have, want)
			}
		})
	}
}
