//go:build !windows

package wiring

import "syscall"

// processGone reports a process id that no longer exists.
func processGone(pid int) bool {
	return syscall.Kill(pid, 0) == syscall.ESRCH
}
