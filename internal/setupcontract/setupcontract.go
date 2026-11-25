// Package setupcontract is the setup contract shared by the CLI and the
// Flutter installer: profiles, sections, event stages, resumable settings and
// runtime targets, plus the public key runtime manifests are signed with.
// contract.json is the single source; setup_contract.g.dart is generated
// from it (Dart below).
package setupcontract

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

//go:embed contract.json
var contractJSON []byte

//go:embed runtime_signing_public_key.txt
var publicKeyText string

// Profile is a setup profile (quick or full).
type Profile struct {
	ID                   string `json:"id"`
	Label                string `json:"label"`
	Description          string `json:"description"`
	OptionalCapabilities bool   `json:"optionalCapabilities"`
}

// Section is a wizard section.
type Section struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Optional bool   `json:"optional"`
}

// Contract is the validated contract.
type Contract struct {
	SchemaVersion      int       `json:"schemaVersion"`
	DefaultPort        int       `json:"defaultPort"`
	Profiles           []Profile `json:"profiles"`
	CompletionSections []string  `json:"completionSections"`
	WizardSections     []Section `json:"wizardSections"`
	EventStages        []string  `json:"eventStages"`
	ResumeValueKeys    []string  `json:"resumeValueKeys"`
	// RuntimeTargets keeps the file's platform order for the Dart output.
	RuntimeTargets release.Targets `json:"runtimeTargets"`
	TargetOrder    []string        `json:"-"`
}

// C is the embedded contract.
var C = mustLoad(contractJSON)

func mustLoad(raw []byte) Contract {
	c, err := Load(raw)
	if err != nil {
		panic(err)
	}
	return c
}

// Load parses and validates a contract document.
func Load(raw []byte) (Contract, error) {
	var c Contract
	if err := json.Unmarshal(raw, &c); err != nil {
		return c, err
	}
	if c.SchemaVersion != 1 {
		return c, fmt.Errorf("Unsupported setup contract schema version.")
	}
	if c.DefaultPort < 1 || c.DefaultPort > 65535 {
		return c, fmt.Errorf("Invalid setup contract default port.")
	}
	if len(c.Profiles) < 2 {
		return c, fmt.Errorf("The setup contract requires setup profiles.")
	}
	ids := map[string]bool{}
	for _, p := range c.Profiles {
		if strings.TrimSpace(p.ID) == "" || strings.TrimSpace(p.Label) == "" || strings.TrimSpace(p.Description) == "" || ids[p.ID] {
			return c, fmt.Errorf("Invalid setup profile in setup contract.")
		}
		ids[p.ID] = true
	}
	sections := map[string]bool{}
	for _, s := range c.WizardSections {
		if strings.TrimSpace(s.ID) == "" || strings.TrimSpace(s.Label) == "" || sections[s.ID] {
			return c, fmt.Errorf("Invalid setup wizard section in setup contract.")
		}
		sections[s.ID] = true
	}
	for name, list := range map[string][]string{"completionSections": c.CompletionSections, "eventStages": c.EventStages, "resumeValueKeys": c.ResumeValueKeys} {
		if err := checkList(list, name); err != nil {
			return c, err
		}
	}
	for platform, archs := range c.RuntimeTargets {
		if err := checkList(archs, "runtimeTargets."+platform); err != nil {
			return c, err
		}
	}
	var order struct {
		RuntimeTargets json.RawMessage `json:"runtimeTargets"`
	}
	_ = json.Unmarshal(raw, &order)
	dec := json.NewDecoder(strings.NewReader(string(order.RuntimeTargets)))
	depth := 0
	for {
		tok, err := dec.Token()
		if err != nil {
			break
		}
		switch t := tok.(type) {
		case json.Delim:
			if t == '{' || t == '[' {
				depth++
			} else {
				depth--
			}
		case string:
			if depth == 1 {
				c.TargetOrder = append(c.TargetOrder, t)
			}
		}
	}
	return c, nil
}

func checkList(list []string, field string) error {
	seen := map[string]bool{}
	if len(list) == 0 {
		return fmt.Errorf("Invalid setup contract field: %s.", field)
	}
	for _, v := range list {
		if strings.TrimSpace(v) == "" || seen[v] {
			return fmt.Errorf("Invalid setup contract field: %s.", field)
		}
		seen[v] = true
	}
	return nil
}

// Profile returns the profile with id, or false.
func (c Contract) Profile(id string) (Profile, bool) {
	for _, p := range c.Profiles {
		if p.ID == id {
			return p, true
		}
	}
	return Profile{}, false
}

// PublicKey is the embedded runtime signing key as raw base64.
func PublicKey() string {
	k, err := release.NormalizePublicKey(publicKeyText)
	if err != nil {
		panic(err)
	}
	return k
}

func dartString(v string) string {
	return "'" + strings.NewReplacer(`\`, `\\`, `'`, `\'`).Replace(v) + "'"
}

func dartList(name string, values []string) string {
	quoted := make([]string, len(values))
	for i, v := range values {
		quoted[i] = dartString(v)
	}
	if len(values) <= 2 {
		return "const List<String> " + name + " = <String>[" + strings.Join(quoted, ", ") + "];"
	}
	lines := []string{"const List<String> " + name + " = <String>["}
	for _, q := range quoted {
		lines = append(lines, "  "+q+",")
	}
	return strings.Join(append(lines, "];"), "\n")
}

// Dart renders flutter_app/lib/src/setup_contract.g.dart.
func (c Contract) Dart(publicKey string) string {
	ids := func(n int, f func(int) string) []string {
		out := make([]string, n)
		for i := range out {
			out[i] = f(i)
		}
		return out
	}
	lines := []string{
		"// Generated by `go run ./cmd/neoagent-release setup-contract`. Do not edit.",
		"",
		fmt.Sprintf("const int setupContractSchemaVersion = %d;", c.SchemaVersion),
		fmt.Sprintf("const int neoAgentDefaultPort = %d;", c.DefaultPort),
		fmt.Sprintf("const String neoAgentDefaultPortText = '%d';", c.DefaultPort),
		"const String embeddedRuntimeSigningPublicKey = " + dartString(publicKey) + ";",
		"",
		dartList("setupProfileIds", ids(len(c.Profiles), func(i int) string { return c.Profiles[i].ID })),
		"",
		dartList("setupCompletionSections", c.CompletionSections),
		"",
		dartList("setupWizardSectionIds", ids(len(c.WizardSections), func(i int) string { return c.WizardSections[i].ID })),
		"",
		dartList("setupEventStages", c.EventStages),
		"",
		dartList("setupResumeValueKeys", c.ResumeValueKeys),
		"",
		"const Map<String, List<String>> setupRuntimeTargets = <String, List<String>>{",
	}
	for _, platform := range c.TargetOrder {
		archs := c.RuntimeTargets[platform]
		quoted := make([]string, len(archs))
		for i, a := range archs {
			quoted[i] = dartString(a)
		}
		lines = append(lines, "  "+dartString(platform)+": <String>["+strings.Join(quoted, ", ")+"],")
	}
	return strings.Join(append(lines, "};", ""), "\n")
}
