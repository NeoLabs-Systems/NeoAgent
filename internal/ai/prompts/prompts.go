// Package prompts holds the model-facing prompt fragments of the harness. The
// markdown files are copies of the ones the Node server shipped and are used
// byte for byte: changing a fragment's text means bumping its version, because
// evals and run metrics compare by version.
package prompts

import (
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"sync"
)

//go:embed base capabilities runtime voice
var files embed.FS

// Fragment is one versioned prompt file.
type Fragment struct {
	ID      string
	Version int
	Text    string
}

var headerPattern = regexp.MustCompile(`(?s)^---\n(.*?)\n---\n(.*)$`)

func parse(file string) (Fragment, error) {
	raw, err := files.ReadFile(file)
	if err != nil {
		return Fragment{}, fmt.Errorf("prompts: %w", err)
	}
	match := headerPattern.FindStringSubmatch(string(raw))
	if match == nil {
		return Fragment{}, fmt.Errorf("prompts: fragment %s has no header", file)
	}
	header := map[string]string{}
	for _, line := range strings.Split(match[1], "\n") {
		index := strings.Index(line, ":")
		if index < 0 {
			continue
		}
		header[strings.TrimSpace(line[:index])] = strings.TrimSpace(line[index+1:])
	}
	version, _ := strconv.Atoi(header["version"])
	return Fragment{ID: header["id"], Version: version, Text: strings.TrimSpace(match[2])}, nil
}

// Context is what decides which stable fragments apply.
type Context struct {
	TriggerSource string
}

type stableEntry struct {
	file     string
	activate func(Context) bool
}

// Stable fragments form the cacheable head of every prompt, in this order, so
// a change in what follows them cannot invalidate the provider's prompt cache.
var stableFragments = []stableEntry{
	{file: "base/behavior.md"},
	{file: "base/tools.md"},
	{file: "base/quick_actions.md"},
	{file: "base/external_actions.md"},
	{file: "base/security.md"},
	{file: "capabilities/voice_task.md", activate: func(c Context) bool { return c.TriggerSource == "voice_live" }},
	{file: "capabilities/messaging.md", activate: func(c Context) bool { return c.TriggerSource == "messaging" }},
}

var (
	cacheMu sync.Mutex
	cache   = map[string]Fragment{}
)

func load(file string) (Fragment, error) {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	if fragment, ok := cache[file]; ok {
		return fragment, nil
	}
	fragment, err := parse(file)
	if err != nil {
		return Fragment{}, err
	}
	cache[file] = fragment
	return fragment, nil
}

// SelectStable returns the stable fragments active for the context.
func SelectStable(ctx Context) []Fragment {
	var out []Fragment
	for _, entry := range stableFragments {
		if entry.activate != nil && !entry.activate(ctx) {
			continue
		}
		fragment, err := load(entry.file)
		if err != nil {
			// The files are embedded and checked by the tests, so this is a build defect.
			panic(err)
		}
		out = append(out, fragment)
	}
	return out
}

var placeholder = regexp.MustCompile(`\{\{(\w+)\}\}`)

// Render is the text of a runtime fragment with its {{placeholders}} filled.
// A missing value renders as the empty string.
func Render(file string, values map[string]string) string {
	fragment, err := load(file)
	if err != nil {
		panic(err)
	}
	return placeholder.ReplaceAllStringFunc(fragment.Text, func(token string) string {
		return values[token[2:len(token)-2]]
	})
}

// Version names exactly which prompt text a run saw.
type Version struct {
	Fragments []string `json:"fragments"`
	Digest    string   `json:"digest"`
}

// VersionOf describes the fragments a prompt was built from.
func VersionOf(fragments []Fragment) Version {
	list := make([]string, len(fragments))
	for i, f := range fragments {
		list[i] = fmt.Sprintf("%s@%d", f.ID, f.Version)
	}
	sum := sha256.Sum256([]byte(strings.Join(list, "\n")))
	return Version{Fragments: list, Digest: hex.EncodeToString(sum[:])[:16]}
}
