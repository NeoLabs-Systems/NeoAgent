package messaging

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

// vectors are recorded from the Node server's messaging modules by
// gen/vectors.js; each test replays the inputs through the Go port and
// requires the same answers.
type vectors struct {
	Normalize []struct {
		Platform string
		Raw      any
		Result   json.RawMessage
	}
	Capabilities map[string]json.RawMessage
	Defaults     map[string]json.RawMessage
	Keys         []struct{ Platform, Policy, Legacy string }
	Migrate      []struct {
		Platform string
		List     []any
		Result   json.RawMessage
	}
	Stored []struct {
		Platform string
		Policy   *string
		Legacy   *string
		Result   json.RawMessage
	}
	Evaluate []struct {
		Platform string
		Policy   AccessPolicy
		Context  AccessContext
		Result   struct {
			Allowed           bool
			Reason            string
			ApprovedSender    bool
			AllowUntagged     bool
			ParticipationHint string
		}
	}
	Apply []struct {
		Platform string
		Policy   AccessPolicy
		Bucket   *string
		Rule     map[string]any
		Result   json.RawMessage
	}
	Suggestions []struct {
		Platform string
		Context  AccessContext
		Options  struct {
			SenderName, Meta, ServerLabel, GroupLabel, ChannelLabel, RoomLabel string
		}
		Result json.RawMessage
	}
	Summaries []struct {
		Platform string
		Policy   AccessPolicy
		Result   string
	}
	Recent []struct {
		Platform string
		Row      struct {
			PlatformChatID string `json:"platform_chat_id"`
			Metadata       map[string]any
		}
		Result json.RawMessage
	}
	ContextFromMessage []struct {
		Msg    map[string]any
		Result json.RawMessage
	}
	NormalizeOutgoing []struct {
		Platform string
		Content  any
		Strip    *bool
		Result   string
	}
	Split []struct {
		Platform string
		Text     string
		Result   []string
	}
	Guides map[string]struct {
		Guide   string
		NoIntro string
	}
	SendRef       string
	SplitOutgoing []struct {
		Platform string
		Text     string
		Result   []string
	}
	Fence []struct {
		Text    any
		Fenced  string
		Neutral string
	}
	Identity []struct {
		Msg    map[string]any
		Result string
	}
	IdentityNote string
	ReplyContext []struct {
		Msg    map[string]any
		Result string
	}
	Usage []struct {
		Lang      *string
		RateLimit *struct {
			Window     string
			RecoversAt map[string]string
		}
		Now    int64
		Result string
	}
	FixedSamples []struct {
		Lang   string
		Key    string
		Values map[string]string
	}
	Queue []struct {
		Name     string
		Steps    []map[string]any
		Executed []map[string]any
	}
	QueueKeys []struct {
		UserID int64 `json:"userId"`
		Msg    map[string]any
		Key    string
	}
}

func loadVectors(t *testing.T) *vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return &v
}

// sameJSON requires got (marshalled) to equal want as decoded JSON.
func sameJSON(t *testing.T, label string, got any, want json.RawMessage) {
	t.Helper()
	raw, err := json.Marshal(got)
	if err != nil {
		t.Fatal(err)
	}
	var g, w any
	if err := json.Unmarshal(raw, &g); err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(want, &w); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(g, w) {
		t.Errorf("%s:\n got  %s\n want %s", label, raw, want)
	}
}

func TestNormalizeAccessPolicyMatchesNode(t *testing.T) {
	for i, c := range loadVectors(t).Normalize {
		sameJSON(t, c.Platform+" #"+string(rune('a'+i%26)), NormalizeAccessPolicy(c.Platform, c.Raw), c.Result)
	}
}

func TestCapabilitiesAndDefaultsMatchNode(t *testing.T) {
	v := loadVectors(t)
	for platform, want := range v.Capabilities {
		sameJSON(t, "capabilities "+platform, PlatformCapabilities(platform), want)
	}
	for platform, want := range v.Defaults {
		sameJSON(t, "default "+platform, DefaultAccessPolicy(platform), want)
	}
	for _, k := range v.Keys {
		if AccessPolicyKey(k.Platform) != k.Policy || LegacyWhitelistKey(k.Platform) != k.Legacy {
			t.Errorf("keys for %q differ", k.Platform)
		}
	}
}

func TestMigrateLegacyWhitelistMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Migrate {
		sameJSON(t, c.Platform+" migrate", MigrateLegacyWhitelist(c.Platform, jsStringList(c.List)), c.Result)
	}
}

func TestParseStoredAccessPolicyMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Stored {
		sameJSON(t, c.Platform+" stored", ParseStoredAccessPolicy(c.Platform, c.Policy, c.Legacy), c.Result)
	}
}

func TestEvaluateAccessPolicyMatchesNode(t *testing.T) {
	for i, c := range loadVectors(t).Evaluate {
		got := EvaluateAccessPolicy(c.Policy, c.Context, c.Platform)
		w := c.Result
		if got.Allowed != w.Allowed || got.Reason != w.Reason || got.ApprovedSender != w.ApprovedSender ||
			got.AllowUntagged != w.AllowUntagged || got.ParticipationHint != w.ParticipationHint {
			t.Errorf("case %d %s ctx=%+v: got %+v want %+v", i, c.Platform, c.Context, got, w)
		}
	}
}

func TestApplyAccessPolicyRuleMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Apply {
		bucket := ""
		if c.Bucket != nil {
			bucket = *c.Bucket
		}
		got, ok := ApplyAccessPolicyRule(c.Platform, c.Policy, bucket, c.Rule)
		if string(c.Result) == "null" {
			if ok {
				t.Errorf("%s %q %v: expected the rule to be refused", c.Platform, bucket, c.Rule)
			}
			continue
		}
		if !ok {
			t.Errorf("%s %q %v: rule refused", c.Platform, bucket, c.Rule)
			continue
		}
		sameJSON(t, c.Platform+" apply "+bucket, got, c.Result)
	}
}

func TestBlockedSenderPayloadMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Suggestions {
		got := BuildBlockedSender(c.Platform, c.Context, BlockedOptions(c.Options))
		sameJSON(t, c.Platform+" blocked "+c.Context.ChatID, got, c.Result)
	}
}

func TestSummarizeAccessPolicyMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Summaries {
		if got := SummarizeAccessPolicy(c.Platform, c.Policy); got != c.Result {
			t.Errorf("%s: got %q want %q", c.Platform, got, c.Result)
		}
	}
}

func TestClassifyRecentTargetMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Recent {
		got, ok := ClassifyRecentTarget(c.Platform, RecentRow{PlatformChatID: c.Row.PlatformChatID, Metadata: c.Row.Metadata})
		if string(c.Result) == "null" {
			if ok {
				t.Errorf("%s %+v: expected no target, got %+v", c.Platform, c.Row, got)
			}
			continue
		}
		if !ok {
			t.Errorf("%s %+v: no target", c.Platform, c.Row)
			continue
		}
		sameJSON(t, c.Platform+" recent", got, c.Result)
	}
}

func TestContextFromMessageMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).ContextFromMessage {
		raw, _ := json.Marshal(c.Msg)
		var in struct {
			Platform, ChatID, Sender, GroupID, ChannelID, GuildID, ServerID, RoomID string
			IsGroup, WasMentioned                                                   bool
			RoleIDs                                                                 []any
		}
		if err := json.Unmarshal(raw, &in); err != nil {
			t.Fatal(err)
		}
		msg := Message{Platform: in.Platform, ChatID: in.ChatID, Sender: in.Sender, IsGroup: in.IsGroup, WasMentioned: in.WasMentioned,
			GroupID: nstr(in.GroupID), ChannelID: nstr(in.ChannelID), GuildID: nstr(in.GuildID), ServerID: nstr(in.ServerID), RoomID: nstr(in.RoomID), RoleIDs: jsStringList(in.RoleIDs)}
		got := ContextFromMessage(msg)
		var want AccessContext
		if err := json.Unmarshal(c.Result, &want); err != nil {
			t.Fatal(err)
		}
		if got.RoleIDs == nil {
			got.RoleIDs = []string{}
		}
		if want.RoleIDs == nil {
			want.RoleIDs = []string{}
		}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("%v: got %+v want %+v", c.Msg, got, want)
		}
	}
}
