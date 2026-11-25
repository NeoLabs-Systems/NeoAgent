package browser

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

type vectors struct {
	Identities map[string]Identity `json:"identities"`
	Challenges []struct {
		Input struct {
			Title, URL, HTML, Text, PageContent string
		} `json:"input"`
		Result BotDetection `json:"result"`
	} `json:"challenges"`
	Referrer  map[string]string `json:"referrer"`
	WaitUntil map[string]string `json:"waitUntil"`
	Isolated  [][2]string       `json:"isolated"`
}

// TestMatchesNode replays the Node anti-detection helpers
// (testdata/gen_vectors.js).
func TestMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	for key, want := range v.Identities {
		if got := ChooseIdentity(key); !reflect.DeepEqual(got, want) {
			t.Errorf("identity %q:\n got %+v\nwant %+v", key, got, want)
		}
	}
	for _, c := range v.Challenges {
		text := c.Input.Text
		if text == "" {
			text = c.Input.PageContent
		}
		got := DetectBotChallenge(ChallengeInput{Title: c.Input.Title, URL: c.Input.URL, HTML: c.Input.HTML, Text: text})
		if !reflect.DeepEqual(got, c.Result) {
			t.Errorf("challenge %+v: got %+v want %+v", c.Input, got, c.Result)
		}
	}
	for in, want := range v.Referrer {
		if got := NormalizeReferrerMode(in); got != want {
			t.Errorf("referrer %q: %q want %q", in, got, want)
		}
	}
	for in, want := range v.WaitUntil {
		if got := NormalizeWaitUntil(in); got != want {
			t.Errorf("waitUntil %q: %q want %q", in, got, want)
		}
	}
	for _, pair := range v.Isolated {
		if got := isolatedExpression(pair[0]); got != pair[1] {
			t.Errorf("isolated %q: %q want %q", pair[0], got, pair[1])
		}
	}
}

func TestHumanMousePathEndsOnTarget(t *testing.T) {
	vp := Viewport{1280, 720}
	for i := 0; i < 50; i++ {
		path := HumanMousePath(Point{10, 10}, Point{900, 500}, vp)
		if len(path) < 12 || len(path) > 90 || path[0] != (Point{10, 10}) || path[len(path)-1] != (Point{900, 500}) {
			t.Fatalf("path %d points from %v to %v", len(path), path[0], path[len(path)-1])
		}
		for _, p := range path {
			if p.X < 0 || p.X > 1280 || p.Y < 0 || p.Y > 720 {
				t.Fatalf("point outside viewport %v", p)
			}
		}
	}
	if got := HumanMousePath(Point{5, 5}, Point{6, 5}, vp); len(got) != 2 {
		t.Fatalf("short move %v", got)
	}
}
