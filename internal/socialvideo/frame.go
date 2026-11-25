package socialvideo

import (
	"math"
	"path/filepath"
	"strings"
)

// frameSecond picks the second of the video to grab a still from.
func frameSecond(duration float64) int {
	if math.IsNaN(duration) || math.IsInf(duration, 0) || duration <= 0 {
		return 2
	}
	target := int(math.Floor(duration*0.33 + 0.5))
	return max(1, min(target, 120))
}

func imageContentType(path string) string {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".webp":
		return "image/webp"
	case ".png":
		return "image/png"
	}
	return "application/octet-stream"
}

// FrameImage points at the still taken from a video. URL is null when the
// thumbnail could not be stored.
type FrameImage struct {
	URL        *string `json:"url"`
	ArtifactID *string `json:"artifactId"`
	MimeType   *string `json:"mimeType"`
	ByteSize   *int64  `json:"byteSize"`
	Source     string  `json:"source"`
}
