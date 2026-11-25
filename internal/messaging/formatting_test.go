package messaging

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

func TestNormalizeOutgoingMessageMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).NormalizeOutgoing {
		content := c.Content
		if m, ok := content.(map[string]any); ok && m["__undefined"] == true {
			content = nil
		}
		strip := c.Strip == nil
		if got := NormalizeOutgoingMessage(c.Platform, content, strip); got != c.Result {
			t.Errorf("%q %#v strip=%v:\n got  %q\n want %q", c.Platform, c.Content, strip, got, c.Result)
		}
	}
}

func TestSplitToMessageLimitMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Split {
		got := SplitToMessageLimit(c.Platform, c.Text)
		if !reflect.DeepEqual(got, c.Result) {
			t.Errorf("%s len=%d: got %d parts, want %d", c.Platform, len(c.Text), len(got), len(c.Result))
		}
	}
}

func TestSplitOutgoingMessageMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).SplitOutgoing {
		got := SplitOutgoingMessage(c.Platform, c.Text)
		if len(got) == 0 && len(c.Result) == 0 {
			continue
		}
		if !reflect.DeepEqual(got, c.Result) {
			t.Errorf("%s %q: got %q want %q", c.Platform, c.Text, got, c.Result)
		}
	}
}

func TestFormattingGuidesMatchNode(t *testing.T) {
	v := loadVectors(t)
	for platform, want := range v.Guides {
		if got := BuildPlatformFormattingGuide(platform, true); got != want.Guide {
			t.Errorf("%s guide differs:\n%s", platform, got)
		}
		if got := BuildPlatformFormattingGuide(platform, false); got != want.NoIntro {
			t.Errorf("%s guide without intro differs", platform)
		}
	}
	if SendMessageFormattingReference() != v.SendRef {
		t.Error("send_message formatting reference differs")
	}
}

func TestPromptBlocksMatchNode(t *testing.T) {
	v := loadVectors(t)
	for _, c := range v.Fence {
		text, _ := c.Text.(string)
		if got := FenceUntrusted("external_x", text); got != c.Fenced {
			t.Errorf("fence %q: got %q want %q", text, got, c.Fenced)
		}
		if got := NeutralizeFenceTags(text); got != c.Neutral {
			t.Errorf("neutralize %q: got %q want %q", text, got, c.Neutral)
		}
	}
	for _, c := range v.Identity {
		if got := BuildSenderIdentityBlock(messageFromMap(t, c.Msg)); got != c.Result {
			t.Errorf("identity %v:\n got  %q\n want %q", c.Msg, got, c.Result)
		}
	}
	if SenderIdentityNote != v.IdentityNote {
		t.Error("sender identity note differs")
	}
	for _, c := range v.ReplyContext {
		if got := BuildReplyContextBlock(messageFromMap(t, c.Msg)); got != c.Result {
			t.Errorf("reply context %v:\n got  %q\n want %q", c.Msg, got, c.Result)
		}
	}
}

// messageFromMap reads the Node message objects the vectors use.
func messageFromMap(t *testing.T, m map[string]any) Message {
	t.Helper()
	raw, _ := json.Marshal(m)
	var in struct {
		Platform, ChatID, Sender, SenderName, SenderDisplayName, SenderUsername, SenderTag string
		ChannelName, GroupName, GuildName                                                  string
		IsGroup                                                                            bool
		ReplyTo                                                                            *ReplyRef
	}
	if err := json.Unmarshal(raw, &in); err != nil {
		t.Fatal(err)
	}
	return Message{
		Platform: in.Platform, ChatID: in.ChatID, Sender: in.Sender, SenderName: nstr(in.SenderName),
		SenderDisplayName: nstr(in.SenderDisplayName), SenderUsername: nstr(in.SenderUsername), SenderTag: nstr(in.SenderTag),
		ChannelName: nstr(in.ChannelName), GroupName: nstr(in.GroupName), GuildName: nstr(in.GuildName),
		IsGroup: in.IsGroup, ReplyTo: in.ReplyTo,
	}
}

func TestSplitNeverBreaksACodePoint(t *testing.T) {
	for _, part := range SplitToMessageLimit("discord", strings.Repeat("😀", 2500)) {
		if utf16Len(part) > 2000 {
			t.Fatalf("part of %d units exceeds the limit", utf16Len(part))
		}
	}
}
