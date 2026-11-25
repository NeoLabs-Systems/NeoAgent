//go:build windows

package guest

import "os/exec"

func detach(*exec.Cmd) {}
