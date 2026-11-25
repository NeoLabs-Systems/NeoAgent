package tools

import (
	"fmt"
	"slices"
	"strings"
)

// Meta is the resolved reading of a tool: its traits under its name.
type Meta struct {
	Traits
	Name string
	// Known is true for built-in and integrated tools; integration, MCP and
	// skill tools get the conservative reading.
	Known bool
}

// Registry holds the built-in definitions and the metadata of the integrated
// tools.
type Registry struct {
	definitions []Definition
	static      map[string]Meta
	order       []string
	env         Environment
}

// Environment answers the questions some built-ins' availability depends on.
type Environment interface {
	// HostTerminal reports that commands run on the server's own machine
	// instead of in a guest computer.
	HostTerminal() bool
	// WebSharingEnabled reports whether the owner allows sharing web pages.
	WebSharingEnabled(userID int64) bool
}

// NewRegistry loads the embedded definitions.
func NewRegistry(env Environment) (*Registry, error) {
	file, err := parseDefinitionFile()
	if err != nil {
		return nil, err
	}
	r := &Registry{definitions: file.Definitions, static: map[string]Meta{}, env: env}
	for _, def := range file.Definitions {
		r.static[def.Name] = Meta{Traits: def.Traits, Name: def.Name, Known: true}
		r.order = append(r.order, def.Name)
	}
	for _, integrated := range file.Integrated {
		r.static[integrated.Name] = Meta{Traits: integrated.Traits, Name: integrated.Name, Known: true}
		r.order = append(r.order, integrated.Name)
	}
	return r, nil
}

// Definitions is every built-in definition, in registry order.
func (r *Registry) Definitions() []Definition { return r.definitions }

// Meta resolves what the harness knows about a tool. definition is the live
// definition for tools outside the registry and may be nil.
func (r *Registry) Meta(name string, definition *Definition) Meta {
	name = strings.TrimSpace(name)
	if meta, ok := r.static[name]; ok {
		return meta
	}
	return metaFromDefinition(name, definition)
}

// StaticNames lists the tools the registry knows: built-ins first, then the
// integrated ones.
func (r *Registry) StaticNames() []string { return slices.Clone(r.order) }

// NamesWithSelection lists the tools offered on the first turn for a selection.
func (r *Registry) NamesWithSelection(selection string) []string {
	var names []string
	for _, name := range r.StaticNames() {
		if r.static[name].Selection == selection {
			names = append(names, name)
		}
	}
	return names
}

// Integration, MCP and skill tools declare at most their access and family, so
// they get the conservative reading: anything not declared read-only can have
// side effects, and their output is untrusted.
func metaFromDefinition(name string, definition *Definition) Meta {
	traits := defaultTraits()
	var access string
	if definition != nil {
		access = strings.ToLower(strings.TrimSpace(definition.Access))
	}
	group := "external"
	if definition != nil && (definition.Integration != nil && truthy(definition.Integration) || access != "") {
		group = "integration"
	}
	if definition != nil && definition.ServerID != "" || strings.HasPrefix(name, "mcp_") {
		group = "mcp"
	}
	traits.Group = group
	traits.Access = access
	traits.SideEffect = "external"
	if access == "read" {
		traits.SideEffect = "none"
	}
	traits.StateScope = "external"
	traits.Repeatable = true
	if group == "mcp" {
		traits.StepType = "mcp"
	}
	if definition != nil {
		traits.ResultShape = definition.ResultShape
		traits.FileArgs = definition.FileArgs
	}
	return Meta{Traits: traits, Name: name}
}

func truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case string:
		return x != ""
	case float64:
		return x != 0
	}
	return true
}

func isReadMethod(args map[string]any) bool {
	method := "GET"
	for _, key := range []string{"method", "http_method"} {
		if v, ok := args[key]; ok && v != nil {
			method = strings.ToUpper(strings.TrimSpace(fmt.Sprint(v)))
			break
		}
	}
	if method == "" {
		method = "GET"
	}
	return method == "GET" || method == "HEAD" || method == "OPTIONS"
}

// CallAccess reports whether this particular call can change anything outside
// the run: "read", "write", or "" when the tool does not say. Tools whose
// answer depends on their arguments say so with a dynamic access value.
func CallAccess(meta Meta, args map[string]any) string {
	switch meta.Access {
	case "read", "write":
		return meta.Access
	case "dynamic_http_method":
		if isReadMethod(args) {
			return "read"
		}
		return "write"
	case "dynamic_shell":
		command, _ := args["command"].(string)
		if IsClearlyReadOnlyShellCommand(command, false) {
			return "read"
		}
		return "write"
	}
	return ""
}

// IsShellCall reports whether the tool runs commands.
func IsShellCall(meta Meta) bool {
	return meta.Group == "shell" || meta.Access == "dynamic_shell"
}

// IsReadOnlyCall reports whether this call only reads.
func IsReadOnlyCall(meta Meta, args map[string]any) bool {
	return CallAccess(meta, args) == "read"
}

// Calls that act on one shared page or device stay in order even when each only
// reads: an extract next to a navigation sees whichever page won the race. The
// shell stays serial too, since a command that looks read-only can still depend
// on one before it.
var sharedStateGroups = []string{"browser", "desktop", "android", "shell", "messaging"}

// IsParallelSafeCall reports whether the call may run next to others.
func IsParallelSafeCall(meta Meta, args map[string]any) bool {
	return IsReadOnlyCall(meta, args) && !meta.Exclusive && !slices.Contains(sharedStateGroups, meta.Group)
}

// ChangesState reports whether a successful call moved the work forward. A
// navigation only reads, but what the next browser call sees has changed. A
// tool that does not declare its access (MCP, skills) makes no claim, so its
// result counts as evidence, not as a change; repeat detection still catches it
// spinning.
func ChangesState(meta Meta, args map[string]any) bool {
	switch meta.SideEffect {
	case "navigation":
		return true
	case "none":
		return false
	}
	return CallAccess(meta, args) == "write"
}

// StepType is the kind a run step of this tool is recorded under.
func (r *Registry) StepType(name string, definition *Definition) string {
	meta := r.Meta(name, definition)
	if meta.StepType != "" {
		return meta.StepType
	}
	byGroup := map[string]string{
		"browser": "browser", "desktop": "desktop", "android": "android", "shell": "cli",
		"files": "files", "memory": "memory", "tasks": "tasks", "mcp": "mcp",
	}
	if step, ok := byGroup[meta.Group]; ok {
		return step
	}
	return "tool"
}

// ResultBudget names which result budget a tool's output is held to.
func ResultBudget(meta Meta) string {
	switch meta.Group {
	case "files":
		return "file"
	case "browser":
		return "browser"
	case "shell", "android":
		return "command"
	}
	return "default"
}

// RunOptions are the limits of a run that decide which calls are refused.
type RunOptions struct {
	DisallowedToolNames []string
	// AllowedToolNames is nil when every tool is allowed.
	AllowedToolNames []string
	ReadOnly         bool
}

// RunToolRefusal explains why a call is not allowed, or returns "". Discovery
// and activation never grant authority: every handler, including the external
// fallback dispatch, uses this one eligible-catalog and child-limit decision.
// catalog is nil when the run has no catalog to check against.
func (r *Registry) RunToolRefusal(catalog []Definition, options RunOptions, name string, args map[string]any) string {
	var definition *Definition
	for i := range catalog {
		if catalog[i].Name == name {
			definition = &catalog[i]
			break
		}
	}
	unavailable := name + " is not available to this run."
	if catalog != nil && definition == nil {
		return unavailable
	}
	if slices.Contains(options.DisallowedToolNames, name) {
		return unavailable
	}
	if options.AllowedToolNames != nil && !slices.Contains(options.AllowedToolNames, name) && name != "task_ledger" {
		return unavailable
	}
	meta := r.Meta(name, definition)
	if options.ReadOnly && (IsShellCall(meta) || !IsReadOnlyCall(meta, args)) {
		return "This run may only read, and " + name + " may change something or run commands."
	}
	return ""
}
