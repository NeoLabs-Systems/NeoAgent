package android

import (
	"bytes"
	"encoding/binary"
	"fmt"
)

const maxScreenshotBytes = 20 << 20

var pngSignature = []byte{0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a}

// validatePNG applies the screenshot checks of the Node server's
// validateImageBuffer for a payload that must be a PNG.
func validatePNG(b []byte) error {
	if len(b) == 0 {
		return fmt.Errorf("Screenshot payload is empty.")
	}
	if len(b) > maxScreenshotBytes {
		return fmt.Errorf("Screenshot payload exceeds the %d-byte limit.", maxScreenshotBytes)
	}
	if len(b) >= 24 && bytes.Equal(b[:8], pngSignature) && string(b[12:16]) == "IHDR" {
		w, h := binary.BigEndian.Uint32(b[16:20]), binary.BigEndian.Uint32(b[20:24])
		if w == 0 || h == 0 || w > 32768 || h > 32768 || uint64(w)*uint64(h) > 150_000_000 {
			return fmt.Errorf("Screenshot PNG has invalid or unsafe dimensions.")
		}
		return nil
	}
	if len(b) >= 4 && b[0] == 0xff && b[1] == 0xd8 && b[len(b)-2] == 0xff && b[len(b)-1] == 0xd9 {
		return fmt.Errorf("Screenshot type image/jpeg is not allowed.")
	}
	return fmt.Errorf("Screenshot payload is not a valid PNG or JPEG image.")
}
