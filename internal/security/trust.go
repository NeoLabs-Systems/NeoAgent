package security

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// Deterministic checks on a tool call against the run's trust record. They
// hold whatever the model was talked into, so they are the boundary. Two kinds
// of review, both answered by asking the owner: "audience" (someone other than
// the owner steers the run; holds even in allow_all) and "taint" (the run read
// outside content and the call would carry data somewhere new or plant an
// instruction for later runs; allow_all skips it).

var sharedAudienceTools = map[string]bool{"think": true, "search_tools": true, "activate_tools": true, "send_interim_update": true, "send_message": true,
	"react_to_message": true, "web_search": true, "social_video_extract": true, "generate_image": true, "generate_table": true, "generate_graph": true,
	"analyze_image": true, "transcribe_audio": true, "ocr_extract": true}

var mediaPathArgs = []string{"image_path", "audio_path"}
var recipientArgs = []string{"to", "cc", "bcc", "recipient", "recipients"}
var readMethods = map[string]bool{"GET": true, "HEAD": true, "OPTIONS": true}

var secretPatterns = []*regexp.Regexp{
	regexp.MustCompile(`\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{20,}`),
	regexp.MustCompile(`\bnvapi-[A-Za-z0-9_-]{30,}`),
	regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9]{36,}`),
	regexp.MustCompile(`\bgithub_pat_[A-Za-z0-9_]{40,}`),
	regexp.MustCompile(`\bxox[abprs]-[A-Za-z0-9-]{10,}`),
	regexp.MustCompile(`\bAKIA[0-9A-Z]{16}\b`),
	regexp.MustCompile(`\bAIza[0-9A-Za-z_-]{35}\b`),
	regexp.MustCompile(`\b[rs]k_live_[0-9A-Za-z]{20,}`),
	regexp.MustCompile(`\b\d{8,10}:AA[A-Za-z0-9_-]{33}\b`),
	regexp.MustCompile(`\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}`),
	regexp.MustCompile(`-----BEGIN [A-Z ]*PRIVATE KEY-----`),
}

var secretEnvKey = regexp.MustCompile(`(?i)(SECRET|TOKEN|PASSWORD|API_KEY|PRIVATE_KEY)`)

var (
	serverSecretsOnce sync.Once
	serverSecrets     []string
)

func secrets() []string {
	serverSecretsOnce.Do(func() {
		for _, kv := range os.Environ() {
			key, value, ok := strings.Cut(kv, "=")
			if ok && secretEnvKey.MatchString(key) && len([]rune(value)) >= 16 {
				serverSecrets = append(serverSecrets, value)
			}
		}
	})
	return serverSecrets
}

// RedactSecrets hides credentials in a text shown to a person.
func RedactSecrets(text string) string {
	for _, s := range secrets() {
		text = strings.ReplaceAll(text, s, "[hidden]")
	}
	for _, p := range secretPatterns {
		text = p.ReplaceAllString(text, "[hidden]")
	}
	return text
}

var angleAddress = regexp.MustCompile(`^.*<([^>]+)>\s*$`)

func listValues(v any) []string {
	switch t := v.(type) {
	case []any:
		var out []string
		for _, item := range t {
			out = append(out, listValues(item)...)
		}
		return out
	case string:
		var out []string
		for _, part := range regexp.MustCompile(`[,;]`).Split(t, -1) {
			if s := strings.TrimSpace(angleAddress.ReplaceAllString(part, "$1")); s != "" {
				out = append(out, s)
			}
		}
		return out
	}
	return nil
}

func hostOf(raw string) string {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return ""
	}
	return strings.TrimPrefix(strings.ToLower(u.Hostname()), "www.")
}

// Review is why a call needs the owner.
type Review struct {
	Kind         string // "audience" or "taint"
	Reason       string
	ReasonKey    string
	ReasonParams map[string]string
}

func str(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return fmt.Sprint(v)
}

func reviewShared(name string, args map[string]any, trust *agent.Trust) *Review {
	where := "a shared conversation"
	if trust.Origin != nil {
		where = trust.Origin.Platform + " chat " + trust.Origin.ChatID
	}
	if !sharedAudienceTools[name] {
		return &Review{Reason: fmt.Sprintf("Someone in %s other than you asked for %s.", where, name), ReasonKey: "someoneElse"}
	}
	if to := str(args["to"]); name == "send_message" && to != "" && !trust.IsOriginTarget(to) {
		return &Review{Reason: fmt.Sprintf("A run started from %s wants to message %s.", where, to), ReasonKey: "messageOther", ReasonParams: map[string]string{"target": to}}
	}
	for _, key := range mediaPathArgs {
		if p := str(args[key]); p != "" && !trust.MediaPaths[p] {
			return &Review{Reason: fmt.Sprintf("A run started from %s wants to open %s, which did not come with the message.", where, p), ReasonKey: "openFile"}
		}
	}
	return nil
}

func reviewTainted(meta tools.Meta, name string, args map[string]any, category string, trust *agent.Trust) *Review {
	read := "this run has read content from " + trust.DescribeTaint()
	if meta.Persistent {
		return &Review{Reason: fmt.Sprintf("%s would outlast this run, and %s.", name, read), ReasonKey: "outlast"}
	}
	keys := meta.RecipientArgs
	if len(keys) == 0 {
		keys = recipientArgs
	}
	for _, key := range keys {
		for _, recipient := range listValues(args[key]) {
			if !trust.IsOwnerNamed(recipient) {
				return &Review{Reason: fmt.Sprintf("You did not name %s as a recipient, and %s.", recipient, read), ReasonKey: "newRecipient", ReasonParams: map[string]string{"recipient": recipient}}
			}
		}
	}
	if name == "http_request" {
		method := strings.ToUpper(strings.TrimSpace(str(orDefault(args["method"], "GET"))))
		if method == "" {
			method = "GET"
		}
		host := hostOf(str(args["url"]))
		if !readMethods[method] && host != "" && !trust.IsOwnerNamed(host) {
			return &Review{Reason: fmt.Sprintf("%s to %s, a host you did not name, and %s.", method, host, read), ReasonKey: "newHost", ReasonParams: map[string]string{"host": host}}
		}
	}
	outbound := meta.Egress || category == "external"
	for _, key := range recipientArgs {
		outbound = outbound || args[key] != nil
	}
	if outbound {
		serialized, _ := json.Marshal(args)
		leaks := false
		for _, p := range secretPatterns {
			leaks = leaks || p.Match(serialized)
		}
		for _, s := range secrets() {
			leaks = leaks || strings.Contains(string(serialized), s)
		}
		if leaks {
			return &Review{Reason: fmt.Sprintf("%s would send what looks like a credential, and %s.", name, read), ReasonKey: "credential"}
		}
	}
	return nil
}

// ReviewCall checks a call against the run's trust record.
func ReviewCall(registry *tools.Registry, name string, args map[string]any, category string, trust *agent.Trust) *Review {
	if trust == nil {
		return nil
	}
	if args == nil {
		args = map[string]any{}
	}
	if trust.Audience == "shared" && !trust.ApprovedSpeaker {
		if r := reviewShared(name, args, trust); r != nil {
			r.Kind = "audience"
			return r
		}
	}
	if !trust.Tainted() {
		return nil
	}
	if r := reviewTainted(registry.Meta(name, nil), name, args, category, trust); r != nil {
		r.Kind = "taint"
		return r
	}
	return nil
}
