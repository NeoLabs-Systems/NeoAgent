package integrations

import "strings"

// Toolset answers the questions about a provider's tools that do not depend on
// the provider: which app a tool belongs to, which tools an app set unlocks.
type Toolset struct {
	tools []Tool
	appOf map[string]string
}

// NewToolset indexes tools by name.
func NewToolset(tools []Tool) Toolset {
	appOf := make(map[string]string, len(tools))
	for _, t := range tools {
		if t.Name != "" && t.AppID != "" {
			appOf[t.Name] = t.AppID
		}
	}
	return Toolset{tools: tools, appOf: appOf}
}

// ForApps are the tools of the given apps, in definition order.
func (ts Toolset) ForApps(appIDs []string) []Tool {
	set := make(map[string]bool, len(appIDs))
	for _, id := range appIDs {
		set[id] = true
	}
	var out []Tool
	for _, t := range ts.tools {
		if set[t.AppID] {
			out = append(out, t)
		}
	}
	return out
}

// AppID is the app a tool belongs to, or "".
func (ts Toolset) AppID(name string) string { return ts.appOf[strings.TrimSpace(name)] }

// Supports reports whether the provider has a tool of that name.
func (ts Toolset) Supports(name string) bool {
	_, ok := ts.appOf[strings.TrimSpace(name)]
	return ok
}

// CountForApp is the number of tools of one app.
func (ts Toolset) CountForApp(appID string) int {
	n := 0
	for _, t := range ts.tools {
		if t.AppID == appID {
			n++
		}
	}
	return n
}

// NamesForApp lists an app's tool names.
func (ts Toolset) NamesForApp(appID string) []string {
	var names []string
	for _, t := range ts.tools {
		if t.AppID == appID {
			names = append(names, t.Name)
		}
	}
	return names
}
