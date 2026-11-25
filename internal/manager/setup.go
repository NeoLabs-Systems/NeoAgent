package manager

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/envfile"
	"github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

// SetupOptions are the flags of `install` and `setup`.
type SetupOptions struct {
	Profile               string // "", "quick" or "full"
	Resume                bool
	JSON                  bool
	NonInteractive        bool
	RuntimePackage        bool
	DeferOptionalSections bool
	Channel               string
	ChannelGiven          bool
}

// ParseSetupArguments reads the setup flags; --quick with --full is an error.
func ParseSetupArguments(args []string) (SetupOptions, error) {
	o := SetupOptions{
		Resume: cli.HasFlag(args, "--resume"), JSON: cli.HasFlag(args, "--json"),
		NonInteractive: cli.HasFlag(args, "--non-interactive"), RuntimePackage: cli.HasFlag(args, "--runtime-package"),
		DeferOptionalSections: cli.HasFlag(args, "--defer-optional-sections"),
	}
	if cli.HasFlag(args, "--quick") {
		o.Profile = "quick"
	}
	if cli.HasFlag(args, "--full") {
		if o.Profile != "" {
			return o, cli.Errorf("SETUP_PROFILE_CONFLICT", "Choose either --quick or --full, not both.")
		}
		o.Profile = "full"
	}
	o.Channel, o.ChannelGiven = cli.FlagValue(args, "--channel")
	return o, nil
}

func normalizeProfile(v string) string {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "full", "complete":
		return "full"
	}
	return "quick"
}

// SetupState is setup-state.json: where an interrupted setup resumes.
type SetupState struct {
	SchemaVersion     int               `json:"schemaVersion"`
	RunID             string            `json:"runId"`
	Profile           string            `json:"profile"`
	Stage             string            `json:"stage"`
	Status            string            `json:"status"`
	CompletedSections []string          `json:"completedSections"`
	ResumeValues      map[string]string `json:"resumeValues"`
	UpdatedAt         string            `json:"updatedAt"`
}

func (a *App) stateFile() string { return filepath.Join(a.Paths.Home, "setup-state.json") }

func safeState(s SetupState) SetupState {
	values := map[string]string{}
	for k, v := range s.ResumeValues {
		if slices.Contains(setupcontract.C.ResumeValueKeys, k) && len(v) <= 4096 {
			values[k] = v
		}
	}
	if s.RunID == "" {
		s.RunID = cli.NewUUID()
	}
	if s.Stage == "" {
		s.Stage = "choose-profile"
	}
	if s.Status == "" {
		s.Status = "pending"
	}
	if s.CompletedSections == nil {
		s.CompletedSections = []string{}
	}
	return SetupState{
		SchemaVersion: setupcontract.C.SchemaVersion, RunID: s.RunID, Profile: normalizeProfile(s.Profile),
		Stage: s.Stage, Status: s.Status, CompletedSections: s.CompletedSections, ResumeValues: values,
		UpdatedAt: cli.ISOTime(time.Now()),
	}
}

func (a *App) writeState(s SetupState) (SetupState, error) {
	s = safeState(s)
	data, err := release.Serialize(s)
	if err != nil {
		return s, err
	}
	return s, envfile.WriteAtomic(a.stateFile(), data, 0o600)
}

func (a *App) readState() *SetupState {
	raw, err := os.ReadFile(a.stateFile())
	if err != nil {
		return nil
	}
	var s SetupState
	if json.Unmarshal(raw, &s) != nil || s.SchemaVersion != setupcontract.C.SchemaVersion {
		return nil
	}
	s = safeState(s)
	return &s
}

func (a *App) clearState() { _ = os.Remove(a.stateFile()) }

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func randomURLSecret() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func truthy(v string) string {
	if strings.EqualFold(strings.TrimSpace(v), "true") {
		return "true"
	}
	return "false"
}

// writeDefaultEnv fills in every default the env file does not set yet.
func (a *App) writeDefaultEnv(port int) error {
	current := a.env()
	get := func(k, def string) string {
		if v := strings.TrimSpace(current[k]); v != "" {
			return v
		}
		return def
	}
	publicURL := get("PUBLIC_URL", "")
	secure := get("SECURE_COOKIES", truthy(strconv.FormatBool(strings.HasPrefix(publicURL, "https://"))))
	defaults := [][2]string{
		{"NODE_ENV", "production"},
		{"PORT", get("PORT", strconv.Itoa(port))},
		{"PUBLIC_URL", publicURL},
		{"SECURE_COOKIES", truthy(secure)},
		{"TRUST_PROXY", truthy(get("TRUST_PROXY", secure))},
		{"SESSION_SECRET", get("SESSION_SECRET", randomHex(24))},
		{"NEOAGENT_DEPLOYMENT_MODE", deploymentMode(get("NEOAGENT_DEPLOYMENT_MODE", "self_hosted"))},
		{"NEOAGENT_RELEASE_CHANNEL", release.NormalizeChannel(get("NEOAGENT_RELEASE_CHANNEL", "stable"))},
		{"NEOAGENT_VM_GUEST_TOKEN", get("NEOAGENT_VM_GUEST_TOKEN", randomHex(24))},
		{"XAI_BASE_URL", get("XAI_BASE_URL", "https://api.x.ai/v1")},
		{"OLLAMA_URL", get("OLLAMA_URL", "http://localhost:11434")},
	}
	for _, kv := range defaults {
		if kv[1] == "" || strings.TrimSpace(current[kv[0]]) != "" {
			continue
		}
		if err := a.setEnv(kv[0], kv[1]); err != nil {
			return err
		}
	}
	return nil
}

func deploymentMode(v string) string {
	if strings.EqualFold(strings.TrimSpace(v), "managed") {
		return "managed"
	}
	return "self_hosted"
}

// apiKeyProviders are the AI services setup can take an API key for.
var apiKeyProviders = []struct{ Label, EnvKey string }{
	{"OpenAI", "OPENAI_API_KEY"}, {"Custom OpenAI-compatible", "OPENAI_COMPATIBLE_API_KEY"},
	{"Anthropic", "ANTHROPIC_API_KEY"}, {"Google", "GOOGLE_AI_KEY"}, {"xAI", "XAI_API_KEY"},
	{"NVIDIA NIM", "NVIDIA_API_KEY"}, {"MiniMax Code", "MINIMAX_API_KEY"}, {"Nous Portal", "NOUS_API_KEY"},
	{"OpenRouter", "OPENROUTER_API_KEY"}, {"TypeSafe", "TYPESAFE_API_KEY"},
}

const pickAINote = "Pick an AI any time from the Admin tab in the app, or run `neoagent setup` again."

// chooseAIProvider is quick setup's AI question; it returns the saved
// provider's label, or "" when skipped.
func (a *App) chooseAIProvider() (string, error) {
	a.UI.Title("Which AI should NeoAgent use?", `This is the "brain" that reads your messages and decides what to do.`)
	method, err := a.UI.Select("Connect an AI", []cli.Choice{
		{Value: "key", Label: "Paste an API key", Hint: "OpenAI, Anthropic, Google, xAI and more"},
		{Value: "login", Label: "Sign in with an account I already have", Hint: "Claude, ChatGPT, Copilot or Grok"},
		{Value: "later", Label: "I'll decide later", Hint: "NeoAgent can't answer until you pick one"},
	})
	if err != nil {
		return "", err
	}
	switch method {
	case "key":
		current := a.env()
		var choices []cli.Choice
		for i, p := range apiKeyProviders {
			hint := ""
			if strings.TrimSpace(current[p.EnvKey]) != "" {
				hint = "already saved"
			}
			choices = append(choices, cli.Choice{Value: strconv.Itoa(i), Label: p.Label, Hint: hint})
		}
		picked, err := a.UI.Select("Which service is the key from?", choices)
		if err != nil {
			return "", err
		}
		i, _ := strconv.Atoi(picked)
		p := apiKeyProviders[i]
		key, err := a.UI.AskSecret(p.Label+" API key", current[p.EnvKey])
		if err != nil {
			return "", err
		}
		if strings.TrimSpace(key) != "" {
			return p.Label, a.setEnv(p.EnvKey, key)
		}
	case "login":
		var choices []cli.Choice
		for _, p := range loginProviders {
			choices = append(choices, cli.Choice{Value: p.ID, Label: p.Label})
		}
		id, err := a.UI.Select("Which account?", choices)
		if err != nil {
			return "", err
		}
		for _, p := range loginProviders {
			if p.ID == id {
				return p.Label, p.flow(a, context.Background())
			}
		}
	}
	a.note(pickAINote)
	return "", nil
}

// runSetupProfile writes the configuration and returns the port to serve on.
func (a *App) runSetupProfile(ctx context.Context, profile string, o SetupOptions) (int, error) {
	interactive := !o.NonInteractive && !o.JSON && a.UI.Interactive()
	if profile == "full" && !o.DeferOptionalSections && !interactive {
		return 0, cli.Errorf("SETUP_REQUIRED_VALUE_MISSING", "Full setup requires an interactive terminal. Use --quick for unattended setup.")
	}
	port := a.Port()
	if strings.TrimSpace(os.Getenv("PORT")) == "" {
		var err error
		if port, err = cli.FindAvailablePort(setupcontract.C.DefaultPort, setupcontract.C.DefaultPort); err != nil {
			return 0, err
		}
	}
	var previous *SetupState
	if o.Resume {
		previous = a.readState()
	}
	state := SetupState{RunID: a.Events.RunID, Profile: profile, Stage: "configuration", Status: "in_progress"}
	if previous != nil {
		state.RunID, state.Stage, state.CompletedSections, state.ResumeValues = previous.RunID, previous.Stage, previous.CompletedSections, previous.ResumeValues
	}
	state, err := a.writeState(state)
	if err != nil {
		return 0, err
	}
	label := "Quickstart"
	if p, ok := setupcontract.C.Profile(profile); ok {
		label = p.Label
	}
	a.Events.Start("configuration", "Preparing "+label, 0.05)

	completed := []string{"core"}
	switch {
	case profile == "quick":
		if err := a.writeDefaultEnv(port); err != nil {
			return 0, err
		}
		state.Stage, state.CompletedSections = "provider", completed
		_, _ = a.writeState(state)
		if interactive {
			connected, err := a.chooseAIProvider()
			if err != nil {
				return 0, err
			}
			if connected != "" {
				completed = append(completed, "providers")
			}
		} else {
			a.note(pickAINote)
		}
	case o.DeferOptionalSections && o.NonInteractive:
		if err := a.writeDefaultEnv(port); err != nil {
			return 0, err
		}
		a.note("Configure AI providers from the Admin tab in the app or `neoagent env`. Continue integrations, voice, and optional tools in the NeoAgent app.")
	default:
		start, done, values := prepareResume(previous)
		completed, err = a.runFullSetup(port, start, done, values, func(sectionID string, sections []string, resume map[string]string) {
			state.Stage, state.Status, state.CompletedSections, state.ResumeValues = sectionID, "in_progress", sections, resume
			_, _ = a.writeState(state)
		})
		if err != nil {
			return 0, err
		}
	}
	if err := a.setEnv("NEOAGENT_SETUP_PROFILE", profile); err != nil {
		return 0, err
	}
	if err := a.setEnv("NEOAGENT_SETUP_COMPLETED_SECTIONS", strings.Join(completed, ",")); err != nil {
		return 0, err
	}
	state.Stage, state.Status, state.CompletedSections = "configured", "configured", completed
	if _, err := a.writeState(state); err != nil {
		return 0, err
	}
	a.Events.Complete("configuration", "Configuration saved", 0.15)
	return a.Port(), nil
}

func (a *App) resolveProfile(o SetupOptions) (string, error) {
	if o.Resume {
		s := a.readState()
		if s == nil {
			return "", cli.Errorf("SETUP_RESUME_NOT_FOUND", "No interrupted setup was found.")
		}
		return s.Profile, nil
	}
	if o.Profile != "" {
		return normalizeProfile(o.Profile), nil
	}
	if o.JSON || o.NonInteractive || !a.UI.Interactive() {
		return "quick", nil
	}
	return a.UI.Select("How would you like to set up?", []cli.Choice{
		{Value: "quick", Label: "Quickstart", Hint: "Safe defaults, ready in a few minutes (recommended)"},
		{Value: "full", Label: "Full setup", Hint: "Address, AI, integrations and voice, one by one"},
	})
}

func (a *App) applyChannelFlag(o SetupOptions) error {
	if !o.ChannelGiven {
		return nil
	}
	channel := release.ParseChannel(o.Channel)
	if channel == "" {
		return usageError("Usage: neoagent install --channel stable|beta")
	}
	return a.setEnv("NEOAGENT_RELEASE_CHANNEL", channel)
}

func (a *App) cmdSetup(ctx context.Context, args []string) error {
	o, err := ParseSetupArguments(args)
	if err != nil {
		return err
	}
	if err := a.applyChannelFlag(o); err != nil {
		return err
	}
	profile, err := a.resolveProfile(o)
	if err != nil {
		return err
	}
	a.Events.Profile = profile
	if _, err := a.runSetupProfile(ctx, profile, o); err != nil {
		return err
	}
	a.clearState()
	a.Events.Complete("setup", "Setup configuration is complete", 1)
	if a.JSON {
		return nil
	}
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold("Settings saved"), "")
	switch {
	case !a.Service.Managed():
		a.UI.Note("Next, run " + a.UI.Command("neoagent install") + " to start NeoAgent on this computer.")
	case a.UI.Interactive():
		if ok, _ := a.UI.Confirm("Restart NeoAgent now to use them?", true); ok {
			return a.cmdRestart(ctx, nil)
		}
		fallthrough
	default:
		a.UI.Note("They take effect after " + a.UI.Command("neoagent restart") + ".")
	}
	return nil
}

// liveVoiceProviderIDs are the live voice providers full setup accepts.
var liveVoiceProviderIDs = []string{"openai", "google", "neorouter_openai", "neorouter_google"}

func validLiveVoiceProvider(v string) bool {
	_, ok := voice.ProviderByID(v)
	return ok
}

var placeholderSecrets = map[string]bool{
	"neoagent-dev-secret-change-me":                true,
	"change-this-to-a-random-secret-in-production": true,
	"change-me-to-something-random":                true,
}

var weakGuestToken = regexp.MustCompile(`(?i)^(change|replace|set|your|example|sample|placeholder|token|secret)[-_a-z0-9]*$|change-this-guest-token-before-prod`)

// ensureSecrets gives the env file a session secret and a guest token before
// a production start, as the Node.js server did on its first start.
func (a *App) ensureSecrets() error {
	if v := strings.TrimSpace(os.Getenv("SESSION_SECRET")); v == "" || placeholderSecrets[v] {
		if err := a.setEnv("SESSION_SECRET", randomHex(32)); err != nil {
			return err
		}
	}
	if v := strings.TrimSpace(os.Getenv("NEOAGENT_VM_GUEST_TOKEN")); len(v) < 32 || weakGuestToken.MatchString(v) || strings.Trim(v, v[:1]) == "" {
		return a.setEnv("NEOAGENT_VM_GUEST_TOKEN", randomHex(32))
	}
	return nil
}
