package runtime

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

func TestQEMUArgsMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/qemu_args.json")
	if err != nil {
		t.Fatal(err)
	}
	var want [][]string
	if err := json.Unmarshal(raw, &want); err != nil {
		t.Fatal(err)
	}
	base := QEMUArgsConfig{Architecture: "x64", Accelerators: []string{"tcg"}, MemoryMB: 4096, CPUs: 2, SystemDisk: "/tmp/sys,disk", DataDisk: "/tmp/data", SeedImage: "/tmp/seed", GuestAgentPort: 8080, HostAgentPort: 12345, QEMUDataDirectory: "/qemu", VNC: vm.Address{Path: "/tmp/vnc"}, QMP: vm.Address{Path: "/tmp/qmp"}}
	for i := range want {
		cfg := base
		if i == 1 {
			cfg.VNC = vm.Address{Port: 5912}
			cfg.QMP = vm.Address{Port: 4321}
			cfg.KernelImage = "/kernel"
			cfg.InitrdImage = "/initrd"
		}
		if i == 2 {
			cfg = QEMUArgsConfig{Architecture: "arm64", Accelerators: []string{"hvf"}, MemoryMB: 2048, CPUs: 4, SystemDisk: "/sys", DataDisk: "/data", SeedImage: "/seed", GuestAgentPort: 8000, HostAgentPort: 5000, VNC: vm.Address{Path: "/vnc"}, QMP: vm.Address{Path: "/qmp"}, ARMFirmwareCode: "/firmware,code", ARMFirmwareVariables: "/firmware,vars"}
		}
		got, err := BuildQEMUArgs(cfg)
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(got, want[i]) {
			t.Fatalf("case %d\ngot %v\nwant %v", i, got, want[i])
		}
	}
	if _, err := BuildQEMUArgs(QEMUArgsConfig{Architecture: "arm64", Accelerators: []string{"tcg"}}); err == nil {
		t.Fatal("missing firmware accepted")
	}
	if _, err := BuildQEMUArgs(QEMUArgsConfig{Architecture: "x64"}); err == nil {
		t.Fatal("missing accelerator accepted")
	}
}
