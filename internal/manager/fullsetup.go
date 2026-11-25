package manager

import (
	"fmt"
	"slices"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/envfile"
	"github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

type field struct {
	key, label, def string
	secret          bool
}

var providerFields = []field{
	{"ANTHROPIC_API_KEY", "Anthropic API key", "", true}, {"ANTHROPIC_BASE_URL", "Anthropic base URL", "", false},
	{"OPENAI_API_KEY", "OpenAI API key", "", true}, {"OPENAI_BASE_URL", "OpenAI base URL", "", false},
	{"XAI_API_KEY", "xAI API key", "", true}, {"XAI_BASE_URL", "xAI base URL", "https://api.x.ai/v1", false},
	{"GOOGLE_AI_KEY", "Google API key", "", true}, {"MINIMAX_API_KEY", "MiniMax Code key", "", true},
	{"BRAVE_SEARCH_API_KEY", "Brave Search API key", "", true}, {"OLLAMA_URL", "Ollama URL", "http://localhost:11434", false},
}

var integrationFields = func() []field {
	var out []field
	for _, p := range [][2]string{{"GOOGLE", "Google"}, {"NOTION", "Notion"}, {"MICROSOFT", "Microsoft 365"}, {"SLACK", "Slack"}, {"FIGMA", "Figma"}, {"GITHUB", "GitHub"}} {
		out = append(out,
			field{p[0] + "_OAUTH_CLIENT_ID", p[1] + " OAuth client ID", "", true},
			field{p[0] + "_OAUTH_CLIENT_SECRET", p[1] + " OAuth client secret", "", true},
			field{p[0] + "_OAUTH_REDIRECT_URI", p[1] + " OAuth redirect URI", "", false})
		if p[0] == "MICROSOFT" {
			out = append(out, field{"MICROSOFT_OAUTH_TENANT_ID", "Microsoft 365 OAuth tenant ID", "common", false})
		}
	}
	return out
}()

var voiceFields = []field{
	{"VOICE_LIVE_PROVIDER", "Live voice provider (" + strings.Join(liveVoiceProviderIDs, " or ") + ")", "openai", false},
	{"VOICE_LIVE_MODEL", "Live voice model (blank for the provider default)", "", false},
	{"VOICE_LIVE_VOICE", "Live voice (blank for the provider default)", "", false},
	{"DEEPGRAM_API_KEY", "Deepgram API key for voice-note transcription (optional)", "", true},
}

var sectionCompletionKeys = map[string][]string{
	"providers":    {"ANTHROPIC_API_KEY", "OPENAI_API_KEY", "XAI_API_KEY", "GOOGLE_AI_KEY", "MINIMAX_API_KEY"},
	"integrations": {"GOOGLE_OAUTH_CLIENT_ID", "NOTION_OAUTH_CLIENT_ID", "MICROSOFT_OAUTH_CLIENT_ID", "SLACK_OAUTH_CLIENT_ID", "FIGMA_OAUTH_CLIENT_ID", "GITHUB_OAUTH_CLIENT_ID"},
	"voice":        {"VOICE_LIVE_PROVIDER"},
}

func countConfigured(draft map[string]string, keys []string) int {
	n := 0
	for _, k := range keys {
		if strings.TrimSpace(draft[k]) != "" {
			n++
		}
	}
	return n
}

func sectionConfigured(draft map[string]string, id string) bool {
	return countConfigured(draft, sectionCompletionKeys[id]) > 0
}

func resumeValues(draft map[string]string) map[string]string {
	out := map[string]string{}
	for _, k := range setupcontract.C.ResumeValueKeys {
		if v, ok := draft[k]; ok {
			out[k] = v
		}
	}
	return out
}

// mappedCompleted reports "network" with "core" and never "review".
func mappedCompleted(sections []string) []string {
	var out []string
	for _, s := range sections {
		if s != "review" && !slices.Contains(out, s) {
			out = append(out, s)
		}
	}
	if slices.Contains(out, "core") && !slices.Contains(out, "network") {
		out = append(out, "network")
	}
	return out
}

func prepareResume(s *SetupState) (start string, completed []string, values map[string]string) {
	if s == nil {
		return "", nil, map[string]string{}
	}
	values = resumeValues(s.ResumeValues)
	hasCore := values["PORT"] != ""
	start = "providers"
	if s.Stage == "core" || !hasCore {
		start = "core"
	}
	if hasCore {
		completed = []string{"core", "network"}
	}
	return start, completed, values
}

func sectionChoice(v string, canGoBack bool) string {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "q", "quit":
		return "cancel"
	case "b", "back":
		if canGoBack {
			return "back"
		}
	case "n", "no":
		return "skip"
	}
	return "next"
}

func boolValue(v, label string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "true", "1", "yes", "on":
		return "true", nil
	case "false", "0", "no", "off":
		return "false", nil
	}
	return "", cli.Errorf("SETUP_VALUE_INVALID", "%s must be true or false.", label)
}

func (a *App) promptFields(fields []field, draft map[string]string) error {
	for _, f := range fields {
		def := draft[f.key]
		if def == "" {
			def = f.def
		}
		var v string
		var err error
		if f.secret {
			v, err = a.UI.AskSecret(f.label, def)
		} else {
			v, err = a.UI.Ask(f.label, def)
		}
		if err != nil {
			return err
		}
		draft[f.key] = v
	}
	return nil
}

func (a *App) promptCore(draft map[string]string, suggested int, canGoBack bool) (string, error) {
	a.UI.Section("Installation and network")
	def := draft["PORT"]
	if def == "" {
		def = strconv.Itoa(suggested)
	}
	raw, err := a.UI.Ask("Server port", def)
	if err != nil {
		return "", err
	}
	port, err := strconv.Atoi(raw)
	if err != nil || port < 1 || port > 65535 {
		return "", cli.Errorf("SETUP_PORT_INVALID", "Server port must be an integer between 1 and 65535.")
	}
	draft["PORT"] = strconv.Itoa(port)
	if draft["PUBLIC_URL"], err = a.UI.Ask("Public base URL", draft["PUBLIC_URL"]); err != nil {
		return "", err
	}
	secureDef := draft["SECURE_COOKIES"]
	if secureDef == "" {
		secureDef = truthy(strconv.FormatBool(strings.HasPrefix(draft["PUBLIC_URL"], "https://")))
	}
	ask := func(question, def, label, key string) error {
		v, err := a.UI.Ask(question, def)
		if err != nil {
			return err
		}
		draft[key], err = boolValue(v, label)
		return err
	}
	if err := ask("Secure cookies (true/false)", secureDef, "Secure cookies", "SECURE_COOKIES"); err != nil {
		return "", err
	}
	trustDef := draft["TRUST_PROXY"]
	if trustDef == "" {
		trustDef = draft["SECURE_COOKIES"]
	}
	if err := ask("Trust reverse proxy headers (true/false)", trustDef, "Trust reverse proxy headers", "TRUST_PROXY"); err != nil {
		return "", err
	}
	mode, err := a.UI.Ask("Deployment mode (self_hosted/managed)", orDefault(draft["NEOAGENT_DEPLOYMENT_MODE"], "self_hosted"))
	if err != nil {
		return "", err
	}
	draft["NEOAGENT_DEPLOYMENT_MODE"] = deploymentMode(mode)
	channel, err := a.UI.Ask("Release channel (stable/beta)", orDefault(draft["NEOAGENT_RELEASE_CHANNEL"], "stable"))
	if err != nil {
		return "", err
	}
	draft["NEOAGENT_RELEASE_CHANNEL"] = release.NormalizeChannel(channel)
	if draft["ALLOWED_ORIGINS"], err = a.UI.Ask("Allowed CORS origins", draft["ALLOWED_ORIGINS"]); err != nil {
		return "", err
	}
	question := "Continue or cancel? (Y/q)"
	if canGoBack {
		question = "Continue, go back, or cancel? (Y/b/q)"
	}
	choice, err := a.UI.Ask(question, "Y")
	return sectionChoice(choice, canGoBack), err
}

func orDefault(v, def string) string {
	if strings.TrimSpace(v) == "" {
		return def
	}
	return v
}

func (a *App) promptOptional(section setupcontract.Section, fields []field, draft map[string]string, canGoBack bool) (string, bool, error) {
	a.UI.Section(section.Label)
	back := ""
	if canGoBack {
		back = "/b"
	}
	choice, err := a.UI.Ask(fmt.Sprintf("Configure %s now? (Y/n%s/q)", strings.ToLower(section.Label), back), "Y")
	if err != nil {
		return "", false, err
	}
	if action := sectionChoice(choice, canGoBack); action != "next" {
		return action, sectionConfigured(draft, section.ID), nil
	}
	if err := a.promptFields(fields, draft); err != nil {
		return "", false, err
	}
	nav, err := a.UI.Ask("Continue, go back, or cancel? (Y/b/q)", "Y")
	return sectionChoice(nav, true), sectionConfigured(draft, section.ID), err
}

func (a *App) promptReview(draft map[string]string) (string, error) {
	a.UI.Section("Review")
	network := "local/private"
	if draft["PUBLIC_URL"] != "" {
		network = "remote address configured"
	}
	voiceState := "not configured"
	if sectionConfigured(draft, "voice") {
		voiceState = "configured"
	}
	a.UI.Info("Port: " + draft["PORT"])
	a.UI.Info("Network: " + network)
	a.UI.Info(fmt.Sprintf("AI providers: %d configured", countConfigured(draft, sectionCompletionKeys["providers"])))
	a.UI.Info(fmt.Sprintf("Integrations: %d configured", countConfigured(draft, sectionCompletionKeys["integrations"])))
	a.UI.Info("Voice: " + voiceState)
	choice, err := a.UI.Ask("Apply this setup, go back, or cancel? (Y/b/q)", "Y")
	return sectionChoice(choice, true), err
}

// runFullSetup walks the wizard sections (back, skip and cancel allowed) and
// writes the env file once, after review. Nothing changes on cancel.
func (a *App) runFullSetup(suggested int, start string, done []string, initial map[string]string, transition func(string, []string, map[string]string)) ([]string, error) {
	raw, err := envfile.Read(a.Paths.EnvFile)
	if err != nil {
		return nil, err
	}
	draft := envfile.Parse(raw)
	for k, v := range initial {
		draft[k] = v
	}
	a.UI.Title("Full setup", "Values are validated before any configuration is changed.")
	sections := setupcontract.C.WizardSections
	index := max(slices.IndexFunc(sections, func(s setupcontract.Section) bool { return s.ID == start }), 0)
	var completed, skipped []string
	for _, s := range done {
		if s != "network" {
			completed = append(completed, s)
		}
	}
	remove := func(list []string, v string) []string {
		return slices.DeleteFunc(list, func(x string) bool { return x == v })
	}
	add := func(list []string, v string) []string {
		if !slices.Contains(list, v) {
			return append(list, v)
		}
		return list
	}
	for index < len(sections) {
		section := sections[index]
		canGoBack := index > 0
		var action string
		configured := true
		switch section.ID {
		case "core":
			action, err = a.promptCore(draft, suggested, canGoBack)
		case "providers":
			action, configured, err = a.promptOptional(section, providerFields, draft, canGoBack)
		case "integrations":
			action, configured, err = a.promptOptional(section, integrationFields, draft, canGoBack)
		case "voice":
			action, configured, err = a.promptOptional(section, voiceFields, draft, canGoBack)
		default:
			action, err = a.promptReview(draft)
		}
		if err != nil {
			return nil, err
		}
		switch action {
		case "cancel":
			return nil, cli.Errorf("SETUP_CANCELLED", "Setup was cancelled before any changes were saved.")
		case "back":
			if index > 0 {
				index--
			}
			transition(sections[index].ID, mappedCompleted(completed), resumeValues(draft))
			continue
		}
		if section.ID != "review" {
			switch {
			case action == "skip":
				if configured {
					completed = add(completed, section.ID)
				} else {
					completed = remove(completed, section.ID)
				}
				skipped = add(skipped, section.ID)
			case !configured:
				completed = remove(completed, section.ID)
				skipped = add(skipped, section.ID)
			default:
				completed = add(completed, section.ID)
				skipped = remove(skipped, section.ID)
			}
		}
		index++
		next := "configured"
		if index < len(sections) {
			next = sections[index].ID
		}
		transition(next, mappedCompleted(completed), resumeValues(draft))
	}
	provider := strings.ToLower(strings.TrimSpace(draft["VOICE_LIVE_PROVIDER"]))
	if provider != "" && !validLiveVoiceProvider(provider) {
		return nil, cli.Errorf("SETUP_VALUE_INVALID", "Live voice provider must be one of: %s.", strings.Join(liveVoiceProviderIDs, ", "))
	}
	draft["VOICE_LIVE_PROVIDER"] = provider
	keys, updates := environmentUpdates(draft)
	if err := envfile.WriteAtomic(a.Paths.EnvFile, []byte(envfile.Merge(raw, keys, updates)), 0o600); err != nil {
		return nil, err
	}
	a.UI.OK("Saved validated configuration to " + a.Paths.EnvFile)
	return mappedCompleted(completed), nil
}

// environmentUpdates are the env values full setup writes, in order; blank
// optional values are left out.
func environmentUpdates(draft map[string]string) ([]string, map[string]string) {
	var keys []string
	updates := map[string]string{}
	set := func(k, v string) {
		if strings.TrimSpace(v) == "" {
			return
		}
		if _, seen := updates[k]; !seen {
			keys = append(keys, k)
		}
		updates[k] = v
	}
	set("NODE_ENV", "production")
	set("PORT", draft["PORT"])
	set("PUBLIC_URL", draft["PUBLIC_URL"])
	set("SECURE_COOKIES", draft["SECURE_COOKIES"])
	set("TRUST_PROXY", draft["TRUST_PROXY"])
	set("SESSION_SECRET", orDefault(draft["SESSION_SECRET"], randomURLSecret()))
	set("NEOAGENT_DEPLOYMENT_MODE", orDefault(draft["NEOAGENT_DEPLOYMENT_MODE"], "self_hosted"))
	set("NEOAGENT_RELEASE_CHANNEL", orDefault(draft["NEOAGENT_RELEASE_CHANNEL"], "stable"))
	set("NEOAGENT_VM_GUEST_TOKEN", orDefault(draft["NEOAGENT_VM_GUEST_TOKEN"], randomURLSecret()))
	set("ALLOWED_ORIGINS", draft["ALLOWED_ORIGINS"])
	for _, list := range [][]field{providerFields, integrationFields, voiceFields} {
		for _, f := range list {
			set(f.key, draft[f.key])
		}
	}
	return keys, updates
}
