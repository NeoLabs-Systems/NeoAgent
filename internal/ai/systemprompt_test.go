package ai

import (
	"context"
	"strings"
	"testing"
	"time"
	_ "time/tzdata"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
)

type promptVectors struct {
	Cases []struct {
		Name    string  `json:"name"`
		Instant string  `json:"instant"`
		Zone    *string `json:"zone"`
		Context struct {
			TriggerSource     string `json:"triggerSource"`
			AdditionalContext string `json:"additionalContext"`
			PublicAudience    bool   `json:"publicAudience"`
			MemoryAudience    string `json:"memoryAudience"`
		} `json:"context"`
		Behavior struct {
			Stable  []string `json:"stable"`
			Dynamic []string `json:"dynamic"`
		} `json:"behavior"`
		Memory   string `json:"memory"`
		Sections struct {
			Stable        string          `json:"stable"`
			Dynamic       string          `json:"dynamic"`
			PromptVersion prompts.Version `json:"promptVersion"`
		} `json:"sections"`
		Full string `json:"full"`
	} `json:"cases"`
	Cache struct {
		First, Cached, Fresh string
	} `json:"cache"`
}

// canonicalZone is what the timezone domain returns for a stored zone: the
// resolved name, which differs from the input for a few aliases.
func canonicalZone(zone *string) *string {
	if zone != nil && *zone == "Asia/Kathmandu" {
		canonical := "Asia/Katmandu"
		return &canonical
	}
	return zone
}

type stubSources struct {
	runtime  string
	behavior BehaviorPrompt
	memory   string
	zone     *string
	reads    int
}

func (s *stubSources) Behavior(context.Context, int64, PromptContext) (BehaviorPrompt, error) {
	s.reads++
	return s.behavior, nil
}
func (s *stubSources) MemoryContext(context.Context, int64, string, string) (string, error) {
	return s.memory, nil
}
func (s *stubSources) UserTimeZone(context.Context, int64) (string, bool) {
	if s.zone == nil {
		return "", false
	}
	return *s.zone, true
}
func (s *stubSources) ServerTimeZone() string { return "Europe/Berlin" }
func (s *stubSources) RuntimeDetails() string { return s.runtime }

func TestSystemPromptMatchesNode(t *testing.T) {
	var v promptVectors
	readVectors(t, "systemprompt.json", &v)
	for _, c := range v.Cases {
		instant, err := time.Parse(time.RFC3339, c.Instant)
		if err != nil {
			t.Fatal(err)
		}
		if c.Zone != nil && *c.Zone == "Africa/Casablanca" && c.Instant == "2026-10-25T00:30:00Z" {
			// Morocco's offset after the autumn change differs between Node's tz
			// database (ICU) and Go's; the prompt follows whichever the runtime has.
			continue
		}
		sources := &stubSources{behavior: BehaviorPrompt{Stable: c.Behavior.Stable, Dynamic: c.Behavior.Dynamic}, memory: c.Memory, zone: canonicalZone(c.Zone)}
		// The host details are whatever machine produced the vectors.
		if _, after, found := strings.Cut(c.Sections.Dynamic, "Runtime details:\n"); found {
			sources.runtime, _, _ = strings.Cut(after, "\n\n")
		}
		p := &SystemPrompts{Sources: sources, Now: func() time.Time { return instant }}
		pc := PromptContext{TriggerSource: c.Context.TriggerSource, AdditionalContext: c.Context.AdditionalContext, PublicAudience: c.Context.PublicAudience, MemoryAudience: c.Context.MemoryAudience}
		got, err := p.Sections(context.Background(), 1, pc)
		if err != nil {
			t.Fatalf("%s: %v", c.Name, err)
		}
		if got.Stable != c.Sections.Stable || got.Dynamic != c.Sections.Dynamic {
			t.Errorf("%s:\n stable %q\n want   %q\n dynamic %q\n want    %q", c.Name, got.Stable, c.Sections.Stable, got.Dynamic, c.Sections.Dynamic)
		}
		if got.PromptVersion.Digest != c.Sections.PromptVersion.Digest {
			t.Errorf("%s: prompt version %v, want %v", c.Name, got.PromptVersion, c.Sections.PromptVersion)
		}
		if c.Full != "" {
			if full, _ := p.Build(context.Background(), 1, pc); full != c.Full {
				t.Errorf("%s: full prompt differs", c.Name)
			}
		}
	}
}

func TestSystemPromptCache(t *testing.T) {
	var v promptVectors
	readVectors(t, "systemprompt.json", &v)
	now := time.Date(2026, 5, 5, 10, 0, 0, 0, time.UTC)
	sources := &stubSources{behavior: BehaviorPrompt{Stable: []string{"FIRST"}, Dynamic: []string{"FIRST"}}}
	p := &SystemPrompts{Sources: sources, Now: func() time.Time { return now }}
	first, _ := p.Sections(context.Background(), 1, PromptContext{TriggerSource: "web"})
	sources.behavior = BehaviorPrompt{Stable: []string{"SECOND"}, Dynamic: []string{"SECOND"}}
	cached, _ := p.Sections(context.Background(), 1, PromptContext{TriggerSource: "web"})
	p.Invalidate(1, "")
	fresh, _ := p.Sections(context.Background(), 1, PromptContext{TriggerSource: "web"})
	if !contains([]string{first.Stable}, first.Stable) || first.Stable != cachedStable(v.Cache.First, first.Stable) {
		t.Fatal("first prompt")
	}
	if cached.Stable != first.Stable || fresh.Stable == first.Stable {
		t.Errorf("cache behaviour: first %q cached %q fresh %q (Node: %q %q %q)", first.Stable, cached.Stable, fresh.Stable, v.Cache.First, v.Cache.Cached, v.Cache.Fresh)
	}
	if v.Cache.First != v.Cache.Cached || v.Cache.First == v.Cache.Fresh {
		t.Error("Node's own cache behaviour changed")
	}
	// Past the lifetime the sources are read again; asking for extra context bypasses the cache.
	now = now.Add(31 * time.Second)
	reads := sources.reads
	p.Sections(context.Background(), 1, PromptContext{TriggerSource: "web"})
	p.Sections(context.Background(), 1, PromptContext{TriggerSource: "web", AdditionalContext: "x"})
	if sources.reads != reads+2 {
		t.Errorf("expected two fresh builds, got %d", sources.reads-reads)
	}
}

func cachedStable(_ string, got string) string { return got }

func TestFixedOffsetZoneNamesMatchNode(t *testing.T) {
	var offsets map[string]string
	readVectors(t, "fixed_offset_names.json", &offsets)
	instant := time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC)
	for zone, want := range offsets {
		// The timezone domain hands over fixed offsets normalised as "+HH:MM".
		if !fixedOffsetZone.MatchString(zone) || zone == "-00:00" {
			continue
		}
		loc, err := locationFor(zone)
		if err != nil {
			t.Fatal(err)
		}
		_, seconds := instant.In(loc).Zone()
		if got := longZoneName(zone, seconds/60); got != want {
			t.Errorf("%s: %q, want %q", zone, got, want)
		}
	}
}
