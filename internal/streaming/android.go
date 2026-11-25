package streaming

import (
	"bytes"
	"context"
	"fmt"
	"image/jpeg"
	"image/png"
	"io"
	"log/slog"
	"os/exec"
	"strconv"
	"sync"
	"time"
)

const (
	// screenrecord stops by itself after 180 s; restart a little before so the
	// stream has no gap.
	screenrecordRestart   = 170 * time.Second
	defaultFirstFrameWait = 6 * time.Second
	restartAfterExit      = 2 * time.Second
	pollRetryDelay        = 500 * time.Millisecond
)

// PNGSource captures the Android screen as a PNG. The Android controller
// implements it (CapturePNG).
type PNGSource interface {
	CapturePNG(ctx context.Context) ([]byte, error)
}

// AndroidConfig configures an AndroidStream.
type AndroidConfig struct {
	UserID   string
	DeviceID string // the adb serial
	ADBBin   string // path of adb; "adb" when empty
	FFmpeg   string // "ffmpeg" when empty
	Source   PNGSource
	Sink     FrameSink
	FPS      int // 1-30, default 12
	Quality  int // 30-95, default 75
	// FirstFrameTimeout is how long the H.264 pipeline may stay silent before
	// the screencap poller takes over (NEOAGENT_ANDROID_STREAM_FIRST_FRAME_TIMEOUT_MS,
	// default 6 s).
	FirstFrameTimeout time.Duration
	Log               *slog.Logger
}

// AndroidStream streams the emulator screen: `adb exec-out screenrecord`
// (H.264) decoded and re-encoded to MJPEG by ffmpeg, restarted before
// Android's three minute recording limit, with a screencap polling fallback
// when the H.264 pipeline cannot start.
type AndroidStream struct {
	cfg AndroidConfig
	log *throttledLog

	mu     sync.Mutex
	cancel context.CancelFunc
	done   chan struct{}

	seqMu sync.Mutex
	seq   uint32
}

// NewAndroidStream applies the defaults and limits.
func NewAndroidStream(cfg AndroidConfig) *AndroidStream {
	cfg.FPS = clampInt(cfg.FPS, 12, 1, 30)
	cfg.Quality = clampInt(cfg.Quality, 75, 30, 95)
	if cfg.ADBBin == "" {
		cfg.ADBBin = "adb"
	}
	if cfg.FFmpeg == "" {
		cfg.FFmpeg = "ffmpeg"
	}
	if cfg.FirstFrameTimeout == 0 {
		cfg.FirstFrameTimeout = defaultFirstFrameWait
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	return &AndroidStream{cfg: cfg, log: &throttledLog{log: cfg.Log, interval: 10 * time.Second}}
}

// Start begins streaming; it does nothing when already running.
func (s *AndroidStream) Start() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.cancel != nil {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.cancel, s.done = cancel, make(chan struct{})
	go func(done chan struct{}) {
		defer close(done)
		s.run(ctx)
	}(s.done)
}

// Stop ends the stream and its child processes.
func (s *AndroidStream) Stop() {
	s.mu.Lock()
	cancel, done := s.cancel, s.done
	s.cancel, s.done = nil, nil
	s.mu.Unlock()
	if cancel != nil {
		cancel()
		<-done
	}
}

func (s *AndroidStream) sequence() uint32 {
	s.seqMu.Lock()
	defer s.seqMu.Unlock()
	n := s.seq
	s.seq++
	return n
}

func (s *AndroidStream) frames() uint32 {
	s.seqMu.Lock()
	defer s.seqMu.Unlock()
	return s.seq
}

func (s *AndroidStream) publish(jpegData []byte) {
	s.cfg.Sink.HandleFrame(s.cfg.UserID, s.cfg.DeviceID, Frame{
		JPEG: jpegData, Platform: "android", Seq: s.sequence(), TS: nowTS(), Flags: 1,
	})
}

type pipelineEnd int

const (
	endStopped pipelineEnd = iota
	endFallback
	endRestartNow
	endRestartLater
)

// run supervises the H.264 pipeline and falls back to polling for good once it
// proves unusable.
func (s *AndroidStream) run(ctx context.Context) {
	for ctx.Err() == nil {
		switch s.runPipeline(ctx) {
		case endStopped:
			return
		case endFallback:
			s.pollLoop(ctx)
			return
		case endRestartLater:
			select {
			case <-ctx.Done():
				return
			case <-time.After(restartAfterExit):
			}
		}
	}
}

// ffmpegQuality maps the 30-95 quality range to ffmpeg's -q:v 2-20 (lower is
// better).
func ffmpegQuality(quality int) int {
	return int(float64(2) + float64(95-quality)/float64(95-30)*18 + 0.5)
}

func (s *AndroidStream) runPipeline(ctx context.Context) pipelineEnd {
	pctx, cancel := context.WithTimeout(ctx, screenrecordRestart)
	defer cancel()

	adb := exec.CommandContext(pctx, s.cfg.ADBBin, "-s", s.cfg.DeviceID, "exec-out", "screenrecord",
		"--output-format=h264", "--bit-rate=2000000", "--size=1280x720", "-")
	ffmpeg := exec.CommandContext(pctx, s.cfg.FFmpeg, "-loglevel", "error", "-f", "h264", "-i", "pipe:0",
		"-f", "image2pipe", "-vcodec", "mjpeg", "-q:v", strconv.Itoa(ffmpegQuality(s.cfg.Quality)),
		"-vf", fmt.Sprintf("fps=%d", s.cfg.FPS), "pipe:1")
	for _, c := range []*exec.Cmd{adb, ffmpeg} {
		c.SysProcAttr = groupAttrs()
		c.Cancel = func() error { return nil }
	}
	adb.Cancel = func() error { return terminateGroup(adb.Process) }
	ffmpeg.Cancel = func() error { return terminateGroup(ffmpeg.Process) }
	adb.WaitDelay, ffmpeg.WaitDelay = time.Second, time.Second

	adbOut, err := adb.StdoutPipe()
	if err != nil {
		s.log.warn("[AndroidStream] Failed to prepare adb for H.264 streaming, falling back to screencap", "error", err)
		return endFallback
	}
	ffIn, err := ffmpeg.StdinPipe()
	if err != nil {
		return endFallback
	}
	ffOut, err := ffmpeg.StdoutPipe()
	if err != nil {
		return endFallback
	}
	if err := adb.Start(); err != nil {
		s.log.warn("[AndroidStream] Failed to spawn adb for H.264 streaming, falling back to screencap", "error", err)
		return endFallback
	}
	if err := ffmpeg.Start(); err != nil {
		s.log.warn("[AndroidStream] ffmpeg not found, falling back to screencap", "error", err)
		cancel()
		_ = adb.Wait()
		return endFallback
	}

	adbExit := make(chan error, 1)
	go func() {
		_, _ = io.Copy(ffIn, adbOut)
		_ = ffIn.Close()
	}()
	go func() { adbExit <- adb.Wait() }()
	ffExit := make(chan struct{})
	go func() {
		parser := &JPEGParser{}
		buf := make([]byte, 64<<10)
		for {
			n, err := ffOut.Read(buf)
			for _, f := range parser.Push(buf[:n]) {
				if ctx.Err() == nil {
					s.publish(f)
				}
			}
			if err != nil {
				break
			}
		}
		_ = ffmpeg.Wait()
		close(ffExit)
	}()

	firstFrame := time.NewTimer(s.cfg.FirstFrameTimeout)
	defer firstFrame.Stop()
	// stopPipeline ends both processes before returning why.
	stopPipeline := func(end pipelineEnd) pipelineEnd {
		cancel()
		<-adbExit
		<-ffExit
		return end
	}
	for {
		select {
		case <-ctx.Done():
			return stopPipeline(endStopped)
		case <-pctx.Done():
			// screenrecord's own limit: start the next recording at once.
			return stopPipeline(endRestartNow)
		case <-firstFrame.C:
			if s.frames() == 0 {
				s.log.warn("[AndroidStream] H.264 stream produced no frames before timeout — using screencap fallback")
				return stopPipeline(endFallback)
			}
		case err := <-adbExit:
			adbExit <- err
			code := 0
			if err != nil {
				code = -1
				if ee, ok := err.(*exec.ExitError); ok {
					code = ee.ExitCode()
				}
			}
			if code != 0 && s.frames() == 0 {
				s.log.warn("[AndroidStream] screenrecord exited before producing any frames — using screencap fallback", "code", code)
				return stopPipeline(endFallback)
			}
			s.log.warn("[AndroidStream] adb screenrecord exited, restarting in 2 s", "code", code)
			return stopPipeline(endRestartLater)
		case <-ffExit:
			if s.frames() == 0 {
				s.log.warn("[AndroidStream] ffmpeg exited before producing any frames — using screencap fallback")
				return stopPipeline(endFallback)
			}
			return stopPipeline(endRestartLater)
		}
	}
}

// pollLoop captures PNG screenshots back to back and re-encodes them as JPEG,
// with no idle wait between captures.
func (s *AndroidStream) pollLoop(ctx context.Context) {
	for ctx.Err() == nil {
		data, err := s.cfg.Source.CapturePNG(ctx)
		if err == nil && ctx.Err() == nil && len(data) > 0 {
			var jpegData []byte
			if jpegData, err = pngToJPEG(data, s.cfg.Quality); err == nil {
				if ctx.Err() == nil {
					s.publish(jpegData)
				}
				continue
			}
		}
		if err == nil || ctx.Err() != nil {
			continue
		}
		s.log.warn("[AndroidStream] screencap poll failed", "device", s.cfg.DeviceID, "error", err)
		select {
		case <-ctx.Done():
		case <-time.After(pollRetryDelay):
		}
	}
}

// pngToJPEG re-encodes an image at the given quality, keeping its dimensions.
func pngToJPEG(data []byte, quality int) ([]byte, error) {
	img, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	var out bytes.Buffer
	if err := jpeg.Encode(&out, img, &jpeg.Options{Quality: quality}); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}
