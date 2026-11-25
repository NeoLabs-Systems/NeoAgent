package memory

import (
	"math"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

var protectedCategories = map[string]bool{"identity": true, "preferences": true, "assistant_self": true}

// Retention holds the memories columns that decide how fast a memory fades.
// A NULL column reads as zero here, as Number(null) does in JavaScript.
type Retention struct {
	Pinned         float64 `json:"pinned"`
	Category       string  `json:"category"`
	Importance     float64 `json:"importance"`
	Archived       float64 `json:"archived"`
	Strength       float64 `json:"memory_strength"`
	StaleAfterDays float64 `json:"stale_after_days"`
	LastAccessedAt string  `json:"last_accessed_at"`
	UpdatedAt      string  `json:"updated_at"`
	CreatedAt      string  `json:"created_at"`
}

const msPerDay = 1000 * 60 * 60 * 24

func clamp(value, min, max, fallback float64) float64 {
	if !jsx.IsFinite(value) {
		return fallback
	}
	return math.Max(min, math.Min(max, value))
}

// ageDaysSince is how many days ago a stored timestamp was; 0 when unreadable.
func ageDaysSince(value string, nowMs int64) float64 {
	ts, ok := parseTimestamp(value)
	if !ok || ts == 0 {
		return 0
	}
	return math.Max(0, float64(nowMs-ts)/msPerDay)
}

// IsPinned is true for memories that never fade.
func (m Retention) IsPinned() bool {
	return m.Pinned == 1 || protectedCategories[m.Category] || m.Importance >= 9
}

func firstSet(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// DecayedStrength is the memory strength after fading with age.
func (m Retention) DecayedStrength(nowMs int64) float64 {
	strength := clamp(m.Strength, 0.05, 2, 1)
	if m.IsPinned() {
		return strength
	}
	halfLifeDays := clamp(m.StaleAfterDays, 14, 365, 90)
	age := ageDaysSince(firstSet(m.LastAccessedAt, m.UpdatedAt, m.CreatedAt), nowMs)
	return clamp(strength*math.Pow(0.5, age/halfLifeDays), 0.01, 2, strength)
}

// RetentionScoreMultiplier scales a recall score by how much the memory faded.
func (m Retention) RetentionScoreMultiplier(nowMs int64) float64 {
	if m.IsPinned() {
		return 1.04
	}
	return clamp(0.82+m.DecayedStrength(nowMs)*0.14, 0.65, 1.08, 1)
}

// ReinforcedStrength is the strength after the memory was recalled once.
func (m Retention) ReinforcedStrength() float64 {
	current := clamp(m.Strength, 0.05, 2, 1)
	importanceBoost := clamp(m.Importance, 1, 10, 5) / 250
	return clamp(current+0.06+importanceBoost, 0.05, 2, 1.08)
}

// ArchiveOptions tune IsArchiveEligible. Nil fields use the defaults.
type ArchiveOptions struct {
	NowMs             int64
	MinAgeDays        *float64
	StrengthThreshold *float64
}

func optionOr(value *float64) float64 {
	if value == nil {
		return math.NaN()
	}
	return *value
}

// IsArchiveEligible says whether a weak, old, unpinned memory may be archived.
func (m Retention) IsArchiveEligible(o ArchiveOptions) bool {
	if m.IsPinned() || m.Archived == 1 || m.Importance >= 8 {
		return false
	}
	minAgeDays := clamp(optionOr(o.MinAgeDays), 1, 365, 45)
	threshold := clamp(optionOr(o.StrengthThreshold), 0.01, 1, 0.18)
	age := ageDaysSince(firstSet(m.UpdatedAt, m.CreatedAt), o.NowMs)
	return age >= minAgeDays && m.DecayedStrength(o.NowMs) < threshold
}
