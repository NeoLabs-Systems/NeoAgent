package prompts

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

type vectors struct {
	Stable map[string]struct {
		Texts   []string `json:"texts"`
		Version Version  `json:"version"`
	} `json:"stable"`
	Rendered map[string]string `json:"rendered"`
}

func loadVectors(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/prompts.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestStableFragmentsMatchNode(t *testing.T) {
	for source, want := range loadVectors(t).Stable {
		fragments := SelectStable(Context{TriggerSource: source})
		var texts []string
		for _, f := range fragments {
			texts = append(texts, f.Text)
		}
		if !reflect.DeepEqual(texts, want.Texts) {
			t.Errorf("%s: stable texts differ", source)
		}
		if got := VersionOf(fragments); !reflect.DeepEqual(got, want.Version) {
			t.Errorf("%s: version %v, want %v", source, got, want.Version)
		}
	}
}

func TestRuntimeFragmentsMatchNode(t *testing.T) {
	for file, want := range loadVectors(t).Rendered {
		values := map[string]string{}
		raw, _ := files.ReadFile(file)
		for _, token := range placeholder.FindAllStringSubmatch(string(raw), -1) {
			values[token[1]] = "<" + token[1] + ">"
		}
		if file == "runtime/wrap_up.md" {
			delete(values, "reason")
		}
		if got := Render(file, values); got != want {
			t.Errorf("%s renders differently:\n%q\nwant\n%q", file, got, want)
		}
	}
}

// Node still holds the original files while both servers exist; the embedded
// copies must not drift from them.
func TestEmbeddedFilesMatchNodeSources(t *testing.T) {
	source := filepath.Join("..", "..", "..", "..", "..", "server", "services", "ai", "prompts")
	if _, err := os.Stat(source); err != nil {
		t.Skip("Node sources are gone")
	}
	for _, dir := range []string{"base", "capabilities", "runtime", "voice"} {
		entries, err := files.ReadDir(dir)
		if err != nil {
			t.Fatal(err)
		}
		onDisk, _ := os.ReadDir(filepath.Join(source, dir))
		if len(entries) != len(onDisk) {
			t.Errorf("%s: %d embedded files, %d in Node", dir, len(entries), len(onDisk))
		}
		for _, entry := range entries {
			embedded, _ := files.ReadFile(dir + "/" + entry.Name())
			original, err := os.ReadFile(filepath.Join(source, dir, entry.Name()))
			if err != nil || string(embedded) != string(original) {
				t.Errorf("%s/%s differs from Node", dir, entry.Name())
			}
		}
	}
}

func TestEveryFragmentHasAHeader(t *testing.T) {
	for _, dir := range []string{"base", "capabilities", "runtime", "voice"} {
		entries, _ := files.ReadDir(dir)
		for _, entry := range entries {
			f, err := parse(dir + "/" + entry.Name())
			if err != nil || f.ID == "" || f.Version == 0 || strings.TrimSpace(f.Text) == "" {
				t.Errorf("%s/%s: bad fragment %+v %v", dir, entry.Name(), f, err)
			}
		}
	}
}
