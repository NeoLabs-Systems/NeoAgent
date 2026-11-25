// Package tools is the registry of the tools a model can call: every built-in
// definition (name, description, JSON schema and the traits the harness reads),
// how a definition is shown to a provider, the metadata that scheduling, repeat
// detection and the security policy read, and the repair of near-miss
// arguments.
//
// definitions.json is generated from the Node server's tool registry by
// ../gen/definitions.js, so descriptions and schemas are the ones the Node
// harness showed its models.
package tools

import (
	_ "embed"
	"encoding/json"
	"fmt"
)

//go:embed definitions.json
var definitionsJSON []byte

// Traits is what the harness knows about a tool besides its schema. Scheduling,
// repeat detection, progress tracking, trust, result budgets and the security
// policy all read this instead of keeping their own lists of tool names.
type Traits struct {
	Group      string `json:"group"`
	StepType   string `json:"stepType"`
	Access     string `json:"access"`
	SideEffect string `json:"sideEffect"`
	StateScope string `json:"stateScope"`
	// LatencyClass is how long a call takes. "remote" means it calls a remote
	// service, which the repeat check reads: only a service fails the same way
	// whatever it is asked.
	LatencyClass string `json:"latencyClass"`
	Repeatable   bool   `json:"repeatable"`
	// Untrusted: the result can carry content the owner did not write.
	Untrusted     bool           `json:"untrusted"`
	Exclusive     bool           `json:"exclusive"`
	Capabilities  []string       `json:"capabilities"`
	Prerequisites []string       `json:"prerequisites"`
	Policy        map[string]any `json:"policy"`
	WhenToUse     []string       `json:"whenToUse"`
	WhenNotToUse  []string       `json:"whenNotToUse"`
	// Selection is when the tool is on the first turn: "always", "default" or "coding".
	Selection string `json:"selection"`
	// Persistent tools outlast the run; Egress tools can carry an argument off the machine.
	Persistent bool `json:"persistent"`
	Egress     bool `json:"egress"`
	// RecipientArgs names the arguments that say who receives something, when
	// they differ from the usual ones.
	RecipientArgs []string `json:"recipientArgs"`
	// ResultShape says how the result is cut down; without one it gets a plain summary.
	ResultShape string `json:"resultShape"`
	// FileArgs name a file in the agent's workspace for the tool to read.
	FileArgs []string `json:"fileArgs"`
}

func defaultTraits() Traits {
	return Traits{
		Group:        "external",
		SideEffect:   "none",
		StateScope:   "none",
		LatencyClass: "remote",
		Untrusted:    true,
	}
}

// Definition is one tool as the registry stores it. Built-in definitions come
// from definitions.json; skills, integrations and MCP servers supply theirs at
// run time.
type Definition struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters"`
	Family      string         `json:"family"`
	// Integration is set on tools an official integration provides.
	Integration any    `json:"integration"`
	ServerID    string `json:"serverId"`
	// AvailableWhen marks built-ins that are only offered in some situations;
	// Registry.Available holds the rule by tool name.
	AvailableWhen bool `json:"availableWhen"`
	Traits
}

// UnmarshalJSON starts from the trait defaults, so a definition only states
// what differs.
func (d *Definition) UnmarshalJSON(data []byte) error {
	type plain Definition
	value := plain{Traits: defaultTraits()}
	if err := json.Unmarshal(data, &value); err != nil {
		return err
	}
	*d = Definition(value)
	return nil
}

type definitionFile struct {
	Definitions []Definition       `json:"definitions"`
	Integrated  []IntegratedTraits `json:"integrated"`
}

// IntegratedTraits is the metadata of a tool whose schema lives with its
// implementation.
type IntegratedTraits struct {
	Name string
	Traits
}

// UnmarshalJSON starts from the trait defaults.
func (t *IntegratedTraits) UnmarshalJSON(data []byte) error {
	t.Traits = defaultTraits()
	if err := json.Unmarshal(data, &t.Traits); err != nil {
		return err
	}
	var named struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(data, &named); err != nil {
		return err
	}
	t.Name = named.Name
	return nil
}

func parseDefinitionFile() (definitionFile, error) {
	var file definitionFile
	if err := json.Unmarshal(definitionsJSON, &file); err != nil {
		return definitionFile{}, fmt.Errorf("tools: definitions.json: %w", err)
	}
	return file, nil
}
