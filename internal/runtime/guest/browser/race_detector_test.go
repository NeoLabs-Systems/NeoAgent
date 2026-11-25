//go:build race

package browser

import "testing"

func skipChromiumUnderRaceDetector(t *testing.T) {
	t.Helper()
	t.Skip("chromedp's CDP frame-tree initialization is not race-clean; browser integration runs without -race")
}
