package codenav

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

func TestNavigateStructureAndSemantic(t *testing.T) {
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
	if _, err := db.W.Exec("INSERT INTO users (id, username, password) VALUES (1, 'u', 'x')"); err != nil {
		t.Fatal(err)
	}
	ws, err := workspace.New(filepath.Join(dir, "ws"), false)
	if err != nil {
		t.Fatal(err)
	}
	root, err := ws.Root("1")
	if err != nil {
		t.Fatal(err)
	}
	must := func(p, body string) {
		full := filepath.Join(root, p)
		_ = os.MkdirAll(filepath.Dir(full), 0o700)
		if err := os.WriteFile(full, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	must("src/billing.ts", "export function computeInvoiceTotal(items) { return items.length; }\nconst unrelated = 1;\n")
	must("node_modules/x/index.js", "function invoice() {}\n")
	must("notes.txt", "invoice")
	s := &Service{DB: db, Workspace: ws}

	got, err := s.Navigate(ctx, 1, map[string]any{"mode": "structure", "path": "src/billing.ts"})
	if err != nil {
		t.Fatal(err)
	}
	st := got.(structureResult)
	if len(st.Symbols) != 2 || st.Symbols[0].Name != "computeInvoiceTotal" || st.Symbols[1].Type != "VariableDeclaration" {
		t.Fatalf("%+v", st)
	}
	if _, err := s.Navigate(ctx, 1, map[string]any{"mode": "structure", "path": "notes.txt"}); err == nil || err.Error() != "Structural parsing currently supports JavaScript and TypeScript files." {
		t.Fatal(err)
	}
	if _, err := s.Navigate(ctx, 1, map[string]any{"mode": "grep"}); err == nil {
		t.Fatal("unknown mode accepted")
	}
	if _, err := s.Navigate(ctx, 1, map[string]any{"mode": "semantic"}); err == nil || err.Error() != "query is required." {
		t.Fatal(err)
	}
	res, err := s.Navigate(ctx, 1, map[string]any{"mode": "semantic", "query": "invoice total computeInvoiceTotal"})
	if err != nil {
		t.Fatal(err)
	}
	m := res.(map[string]any)
	hits := m["results"].([]semanticHit)
	if m["indexStatus"].(indexStatus) != (indexStatus{FilesScanned: 1, SymbolsIndexed: 2}) || len(hits) != 1 || hits[0].Path != "src/billing.ts" {
		t.Fatalf("%+v", m)
	}
	again, _ := s.Navigate(ctx, 1, map[string]any{"mode": "semantic", "query": "computeInvoiceTotal"})
	if again.(map[string]any)["indexStatus"].(indexStatus).SymbolsIndexed != 0 {
		t.Fatal("unchanged symbols were indexed again")
	}
}
