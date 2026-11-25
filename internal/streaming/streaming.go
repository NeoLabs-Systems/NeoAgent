// Package streaming produces the live screen frames of the browser and the
// Android emulator and starts, stops and reports streams for /api/stream. The stream hub that fans frames out to subscribers
// belongs to the realtime layer and is reached through the Hub interface.
package streaming

import (
	"bytes"
	"log/slog"
	"sync"
	"time"
)

// Frame is one JPEG image of a stream.
type Frame struct {
	JPEG     []byte
	Platform string
	Seq      uint32
	// TS is the capture time in milliseconds, truncated to 32 bits as the
	// wire format has it.
	TS    uint32
	Flags uint8
}

// FrameSink receives frames. The realtime hub implements it
// (StreamHub.handleFrame in Node).
type FrameSink interface {
	HandleFrame(userID, deviceID string, frame Frame)
}

// clampInt bounds v, using fallback when v is zero.
func clampInt(v, fallback, lo, hi int) int {
	if v == 0 {
		return fallback
	}
	return min(hi, max(lo, v))
}

// nowTS is Date.now() >>> 0.
func nowTS() uint32 { return uint32(time.Now().UnixMilli()) }

// JPEGParser extracts complete JPEG images from a byte stream: ffmpeg writes
// MJPEG as concatenated images, each from an SOI marker (FF D8) to an EOI
// marker (FF D9).
type JPEGParser struct {
	buf []byte
}

var (
	soi = []byte{0xff, 0xd8}
	eoi = []byte{0xff, 0xd9}
)

// Push adds bytes and returns every image they completed. Bytes before an SOI
// are discarded; a trailing partial image is kept for the next call.
func (p *JPEGParser) Push(chunk []byte) [][]byte {
	if len(chunk) == 0 {
		return nil
	}
	p.buf = append(p.buf, chunk...)
	var frames [][]byte
	for {
		start := bytes.Index(p.buf, soi)
		if start < 0 {
			// Keep a trailing FF: its D8 may arrive in the next chunk.
			if n := len(p.buf); n > 0 && p.buf[n-1] == 0xff {
				p.buf = []byte{0xff}
			} else {
				p.buf = nil
			}
			return frames
		}
		end := bytes.Index(p.buf[start+2:], eoi)
		if end < 0 {
			p.buf = append([]byte(nil), p.buf[start:]...)
			return frames
		}
		end += start + 2
		frames = append(frames, append([]byte(nil), p.buf[start:end+2]...))
		p.buf = p.buf[end+2:]
	}
}

// throttledLog logs at most once per interval, as a stream that fails every
// frame would otherwise flood the log.
type throttledLog struct {
	log      *slog.Logger
	mu       sync.Mutex
	last     time.Time
	interval time.Duration
}

func (t *throttledLog) warn(msg string, args ...any) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if time.Since(t.last) <= t.interval {
		return
	}
	t.last = time.Now()
	t.log.Warn(msg, args...)
}
