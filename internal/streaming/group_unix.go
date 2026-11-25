//go:build !windows

package streaming

import (
	"os"
	"syscall"
)

// Each pipeline command runs in its own process group so cancelling ends
// whatever it spawned.
func groupAttrs() *syscall.SysProcAttr { return &syscall.SysProcAttr{Setpgid: true} }

func terminateGroup(p *os.Process) error { return syscall.Kill(-p.Pid, syscall.SIGTERM) }
