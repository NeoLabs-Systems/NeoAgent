package sockets

import (
	"context"
	"sync"
	"sync/atomic"
	"time"
)

// browserStream pumps screenshots of a user's browser into the stream hub at
// the requested rate (services/streaming/browser-stream.js).
type browserStream struct {
	srv        *Server
	userID     int64
	deviceID   string
	controller BrowserController
	quality    int
	interval   time.Duration

	mu     sync.Mutex
	cancel context.CancelFunc
	seq    atomic.Uint32
	busy   atomic.Bool
}

func newBrowserStream(srv *Server, userID int64, deviceID string, c BrowserController, fps, quality int) *browserStream {
	return &browserStream{
		srv: srv, userID: userID, deviceID: deviceID, controller: c, quality: quality,
		interval: time.Duration(max(1, 1000/fps)) * time.Millisecond,
	}
}

func (b *browserStream) start() {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.cancel != nil {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	b.cancel = cancel
	go func() {
		b.captureOnce(ctx)
		t := time.NewTicker(b.interval)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				go b.captureOnce(ctx)
			}
		}
	}()
}

func (b *browserStream) stop() {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.cancel != nil {
		b.cancel()
		b.cancel = nil
	}
}

// captureOnce takes one frame; a capture still in flight skips the tick.
func (b *browserStream) captureOnce(ctx context.Context) {
	if !b.busy.CompareAndSwap(false, true) {
		return
	}
	defer b.busy.Store(false)
	jpeg, err := b.controller.ScreenshotJPEG(ctx, b.quality)
	if err != nil {
		if ctx.Err() == nil {
			b.srv.log.Warn("[BrowserStream] frame capture failed", "userId", b.userID, "deviceId", b.deviceID, "error", err)
		}
		return
	}
	if len(jpeg) == 0 || ctx.Err() != nil {
		return
	}
	b.srv.streams.HandleFrame(b.userID, b.deviceID, Frame{
		Platform: "browser", JPEG: jpeg, Seq: b.seq.Add(1) - 1, TS: uint32(time.Now().UnixMilli()), Flags: 1,
	})
}
