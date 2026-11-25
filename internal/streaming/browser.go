package streaming

import (
	"context"
	"log/slog"
	"sync"
	"sync/atomic"
	"time"
)

// JPEGSource captures the browser viewport as a JPEG. The browser controller
// implements it.
type JPEGSource interface {
	ScreenshotJPEG(ctx context.Context, quality int) ([]byte, error)
}

// BrowserConfig configures a BrowserStream.
type BrowserConfig struct {
	UserID   string
	DeviceID string // default "browser"
	Source   JPEGSource
	Sink     FrameSink
	FPS      int // 1-20, default 15
	Quality  int // 30-95, default 80
	Log      *slog.Logger
}

// BrowserStream polls the browser for JPEG screenshots at a fixed rate.
type BrowserStream struct {
	cfg BrowserConfig
	log *throttledLog

	mu     sync.Mutex
	cancel context.CancelFunc
	done   chan struct{}

	capturing atomic.Bool
	seq       atomic.Uint32
}

// NewBrowserStream applies the defaults and limits.
func NewBrowserStream(cfg BrowserConfig) *BrowserStream {
	if cfg.DeviceID == "" {
		cfg.DeviceID = "browser"
	}
	cfg.FPS = clampInt(cfg.FPS, 15, 1, 20)
	cfg.Quality = clampInt(cfg.Quality, 80, 30, 95)
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	return &BrowserStream{cfg: cfg, log: &throttledLog{log: cfg.Log, interval: 0}}
}

// Start begins capturing; it does nothing when already running.
func (s *BrowserStream) Start() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.cancel != nil {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.cancel, s.done = cancel, make(chan struct{})
	go s.run(ctx, s.done)
}

// Stop ends capturing and waits for a capture in flight.
func (s *BrowserStream) Stop() {
	s.mu.Lock()
	cancel, done := s.cancel, s.done
	s.cancel, s.done = nil, nil
	s.mu.Unlock()
	if cancel != nil {
		cancel()
		<-done
	}
}

func (s *BrowserStream) run(ctx context.Context, done chan struct{}) {
	defer close(done)
	ticker := time.NewTicker(max(time.Millisecond, time.Second/time.Duration(s.cfg.FPS)))
	defer ticker.Stop()
	s.tick(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.tick(ctx)
		}
	}
}

// tick captures one frame unless the previous capture is still running: a slow
// browser skips ticks instead of queueing frames.
func (s *BrowserStream) tick(ctx context.Context) {
	if s.capturing.CompareAndSwap(false, true) {
		defer s.capturing.Store(false)
		s.captureOnce(ctx)
	}
}

func (s *BrowserStream) captureOnce(ctx context.Context) {
	jpeg, err := s.cfg.Source.ScreenshotJPEG(ctx, s.cfg.Quality)
	if err != nil {
		if ctx.Err() == nil {
			s.log.warn("[BrowserStream] frame capture failed", "user", s.cfg.UserID, "device", s.cfg.DeviceID, "error", err)
		}
		return
	}
	if len(jpeg) == 0 || ctx.Err() != nil {
		return
	}
	s.cfg.Sink.HandleFrame(s.cfg.UserID, s.cfg.DeviceID, Frame{
		JPEG: jpeg, Platform: "browser", Seq: s.seq.Add(1) - 1, TS: nowTS(), Flags: 1,
	})
}
