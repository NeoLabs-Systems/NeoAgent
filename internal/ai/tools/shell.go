package tools

import (
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Classifying a shell command as read-only decides what a read-only run may do
// and which calls count as repeats, so anything doubtful counts as a change.

var readOnlyCommands = setOf("base64", "cat", "diff", "du", "egrep", "fgrep", "find", "git", "grep", "head", "jq",
	"ls", "pwd", "rg", "sed", "sort", "tail", "test", "tr", "tree", "wc", "which")

var gitReadOnlySubcommands = setOf("branch", "diff", "grep", "log", "ls-files", "ls-remote", "rev-parse", "show", "status")

var stateChangingCommands = setOf("apply_patch", "chmod", "chown", "cp", "git-clone", "git-commit", "git-push",
	"git-switch", "git-checkout", "git-merge", "git-rebase", "install", "mkdir", "mv", "npm", "pnpm", "rm", "rmdir",
	"touch", "yarn")

func setOf(values ...string) map[string]bool {
	set := make(map[string]bool, len(values))
	for _, v := range values {
		set[v] = true
	}
	return set
}

// JavaScript's "." excludes line terminators other than \n as well.
const dot = `[^\n\r\x{2028}\x{2029}]`
const space = `[` + textx.SpaceClass + `]`
const nonSpace = `[^` + textx.SpaceClass + `]`

var (
	// sed can write and run commands from inside its script, so only printing
	// lines counts as reading; the pattern is the shape that is allowed.
	sedPrintOnly = regexp.MustCompile(`^sed` + space + `+-n` + space + `+["']?[\d,$;p` + textx.SpaceClass + `]+["']?(?:` + space + `+[^-` + textx.SpaceClass + `]` + nonSpace + `*)*` + space + `*$`)

	writingFlags = map[string]*regexp.Regexp{
		"find":   regexp.MustCompile(space + `-(?:delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)\b`),
		"sort":   regexp.MustCompile(space + `(?:-[a-zA-Z]*o|--output|--compress-program)\b`),
		"rg":     regexp.MustCompile(space + `--(?:pre|hostname-bin)\b`),
		"base64": regexp.MustCompile(space + `(?:-o|--output)\b`),
		"tree":   regexp.MustCompile(space + `-o\b`),
	}
	listingGitBranch = regexp.MustCompile(`^git` + space + `+branch(?:` + space + `+(?:-a|-r|-v+|-vv|--list|--all|--remotes|--show-current|--no-color))*` + space + `*$`)
	sendingCurl      = regexp.MustCompile(space + `(?:-[a-zA-Z]*[XdFTOo]|--(?:request|data` + nonSpace + `*|form` + nonSpace + `*|upload-file|output|remote-name` + nonSpace + `*|json))\b`)
	fdDuplication    = regexp.MustCompile(`\d*>&\d`)
	hiddenExecution  = regexp.MustCompile("\\$\\(|`|<\\(|>\\(|(?:^|[^&])&(?:[^&]|$)")

	lineContinuation = regexp.MustCompile(`\\\n`)
	commentLine      = regexp.MustCompile(`(^|\n)` + space + `*#` + dot + `*`)
	nonNewlineSpace  = regexp.MustCompile(`[` + strings.ReplaceAll(textx.SpaceClass, `\n`, ``) + `]+`)
	commandSplit     = regexp.MustCompile(space + `*(?:&&|\|\||;|\||\n)` + space + `*`)
	envAssignment    = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*=`)
	envAssignmentEnd = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|` + nonSpace + `+)` + space + `*`)
	firstTokenRe     = regexp.MustCompile(`^([A-Za-z0-9_./-]+)`)
	redirectRe       = regexp.MustCompile(`(?:^|[^&|;])(?:>>?|1>)` + space + `*(?:"([^"]+)"|'([^']+)'|(` + nonSpace + `+))`)
	fdTarget         = regexp.MustCompile(`^&\d$`)
	gitPagerFlag     = regexp.MustCompile(space + `(?:--output|--ext-diff|--open-files-in-pager|-O)`)
)

func stripShellNoise(command string) string {
	command = lineContinuation.ReplaceAllString(command, " ")
	command = commentLine.ReplaceAllString(command, "\n")
	// A line break ends a command, so it must survive for the split below.
	command = nonNewlineSpace.ReplaceAllString(command, " ")
	return textx.Trim(command)
}

func firstToken(segment string) string {
	m := firstTokenRe.FindStringSubmatch(textx.Trim(segment))
	if m == nil {
		return ""
	}
	return m[1]
}

func normalizeCommandName(token string) string {
	token = textx.Trim(token)
	if i := strings.LastIndex(token, "/"); i >= 0 {
		token = token[i+1:]
	}
	return strings.ToLower(token)
}

func splitCommandSegments(command string) []string {
	var segments []string
	for _, segment := range commandSplit.Split(stripShellNoise(command), -1) {
		if segment = textx.Trim(segment); segment != "" {
			segments = append(segments, segment)
		}
	}
	return segments
}

func stripEnvAssignments(segment string) string {
	text := textx.Trim(segment)
	for envAssignment.MatchString(text) {
		text = textx.Trim(envAssignmentEnd.ReplaceAllString(text, ""))
	}
	return text
}

func fields(text string) []string { return strings.FieldsFunc(text, textx.IsSpace) }

func gitSubcommand(segment string) string {
	parts := fields(stripEnvAssignments(segment))
	if len(parts) == 0 || normalizeCommandName(parts[0]) != "git" {
		return ""
	}
	if len(parts) < 2 {
		return ""
	}
	return strings.ToLower(parts[1])
}

func isReadOnlyGitCommand(segment string) bool {
	subcommand := gitSubcommand(segment)
	if subcommand == "" || !gitReadOnlySubcommands[subcommand] {
		return false
	}
	if gitPagerFlag.MatchString(segment) {
		return false
	}
	return subcommand != "branch" || listingGitBranch.MatchString(stripEnvAssignments(segment))
}

func hasStateChangingRedirect(segment string) bool {
	for _, m := range redirectRe.FindAllStringSubmatch(segment, -1) {
		target := textx.Trim(firstNonEmpty(m[1], m[2], m[3]))
		if target == "" || target == "/dev/null" || fdTarget.MatchString(target) {
			continue
		}
		if (strings.HasPrefix(target, "/tmp/") || strings.HasPrefix(target, "/var/tmp/")) && !strings.Contains(target, "..") {
			continue
		}
		return true
	}
	return false
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func isStateChangingShellSegment(segment string) bool {
	normalized := stripEnvAssignments(segment)
	if hasStateChangingRedirect(normalized) {
		return true
	}
	command := normalizeCommandName(firstToken(normalized))
	if command == "" {
		return false
	}
	if command == "git" {
		sub := gitSubcommand(normalized)
		return sub != "" && !gitReadOnlySubcommands[sub]
	}
	return stateChangingCommands[command]
}

// IsClearlyReadOnlyShellCommand reports whether a command only reads. fetches
// is for telling repeats apart: a plain download counts as the same evidence
// however it is piped, but it reaches the network, so it is not read-only for
// permissions.
func IsClearlyReadOnlyShellCommand(command string, fetches bool) bool {
	cleaned := fdDuplication.ReplaceAllString(strings.ReplaceAll(stripShellNoise(command), "&&", ""), "")
	if hiddenExecution.MatchString(cleaned) {
		return false
	}
	segments := splitCommandSegments(command)
	if len(segments) == 0 {
		return false
	}
	for _, segment := range segments {
		normalized := stripEnvAssignments(segment)
		// A variable can change what a command runs (PAGER, LD_PRELOAD, GIT_EXTERNAL_DIFF).
		if normalized != segment {
			return false
		}
		if isStateChangingShellSegment(normalized) {
			return false
		}
		name := normalizeCommandName(firstToken(normalized))
		if name == "git" {
			if !isReadOnlyGitCommand(normalized) {
				return false
			}
			continue
		}
		if name == "" {
			return false
		}
		if fetches && name == "curl" && !sendingCurl.MatchString(normalized) {
			continue
		}
		if name == "sed" && !sedPrintOnly.MatchString(normalized) {
			return false
		}
		if re, ok := writingFlags[name]; ok && re.MatchString(normalized) {
			return false
		}
		if !readOnlyCommands[name] {
			return false
		}
	}
	return true
}
