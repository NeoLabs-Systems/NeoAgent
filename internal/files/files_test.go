package files

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

type nodeVectors struct {
	IDs []struct {
		Reference string
		ID        *string
		Error     string
	}
	Resolves []struct {
		Reference     string
		Label         *string
		WithWorkspace bool
		OK            string `json:"ok"`
		Error         string
	}
}

type dirWorkspace string

func (d dirWorkspace) ResolvePath(_, candidate, _ string) (string, error) {
	return filepath.Join(string(d), candidate), nil
}

type noStore struct{}

func (noStore) StoragePath(int64, string) (string, bool)       { return "", false }
func (noStore) StoragePathByFile(int64, string) (string, bool) { return "", false }

func TestMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v nodeVectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	for _, c := range v.IDs {
		id, err := ArtifactIDFromReference(c.Reference)
		switch {
		case c.Error != "":
			if err == nil || err.Error() != c.Error {
				t.Errorf("%q: err = %v, want %q", c.Reference, err, c.Error)
			}
		case c.ID == nil:
			if err != nil || id != "" {
				t.Errorf("%q: got %q, %v, want none", c.Reference, id, err)
			}
		case id != *c.ID || err != nil:
			t.Errorf("%q: got %q, %v, want %q", c.Reference, id, err, *c.ID)
		}
	}
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "file.txt"), []byte("x"), 0o600)
	os.Mkdir(filepath.Join(dir, "sub"), 0o700)
	for _, c := range v.Resolves {
		label := ""
		if c.Label != nil {
			label = *c.Label
		}
		var ws Workspace
		if c.WithWorkspace {
			ws = dirWorkspace(dir)
		}
		got, err := ResolveReference(1, c.Reference, noStore{}, ws, label)
		if c.Error != "" {
			if err == nil || err.Error() != c.Error {
				t.Errorf("%q: err = %v, want %q", c.Reference, err, c.Error)
			}
			continue
		}
		if err != nil || filepath.Base(got) != c.OK {
			t.Errorf("%q: got %q, %v", c.Reference, got, err)
		}
	}
}

type computer struct{ err error }

func (c computer) DownloadFile(_ context.Context, _ int64, ref, _ string) (DownloadedFile, error) {
	return DownloadedFile{Filename: "report.pdf", Path: "/workspace/" + ref, Content: []byte("pdf")}, c.err
}

type artifacts struct {
	noStore
	got BufferArtifact
}

func (a *artifacts) StoreBufferArtifact(_ context.Context, _ int64, in BufferArtifact) (string, error) {
	a.got = in
	return "/data/artifacts/abc.pdf", nil
}

func TestFetchWorkspaceFileArgs(t *testing.T) {
	store := &artifacts{}
	args := map[string]any{"file": " out/report.pdf ", "url": "https://x.test/a", "other": 3.0}
	got, err := FetchWorkspaceFileArgs(context.Background(), 1, args, []string{"file", "url", "missing"}, computer{}, store, "")
	if err != nil {
		t.Fatal(err)
	}
	if got["file"] != "/data/artifacts/abc.pdf" || got["url"] != "https://x.test/a" || args["file"] != " out/report.pdf " {
		t.Fatalf("%v / %v", got, args)
	}
	if g := store.got; g.FilenameBase != "report" || g.Extension != "pdf" || g.Kind != "workspace-file" || g.Metadata["workspacePath"] != "/workspace/out/report.pdf" {
		t.Fatalf("%+v", g)
	}
	_, err = FetchWorkspaceFileArgs(context.Background(), 1, args, []string{"file"}, computer{err: errors.New("boom")}, store, "")
	if err == nil || err.Error() != `file "out/report.pdf" could not be read from your workspace: boom` {
		t.Fatal(err)
	}
}
