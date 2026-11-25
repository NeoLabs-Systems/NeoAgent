package behavior

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"math"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// SettingsKey is where an agent's behavior configuration is stored.
const SettingsKey = "behavior_modules_config"

// ModuleIDs are the behavior modules, in the order they run.
var ModuleIDs = []string{"turn_taking", "social_memory", "norms", "persona", "agent_identity", "channel_style", "social_signals", "social_observability", "delivery"}

const schemaVersion = 2

var (
	participationModes = map[string]bool{"automatic": true, "mention_only": true, "always": true}
	modelPurposes      = map[string]bool{"fast": true, "general": true}
	deliveryStyles     = map[string]bool{"single": true, "natural_bubbles": true}
)

// Leaf is one level of behavior configuration. A sparse leaf (an override)
// carries only the keys it was given.
type Leaf struct {
	sparse                       bool
	set                          map[string]bool
	Enabled                      bool
	Modules                      map[string]bool
	ParticipationMode            string
	MinimumNeedScore             float64
	BatchWindowMs                int
	DecisionContextMessageLimit  int
	DecisionModelID              *string
	DecisionModelPurpose         string
	DeliveryStyle                string
	MaxBubbles                   int
	BubbleGapMs                  int
	NormsRefreshMessageGap       int
	ObservabilityIntervalMinutes int
}

func (l *Leaf) has(key string) bool { return !l.sparse || l.set[key] }

var leafKeys = []string{"enabled", "modules", "participationMode", "minimumNeedScore", "batchWindowMs", "decisionContextMessageLimit", "decisionModelId",
	"decisionModelPurpose", "deliveryStyle", "maxBubbles", "bubbleGapMs", "normsRefreshMessageGap", "observabilityIntervalMinutes"}

func (l *Leaf) value(key string) any {
	switch key {
	case "enabled":
		return l.Enabled
	case "modules":
		return orderedModules(l.Modules)
	case "participationMode":
		return l.ParticipationMode
	case "minimumNeedScore":
		return json.RawMessage(dyn.Number(l.MinimumNeedScore))
	case "batchWindowMs":
		return l.BatchWindowMs
	case "decisionContextMessageLimit":
		return l.DecisionContextMessageLimit
	case "decisionModelId":
		return l.DecisionModelID
	case "decisionModelPurpose":
		return l.DecisionModelPurpose
	case "deliveryStyle":
		return l.DeliveryStyle
	case "maxBubbles":
		return l.MaxBubbles
	case "bubbleGapMs":
		return l.BubbleGapMs
	case "normsRefreshMessageGap":
		return l.NormsRefreshMessageGap
	case "observabilityIntervalMinutes":
		return l.ObservabilityIntervalMinutes
	}
	return nil
}

func (l *Leaf) fields() dyn.Ordered {
	var out dyn.Ordered
	for _, key := range leafKeys {
		if l.has(key) {
			out = append(out, dyn.KV{Key: key, Value: l.value(key)})
		}
	}
	return out
}

// MarshalJSON writes the keys in the Node server's order.
func (l Leaf) MarshalJSON() ([]byte, error) { return json.Marshal(l.fields()) }

func orderedModules(m map[string]bool) dyn.Ordered {
	out := dyn.Ordered{}
	for _, id := range ModuleIDs {
		if v, ok := m[id]; ok {
			out = append(out, dyn.KV{Key: id, Value: dyn.Ordered{{Key: "enabled", Value: v}}})
		}
	}
	return out
}

// Override is a platform or room override, in the order it was stored.
type Override struct {
	Key  string
	Leaf Leaf
}

type overrides []Override

func (o overrides) MarshalJSON() ([]byte, error) {
	out := dyn.Ordered{}
	for _, e := range o {
		out = append(out, dyn.KV{Key: e.Key, Value: e.Leaf})
	}
	return json.Marshal(out)
}

func (o overrides) find(key string) *Leaf {
	for i := range o {
		if o[i].Key == key {
			return &o[i].Leaf
		}
	}
	return nil
}

// Stored is the saved configuration.
type Stored struct {
	Leaf
	PlatformOverrides overrides
	RoomOverrides     overrides
}

// MarshalJSON writes the configuration as the Node server stored it.
func (s Stored) MarshalJSON() ([]byte, error) {
	out := dyn.Ordered{{Key: "schemaVersion", Value: schemaVersion}}
	out = append(out, s.Leaf.fields()...)
	out = append(out, dyn.KV{Key: "platformOverrides", Value: s.PlatformOverrides}, dyn.KV{Key: "roomOverrides", Value: s.RoomOverrides})
	return json.Marshal(out)
}

// Scope is the chat an effective configuration was resolved for.
type Scope struct {
	Platform *string `json:"platform"`
	ChatID   *string `json:"chatId"`
	IsGroup  bool    `json:"isGroup"`
	RoomKey  *string `json:"roomKey"`
}

// Effective is the configuration that applies to one chat.
type Effective struct {
	Leaf
	PlatformOverrides       overrides
	RoomOverrides           overrides
	ParticipationModeSource string
	Scope                   Scope
}

// MarshalJSON writes the configuration in the Node server's order.
func (e Effective) MarshalJSON() ([]byte, error) {
	out := e.Leaf.fields()
	out = append(out, dyn.KV{Key: "platformOverrides", Value: e.PlatformOverrides}, dyn.KV{Key: "roomOverrides", Value: e.RoomOverrides},
		dyn.KV{Key: "participationModeSource", Value: e.ParticipationModeSource}, dyn.KV{Key: "scope", Value: e.Scope})
	return json.Marshal(out)
}

// ModuleEnabled reports whether a module runs under this configuration.
func (e *Effective) ModuleEnabled(id string) bool {
	if e == nil || !e.Enabled {
		return false
	}
	v, ok := e.Modules[id]
	return ok && v
}

// Defaults is the configuration of an agent that never saved one.
func Defaults() Stored {
	modules := map[string]bool{}
	for _, id := range ModuleIDs {
		modules[id] = true
	}
	return Stored{Leaf: Leaf{Enabled: true, Modules: modules, ParticipationMode: "automatic", MinimumNeedScore: 0.58, BatchWindowMs: 900,
		DecisionContextMessageLimit: 12, DecisionModelPurpose: "general", DeliveryStyle: "natural_bubbles", MaxBubbles: 4, BubbleGapMs: 650,
		NormsRefreshMessageGap: 18, ObservabilityIntervalMinutes: 360}, PlatformOverrides: overrides{}, RoomOverrides: overrides{}}
}

// obj is a decoded JSON object with its key order.
type obj struct {
	keys   []string
	values map[string]any
	raw    map[string]json.RawMessage
}

func parseObj(raw json.RawMessage) obj {
	o := obj{values: map[string]any{}, raw: map[string]json.RawMessage{}}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] != '{' {
		return o
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	if _, err := dec.Token(); err != nil {
		return o
	}
	for dec.More() {
		t, err := dec.Token()
		if err != nil {
			return o
		}
		key, _ := t.(string)
		var value json.RawMessage
		if dec.Decode(&value) != nil {
			return o
		}
		if _, seen := o.raw[key]; !seen {
			o.keys = append(o.keys, key)
		}
		o.raw[key] = value
		var v any
		_ = json.Unmarshal(value, &v)
		o.values[key] = v
	}
	return o
}

func (o obj) present(key string) bool { _, ok := o.raw[key]; return ok }

// jsNumber is JavaScript's Number(v) for a JSON value; ok is false for NaN.
func jsNumber(v any, present bool) (float64, bool) {
	if !present {
		return 0, false
	}
	switch x := v.(type) {
	case nil:
		return 0, true
	case bool:
		if x {
			return 1, true
		}
		return 0, true
	case float64:
		return x, true
	case string:
		s := strings.TrimSpace(x)
		if s == "" {
			return 0, true
		}
		f, err := strconv.ParseFloat(s, 64)
		if err != nil || math.IsInf(f, 0) {
			return 0, false
		}
		return f, true
	}
	return 0, false
}

func clamp(o obj, key string, lo, hi, fallback float64) float64 {
	n, ok := jsNumber(o.values[key], o.present(key))
	if !ok {
		return fallback
	}
	return math.Min(hi, math.Max(lo, n))
}

func jsRound(f float64) int { return int(math.Floor(f + 0.5)) }

// jsTruthyString is String(v || ”).
func jsTruthyString(v any) string {
	if !dyn.Truthy(v) {
		return ""
	}
	return dyn.String(v)
}

func normalizeModules(raw any, fallback bool, sparse bool) map[string]bool {
	src, _ := raw.(map[string]any)
	out := map[string]bool{}
	for _, id := range ModuleIDs {
		entryRaw, present := src[id]
		if sparse && !present {
			continue
		}
		entry, _ := entryRaw.(map[string]any)
		if entry == nil || entry["enabled"] == nil {
			out[id] = fallback
		} else {
			out[id] = entry["enabled"] != false
		}
	}
	return out
}

func normalizeLeaf(o obj, base Leaf, sparse bool) Leaf {
	out := Leaf{sparse: sparse, set: map[string]bool{}}
	mark := func(key string) {
		if !sparse || o.present(key) {
			out.set[key] = true
		}
	}
	enabled := base.Enabled
	if o.values["enabled"] != nil {
		enabled = o.values["enabled"] != false
	}
	out.Enabled = enabled
	mark("enabled")
	if !sparse || o.present("modules") {
		out.Modules = normalizeModules(o.values["modules"], enabled, sparse)
		out.set["modules"] = true
	}
	out.ParticipationMode = base.ParticipationMode
	if mode := jsTruthyString(o.values["participationMode"]); participationModes[mode] {
		out.ParticipationMode = mode
	}
	mark("participationMode")
	out.MinimumNeedScore = clamp(o, "minimumNeedScore", 0, 1, base.MinimumNeedScore)
	mark("minimumNeedScore")
	out.BatchWindowMs = jsRound(clamp(o, "batchWindowMs", 0, 5000, float64(base.BatchWindowMs)))
	mark("batchWindowMs")
	out.DecisionContextMessageLimit = jsRound(clamp(o, "decisionContextMessageLimit", 4, 30, float64(base.DecisionContextMessageLimit)))
	mark("decisionContextMessageLimit")
	out.DecisionModelID = base.DecisionModelID
	if v := o.values["decisionModelId"]; v != nil {
		if s := strings.TrimSpace(dyn.String(v)); s != "" {
			out.DecisionModelID = &s
		} else {
			out.DecisionModelID = nil
		}
	}
	mark("decisionModelId")
	out.DecisionModelPurpose = base.DecisionModelPurpose
	if p := jsTruthyString(o.values["decisionModelPurpose"]); modelPurposes[p] {
		out.DecisionModelPurpose = p
	}
	mark("decisionModelPurpose")
	out.DeliveryStyle = base.DeliveryStyle
	if s := jsTruthyString(o.values["deliveryStyle"]); deliveryStyles[s] {
		out.DeliveryStyle = s
	}
	mark("deliveryStyle")
	out.MaxBubbles = jsRound(clamp(o, "maxBubbles", 1, 5, float64(base.MaxBubbles)))
	mark("maxBubbles")
	out.BubbleGapMs = jsRound(clamp(o, "bubbleGapMs", 0, 5000, float64(base.BubbleGapMs)))
	mark("bubbleGapMs")
	out.NormsRefreshMessageGap = jsRound(clamp(o, "normsRefreshMessageGap", 3, 200, float64(base.NormsRefreshMessageGap)))
	mark("normsRefreshMessageGap")
	out.ObservabilityIntervalMinutes = jsRound(clamp(o, "observabilityIntervalMinutes", 30, 10080, float64(base.ObservabilityIntervalMinutes)))
	mark("observabilityIntervalMinutes")
	if !sparse {
		out.set = nil
	}
	return out
}

func readOverrides(raw json.RawMessage, base Leaf) overrides {
	o := parseObj(raw)
	out := overrides{}
	for _, key := range o.keys {
		trimmed := strings.TrimSpace(key)
		if trimmed == "" {
			continue
		}
		leaf := normalizeLeaf(parseObj(o.raw[key]), base, true)
		if existing := out.find(trimmed); existing != nil {
			*existing = leaf
			continue
		}
		out = append(out, Override{Key: trimmed, Leaf: leaf})
	}
	return out
}

// NormalizeStored is normalizeStoredConfig: what gets saved for a raw config.
func NormalizeStored(raw json.RawMessage) Stored {
	o := parseObj(raw)
	if n, _ := jsNumber(o.values["schemaVersion"], o.present("schemaVersion")); n < 2 {
		score, ok := jsNumber(o.values["minimumNeedScore"], o.present("minimumNeedScore"))
		if o.values["minimumNeedScore"] == nil || (ok && score == 0.72) {
			o.values["minimumNeedScore"] = 0.58
			if !o.present("minimumNeedScore") {
				o.keys = append(o.keys, "minimumNeedScore")
			}
			o.raw["minimumNeedScore"] = json.RawMessage("0.58")
		}
	}
	defaults := Defaults()
	s := Stored{Leaf: normalizeLeaf(o, defaults.Leaf, false)}
	s.PlatformOverrides = readOverrides(o.raw["platformOverrides"], s.Leaf)
	rooms := o.raw["roomOverrides"]
	if len(parseObj(rooms).keys) == 0 {
		rooms = o.raw["groupOverrides"]
	}
	s.RoomOverrides = readOverrides(rooms, s.Leaf)
	return s
}

// Store reads and writes behavior configurations.
type Store struct {
	DB     *dbx.DB
	agents agentscope.Resolver
}

// NewStore creates a store.
func NewStore(db *dbx.DB) *Store { return &Store{DB: db, agents: agentscope.Resolver{DB: db}} }

func (s *Store) row(ctx context.Context, userID int64, agentID string) (string, bool) {
	var raw sql.NullString
	err := s.DB.R.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`, userID, agentID, SettingsKey).Scan(&raw)
	if err == nil && raw.Valid {
		return raw.String, true
	}
	if main, _ := s.agents.IsMain(ctx, userID, agentID); main {
		if s.DB.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, SettingsKey).Scan(&raw) == nil && raw.Valid {
			return raw.String, true
		}
	}
	return "", false
}

func parseStored(value string, present bool) Stored {
	if !present || value == "" || !json.Valid([]byte(value)) {
		return Defaults()
	}
	return NormalizeStored(json.RawMessage(value))
}

// Get returns the agent's saved configuration (getBehaviorConfig).
func (s *Store) Get(ctx context.Context, userID int64, agentID string) Stored {
	return parseStored(s.row(ctx, userID, agentID))
}

// Set normalizes and saves a configuration (setBehaviorConfig).
func (s *Store) Set(ctx context.Context, userID int64, agentID string, raw json.RawMessage) (Stored, error) {
	normalized := NormalizeStored(raw)
	text, _ := json.Marshal(normalized)
	_, err := s.DB.W.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)
		ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`, userID, agentID, SettingsKey, string(text))
	return normalized, err
}

// RoomKey names a room in roomOverrides.
func RoomKey(platform, chatID string) string {
	return strings.TrimSpace(platform) + "::" + strings.TrimSpace(chatID)
}

func merge(base Leaf, o *Leaf) Leaf {
	out := base
	out.Modules = map[string]bool{}
	for k, v := range base.Modules {
		out.Modules[k] = v
	}
	for _, key := range leafKeys {
		if !o.has(key) {
			continue
		}
		switch key {
		case "enabled":
			out.Enabled = o.Enabled
		case "modules":
			for k, v := range o.Modules {
				out.Modules[k] = v
			}
		case "participationMode":
			out.ParticipationMode = o.ParticipationMode
		case "minimumNeedScore":
			out.MinimumNeedScore = o.MinimumNeedScore
		case "batchWindowMs":
			out.BatchWindowMs = o.BatchWindowMs
		case "decisionContextMessageLimit":
			out.DecisionContextMessageLimit = o.DecisionContextMessageLimit
		case "decisionModelId":
			out.DecisionModelID = o.DecisionModelID
		case "decisionModelPurpose":
			out.DecisionModelPurpose = o.DecisionModelPurpose
		case "deliveryStyle":
			out.DeliveryStyle = o.DeliveryStyle
		case "maxBubbles":
			out.MaxBubbles = o.MaxBubbles
		case "bubbleGapMs":
			out.BubbleGapMs = o.BubbleGapMs
		case "normsRefreshMessageGap":
			out.NormsRefreshMessageGap = o.NormsRefreshMessageGap
		case "observabilityIntervalMinutes":
			out.ObservabilityIntervalMinutes = o.ObservabilityIntervalMinutes
		}
	}
	return out
}

// Resolve is resolveBehaviorConfig: the configuration for one chat.
func (s *Store) Resolve(ctx context.Context, userID int64, agentID, platform, chatID string, isGroup bool) *Effective {
	value, present := s.row(ctx, userID, agentID)
	return resolve(parseStored(value, present), present, platform, chatID, isGroup)
}

func resolve(stored Stored, present bool, platform, chatID string, isGroup bool) *Effective {
	// normalizeLeafConfig of a normalized config is the config itself.
	leaf := stored.Leaf
	leaf.sparse, leaf.set = false, nil
	source := "default"
	if present {
		source = "agent"
	}
	platform = strings.TrimSpace(platform)
	if platform != "" {
		if o := stored.PlatformOverrides.find(platform); o != nil {
			leaf = merge(leaf, o)
			if o.has("participationMode") {
				source = "platform"
			}
		}
	}
	scope := Scope{IsGroup: isGroup}
	if platform != "" {
		scope.Platform = &platform
	}
	if chatID != "" {
		scope.ChatID = &chatID
	}
	if isGroup && platform != "" && chatID != "" {
		key := RoomKey(platform, chatID)
		scope.RoomKey = &key
		if o := stored.RoomOverrides.find(key); o != nil {
			leaf = merge(leaf, o)
			if o.has("participationMode") {
				source = "room"
			}
		}
	}
	modules := map[string]any{}
	for k, v := range leaf.Modules {
		modules[k] = map[string]any{"enabled": v}
	}
	leaf.Modules = normalizeModules(modules, leaf.Enabled, false)
	return &Effective{Leaf: leaf, PlatformOverrides: stored.PlatformOverrides, RoomOverrides: stored.RoomOverrides, ParticipationModeSource: source, Scope: scope}
}
