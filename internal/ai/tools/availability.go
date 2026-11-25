package tools

import "slices"

// Options describe the run a catalog is built for.
type Options struct {
	// UserID is nil for runs without an owner.
	UserID        *int64
	AgentID       string
	TriggerType   string
	TriggerSource string
}

var interactiveSources = []string{"web", "messaging", "voice_live"}

// Available lists the built-in definitions offered in this situation: a
// handful depend on how the run was started or where the agent's files live.
func (r *Registry) Available(options Options) []Definition {
	var out []Definition
	for _, def := range r.definitions {
		if def.AvailableWhen && !r.availableWhen(def.Name, options) {
			continue
		}
		out = append(out, def)
	}
	return out
}

func (r *Registry) availableWhen(name string, o Options) bool {
	switch name {
	case "background_task":
		return o.TriggerType == "user" && slices.Contains(interactiveSources, o.TriggerSource)
	case "send_interim_update":
		return slices.Contains(interactiveSources, o.TriggerSource) && o.TriggerType != "subagent"
	case "react_to_message":
		return o.TriggerSource == "messaging" && o.TriggerType == "user"
	// These read the server's own disk. With a guest computer that is not where
	// the agent's files are, so they would only ever report nothing.
	case "code_navigate", "query_structured_data":
		return r.env.HostTerminal()
	// Sharing needs a guest computer and an owner who allows it, so with the
	// setting off the model never sees it.
	case "share_web_page":
		return o.UserID != nil && !r.env.HostTerminal() && r.env.WebSharingEnabled(*o.UserID)
	}
	// A definition marked availableWhen without a rule here would be offered
	// everywhere; the tests list the marked ones so a new one cannot slip by.
	return true
}
