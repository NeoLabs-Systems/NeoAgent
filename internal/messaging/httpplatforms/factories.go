package httpplatforms

import "github.com/NeoLabs-Systems/neoagent/internal/messaging"

// genericSpecs are the platforms that are only a configurable webhook.
var genericSpecs = map[string]defaults{
	"feishu":         {label: "Feishu", contentField: "text"},
	"nextcloud_talk": {label: "Nextcloud Talk", contentField: "message"},
	"nostr":          {label: "Nostr", contentField: "content"},
	"synology_chat":  {label: "Synology Chat", contentField: "text"},
	"tlon":           {label: "Tlon", contentField: "text"},
	"zalo":           {label: "Zalo", contentField: "message"},
	"zalo_personal":  {label: "Zalo Personal", contentField: "message"},
	"wechat":         {label: "WeChat", contentField: "content"},
	"webchat":        {label: "WebChat", contentField: "content"},
}

// Factories returns the adapter factory of every platform in this package,
// keyed by platform name.
func Factories(deps Deps) map[string]messaging.Factory {
	f := map[string]messaging.Factory{
		"google_chat": func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newGoogleChat(c, ev, deps), nil
		},
		"teams": func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newTeams(c, ev, deps), nil
		},
		"matrix": func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newMatrix(c, ev, deps), nil
		},
		"signal": func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newSignal(c, ev, deps), nil
		},
		"line": func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newLine(c, ev, deps), nil
		},
		"mattermost": func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newMattermost(c, ev, deps), nil
		},
	}
	for _, name := range []string{"imessage", "bluebubbles"} {
		f[name] = func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newBlueBubbles(name, c, ev, deps), nil
		}
	}
	for _, name := range []string{"irc", "twitch"} {
		f[name] = func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newIRC(name, c, ev, deps), nil
		}
	}
	for name, spec := range genericSpecs {
		f[name] = func(c messaging.Config, ev messaging.Events) (messaging.Platform, error) {
			return newConfigurable(name, c, ev, deps, spec), nil
		}
	}
	return f
}
