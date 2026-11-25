package runtime

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"regexp"
	"strings"
)

const maxScreenshotBytes = 20 * 1024 * 1024

var (
	pngSignature = []byte{0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a}
	imageDataURL = regexp.MustCompile(`(?i)^data:image/(png|jpeg|jpg);base64,([A-Za-z0-9+/]*={0,2})$`)
	base64Text   = regexp.MustCompile(`^[A-Za-z0-9+/]*={0,2}$`)
)

type decodedImage struct {
	data                   []byte
	contentType, extension string
}

func imageError(message string) error {
	return &CodedError{Message: message, Code: "INVALID_IMAGE_PAYLOAD"}
}

// decodeImage reads a PNG or JPEG sent as base64 or a data URL, checking its
// signature, declared type and size.
func decodeImage(text string) (decodedImage, error) {
	if text == "" {
		return decodedImage{}, imageError("Screenshot payload is empty.")
	}
	encoded, declared := text, ""
	if strings.HasPrefix(text, "data:") {
		m := imageDataURL.FindStringSubmatch(text)
		if m == nil {
			return decodedImage{}, imageError("Screenshot data URL is malformed or uses an unsupported type.")
		}
		declared = "image/jpeg"
		if strings.EqualFold(m[1], "png") {
			declared = "image/png"
		}
		encoded = m[2]
	}
	if encoded == "" || len(encoded)%4 == 1 || !base64Text.MatchString(encoded) {
		return decodedImage{}, imageError("Screenshot base64 payload is malformed.")
	}
	padding := strings.Count(encoded[max(0, len(encoded)-2):], "=")
	if len(encoded)*3/4-padding > maxScreenshotBytes {
		return decodedImage{}, &CodedError{Message: fmt.Sprintf("Screenshot payload exceeds the %d-byte limit.", maxScreenshotBytes), Code: "IMAGE_PAYLOAD_TOO_LARGE"}
	}
	data, err := base64.RawStdEncoding.DecodeString(strings.TrimRight(encoded, "="))
	if err != nil {
		return decodedImage{}, imageError("Screenshot base64 payload is malformed.")
	}
	if len(data) == 0 {
		return decodedImage{}, imageError("Screenshot payload is empty.")
	}
	img := decodedImage{data: data}
	switch {
	case len(data) >= 24 && bytes.Equal(data[:8], pngSignature) && string(data[12:16]) == "IHDR":
		w, h := binary.BigEndian.Uint32(data[16:20]), binary.BigEndian.Uint32(data[20:24])
		if w == 0 || h == 0 || w > 32768 || h > 32768 || uint64(w)*uint64(h) > 150_000_000 {
			return decodedImage{}, imageError("Screenshot PNG has invalid or unsafe dimensions.")
		}
		img.contentType, img.extension = "image/png", "png"
	case len(data) >= 4 && data[0] == 0xff && data[1] == 0xd8 && data[len(data)-2] == 0xff && data[len(data)-1] == 0xd9:
		img.contentType, img.extension = "image/jpeg", "jpg"
	default:
		return decodedImage{}, imageError("Screenshot payload is not a valid PNG or JPEG image.")
	}
	if declared != "" && declared != img.contentType {
		return decodedImage{}, imageError("Screenshot data URL type does not match its image bytes.")
	}
	return img, nil
}
