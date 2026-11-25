package skills

import (
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

// Meta is a skill's front matter members in file order.
type Meta = workspace.Obj

// decodeMeta reads a JSON object column; anything else is an empty object.
func decodeMeta(text string) Meta {
	if text == "" {
		return Meta{}
	}
	v, err := workspace.DecodeJSON([]byte(text))
	if err != nil {
		return Meta{}
	}
	if obj, ok := v.(Meta); ok {
		return obj
	}
	return Meta{}
}
