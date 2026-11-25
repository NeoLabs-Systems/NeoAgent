package runtime

import (
	"math"
	"runtime"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

const (
	mib = 1024 * 1024
	gib = 1024 * mib
)

// ResourceProfile is what a host can give to computers.
type ResourceProfile struct {
	TotalMemoryMb         int64 `json:"totalMemoryMb"`
	LogicalCPUCount       int   `json:"logicalCpuCount"`
	ReservePercent        int   `json:"reservePercent"`
	MinimumReserveMb      int   `json:"minimumReserveMb"`
	ReserveMemoryMb       int64 `json:"reserveMemoryMb"`
	AllocatableMemoryMb   int64 `json:"allocatableMemoryMb"`
	AllocatableCPUCount   int   `json:"allocatableCpuCount"`
	MinimumGuestMemoryMb  int   `json:"minimumGuestMemoryMb"`
	MaximumGuestMemoryMb  int   `json:"maximumGuestMemoryMb"`
	MaximumGuestCPUs      int   `json:"maximumGuestCpus"`
	MinimumDiskGiB        int   `json:"minimumDiskGiB"`
	MaximumDiskGiB        int   `json:"maximumDiskGiB"`
	MaxActiveComputers    int   `json:"maxActiveComputers"`
	StorageReservePercent int   `json:"storageReservePercent"`
}

// ProfileOptions override environment and host defaults. A nil field means "use
// the environment variable, then the default".
type ProfileOptions struct {
	TotalMemoryBytes      *uint64
	LogicalCPUCount       *int
	Accelerator           string
	ReservePercent        *float64
	MinimumReserveMb      *float64
	MinimumGuestMemoryMb  *float64
	MaximumGuestMemoryMb  *float64
	MaximumGuestCPUs      *float64
	MinimumDiskGiB        *float64
	MaximumDiskGiB        *float64
	StorageReservePercent *float64
	// Getenv reads the NEOAGENT_COMPUTER_* variables; nil reads nothing.
	Getenv func(string) string
}

// integerSetting parses like Number(value) and clamps, falling back when the
// value is missing or not finite.
func integerSetting(value string, fallback, minimum, maximum int) int {
	parsed, err := strconv.ParseFloat(strings.TrimSpace(value), 64)
	if err != nil || math.IsNaN(parsed) || math.IsInf(parsed, 0) {
		return fallback
	}
	return int(math.Min(float64(maximum), math.Max(float64(minimum), math.Round(parsed))))
}

func (o ProfileOptions) setting(explicit *float64, env string, fallback, minimum, maximum int) int {
	if explicit != nil {
		return integerSetting(strconv.FormatFloat(*explicit, 'f', -1, 64), fallback, minimum, maximum)
	}
	if o.Getenv == nil {
		return fallback
	}
	return integerSetting(o.Getenv(env), fallback, minimum, maximum)
}

// ComputerResourceProfile derives the profile from host memory and CPUs.
func ComputerResourceProfile(o ProfileOptions) ResourceProfile {
	totalBytes := vm.TotalMemoryBytes()
	if o.TotalMemoryBytes != nil {
		totalBytes = *o.TotalMemoryBytes
	}
	totalMemoryMb := int64(totalBytes / mib)
	cpus := runtime.NumCPU()
	if o.LogicalCPUCount != nil {
		cpus = *o.LogicalCPUCount
	}
	cpus = max(1, cpus)

	reservePercent := o.setting(o.ReservePercent, "NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_PERCENT", 25, 10, 75)
	minimumReserveMb := o.setting(o.MinimumReserveMb, "NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_MB", 2048, 512, 131072)
	minimumGuest := o.setting(o.MinimumGuestMemoryMb, "NEOAGENT_COMPUTER_MIN_MEMORY_MB", 1536, 1024, 32768)
	maximumGuest := o.setting(o.MaximumGuestMemoryMb, "NEOAGENT_COMPUTER_MAX_MEMORY_MB", 2560, minimumGuest, 65536)
	maximumCPUs := o.setting(o.MaximumGuestCPUs, "NEOAGENT_COMPUTER_MAX_CPUS", 2, 1, 32)
	minimumDisk := o.setting(o.MinimumDiskGiB, "NEOAGENT_COMPUTER_MIN_DISK_GIB", 6, 4, 1024)
	maximumDisk := o.setting(o.MaximumDiskGiB, "NEOAGENT_COMPUTER_MAX_DISK_GIB", 12, minimumDisk, 4096)

	reserve := max(int64(minimumReserveMb), int64(math.Ceil(float64(totalMemoryMb)*float64(reservePercent)/100)))
	allocatableMemory := max(0, totalMemoryMb-reserve)
	allocatableCPUs := max(0, cpus-1)
	maxActive := max(0, int(min(allocatableMemory/int64(minimumGuest), int64(allocatableCPUs))))
	if strings.ToLower(strings.TrimSpace(o.Accelerator)) == "tcg" {
		maxActive = min(maxActive, 1)
	}
	return ResourceProfile{
		TotalMemoryMb: totalMemoryMb, LogicalCPUCount: cpus, ReservePercent: reservePercent,
		MinimumReserveMb: minimumReserveMb, ReserveMemoryMb: reserve, AllocatableMemoryMb: allocatableMemory,
		AllocatableCPUCount: allocatableCPUs, MinimumGuestMemoryMb: minimumGuest, MaximumGuestMemoryMb: maximumGuest,
		MaximumGuestCPUs: maximumCPUs, MinimumDiskGiB: minimumDisk, MaximumDiskGiB: maximumDisk, MaxActiveComputers: maxActive,
		StorageReservePercent: o.setting(o.StorageReservePercent, "NEOAGENT_COMPUTER_STORAGE_RESERVE_PERCENT", 20, 0, 80),
	}
}

// Allocation is the memory and CPUs given to one computer.
type Allocation struct {
	MemoryMb int64 `json:"memoryMb"`
	CPUs     int   `json:"cpus"`
}

// CodedError is an error with a machine-readable code and the HTTP status it
// maps to; the routes report both.
type CodedError struct {
	Message string
	Code    string
	Status  int
}

func (e *CodedError) Error() string { return e.Message }

// Error codes the runtime reports.
const (
	CodeCapacity        = "COMPUTER_CAPACITY"
	CodeStorageCapacity = "COMPUTER_STORAGE_CAPACITY"
)

// AllocateComputerResources picks the share for one more computer, keeping the
// minimum for the computers the host could still admit.
func AllocateComputerResources(p ResourceProfile, active []Allocation) (Allocation, error) {
	var usedMemory int64
	var usedCPUs int
	for _, a := range active {
		usedMemory += max(0, a.MemoryMb)
		usedCPUs += max(0, a.CPUs)
	}
	remainingMemory := p.AllocatableMemoryMb - usedMemory
	remainingCPUs := p.AllocatableCPUCount - usedCPUs
	if len(active) >= p.MaxActiveComputers || remainingMemory < int64(p.MinimumGuestMemoryMb) || remainingCPUs < 1 {
		return Allocation{}, &CodedError{"This host does not currently have capacity for another cloud computer.", CodeCapacity, 503}
	}
	futureComputers := max(0, p.MaxActiveComputers-(len(active)+1))
	memoryForFuture := int64(futureComputers) * int64(p.MinimumGuestMemoryMb)
	return Allocation{
		MemoryMb: min(int64(p.MaximumGuestMemoryMb), max(int64(p.MinimumGuestMemoryMb), remainingMemory-memoryForFuture)),
		CPUs:     min(p.MaximumGuestCPUs, max(1, remainingCPUs-futureComputers)),
	}, nil
}

// Storage describes the disk a computer's data disk would live on.
type Storage struct {
	AvailableBytes       int64
	SparseLiabilityBytes int64
}

// StorageHeadroomBytes is the free space left after the host's reserve and the
// growth already promised to running computers.
func StorageHeadroomBytes(p ResourceProfile, s Storage) int64 {
	if s.AvailableBytes <= 0 {
		return 0
	}
	reserve := float64(s.AvailableBytes) * float64(p.StorageReservePercent) / 100
	return int64(math.Floor(float64(s.AvailableBytes) - reserve - float64(max(0, s.SparseLiabilityBytes))))
}

// ChooseDataDiskGiB sizes a new data disk within the profile's bounds, or
// fails with COMPUTER_STORAGE_CAPACITY when the host has no room.
func ChooseDataDiskGiB(p ResourceProfile, s Storage) (int, error) {
	availableGiB := StorageHeadroomBytes(p, s) / gib
	if availableGiB <= 0 || availableGiB < int64(p.MinimumDiskGiB) {
		return 0, &CodedError{"This host does not have enough free storage for another cloud computer disk.", CodeStorageCapacity, 507}
	}
	return int(min(int64(p.MaximumDiskGiB), availableGiB)), nil
}
