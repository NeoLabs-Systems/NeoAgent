package agentimport

import (
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	_ "modernc.org/sqlite" // read-only access to OpenClaw's state
)

// platformLabels names the chat platforms the importers know.
var platformLabels = map[string]string{"telegram": "Telegram", "discord": "Discord", "slack": "Slack", "whatsapp": "WhatsApp"}

func isMessagingPlatform(name string) bool { _, ok := platformLabels[name]; return ok }

// envVars is an environment map that keeps the order its values were read in.
type envVars struct {
	keys []string
	m    map[string]string
}

func newEnvVars() *envVars { return &envVars{m: map[string]string{}} }

func (e *envVars) set(key, value string) {
	if _, ok := e.m[key]; !ok {
		e.keys = append(e.keys, key)
	}
	e.m[key] = value
}

// get returns the value, or "" when it is not set.
func (e *envVars) get(key string) string { return e.m[key] }

var (
	envLine  = regexp.MustCompile(`^(?:export` + ws + `+)?([A-Za-z_][A-Za-z0-9_]*)` + ws + `*=` + ws + `*(.*)$`)
	envTrail = regexp.MustCompile(ws + `+#.*$`)
)

// parseDotEnv reads .env files written by hand: `export KEY=value`, quotes and
// inline comments.
func parseDotEnv(text string) *envVars {
	values := newEnvVars()
	for _, raw := range strings.Split(text, "\n") {
		line := trim(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		m := envLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		value := trim(m[2])
		if value != "" && (value[0] == '"' || value[0] == '\'') && strings.LastIndexByte(value, value[0]) > 0 {
			value = value[1:strings.LastIndexByte(value, value[0])]
		} else {
			value = trim(envTrail.ReplaceAllString(value, ""))
		}
		if value != "" {
			values.set(m[1], value)
		}
	}
	return values
}

// envAliases maps source env names to the names NeoAgent reads; the first
// alias present wins.
var envAliases = []struct {
	target  string
	aliases []string
}{
	{"ANTHROPIC_API_KEY", []string{"ANTHROPIC_API_KEY"}},
	{"OPENAI_API_KEY", []string{"OPENAI_API_KEY"}},
	{"OPENROUTER_API_KEY", []string{"OPENROUTER_API_KEY"}},
	{"GOOGLE_AI_KEY", []string{"GOOGLE_AI_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GENERATIVE_AI_API_KEY"}},
	{"XAI_API_KEY", []string{"XAI_API_KEY", "GROK_API_KEY"}},
	{"NVIDIA_API_KEY", []string{"NVIDIA_API_KEY", "NVIDIA_NIM_API_KEY"}},
	{"MINIMAX_API_KEY", []string{"MINIMAX_API_KEY"}},
	{"NOUS_API_KEY", []string{"NOUS_API_KEY"}},
	{"BRAVE_SEARCH_API_KEY", []string{"BRAVE_SEARCH_API_KEY", "BRAVE_API_KEY"}},
	{"DEEPGRAM_API_KEY", []string{"DEEPGRAM_API_KEY"}},
	{"ELEVENLABS_API_KEY", []string{"ELEVENLABS_API_KEY", "XI_API_KEY"}},
}

// knownForeignKeys are services NeoAgent has no use for; they are named in the
// report so the user knows they were seen and left behind on purpose.
var knownForeignKeys = map[string]bool{
	"GROQ_API_KEY": true, "MISTRAL_API_KEY": true, "DEEPSEEK_API_KEY": true, "TOGETHER_API_KEY": true, "FIREWORKS_API_KEY": true,
	"COHERE_API_KEY": true, "PERPLEXITY_API_KEY": true, "MOONSHOT_API_KEY": true, "FAL_KEY": true, "FAL_API_KEY": true,
	"FIRECRAWL_API_KEY": true, "TAVILY_API_KEY": true, "EXA_API_KEY": true, "BROWSERBASE_API_KEY": true, "HF_TOKEN": true,
	"HUGGINGFACE_API_KEY": true, "GITHUB_TOKEN": true, "VOICE_TOOLS_OPENAI_KEY": true,
}

// keyList is the NeoAgent env keys a bundle carries, in the order found.
type keyList struct {
	names []string
	m     map[string]string
}

func newKeyList() *keyList { return &keyList{m: map[string]string{}} }

func (k *keyList) set(name, value string) {
	if _, ok := k.m[name]; !ok {
		k.names = append(k.names, name)
	}
	k.m[name] = value
}

// setIfEmpty is `keys[name] = keys[name] || value`.
func (k *keyList) setIfEmpty(name, value string) {
	if k.m[name] == "" {
		k.set(name, value)
	}
}

func (k *keyList) get(name string) string { return k.m[name] }

// mapEnvKeys splits a source env map into keys NeoAgent uses and names it does
// not.
func mapEnvKeys(source *envVars) (*keyList, []string) {
	keys := newKeyList()
	consumed := map[string]bool{}
	for _, entry := range envAliases {
		for _, alias := range entry.aliases {
			consumed[alias] = true
		}
		for _, alias := range entry.aliases {
			if v := source.get(alias); v != "" {
				keys.set(entry.target, v)
				break
			}
		}
	}
	var ignored []string
	for _, name := range source.keys {
		if !consumed[name] && knownForeignKeys[name] {
			ignored = append(ignored, name)
		}
	}
	return keys, ignored
}

// providerKeyEnv names the env key of each provider id used by OpenClaw auth
// profiles and Hermes provider names.
var providerKeyEnv = map[string]string{
	"anthropic": "ANTHROPIC_API_KEY", "openai": "OPENAI_API_KEY", "openrouter": "OPENROUTER_API_KEY",
	"google": "GOOGLE_AI_KEY", "gemini": "GOOGLE_AI_KEY", "xai": "XAI_API_KEY", "grok": "XAI_API_KEY",
	"nvidia": "NVIDIA_API_KEY", "minimax": "MINIMAX_API_KEY", "nous": "NOUS_API_KEY",
}

// modelProviderIDs maps "provider/model" providers to NeoAgent's
// "provider::model" ids.
var modelProviderIDs = map[string]string{
	"anthropic": "anthropic", "openai": "openai", "openrouter": "openrouter", "google": "google", "gemini": "google",
	"xai": "grok", "grok": "grok", "nvidia": "nvidia", "minimax": "minimax", "ollama": "ollama",
	"nous": "nous", "nous-api": "nous", "openai-compatible": "openai-compatible",
}

// fromSlashModel turns "anthropic/claude-x" into "anthropic::claude-x";
// OpenRouter ids keep their own slash. It returns "" when there is no model.
func fromSlashModel(value any) string {
	text := trim(str(value))
	if slash := strings.Index(text, "/"); slash > 0 {
		return toNeoAgentModel(text[:slash], text[slash+1:])
	}
	return ""
}

func toNeoAgentModel(provider, model string) string {
	id := modelProviderIDs[strings.ToLower(provider)]
	model = trim(model)
	if id == "" || model == "" {
		return ""
	}
	return id + "::" + model
}

var envRef = regexp.MustCompile(`\$\{([A-Za-z_][A-Za-z0-9_]*)\}`)

// resolveSecret reads SecretRef objects ({ source: 'env', id }) and "${VAR}"
// strings. It returns "" when the value cannot be filled in.
func resolveSecret(value any, env *envVars, home string) string {
	if o, ok := value.(*Obj); ok {
		switch str(o.Get("source")) {
		case "env":
			if id := str(o.Get("id")); id != "" {
				return env.get(id)
			}
		case "file":
			if p := str(o.Get("path")); p != "" {
				text, _ := readText(expandHome(p, home))
				return trim(text)
			}
		}
		return ""
	}
	// "${VAR}" anywhere in the value ("Bearer ${TOKEN}"); an unknown name makes
	// the whole value unusable rather than half-filled.
	missing := false
	text := envRef.ReplaceAllStringFunc(trim(str(value)), func(ref string) string {
		name := envRef.FindStringSubmatch(ref)[1]
		if env.get(name) == "" {
			missing = true
		}
		return env.get(name)
	})
	if missing {
		return ""
	}
	return text
}

func expandHome(value, home string) string {
	text := trim(value)
	if text == "~" {
		return home
	}
	if strings.HasPrefix(text, "~/") {
		return filepath.Join(home, text[2:])
	}
	return text
}

// header is one header of a remote MCP server.
type header struct{ Name, Value string }

var (
	bearerValue = regexp.MustCompile(`(?i)^Bearer` + ws + `+(.+)$`)
	sseSuffix   = regexp.MustCompile(`/sse/?$`)
)

// mcpEntry builds a remote MCP server: an Authorization: Bearer header becomes
// NeoAgent's bearer token, other headers are kept as they are.
func mcpEntry(name, url string, rawHeaders any, transport string, enabled bool, env *envVars, home string) MCPServer {
	server := MCPServer{Name: name, URL: url, Enabled: enabled}
	if h := asObj(rawHeaders); h != nil {
		for _, key := range h.Keys() {
			resolved := resolveSecret(h.Get(key), env, home)
			if resolved == "" {
				continue
			}
			if m := bearerValue.FindStringSubmatch(resolved); strings.EqualFold(key, "authorization") && m != nil {
				token := trim(m[1])
				server.Token = &token
			} else {
				server.Headers = append(server.Headers, header{key, resolved})
			}
		}
	}
	if transport == "sse" || sseSuffix.MatchString(url) {
		server.Transport = "sse"
	} else {
		server.Transport = "streamable-http"
	}
	return server
}

// ---- OpenClaw's SQLite state --------------------------------------------------

// openSqlite opens a database read-only; a missing or unreadable file reads as
// nothing.
func openSqlite(file string) *sql.DB {
	if !isFile(file) {
		return nil
	}
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(file)+"?mode=ro&_pragma=query_only(1)")
	if err != nil {
		return nil
	}
	db.SetMaxOpenConns(1)
	if db.Ping() != nil {
		db.Close()
		return nil
	}
	return db
}

// queryStrings runs a query whose columns are all read as text; a missing
// table or any error reads as empty. NULL columns come back as "".
func queryStrings(db *sql.DB, query string, columns int) [][]string {
	if db == nil {
		return nil
	}
	rows, err := db.Query(query)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out [][]string
	for rows.Next() {
		cells := make([]sql.NullString, columns)
		ptrs := make([]any, columns)
		for i := range cells {
			ptrs[i] = &cells[i]
		}
		if rows.Scan(ptrs...) != nil {
			return out
		}
		row := make([]string, columns)
		for i, c := range cells {
			row[i] = c.String
		}
		out = append(out, row)
	}
	return out
}

func homeDirOr(dir string) string {
	if dir != "" {
		return dir
	}
	home, _ := os.UserHomeDir()
	return home
}

func isNoRows(err error) bool { return errors.Is(err, sql.ErrNoRows) }
