package skills

import (
	"bytes"
	"compress/flate"
	"encoding/binary"
	"fmt"
	"io"
	"strings"
)

// A small reader for uploaded .zip archives: stored and deflated entries read
// from the central directory. Zip64, encryption and multi-disk archives are
// refused rather than half-read.
const (
	eocdSignature    = 0x06054b50
	centralSignature = 0x02014b50
	localSignature   = 0x04034b50
	eocdMinSize      = 22
	maxZipComment    = 0xffff

	maxZipEntries  = 5000
	maxEntryBytes  = 5 * 1024 * 1024
	maxUnpackBytes = 64 * 1024 * 1024
)

// zipEntry is one file of an archive, its path as stored with forward slashes.
type zipEntry struct {
	path string
	data []byte
}

func zipFailure(format string, args ...any) error {
	return &StatusError{Status: 400, Message: fmt.Sprintf(format, args...)}
}

var le = binary.LittleEndian

func readZipEntries(buf []byte) ([]zipEntry, error) {
	if len(buf) < eocdMinSize {
		return nil, zipFailure("This file is not a zip archive")
	}
	eocd := -1
	lowest := max(0, len(buf)-eocdMinSize-maxZipComment)
	for off := len(buf) - eocdMinSize; off >= lowest; off-- {
		if le.Uint32(buf[off:]) == eocdSignature {
			eocd = off
			break
		}
	}
	if eocd < 0 {
		return nil, zipFailure("This file is not a zip archive")
	}
	count := int(le.Uint16(buf[eocd+10:]))
	dirSize := int64(le.Uint32(buf[eocd+12:]))
	dirOffset := int64(le.Uint32(buf[eocd+16:]))
	if count == 0xffff || dirOffset == 0xffffffff {
		return nil, zipFailure("Zip64 archives are not supported; zip a smaller folder")
	}
	if count > maxZipEntries {
		return nil, zipFailure("The archive has %d entries; the limit is %d", count, maxZipEntries)
	}
	if dirOffset+dirSize > int64(len(buf)) {
		return nil, zipFailure("The zip archive is damaged")
	}

	var files []zipEntry
	var total int64
	cursor := int(dirOffset)
	for i := 0; i < count; i++ {
		if cursor+46 > len(buf) || le.Uint32(buf[cursor:]) != centralSignature {
			return nil, zipFailure("The zip archive is damaged")
		}
		flags := le.Uint16(buf[cursor+8:])
		method := le.Uint16(buf[cursor+10:])
		compressed := int64(le.Uint32(buf[cursor+20:]))
		size := int64(le.Uint32(buf[cursor+24:]))
		nameLen := int(le.Uint16(buf[cursor+28:]))
		extraLen := int(le.Uint16(buf[cursor+30:]))
		commentLen := int(le.Uint16(buf[cursor+32:]))
		local := int64(le.Uint32(buf[cursor+42:]))
		if cursor+46+nameLen > len(buf) {
			return nil, zipFailure("The zip archive is damaged")
		}
		rawName := buf[cursor+46 : cursor+46+nameLen]
		cursor += 46 + nameLen + extraLen + commentLen

		name := string(rawName)
		if flags&0x800 == 0 {
			runes := make([]rune, len(rawName))
			for j, b := range rawName {
				runes[j] = rune(b)
			}
			name = string(runes)
		}
		if strings.HasSuffix(name, "/") {
			continue
		}
		if flags&0x1 != 0 {
			return nil, zipFailure("Encrypted zip archives are not supported")
		}
		if size > maxEntryBytes {
			continue
		}
		total += size
		if total > maxUnpackBytes {
			return nil, zipFailure("The archive unpacks to more than %d MB", maxUnpackBytes/1024/1024)
		}

		if local+30 > int64(len(buf)) || le.Uint32(buf[local:]) != localSignature {
			return nil, zipFailure("The zip archive is damaged")
		}
		start := local + 30 + int64(le.Uint16(buf[local+26:])) + int64(le.Uint16(buf[local+28:]))
		end := min(start+compressed, int64(len(buf)))
		if start > end {
			return nil, zipFailure("The zip archive is damaged")
		}
		raw := buf[start:end]
		var data []byte
		switch method {
		case 0:
			data = append([]byte(nil), raw...)
		case 8:
			// Inflate no further than the declared size, so a crafted entry
			// cannot expand past the archive's limits.
			var err error
			data, err = io.ReadAll(io.LimitReader(flate.NewReader(bytes.NewReader(raw)), max(size, 1)+1))
			if err != nil || int64(len(data)) > max(size, 1) {
				return nil, zipFailure("The zip archive is damaged")
			}
		default:
			return nil, zipFailure("Unsupported zip compression (method %d)", method)
		}
		if int64(len(data)) != size {
			return nil, zipFailure("The zip archive is damaged")
		}
		files = append(files, zipEntry{path: strings.ReplaceAll(name, "\\", "/"), data: data})
	}
	return files, nil
}
