package wiring

import "os"

// processGone reports a process id that no longer exists. On Windows,
// FindProcess opens the process and fails when there is none.
func processGone(pid int) bool {
	p, err := os.FindProcess(pid)
	if err != nil {
		return true
	}
	_ = p.Release()
	return false
}
