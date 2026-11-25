package artifacts

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
)

func TestCreateBufferArtifact(t *testing.T) {
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (7, 'u', 'x')`); err != nil {
		t.Fatal(err)
	}
	store := &Store{DB: db, Root: filepath.Join(dir, "artifacts")}
	got, err := store.CreateBufferArtifact(ctx, "7", File{Kind: "command-output", Backend: "vm", Extension: ".log", ContentType: "text/plain", FilenameBase: "Command Output..x", Content: []byte("hello"), Metadata: map[string]any{"runId": nil}})
	if err != nil {
		t.Fatal(err)
	}
	if got.URL != "/api/artifacts/"+got.ID+"/content" || got.ByteSize != 5 || !strings.HasSuffix(got.StoragePath, "-command-output-x.log") || filepath.Base(filepath.Dir(got.StoragePath)) != "7" {
		t.Fatalf("%+v", got)
	}
	raw, err := os.ReadFile(got.StoragePath)
	if err != nil || string(raw) != "hello" {
		t.Fatal(err)
	}
	var size int
	var meta, kind string
	if err := db.R.QueryRow(`SELECT byte_size, metadata_json, kind FROM artifacts WHERE id = ? AND user_id = 7`, got.ID).Scan(&size, &meta, &kind); err != nil || size != 5 || meta != `{"runId":null}` || kind != "command-output" {
		t.Fatalf("%v %d %s %s", err, size, meta, kind)
	}
	cancelled, cancel := context.WithCancel(ctx)
	cancel()
	if _, err := store.CreateBufferArtifact(cancelled, "7", File{Content: []byte("x")}); err == nil {
		t.Fatal("cancelled write succeeded")
	}
	var rows int
	_ = db.R.QueryRow(`SELECT COUNT(*) FROM artifacts`).Scan(&rows)
	if rows != 1 {
		t.Fatalf("rows %d", rows)
	}
}
