package runtime

import (
	"fmt"
	"strconv"

	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

// QEMUArgsConfig is the product-specific hardware and disk layout for a guest.
type QEMUArgsConfig struct {
	Architecture                                             string
	Accelerators                                             []string
	MemoryMB, CPUs                                           int
	SystemDisk, DataDisk, SeedImage                          string
	GuestAgentPort, HostAgentPort                            int
	VNC, QMP                                                 vm.Address
	QEMUDataDirectory, ARMFirmwareCode, ARMFirmwareVariables string
	KernelImage, InitrdImage                                 string
}

func displayDeviceArgument(architecture string) string {
	if architecture == "arm64" {
		return fmt.Sprintf("virtio-gpu-pci,edid=on,xres=%d,yres=%d", ComputerDisplayWidth, ComputerDisplayHeight)
	}
	return fmt.Sprintf("virtio-vga,xres=%d,yres=%d", ComputerDisplayWidth, ComputerDisplayHeight)
}
func directBootCommandLine(architecture string) string {
	if architecture == "arm64" {
		return "root=/dev/vda1 ro rootwait console=tty0 console=ttyAMA0"
	}
	return "root=/dev/vda1 ro rootwait console=tty0 console=ttyS0"
}

// BuildQEMUArgs builds the guest command line using the same devices and order
// as the Node QEMU manager. Firmware discovery belongs to the runtime manager.
func BuildQEMUArgs(c QEMUArgsConfig) ([]string, error) {
	var args vm.Args
	args.Add("-name", "NeoAgent Computer").Flag("-nodefaults").Add("-boot", "order=c,menu=off,reboot-timeout=0,splash-time=0,strict=on")
	cpu := "host"
	if len(c.Accelerators) > 0 && c.Accelerators[0] == "tcg" {
		cpu = "max"
	}
	if c.Architecture == "arm64" {
		args.Add("-machine", "virt,highmem=on").Add("-cpu", cpu)
		if c.ARMFirmwareCode == "" || c.ARMFirmwareVariables == "" {
			return nil, &CodedError{Message: "ARM64 QEMU firmware is unavailable. Run neoagent repair to restore the computer runtime.", Code: "COMPUTER_FIRMWARE_MISSING"}
		}
		args.Add("-drive", "if=pflash,unit=0,format=raw,readonly=on,file="+vm.EscapeValue(c.ARMFirmwareCode)).Add("-drive", "if=pflash,unit=1,format=qcow2,file="+vm.EscapeValue(c.ARMFirmwareVariables)).Add("-device", displayDeviceArgument(c.Architecture))
	} else {
		args.Add("-machine", "q35").Add("-cpu", cpu).Add("-device", displayDeviceArgument(c.Architecture))
	}
	if len(c.Accelerators) == 0 || c.Accelerators[0] == "" {
		return nil, &CodedError{Message: "QEMU has no usable hardware accelerator or TCG compatibility accelerator.", Code: "COMPUTER_ACCELERATOR_UNAVAILABLE"}
	}
	args.Add("-accel", c.Accelerators[0])
	if c.QEMUDataDirectory != "" {
		args.Add("-L", c.QEMUDataDirectory)
	}
	if c.KernelImage != "" && c.InitrdImage != "" {
		args.Add("-kernel", c.KernelImage).Add("-initrd", c.InitrdImage).Add("-append", directBootCommandLine(c.Architecture))
	}
	args.Add("-m", strconv.Itoa(c.MemoryMB)).Add("-smp", fmt.Sprintf("cpus=%d,maxcpus=%d", c.CPUs, c.CPUs)).Add("-device", "virtio-balloon").Add("-device", "virtio-rng-pci").Add("-device", "qemu-xhci,id=xhci").Add("-device", "usb-kbd").Add("-device", "usb-tablet")
	args.Add("-drive", "if=none,id=systemdisk,format=qcow2,cache=writeback,discard=unmap,file="+vm.EscapeValue(c.SystemDisk)).Add("-device", "virtio-blk-pci,drive=systemdisk,bootindex=1,romfile=").Add("-drive", "if=none,id=datadisk,format=qcow2,cache=writeback,discard=unmap,file="+vm.EscapeValue(c.DataDisk)).Add("-device", "virtio-blk-pci,drive=datadisk,romfile=").Add("-drive", "if=none,id=seed,format=raw,readonly=on,file="+vm.EscapeValue(c.SeedImage)).Add("-device", "virtio-blk-pci,drive=seed,romfile=")
	args.Add("-netdev", fmt.Sprintf("user,id=net0,hostfwd=tcp:127.0.0.1:%d-:%d", c.HostAgentPort, c.GuestAgentPort)).Add("-device", "virtio-net-pci,netdev=net0,romfile=").Add("-display", "none")
	vnc := fmt.Sprintf("127.0.0.1:%d", c.VNC.Port-5900)
	if c.VNC.Path != "" {
		vnc = "unix:" + c.VNC.Path
	}
	qmp := fmt.Sprintf("tcp:127.0.0.1:%d,server=on,wait=off", c.QMP.Port)
	if c.QMP.Path != "" {
		qmp = "unix:" + c.QMP.Path + ",server=on,wait=off"
	}
	args.Add("-vnc", vnc).Add("-qmp", qmp).Add("-serial", "stdio").Add("-monitor", "none")
	return args.List(), nil
}
