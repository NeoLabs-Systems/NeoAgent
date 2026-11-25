package agentimport

// Bundle is what one scanned agent installation holds, in the shape both
// importers produce and the apply step consumes.
type Bundle struct {
	Source      string
	Label       string
	Path        string
	Home        string
	Agents      []Agent
	Skills      []Skill
	Keys        *keyList
	IgnoredKeys []string
	// SourceModel is the model as the source named it, for the summary.
	SourceModel string
	// Model is the NeoAgent "provider::model" id, or "".
	Model    string
	MCP      []MCPServer
	Tasks    []Task
	Channels []Channel
	Timezone string
	Skipped  []Skipped
}

// Agent is one source agent with its memory files.
type Agent struct {
	Key       string
	Name      string
	IsDefault bool
	// Instructions and UserProfile are "" when the source has none.
	Instructions string
	Memories     []Memory
	UserProfile  string
	DailyLogs    []DailyLog
	Workspace    string
	// Model is the NeoAgent model id of an agent-specific choice, or "".
	Model string
}

// Memory is one remembered fact with its category.
type Memory struct{ Text, Category string }

// DailyLog is one day of notes.
type DailyLog struct{ Date, Content string }

// Skill is a skill folder: SKILL.md plus bundled files.
type Skill struct {
	Name        string
	Description string
	Body        string
	Dir         string
	Origin      string
	Files       []string
}

// MCPServer is a remote MCP server.
type MCPServer struct {
	Name      string
	URL       string
	Token     *string
	Headers   []header
	Transport string
	Enabled   bool
}

// Trigger is when an automation runs.
type Trigger struct {
	Mode           string // "recurring" or "one_time"
	CronExpression string
	RunAt          string
	Note           string
}

// Notify is where an automation reports to.
type Notify struct {
	Platform string
	To       string
}

// Task is an automation.
type Task struct {
	Name     string
	AgentKey string
	Prompt   string
	Trigger  Trigger
	Enabled  bool
	// TZ is the time zone the source schedule used, or "".
	TZ     string
	Notify *Notify
	Model  string
	Note   string
}

// Channel is a chat connection; Config is nil when the connection cannot be
// carried over (WhatsApp) and only its allowlist is.
type Channel struct {
	Platform string
	Config   []header
	Allow    []string
}

// Skipped is something the importer saw and left behind. Detail is the
// original definition, when it is worth handing to the finishing agent.
type Skipped struct {
	Kind   string
	Name   string
	Reason string
	Detail any
}
