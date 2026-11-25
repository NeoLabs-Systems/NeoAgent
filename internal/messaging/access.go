package messaging

import (
	"encoding/json"
	"fmt"
	"math"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"unicode"
)

// The access policy: who may talk to an agent on a platform. The JSON it
// stores and sends is key-for-key what clients and existing rows expect.

const accessPolicySchemaVersion = 3

// Capabilities describes what a platform's access policy can express. Its JSON
// is what GET /:platform/access-policy returns under "capabilities".
type Capabilities struct {
	SupportsDirectPolicy        bool     `json:"supportsDirectPolicy"`
	SupportsSharedPolicy        bool     `json:"supportsSharedPolicy"`
	SupportsMentionGate         bool     `json:"supportsMentionGate"`
	SupportsUntaggedGroupToggle bool     `json:"supportsUntaggedGroupToggle"`
	SupportsDiscovery           bool     `json:"supportsDiscovery"`
	DirectRuleScopes            []string `json:"directRuleScopes"`
	SharedSpaceRuleScopes       []string `json:"sharedSpaceRuleScopes"`
	SharedActorRuleScopes       []string `json:"sharedActorRuleScopes"`
	ManualEntryHint             string   `json:"manualEntryHint"`
	// SharedModes are the modes the owner may pick for shared spaces. Public
	// platforms drop "open".
	SharedModes []string `json:"sharedModes"`
	// RequireSharedActor: a shared-space rule only says where the agent
	// listens; every sender still needs a person or member rule of their own.
	RequireSharedActor bool `json:"requireSharedActor"`
	// MentionOnly: the agent answers shared spaces only when addressed.
	MentionOnly bool `json:"mentionOnly"`
	// SpaceNoun is what the owner calls a shared space on this platform.
	SpaceNoun *string `json:"spaceNoun"`
}

var (
	accessModes        = []string{"allowlist", "open", "disabled"}
	ruleScopes         = []string{"user", "dm", "chat", "group", "channel", "server", "room", "role", "phone_number"}
	directRuleScopes   = []string{"user", "dm", "chat", "phone_number"}
	sharedSpaceScopes  = []string{"chat", "group", "channel", "server", "room"}
	sharedActorScopes  = []string{"user", "role", "phone_number"}
	sharedRawIDPlatfms = []string{"slack", "google_chat", "teams", "matrix", "mattermost", "irc", "twitch", "feishu", "nextcloud_talk", "nostr", "synology_chat", "tlon", "zalo", "wechat", "webchat"}
)

const defaultManualHint = "Use a person, group, channel, room, server, or role."

func capabilityTemplate(mutate func(*Capabilities)) Capabilities {
	c := Capabilities{
		SupportsDirectPolicy:        true,
		SupportsSharedPolicy:        true,
		SupportsUntaggedGroupToggle: true,
		DirectRuleScopes:            directRuleScopes,
		SharedSpaceRuleScopes:       sharedSpaceScopes,
		SharedActorRuleScopes:       sharedActorScopes,
		ManualEntryHint:             defaultManualHint,
		SharedModes:                 accessModes,
	}
	if mutate != nil {
		mutate(&c)
	}
	return c
}

// scoped builds the common override: mention gate plus the three scope lists.
func scoped(mention, discovery bool, direct, space, actor []string, hint string) func(*Capabilities) {
	return func(c *Capabilities) {
		c.SupportsMentionGate = mention
		c.SupportsDiscovery = discovery
		c.DirectRuleScopes = direct
		c.SharedSpaceRuleScopes = space
		c.SharedActorRuleScopes = actor
		if hint != "" {
			c.ManualEntryHint = hint
		}
	}
}

func noDiscovery() func(*Capabilities) { return func(c *Capabilities) { c.SupportsDiscovery = false } }

var platformCapabilities = map[string]Capabilities{
	"whatsapp":    capabilityTemplate(scoped(true, true, []string{"phone_number", "user", "chat"}, []string{"group", "chat"}, []string{"phone_number", "user"}, "Use a phone number or the group's WhatsApp ID.")),
	"discord":     capabilityTemplate(scoped(true, true, []string{"user", "dm"}, []string{"channel", "server"}, []string{"user", "role"}, "Use a Discord user, channel, server, or role.")),
	"telegram":    capabilityTemplate(scoped(true, true, []string{"user", "dm"}, []string{"group", "chat"}, []string{"user"}, "Use a Telegram username, user ID, or group chat ID.")),
	"slack":       capabilityTemplate(scoped(true, false, []string{"user", "chat"}, []string{"channel", "chat"}, []string{"user"}, "Use a Slack person or channel.")),
	"google_chat": capabilityTemplate(scoped(true, false, []string{"user", "chat"}, []string{"room", "chat"}, []string{"user"}, "")),
	"teams":       capabilityTemplate(scoped(true, false, []string{"user", "chat"}, []string{"channel", "chat"}, []string{"user"}, "")),
	"matrix":      capabilityTemplate(scoped(true, false, []string{"user", "chat"}, []string{"room", "chat"}, []string{"user"}, "")),
	"signal":      capabilityTemplate(scoped(true, false, []string{"phone_number", "user", "chat"}, []string{"group", "chat"}, []string{"phone_number", "user"}, "")),
	"imessage":    capabilityTemplate(scoped(false, false, []string{"user", "chat"}, []string{"chat"}, []string{"user"}, "")),
	"bluebubbles": capabilityTemplate(scoped(false, false, []string{"user", "chat"}, []string{"chat"}, []string{"user"}, "")),
	"irc":         capabilityTemplate(scoped(true, false, []string{"user", "chat"}, []string{"channel", "chat"}, []string{"user"}, "")),
	"twitch":      capabilityTemplate(scoped(true, false, []string{"user", "chat"}, []string{"channel", "chat"}, []string{"user"}, "")),
	"line":        capabilityTemplate(scoped(false, false, []string{"user", "chat"}, []string{"group", "room", "chat"}, []string{"user"}, "")),
	"mattermost":  capabilityTemplate(scoped(false, false, []string{"user", "chat"}, []string{"channel", "chat"}, []string{"user"}, "")),
	// GitHub threads are public: anyone can comment, so a repository rule never
	// admits commenters on its own and "anyone" is not offered.
	"github": capabilityTemplate(func(c *Capabilities) {
		c.SupportsDirectPolicy = false
		c.SupportsMentionGate = true
		c.SupportsUntaggedGroupToggle = false
		c.SupportsDiscovery = true
		c.DirectRuleScopes = []string{}
		c.SharedSpaceRuleScopes = []string{"group"}
		c.SharedActorRuleScopes = []string{"user", "role"}
		c.SharedModes = []string{"allowlist", "disabled"}
		c.RequireSharedActor = true
		c.MentionOnly = true
		noun := "repository"
		c.SpaceNoun = &noun
		c.ManualEntryHint = "Use a repository (owner/repo), a GitHub user ID, or a role such as COLLABORATOR."
	}),
	"feishu":         capabilityTemplate(noDiscovery()),
	"nextcloud_talk": capabilityTemplate(noDiscovery()),
	"nostr":          capabilityTemplate(noDiscovery()),
	"synology_chat":  capabilityTemplate(noDiscovery()),
	"tlon":           capabilityTemplate(noDiscovery()),
	"zalo":           capabilityTemplate(noDiscovery()),
	"zalo_personal": capabilityTemplate(func(c *Capabilities) {
		c.SupportsDiscovery = false
		c.DirectRuleScopes = []string{"user", "chat"}
		c.SharedSpaceRuleScopes = []string{"chat"}
	}),
	"wechat":  capabilityTemplate(noDiscovery()),
	"webchat": capabilityTemplate(noDiscovery()),
}

// AccessPolicyKey is the settings key a platform's policy is stored under.
func AccessPolicyKey(platform string) string {
	return "platform_access_policy_" + jsTrim(platform)
}

// LegacyWhitelistKey is the settings key of the older allow-list.
func LegacyWhitelistKey(platform string) string {
	return "platform_whitelist_" + jsTrim(platform)
}

// PlatformCapabilities returns what a platform's policy can express.
func PlatformCapabilities(platform string) Capabilities {
	if c, ok := platformCapabilities[jsTrim(platform)]; ok {
		return c
	}
	return capabilityTemplate(nil)
}

// Rule is one approved person or space.
type Rule struct {
	Scope string `json:"scope"`
	Value string `json:"value"`
	Label string `json:"label,omitempty"`
}

// MemberRule approves a person inside one space only.
type MemberRule struct {
	Rule
	SpaceScope string `json:"spaceScope"`
	SpaceValue string `json:"spaceValue"`
	SpaceLabel string `json:"spaceLabel,omitempty"`
}

// ParticipationRule says whether the agent joins a space untagged.
type ParticipationRule struct {
	Rule
	AllowUntagged bool `json:"allowUntagged"`
}

// AccessPolicy is a normalized policy. Slices are never nil, so the JSON has
// arrays where Node had them.
type AccessPolicy struct {
	SchemaVersion                int                 `json:"schemaVersion"`
	DirectPolicy                 string              `json:"directPolicy"`
	SharedPolicy                 string              `json:"sharedPolicy"`
	DefaultAllowUntaggedInShared bool                `json:"defaultAllowUntaggedInShared"`
	DirectRules                  []Rule              `json:"directRules"`
	SharedSpaceRules             []Rule              `json:"sharedSpaceRules"`
	SharedActorRules             []Rule              `json:"sharedActorRules"`
	SharedMemberRules            []MemberRule        `json:"sharedMemberRules"`
	SharedParticipationRules     []ParticipationRule `json:"sharedParticipationRules"`
}

// DefaultAccessPolicy is the policy of an agent nobody has configured.
func DefaultAccessPolicy(platform string) AccessPolicy {
	caps := PlatformCapabilities(platform)
	shared := "disabled"
	if caps.SupportsSharedPolicy {
		shared = "allowlist"
	}
	return AccessPolicy{
		SchemaVersion:                accessPolicySchemaVersion,
		DirectPolicy:                 "allowlist",
		SharedPolicy:                 shared,
		DefaultAllowUntaggedInShared: !caps.SupportsUntaggedGroupToggle && !caps.MentionOnly,
		DirectRules:                  []Rule{},
		SharedSpaceRules:             []Rule{},
		SharedActorRules:             []Rule{},
		SharedMemberRules:            []MemberRule{},
		SharedParticipationRules:     []ParticipationRule{},
	}
}

// --- JavaScript value semantics -------------------------------------------

// jsSpace is what String.prototype.trim removes.
func jsSpace(r rune) bool {
	return unicode.IsSpace(r) || r == '\uFEFF' || r == '\u00A0' || r == '\u2028' || r == '\u2029'
}

func jsTrim(s string) string { return strings.TrimFunc(s, jsSpace) }

// jsOrEmpty is String(value || ”): a falsy value reads as "".
func jsOrEmpty(v any) string {
	switch v := v.(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		if v {
			return "true"
		}
		return ""
	case float64:
		if v == 0 || math.IsNaN(v) {
			return ""
		}
		return jsNumber(v)
	case []any:
		parts := make([]string, len(v))
		for i, item := range v {
			if item != nil {
				parts[i] = jsOrEmpty(item)
				if s, ok := item.(float64); ok && s == 0 {
					parts[i] = "0"
				}
				if b, ok := item.(bool); ok && !b {
					parts[i] = "false"
				}
			}
		}
		return strings.Join(parts, ",")
	default:
		return "[object Object]"
	}
}

func jsNumber(f float64) string {
	if f == math.Trunc(f) && math.Abs(f) < 1e21 {
		return strconv.FormatFloat(f, 'f', -1, 64)
	}
	return strconv.FormatFloat(f, 'g', -1, 64)
}

// jsNumeric is Number(value || 0).
func jsNumeric(v any) float64 {
	switch v := v.(type) {
	case float64:
		return v
	case string:
		s := jsTrim(v)
		if s == "" {
			return 0
		}
		f, err := strconv.ParseFloat(s, 64)
		if err != nil {
			return math.NaN()
		}
		return f
	case bool:
		if v {
			return 1
		}
		return 0
	case nil:
		return 0
	}
	return math.NaN()
}

var controlChars = regexp.MustCompile(`[\x00-\x1f\x7f]`)

func sanitizeValue(scope, value string) string {
	if scope == "phone_number" {
		return jsTrim(strings.Map(func(r rune) rune {
			if (r >= '0' && r <= '9') || r == '+' {
				return r
			}
			return -1
		}, value))
	}
	return jsTrim(controlChars.ReplaceAllString(value, ""))
}

func normalizeScope(scope any) string {
	s := strings.ToLower(jsTrim(jsOrEmpty(scope)))
	switch s {
	case "guild":
		return "server"
	case "phone":
		return "phone_number"
	}
	return s
}

func normalizeMode(value any, fallback string) string {
	s := strings.ToLower(jsTrim(jsOrEmpty(value)))
	if slices.Contains(accessModes, s) {
		return s
	}
	return fallback
}

func asMap(v any) (map[string]any, bool) {
	m, ok := v.(map[string]any)
	return m, ok
}

func asList(v any) []any {
	l, _ := v.([]any)
	return l
}

func normalizeRule(raw any, allowed []string) (Rule, bool) {
	m, ok := asMap(raw)
	if !ok {
		return Rule{}, false
	}
	scope := normalizeScope(m["scope"])
	if !slices.Contains(ruleScopes, scope) || !slices.Contains(allowed, scope) {
		return Rule{}, false
	}
	value := sanitizeValue(scope, jsOrEmpty(m["value"]))
	if value == "" {
		return Rule{}, false
	}
	return Rule{Scope: scope, Value: value, Label: jsTrim(jsOrEmpty(m["label"]))}, true
}

func ruleKey(r Rule, spaceScope, spaceValue string) string {
	return r.Scope + ":" + r.Value + ":" + spaceScope + ":" + spaceValue
}

func normalizeRules(raw []any, allowed []string) []Rule {
	out := []Rule{}
	seen := map[string]bool{}
	for _, item := range raw {
		rule, ok := normalizeRule(item, allowed)
		if !ok || seen[ruleKey(rule, "", "")] {
			continue
		}
		seen[ruleKey(rule, "", "")] = true
		out = append(out, rule)
	}
	return out
}

func normalizeMemberRule(raw any, actorScopes, spaceScopes []string) (MemberRule, bool) {
	rule, ok := normalizeRule(raw, actorScopes)
	if !ok {
		return MemberRule{}, false
	}
	m, _ := asMap(raw)
	spaceScope := normalizeScope(m["spaceScope"])
	if !slices.Contains(ruleScopes, spaceScope) || !slices.Contains(spaceScopes, spaceScope) {
		return MemberRule{}, false
	}
	spaceValue := sanitizeValue(spaceScope, jsOrEmpty(m["spaceValue"]))
	if spaceValue == "" {
		return MemberRule{}, false
	}
	return MemberRule{Rule: rule, SpaceScope: spaceScope, SpaceValue: spaceValue, SpaceLabel: jsTrim(jsOrEmpty(m["spaceLabel"]))}, true
}

// NormalizeAccessPolicy turns whatever was stored or submitted (decoded JSON)
// into a valid policy for the platform.
func NormalizeAccessPolicy(platform string, value any) AccessPolicy {
	caps := PlatformCapabilities(platform)
	defaults := DefaultAccessPolicy(platform)
	raw, _ := asMap(value)
	if raw == nil {
		raw = map[string]any{}
	}
	rawSpace := asList(raw["sharedSpaceRules"])
	rawActor := asList(raw["sharedActorRules"])
	rawMember := asList(raw["sharedMemberRules"])
	rawParticipation := asList(raw["sharedParticipationRules"])
	rawShared := raw["sharedPolicy"]
	schemaVersion := jsNumeric(raw["schemaVersion"])
	legacyParticipation := schemaVersion < 3

	if schemaVersion < 2 && len(rawMember) == 0 && len(rawActor) > 0 && normalizeMode(rawShared, defaults.SharedPolicy) == "open" {
		rawShared = "allowlist"
		rawSpace = nil
	}
	if schemaVersion < 2 && len(rawMember) == 0 && len(rawActor) > 0 && len(rawSpace) > 0 && normalizeMode(rawShared, defaults.SharedPolicy) == "allowlist" {
		var members []any
		for _, space := range rawSpace {
			spaceMap, _ := asMap(space)
			for _, actor := range rawActor {
				member := map[string]any{}
				if actorMap, ok := asMap(actor); ok {
					for k, v := range actorMap {
						member[k] = v
					}
				}
				member["spaceScope"] = spaceMap["scope"]
				member["spaceValue"] = spaceMap["value"]
				member["spaceLabel"] = spaceMap["label"]
				members = append(members, member)
			}
		}
		rawMember = members
		rawSpace = nil
		rawActor = nil
	}

	shared := normalizeMode(rawShared, defaults.SharedPolicy)
	if !slices.Contains(caps.SharedModes, shared) {
		shared = "allowlist"
	}
	p := AccessPolicy{
		SchemaVersion:            accessPolicySchemaVersion,
		DirectPolicy:             normalizeMode(raw["directPolicy"], defaults.DirectPolicy),
		SharedPolicy:             shared,
		DirectRules:              normalizeRules(asList(raw["directRules"]), caps.DirectRuleScopes),
		SharedSpaceRules:         normalizeRules(rawSpace, caps.SharedSpaceRuleScopes),
		SharedActorRules:         normalizeRules(rawActor, caps.SharedActorRuleScopes),
		SharedMemberRules:        []MemberRule{},
		SharedParticipationRules: []ParticipationRule{},
	}
	switch {
	case !caps.SupportsUntaggedGroupToggle:
		p.DefaultAllowUntaggedInShared = true
	case legacyParticipation:
		p.DefaultAllowUntaggedInShared = raw["requireMentionInShared"] != true
	default:
		p.DefaultAllowUntaggedInShared = raw["defaultAllowUntaggedInShared"] == true
	}
	seen := map[string]bool{}
	for _, item := range rawMember {
		rule, ok := normalizeMemberRule(item, caps.SharedActorRuleScopes, caps.SharedSpaceRuleScopes)
		key := ruleKey(rule.Rule, rule.SpaceScope, rule.SpaceValue)
		if !ok || seen[key] {
			continue
		}
		seen[key] = true
		p.SharedMemberRules = append(p.SharedMemberRules, rule)
	}
	seen = map[string]bool{}
	for _, item := range rawParticipation {
		rule, ok := normalizeRule(item, caps.SharedSpaceRuleScopes)
		if !ok || seen[ruleKey(rule, "", "")] {
			continue
		}
		seen[ruleKey(rule, "", "")] = true
		m, _ := asMap(item)
		p.SharedParticipationRules = append(p.SharedParticipationRules, ParticipationRule{Rule: rule, AllowUntagged: m["allowUntagged"] == true})
	}
	if !caps.SupportsSharedPolicy {
		p.SharedPolicy = "disabled"
		p.DefaultAllowUntaggedInShared = true
		p.SharedSpaceRules = []Rule{}
		p.SharedActorRules = []Rule{}
		p.SharedMemberRules = []MemberRule{}
		p.SharedParticipationRules = []ParticipationRule{}
	}
	if caps.MentionOnly {
		p.DefaultAllowUntaggedInShared = false
		p.SharedParticipationRules = []ParticipationRule{}
	}
	return p
}

// Normalize runs an already-typed policy through the platform's rules again.
func (p AccessPolicy) Normalize(platform string) AccessPolicy {
	return NormalizeAccessPolicy(platform, toJSONValue(p))
}

// toJSONValue is the decoded-JSON form of v.
func toJSONValue(v any) any {
	raw, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var out any
	_ = json.Unmarshal(raw, &out)
	return out
}

// --- Legacy allow-list migration -------------------------------------------

var prefixedEntryRe = regexp.MustCompile(`(?i)^([a-z_]+):((?s:.*))$`)

func isWhatsAppGroupID(value string) bool {
	head, _, _ := strings.Cut(strings.ToLower(jsTrim(value)), ":")
	return strings.HasSuffix(head, "@g.us")
}

func digitsOnly(s string) string {
	return strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, s)
}

func normalizeWhatsAppDirectID(value string) string {
	raw := strings.ToLower(jsTrim(value))
	base := raw
	if strings.Contains(raw, "@") {
		base, _, _ = strings.Cut(raw, "@")
	}
	primary := base
	if strings.Contains(base, ":") {
		primary, _, _ = strings.Cut(base, ":")
	}
	if d := digitsOnly(primary); d != "" {
		return d
	}
	return primary
}

type legacyState struct {
	direct, space, actor []Rule
}

func (s *legacyState) add(bucket *[]Rule, scope, value string, allowed []string) {
	if rule, ok := normalizeRule(map[string]any{"scope": scope, "value": value}, allowed); ok {
		*bucket = append(*bucket, rule)
	}
}

// MigrateLegacyWhitelist converts the old flat allow-list into a policy.
func MigrateLegacyWhitelist(platform string, entries []string) AccessPolicy {
	caps := PlatformCapabilities(platform)
	policy := DefaultAccessPolicy(platform)
	var st legacyState
	var list []string
	for _, e := range entries {
		if e = jsTrim(e); e != "" {
			list = append(list, e)
		}
	}
	if slices.Contains(list, "*") {
		policy.DirectPolicy = "open"
		if caps.SupportsSharedPolicy {
			policy.SharedPolicy = "open"
		}
	}
	for _, entry := range list {
		if entry == "*" {
			continue
		}
		m := prefixedEntryRe.FindStringSubmatch(entry)
		rawScope, rawValue := "", entry
		if m != nil {
			rawScope, rawValue = m[1], m[2]
		}
		scope := normalizeScope(rawScope)
		valueScope := scope
		if valueScope == "" {
			valueScope = "chat"
		}
		value := sanitizeValue(valueScope, rawValue)
		if value == "" {
			continue
		}
		switch {
		case platform == "whatsapp":
			if scope == "group" || isWhatsAppGroupID(value) {
				st.add(&st.space, "group", value, caps.SharedSpaceRuleScopes)
				continue
			}
			directValue := value
			if scope != "chat" {
				directValue = normalizeWhatsAppDirectID(value)
			}
			if directValue == "" {
				continue
			}
			if scope == "chat" {
				st.add(&st.direct, "chat", directValue, caps.DirectRuleScopes)
			} else {
				st.add(&st.direct, "phone_number", directValue, caps.DirectRuleScopes)
				st.add(&st.actor, "phone_number", directValue, caps.SharedActorRuleScopes)
			}
			continue
		case platform == "telegram" && m == nil:
			if strings.HasPrefix(value, "-") {
				st.add(&st.space, "group", value, caps.SharedSpaceRuleScopes)
			} else {
				st.add(&st.direct, "user", value, caps.DirectRuleScopes)
				st.add(&st.actor, "user", value, caps.SharedActorRuleScopes)
			}
			continue
		case platform == "discord" && m == nil:
			st.add(&st.direct, "user", value, caps.DirectRuleScopes)
			st.add(&st.actor, "user", value, caps.SharedActorRuleScopes)
			continue
		}
		switch scope {
		case "user":
			st.add(&st.direct, "user", value, caps.DirectRuleScopes)
			st.add(&st.actor, "user", value, caps.SharedActorRuleScopes)
		case "role":
			st.add(&st.actor, "role", value, caps.SharedActorRuleScopes)
		case "group", "channel", "server", "room", "chat":
			st.add(&st.space, scope, value, caps.SharedSpaceRuleScopes)
		case "phone_number":
			st.add(&st.direct, "phone_number", value, caps.DirectRuleScopes)
			st.add(&st.actor, "phone_number", value, caps.SharedActorRuleScopes)
		default:
			raw := sanitizeValue("chat", entry)
			if slices.Contains(sharedRawIDPlatfms, platform) {
				st.add(&st.space, "chat", raw, caps.SharedSpaceRuleScopes)
				break
			}
			st.add(&st.direct, "chat", raw, caps.DirectRuleScopes)
			st.add(&st.space, "chat", raw, caps.SharedSpaceRuleScopes)
		}
	}
	policy.DirectRules, policy.SharedSpaceRules, policy.SharedActorRules = nonNil(st.direct), nonNil(st.space), nonNil(st.actor)
	return policy.Normalize(platform)
}

func nonNil(r []Rule) []Rule {
	if r == nil {
		return []Rule{}
	}
	return r
}

// ParseStoredAccessPolicy reads a stored policy (JSON text), falling back to
// the legacy allow-list and then the default. Either argument may be nil.
func ParseStoredAccessPolicy(platform string, policyValue, legacyValue *string) AccessPolicy {
	if policyValue != nil {
		var parsed any
		if err := json.Unmarshal([]byte(*policyValue), &parsed); err != nil {
			return DefaultAccessPolicy(platform)
		}
		return NormalizeAccessPolicy(platform, parsed)
	}
	if legacyValue != nil {
		var parsed any
		if err := json.Unmarshal([]byte(*legacyValue), &parsed); err != nil {
			return DefaultAccessPolicy(platform)
		}
		return MigrateLegacyWhitelist(platform, jsStringList(parsed))
	}
	return DefaultAccessPolicy(platform)
}

// jsStringList is `Array.isArray(v) ? v.map(item => String(item || ”)) : []`.
func jsStringList(v any) []string {
	list, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]string, len(list))
	for i, item := range list {
		out[i] = jsOrEmpty(item)
	}
	return out
}

// --- Evaluation ---------------------------------------------------------------

// AccessContext describes one inbound message for the policy.
type AccessContext struct {
	Platform         string   `json:"platform"`
	SenderID         string   `json:"senderId"`
	ChatID           string   `json:"chatId"`
	IsDirect         bool     `json:"isDirect"`
	IsShared         bool     `json:"isShared"`
	GroupID          string   `json:"groupId"`
	ChannelID        string   `json:"channelId"`
	ServerID         string   `json:"serverId"`
	RoomID           string   `json:"roomId"`
	RoleIDs          []string `json:"roleIds"`
	PhoneNumber      string   `json:"phoneNumber"`
	WasMentioned     bool     `json:"wasMentioned"`
	Text             string   `json:"text,omitempty"`
	MessageID        string   `json:"messageId,omitempty"`
	SenderName       string   `json:"senderName,omitempty"`
	StableSenderID   string   `json:"stableSenderId,omitempty"`
	NormalizedChatID string   `json:"normalizedChatId,omitempty"`
}

// AccessDecision is the policy's verdict. AllowUntagged and ApprovedSender are
// only meaningful for an allowed message in a shared space.
type AccessDecision struct {
	Allowed           bool   `json:"allowed"`
	Reason            string `json:"reason"`
	ApprovedSender    bool   `json:"approvedSender"`
	AllowUntagged     bool   `json:"allowUntagged"`
	ParticipationHint string `json:"participationHint,omitempty"`
	// OwnerUserID is set by an instance-wide gate: whose agent the sender
	// speaks to.
	OwnerUserID int64 `json:"-"`
}

var phoneJunk = regexp.MustCompile(`[^0-9+]`)

func normalizePhone(s string) string { return phoneJunk.ReplaceAllString(s, "") }

func contextMatchesRule(rule Rule, c AccessContext) bool {
	v := rule.Value
	switch rule.Scope {
	case "user":
		return v != "" && c.SenderID == v
	case "dm":
		return c.IsDirect && v != "" && c.ChatID == v
	case "chat":
		return v != "" && c.ChatID == v
	case "group":
		return c.IsShared && v != "" && firstNonEmpty(c.GroupID, c.ChatID) == v
	case "channel":
		return c.IsShared && v != "" && firstNonEmpty(c.ChannelID, c.ChatID) == v
	case "server":
		return c.IsShared && v != "" && c.ServerID == v
	case "room":
		return c.IsShared && v != "" && firstNonEmpty(c.RoomID, c.ChatID) == v
	case "role":
		return slices.Contains(c.RoleIDs, v)
	case "phone_number":
		return normalizePhone(firstNonEmpty(c.PhoneNumber, c.SenderID)) == normalizePhone(v)
	}
	return false
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func matchesMemberRule(rule MemberRule, c AccessContext) bool {
	return contextMatchesRule(rule.Rule, c) && contextMatchesRule(Rule{Scope: rule.SpaceScope, Value: rule.SpaceValue}, c)
}

func allowUntaggedFor(p AccessPolicy, c AccessContext) bool {
	priority := map[string]int{"group": 4, "channel": 4, "room": 4, "chat": 3, "server": 2}
	var best *ParticipationRule
	for i := range p.SharedParticipationRules {
		rule := &p.SharedParticipationRules[i]
		if !contextMatchesRule(rule.Rule, c) {
			continue
		}
		if best == nil || priority[rule.Scope] > priority[best.Scope] {
			best = rule
		}
	}
	if best != nil {
		return best.AllowUntagged
	}
	return p.DefaultAllowUntaggedInShared
}

// EvaluateAccessPolicy decides whether a message may reach the agent.
func EvaluateAccessPolicy(policy AccessPolicy, c AccessContext, platform string) AccessDecision {
	caps := PlatformCapabilities(platform)
	p := policy.Normalize(platform)
	if c.IsDirect {
		if p.DirectPolicy == "disabled" {
			return AccessDecision{Reason: "direct_disabled"}
		}
		if p.DirectPolicy == "allowlist" {
			match := slices.ContainsFunc(p.DirectRules, func(r Rule) bool { return contextMatchesRule(r, c) }) ||
				slices.ContainsFunc(p.SharedActorRules, func(r Rule) bool { return contextMatchesRule(r, c) })
			if !match {
				return AccessDecision{Reason: "direct_not_allowed"}
			}
		}
		return AccessDecision{Allowed: true, Reason: "allowed"}
	}
	if c.IsShared {
		if !caps.SupportsSharedPolicy || p.SharedPolicy == "disabled" {
			return AccessDecision{Reason: "shared_disabled"}
		}
		if p.SharedPolicy == "allowlist" {
			spaceMatch := slices.ContainsFunc(p.SharedSpaceRules, func(r Rule) bool { return contextMatchesRule(r, c) })
			memberMatch := slices.ContainsFunc(p.SharedMemberRules, func(r MemberRule) bool { return matchesMemberRule(r, c) })
			// Where anyone can post, a space rule alone admits no one. An
			// approved person is trusted wherever they ask, but a role only
			// inside a listed space: roles are relative to the space.
			actorMatch := slices.ContainsFunc(p.SharedActorRules, func(r Rule) bool {
				return contextMatchesRule(r, c) && (!caps.RequireSharedActor || r.Scope != "role" || spaceMatch)
			})
			allowed := spaceMatch || actorMatch || memberMatch
			if caps.RequireSharedActor {
				allowed = actorMatch || memberMatch
			}
			if !allowed {
				return AccessDecision{Reason: "shared_not_allowed"}
			}
		}
		untagged := allowUntaggedFor(p, c)
		approved := slices.ContainsFunc(p.SharedActorRules, func(r Rule) bool { return r.Scope != "role" && contextMatchesRule(r, c) })
		hint := "mention_only"
		if untagged {
			hint = "automatic"
		}
		return AccessDecision{Allowed: true, Reason: "allowed", ApprovedSender: approved, AllowUntagged: untagged, ParticipationHint: hint}
	}
	return AccessDecision{Reason: "unsupported_context"}
}

// DirectOnlyAllowlist reports whether the policy is an allowlist for private
// chats, the mode in which a listed sender speaks for the owner.
func (p AccessPolicy) DirectOnlyAllowlist() bool { return p.DirectPolicy == "allowlist" }

// --- Applying a suggested rule ----------------------------------------------

// Suggestion is a one-tap way to allow a blocked sender.
type Suggestion struct {
	Label      string         `json:"label"`
	PrefixedID string         `json:"prefixedId"`
	Bucket     string         `json:"bucket"`
	Rule       SuggestionRule `json:"rule"`
}

// SuggestionRule is the rule a Suggestion would add.
type SuggestionRule struct {
	Scope      string `json:"scope"`
	Value      string `json:"value"`
	SpaceScope string `json:"spaceScope,omitempty"`
	SpaceValue string `json:"spaceValue,omitempty"`
	SpaceLabel string `json:"spaceLabel,omitempty"`
}

// ApplyAccessPolicyRule adds a suggested rule to a policy. ok is false when the
// rule is not valid for the platform.
func ApplyAccessPolicyRule(platform string, policy AccessPolicy, bucket string, rawRule map[string]any) (AccessPolicy, bool) {
	next := policy.Normalize(platform)
	caps := PlatformCapabilities(platform)
	switch jsTrim(bucket) {
	case "directRules":
		rule, ok := normalizeRule(rawRule, caps.DirectRuleScopes)
		if !ok {
			return AccessPolicy{}, false
		}
		next.DirectRules = append(next.DirectRules, rule)
		if next.DirectPolicy == "disabled" {
			next.DirectPolicy = "allowlist"
		}
	case "sharedActorRules":
		rule, ok := normalizeRule(rawRule, caps.SharedActorRuleScopes)
		if !ok {
			return AccessPolicy{}, false
		}
		next.SharedActorRules = append(next.SharedActorRules, rule)
		if next.DirectPolicy == "disabled" {
			next.DirectPolicy = "allowlist"
		}
		if next.SharedPolicy == "disabled" {
			next.SharedPolicy = "allowlist"
		}
	case "sharedMemberRules":
		rule, ok := normalizeMemberRule(rawRule, caps.SharedActorRuleScopes, caps.SharedSpaceRuleScopes)
		if !ok {
			return AccessPolicy{}, false
		}
		next.SharedMemberRules = append(next.SharedMemberRules, rule)
		if next.SharedPolicy == "disabled" {
			next.SharedPolicy = "allowlist"
		}
	case "sharedSpaceRules":
		rule, ok := normalizeRule(rawRule, caps.SharedSpaceRuleScopes)
		if !ok {
			return AccessPolicy{}, false
		}
		next.SharedSpaceRules = append(next.SharedSpaceRules, rule)
		if next.SharedPolicy == "disabled" {
			next.SharedPolicy = "allowlist"
		}
	default:
		return AccessPolicy{}, false
	}
	return next.Normalize(platform), true
}

// --- Blocked sender suggestions ---------------------------------------------

// BlockedOptions are the display extras for a blocked-sender notice.
type BlockedOptions struct {
	SenderName   string
	Meta         string
	ServerLabel  string
	GroupLabel   string
	ChannelLabel string
	RoomLabel    string
}

func labelForScope(scope string) string {
	if scope == "phone_number" {
		return "number"
	}
	return scope
}

func makeSuggestion(scope, value, label, bucket, spaceScope, spaceValue, spaceLabel string) *Suggestion {
	if scope == "" || value == "" || bucket == "" {
		return nil
	}
	rule := SuggestionRule{Scope: scope, Value: value}
	if spaceScope != "" && spaceValue != "" {
		rule.SpaceScope, rule.SpaceValue = spaceScope, spaceValue
	}
	rule.SpaceLabel = spaceLabel
	if label == "" {
		label = "Allow " + labelForScope(scope) + " " + value
	}
	prefixed := scope + ":" + value
	if scope == "phone_number" {
		prefixed = value
	}
	return &Suggestion{Label: label, PrefixedID: prefixed, Bucket: bucket, Rule: rule}
}

type sharedSpace struct{ scope, value, label string }

func sharedSpaceFromContext(c AccessContext, o BlockedOptions, allowed []string) *sharedSpace {
	has := func(s string) bool { return slices.Contains(allowed, s) }
	switch {
	case c.ChannelID != "" && has("channel"):
		return &sharedSpace{"channel", c.ChannelID, firstNonEmpty(o.ChannelLabel, c.ChannelID)}
	case c.RoomID != "" && has("room"):
		return &sharedSpace{"room", c.RoomID, firstNonEmpty(o.RoomLabel, c.RoomID)}
	case c.GroupID != "" && has("group"):
		return &sharedSpace{"group", c.GroupID, firstNonEmpty(o.GroupLabel, c.GroupID)}
	case c.ChatID != "" && has("chat"):
		return &sharedSpace{"chat", c.ChatID, c.ChatID}
	}
	return nil
}

// BlockedSenderSuggestions lists the ways to allow the sender of a refused
// message.
func BlockedSenderSuggestions(platform string, c AccessContext, o BlockedOptions) []Suggestion {
	caps := PlatformCapabilities(platform)
	senderLabel := jsTrim(firstNonEmpty(o.SenderName, c.SenderID))
	chatID := jsTrim(c.ChatID)
	actorScope := "user"
	if c.PhoneNumber != "" {
		actorScope = "phone_number"
	}
	actorValue := jsTrim(firstNonEmpty(c.PhoneNumber, c.SenderID))
	canActor := slices.Contains(caps.SharedActorRuleScopes, actorScope)
	var list []*Suggestion
	if c.IsDirect {
		switch {
		case actorValue != "" && canActor:
			list = append(list, makeSuggestion(actorScope, actorValue, "Allow sender everywhere ("+firstNonEmpty(senderLabel, actorValue)+")", "sharedActorRules", "", "", ""))
		case c.PhoneNumber != "":
			list = append(list, makeSuggestion("phone_number", c.PhoneNumber, "Allow sender ("+firstNonEmpty(senderLabel, c.PhoneNumber)+")", "directRules", "", "", ""))
		case c.SenderID != "":
			list = append(list, makeSuggestion("user", c.SenderID, "Allow sender ("+firstNonEmpty(senderLabel, c.SenderID)+")", "directRules", "", "", ""))
		}
		if chatID != "" && jsTrim(c.SenderID) == "" {
			list = append(list, makeSuggestion("chat", chatID, "Allow chat ("+chatID+")", "directRules", "", "", ""))
		}
	} else if c.IsShared {
		space := sharedSpaceFromContext(c, o, caps.SharedSpaceRuleScopes)
		noun := labelForScope("")
		if space != nil {
			noun = labelForScope(space.scope)
		}
		if caps.SpaceNoun != nil {
			noun = *caps.SpaceNoun
		}
		if actorValue != "" && canActor && space != nil {
			list = append(list, makeSuggestion(actorScope, actorValue, "Allow sender in this "+noun+" only ("+firstNonEmpty(senderLabel, actorValue)+")", "sharedMemberRules", space.scope, space.value, space.label))
			list = append(list, makeSuggestion(actorScope, actorValue, "Allow sender everywhere ("+firstNonEmpty(senderLabel, actorValue)+")", "sharedActorRules", "", "", ""))
		}
		if space != nil && !caps.RequireSharedActor {
			list = append(list, makeSuggestion(space.scope, space.value, "Allow everyone in this "+labelForScope(space.scope)+" ("+space.label+")", "sharedSpaceRules", "", "", ""))
		}
	}
	out := []Suggestion{}
	seen := map[string]bool{}
	for _, s := range list {
		if s == nil {
			continue
		}
		key := strings.Join([]string{s.Bucket, s.Rule.Scope, s.Rule.Value, s.Rule.SpaceScope, s.Rule.SpaceValue}, ":")
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, *s)
	}
	return out
}

// BuildBlockedSender is the payload for a refused sender.
func BuildBlockedSender(platform string, c AccessContext, o BlockedOptions) BlockedSender {
	return BlockedSender{
		Sender:      nstr(firstNonEmpty(c.SenderID, c.PhoneNumber)),
		ChatID:      nstr(c.ChatID),
		SenderName:  nstr(o.SenderName),
		Meta:        o.Meta,
		Suggestions: BlockedSenderSuggestions(platform, c, o),
	}
}

func accessModeLabel(mode string) string {
	switch mode {
	case "open":
		return "anyone"
	case "disabled":
		return "off"
	}
	return "approved only"
}

// SummarizeAccessPolicy is the one-line summary the app shows.
func SummarizeAccessPolicy(platform string, policy AccessPolicy) string {
	caps := PlatformCapabilities(platform)
	p := policy.Normalize(platform)
	var parts []string
	if caps.SupportsDirectPolicy {
		parts = append(parts, "Private chats: "+accessModeLabel(p.DirectPolicy))
	}
	if caps.SupportsSharedPolicy {
		parts = append(parts, "Groups: "+accessModeLabel(p.SharedPolicy))
		switch {
		case caps.MentionOnly:
			parts = append(parts, "replies when tagged")
		case caps.SupportsUntaggedGroupToggle:
			taggedOnly := 0
			for _, r := range p.SharedParticipationRules {
				if !r.AllowUntagged {
					taggedOnly++
				}
			}
			switch {
			case !p.DefaultAllowUntaggedInShared:
				parts = append(parts, "replies when tagged")
			case taggedOnly > 0:
				plural := "s"
				if taggedOnly == 1 {
					plural = ""
				}
				parts = append(parts, fmt.Sprintf("%d group%s tagged-only", taggedOnly, plural))
			default:
				parts = append(parts, "joins group conversations")
			}
		}
	}
	if n := len(p.DirectRules) + len(p.SharedSpaceRules) + len(p.SharedActorRules) + len(p.SharedMemberRules); n > 0 {
		parts = append(parts, fmt.Sprintf("%d approved", n))
	}
	return strings.Join(parts, " · ")
}

// --- Recent targets -----------------------------------------------------------

// RecentRow is a stored message the access screen learns targets from.
type RecentRow struct {
	PlatformChatID string
	Metadata       map[string]any
}

func metaString(m map[string]any, keys ...string) string {
	for _, k := range keys {
		if s := jsOrEmpty(m[k]); s != "" {
			return s
		}
	}
	return ""
}

func directChatActorID(chatID, sender string) string {
	who := jsTrim(sender)
	if who != "" {
		return strings.TrimPrefix(who, "dm_")
	}
	id := jsTrim(chatID)
	return strings.TrimPrefix(id, "dm_")
}

var truthyFlag = regexp.MustCompile(`(?i)^(true|1)$`)

func isDirectRecentChat(chatID, sender string, m map[string]any) bool {
	id, who := jsTrim(chatID), jsTrim(sender)
	if strings.HasPrefix(id, "dm_") {
		return true
	}
	if who != "" && (id == who || id == "dm_"+who) {
		return true
	}
	if truthyFlag.MatchString(jsStringify(m["isGroup"])) {
		return false
	}
	return id == ""
}

// jsStringify is String(value) for decoded JSON (null reads "null").
func jsStringify(v any) string {
	switch v := v.(type) {
	case nil:
		return "null"
	case bool:
		return strconv.FormatBool(v)
	case float64:
		return jsNumber(v)
	}
	return jsOrEmpty(v)
}

// ClassifyRecentTarget turns a recent message into an access target, or false.
func ClassifyRecentTarget(platform string, row RecentRow) (AccessTarget, bool) {
	chatID := jsTrim(row.PlatformChatID)
	m := row.Metadata
	if m == nil {
		m = map[string]any{}
	}
	sender := jsTrim(metaString(m, "sender", "senderId", "sender_id"))
	senderName := jsTrim(metaString(m, "senderName", "sender_name", "senderDisplayName", "sender_display_name", "senderUsername", "sender_username"))
	groupName := jsTrim(metaString(m, "groupName", "group_name", "channelName", "channel_name", "roomName", "room_name", "serverName", "server_name", "guildName", "guild_name"))
	if chatID == "" && sender == "" {
		return AccessTarget{}, false
	}
	if platform == "github" {
		repo, _, _ := strings.Cut(chatID, "#")
		if repo == "" {
			return AccessTarget{}, false
		}
		return AccessTarget{Source: "recent", Bucket: "sharedSpaceRules", Scope: "group", Value: repo, Label: repo, Subtitle: "Recent repository"}, true
	}
	direct := isDirectRecentChat(chatID, sender, m)
	if platform == "whatsapp" && !direct && chatID != "" {
		return AccessTarget{Source: "recent", Bucket: "sharedSpaceRules", Scope: "group", Value: chatID, Label: firstNonEmpty(groupName, chatID), Subtitle: "Recent WhatsApp group"}, true
	}
	if platform == "whatsapp" {
		value := normalizePhone(firstNonEmpty(sender, chatID))
		if value == "" {
			return AccessTarget{}, false
		}
		return AccessTarget{Source: "recent", Bucket: "directRules", Scope: "phone_number", Value: value, Label: firstNonEmpty(senderName, value), Subtitle: "Recent contact"}, true
	}
	if direct {
		value := directChatActorID(chatID, sender)
		if value == "" {
			return AccessTarget{}, false
		}
		return AccessTarget{Source: "recent", Bucket: "directRules", Scope: "user", Value: value, Label: firstNonEmpty(senderName, "Private chat"), Subtitle: "Recent private chat"}, true
	}
	scope := "chat"
	switch platform {
	case "matrix":
		scope = "room"
	case "discord":
		scope = "channel"
	case "telegram":
		scope = "group"
	}
	return AccessTarget{Source: "recent", Bucket: "sharedSpaceRules", Scope: scope, Value: chatID, Label: firstNonEmpty(groupName, chatID), Subtitle: "Recent conversation"}, true
}

// ContextFromMessage builds the access context of a queued message.
func ContextFromMessage(m Message) AccessContext {
	chatID := jsTrim(m.ChatID)
	senderID := jsTrim(m.Sender)
	caps := PlatformCapabilities(m.Platform)
	phone := ""
	if slices.Contains(caps.DirectRuleScopes, "phone_number") {
		phone = normalizePhone(senderID)
	}
	c := AccessContext{
		Platform:         m.Platform,
		SenderID:         senderID,
		ChatID:           chatID,
		IsDirect:         !m.IsGroup,
		IsShared:         m.IsGroup,
		ServerID:         jsTrim(firstNonEmpty(string(m.GuildID), string(m.ServerID))),
		RoomID:           jsTrim(string(m.RoomID)),
		RoleIDs:          append([]string{}, m.RoleIDs...),
		PhoneNumber:      phone,
		WasMentioned:     m.WasMentioned,
		NormalizedChatID: strings.TrimPrefix(chatID, "dm_"),
	}
	if m.IsGroup {
		c.GroupID = jsTrim(firstNonEmpty(string(m.GroupID), m.ChatID))
		c.ChannelID = jsTrim(firstNonEmpty(string(m.ChannelID), m.ChatID))
	}
	return c
}
