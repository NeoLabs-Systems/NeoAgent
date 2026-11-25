package guest

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"net/http"
	"os"
	"runtime"
	"strings"
)

func nodePlatform() string {
	if runtime.GOOS == "windows" {
		return "win32"
	}
	return runtime.GOOS
}

func nodeArch() string {
	switch runtime.GOARCH {
	case "amd64":
		return "x64"
	case "386":
		return "ia32"
	}
	return runtime.GOARCH
}

type healthBody struct {
	Status            string `json:"status"`
	Runtime           string `json:"runtime"`
	Profile           string `json:"profile"`
	Platform          string `json:"platform"`
	Arch              string `json:"arch"`
	CloudInitFinished bool   `json:"cloudInitFinished"`
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	finished := exists(s.cfg.CloudInitFinishedPath)
	status := "starting"
	if finished {
		status = "ok"
	}
	writeJSON(w, http.StatusOK, healthBody{status, runtimeName, s.cfg.Profile, nodePlatform(), nodeArch(), finished})
}

type bootAsset struct {
	SHA256  string `json:"sha256"`
	Size    int    `json:"size"`
	Content string `json:"content"`
}

func encodeAsset(data []byte) bootAsset {
	sum := sha256.Sum256(data)
	return bootAsset{hex.EncodeToString(sum[:]), len(data), base64.StdEncoding.EncodeToString(data)}
}

// kernelRelease is `uname -r`.
func kernelRelease() (string, error) {
	raw, err := os.ReadFile("/proc/sys/kernel/osrelease")
	return strings.TrimSpace(string(raw)), err
}

// bootAssets hands the host the guest's kernel and initramfs so later starts
// can boot them directly.
func (s *Server) bootAssets(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) {
		release, err := kernelRelease()
		if err != nil {
			return nil, err
		}
		kernel, err := os.ReadFile("/boot/vmlinuz-" + release)
		if err != nil {
			return nil, err
		}
		initrd, err := os.ReadFile("/boot/initrd.img-" + release)
		if err != nil {
			return nil, err
		}
		return struct {
			Release string    `json:"release"`
			Kernel  bootAsset `json:"kernel"`
			Initrd  bootAsset `json:"initrd"`
		}{release, encodeAsset(kernel), encodeAsset(initrd)}, nil
	})
}
