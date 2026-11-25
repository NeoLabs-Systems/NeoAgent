//go:build !race

package browser

import "testing"

func skipChromiumUnderRaceDetector(*testing.T) {}
