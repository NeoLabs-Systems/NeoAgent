package setupcontract

import (
	"os"
	"strings"
	"testing"
)

// The generated Dart file must be exactly what Dart renders; CI runs the
// same check through `neoagent-release setup-contract --check`.
func TestDartFileIsCurrent(t *testing.T) {
	raw, err := os.ReadFile("../../flutter_app/lib/src/setup_contract.g.dart")
	if err != nil {
		t.Skip("flutter_app is not checked out")
	}
	if got := C.Dart(PublicKey()); got != string(raw) {
		t.Fatalf("setup_contract.g.dart is stale; run go run ./cmd/neoagent-release setup-contract\n%s", got)
	}
}

func TestContractValues(t *testing.T) {
	if C.DefaultPort != 3333 || C.SchemaVersion != 1 || strings.Join(C.TargetOrder, ",") != "macos,windows,linux" {
		t.Fatalf("%+v", C)
	}
	if _, ok := C.Profile("full"); !ok {
		t.Fatal("full profile")
	}
	if PublicKey() != "uDNavzHE5LnKMnSPWetl8RVaDYfcI29PFmrBg28qE8U=" {
		t.Fatal(PublicKey())
	}
	if _, err := Load([]byte(`{"schemaVersion":2}`)); err == nil {
		t.Fatal("schema 2 accepted")
	}
}
