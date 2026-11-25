//go:build windows

package streaming

import (
	"os"
	"syscall"
)

func groupAttrs() *syscall.SysProcAttr { return &syscall.SysProcAttr{} }

func terminateGroup(p *os.Process) error { return p.Kill() }
