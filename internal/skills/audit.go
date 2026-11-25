package skills

import (
	"path/filepath"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

var (
	shellMetachar = regexp.MustCompile("[;&|`$\n\r(){}\\\\<>]")
	placeholder   = regexp.MustCompile(`\{[^{}]*\}`)
	packageRef    = regexp.MustCompile(`^(?:@[\w.-]+/)?[\w.-]+(?:@[\w.*^~<>=|-]+)?$`)
)

// AuditSkills is the capability audit of every loaded skill: files outside the
// skills folder, command templates with shell metacharacters, and dependency
// entries that are not plain package references.
func (r *Runner) AuditSkills() any {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := []*jsonobj.Object{}
	for _, key := range r.order {
		s := r.skills[key]
		if s == nil {
			continue
		}
		findings := []*jsonobj.Object{}
		if rel, err := filepath.Rel(r.dir, filepath.Clean(s.FilePath)); err != nil || strings.HasPrefix(rel, "..") || filepath.IsAbs(rel) {
			findings = append(findings, jsonobj.New("severity", "high", "code", "path_escape", "message", "Skill file is outside the managed skills directory."))
		}
		if command, _ := s.Metadata.Value("command").(string); command != "" {
			if shellMetachar.MatchString(placeholder.ReplaceAllString(command, "")) {
				findings = append(findings, jsonobj.New("severity", "high", "code", "unsafe_command_template", "message", "Command template contains unsafe shell metacharacters."))
			}
		}
		if deps, ok := s.Metadata.Value("dependencies").([]any); ok {
			for _, d := range deps {
				ref, isString := d.(string)
				if !isString || !packageRef.MatchString(ref) {
					findings = append(findings, jsonobj.New("severity", "medium", "code", "untrusted_dependency", "message", "Dependency metadata contains an unsupported package reference."))
				}
			}
		}
		out = append(out, jsonobj.New(
			"name", s.Name,
			"enabled", s.Metadata.Value("enabled") != false,
			"autoCreated", s.Metadata.Value("auto_created") == true,
			"findingCount", len(findings),
			"findings", findings,
		))
	}
	return out
}
