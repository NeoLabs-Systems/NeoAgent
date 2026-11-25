package ai

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

type hostEnv struct{}

func (hostEnv) HostTerminal() bool                  { return false }
func (hostEnv) WebSharingEnabled(userID int64) bool { return false }

func testShaper(t *testing.T) *Shaper {
	t.Helper()
	registry, err := tools.NewRegistry(hostEnv{})
	if err != nil {
		t.Fatal(err)
	}
	return &Shaper{Tools: registry}
}

func readVectors(t *testing.T, name string, into any) {
	t.Helper()
	raw, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(raw, into); err != nil {
		t.Fatal(err)
	}
}

type resultVectors struct {
	Results []struct {
		Tool   string  `json:"tool"`
		Args   dyn.Map `json:"args"`
		Result any     `json:"result"`
		Limits struct {
			SoftLimit int `json:"softLimit"`
			HardLimit int `json:"hardLimit"`
		} `json:"limits"`
		Retain   bool   `json:"retain"`
		Expected string `json:"expected"`
	} `json:"results"`
	TestOutput []struct {
		Name  string `json:"name"`
		Input struct {
			Command string `json:"command"`
			Stdout  string `json:"stdout"`
			Stderr  string `json:"stderr"`
		} `json:"input"`
		Expected any `json:"expected"`
	} `json:"testOutput"`
	Outcomes []struct {
		Input    any    `json:"input"`
		Expected string `json:"expected"`
	} `json:"outcomes"`
	Clamps []struct {
		Text  any    `json:"text"`
		Max   int    `json:"max"`
		Clamp string `json:"clamp"`
	} `json:"clamps"`
	LineExcerpts []struct {
		Text    any    `json:"text"`
		Lines   int    `json:"ml"`
		Chars   int    `json:"mc"`
		Excerpt string `json:"excerpt"`
	} `json:"lineExcerpts"`
	Retained []struct {
		Payload any    `json:"payload"`
		Text    string `json:"text"`
	} `json:"retained"`
	Logs []struct {
		Value any    `json:"value"`
		Max   int    `json:"max"`
		Text  string `json:"text"`
	} `json:"logs"`
}

func TestCompactToolResultMatchesNode(t *testing.T) {
	var v resultVectors
	readVectors(t, "results.json", &v)
	shaper := testShaper(t)
	for i, c := range v.Results {
		options := ResultOptions{SoftLimit: c.Limits.SoftLimit, HardLimit: c.Limits.HardLimit}
		if c.Retain {
			options.RetainFullResult = func(payload any) *RetainedResult {
				text, ok := payload.(string)
				if !ok {
					text = dyn.StringifyIndent(payload)
				}
				return &RetainedResult{ArtifactID: "retained-1", TotalLines: len(strings.Split(text, "\n"))}
			}
		}
		if got := shaper.CompactToolResult(c.Tool, c.Args, c.Result, options); got != c.Expected {
			t.Errorf("case %d (%s):\n got  %s\n want %s", i, c.Tool, got, c.Expected)
		}
	}
}

func TestTestOutputMatchesNode(t *testing.T) {
	var v resultVectors
	readVectors(t, "results.json", &v)
	for _, c := range v.TestOutput {
		got := ParseTestOutput(c.Input.Command, c.Input.Stdout, c.Input.Stderr)
		var gotValue any
		if got != nil {
			raw, _ := json.Marshal(got)
			json.Unmarshal(raw, &gotValue)
		}
		gotJSON, _ := json.Marshal(gotValue)
		wantJSON, _ := json.Marshal(c.Expected)
		// Compare through generic values, so key order does not matter.
		var a, b any
		json.Unmarshal(gotJSON, &a)
		json.Unmarshal(wantJSON, &b)
		if dyn.Stringify(a) != dyn.Stringify(b) {
			t.Errorf("%s:\n got  %s\n want %s", c.Name, gotJSON, wantJSON)
		}
	}
}

func TestOutcomeAndClampHelpersMatchNode(t *testing.T) {
	var v resultVectors
	readVectors(t, "results.json", &v)
	for _, c := range v.Outcomes {
		if got := commandFailureMessage(c.Input); got != c.Expected {
			t.Errorf("outcome %v: %q, want %q", c.Input, got, c.Expected)
		}
	}
	for _, c := range v.Clamps {
		if got := ClampText(c.Text, c.Max); got != c.Clamp {
			t.Errorf("clamp %v: %q, want %q", c.Text, got, c.Clamp)
		}
	}
	for _, c := range v.LineExcerpts {
		if got := LineExcerpt(c.Text, c.Lines, c.Chars); got != c.Excerpt {
			t.Errorf("excerpt %v: %q, want %q", c.Text, got, c.Excerpt)
		}
	}
	for _, c := range v.Retained {
		if got := ToRetainedText(c.Payload); got != c.Text {
			t.Errorf("retained %v: differs", c.Payload)
		}
	}
	for _, c := range v.Logs {
		if got := SummarizeForLog(c.Value, c.Max); got != c.Text {
			t.Errorf("log %v: %q, want %q", c.Value, got, c.Text)
		}
	}
}
