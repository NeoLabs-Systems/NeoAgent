package integrations

import (
	"encoding/json"
	"fmt"
)

// Spec is a provider's static description, generated from the Node registry by
// gen/dump.js and embedded next to the provider's code.
type Spec struct {
	Key                      string            `json:"key"`
	Label                    string            `json:"label"`
	Description              string            `json:"description"`
	Icon                     string            `json:"icon"`
	RequiresRefreshToken     bool              `json:"requiresRefreshToken"`
	Apps                     []App             `json:"apps"`
	ConnectPrompt            *string           `json:"connectPrompt"`
	SupportsMultipleAccounts *bool             `json:"supportsMultipleAccounts"`
	ConnectionMethod         string            `json:"connectionMethod"`
	Tools                    []json.RawMessage `json:"tools"`
	// DefaultApp is the app of tools that name none (GitHub's repos tools).
	// The provider sets it after LoadSpec.
	DefaultApp string `json:"-"`
}

// LoadSpec decodes an embedded provider.json. It panics on malformed data,
// which can only be a build-time mistake.
func LoadSpec(data []byte) Spec {
	var s Spec
	if err := json.Unmarshal(data, &s); err != nil {
		panic(fmt.Sprintf("integrations: bad provider spec: %v", err))
	}
	return s
}

// ToolList parses the spec's tool definitions.
func (s Spec) ToolList() []Tool {
	tools := make([]Tool, 0, len(s.Tools))
	for _, raw := range s.Tools {
		t, err := ParseTool(raw)
		if err != nil {
			panic(fmt.Sprintf("integrations: bad tool in %s spec: %v", s.Key, err))
		}
		if t.AppID == "" {
			t.AppID = s.DefaultApp
		}
		tools = append(tools, t)
	}
	return tools
}

// Info is the provider's static facts.
func (s Spec) Info() Info {
	return Info{Key: s.Key, Label: s.Label, Description: s.Description, Icon: s.Icon, RequiresRefreshToken: s.RequiresRefreshToken, Apps: s.Apps}
}
