//go:build windows

package android

import "os"

// Windows cannot ask a process to terminate; both end it.
func terminatePID(pid int) { killPID(pid) }

func killPID(pid int) {
	if p, err := os.FindProcess(pid); err == nil {
		_ = p.Kill()
	}
}
