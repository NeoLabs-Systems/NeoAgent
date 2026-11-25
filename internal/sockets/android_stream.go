package sockets

import (
	"bytes"
	"context"
	"errors"
	"image/jpeg"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

const (
	defaultFirstFrameTimeout = 6 * time.Second
	screenrecordRestart      = 170 * time.Second // Android stops screenrecord at 180 s
	relaunchDelay            = 2 * time.Second
	pollRetryDelay           = 500 * time.Millisecond
	logThrottle              = 10 * time.Second
)

// PNGToJPEG re-encodes a screenshot as a JPEG of the given quality (1-100).
func PNGToJPEG(data []byte, quality int) ([]byte, error) {
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

// jpegSplitter cuts complete JPEG images (SOI FF D8 ... EOI FF D9) out of the
// raw MJPEG byte stream ffmpeg writes.
type jpegSplitter struct{ buf []byte }

var (
	jpegSOI = []byte{0xff, 0xd8}
	jpegEOI = []byte{0xff, 0xd9}
)

func (p *jpegSplitter) push(chunk []byte) [][]byte {
	p.buf = append(p.buf, chunk...)
	var frames [][]byte
	for {
		soi := bytes.Index(p.buf, jpegSOI)
		if soi < 0 {
			// No frame start: discard everything but a trailing FF, which may be
			// the first half of a marker split across two reads.
			if n := len(p.buf); n > 0 && p.buf[n-1] == 0xff {
				p.buf = append(p.buf[:0], 0xff)
			} else {
				p.buf = p.buf[:0]
			}
			return frames
		}
		eoi := bytes.Index(p.buf[soi+2:], jpegEOI)
		if eoi < 0 { // frame still arriving: keep it from its start
			p.buf = append(p.buf[:0], p.buf[soi:]...)
			return frames
		}
		end := soi + 2 + eoi + 2
		frames = append(frames, append([]byte(nil), p.buf[soi:end]...))
		p.buf = p.buf[end:]
	}
}

// androidStream streams the emulator screen: adb screenrecord (H.264) piped
// through ffmpeg to MJPEG, restarted before Android's time limit, falling back
// to screenshot polling when the pipeline cannot start
// (services/streaming/android-stream.js).
type androidStream struct {
	srv      *Server
	userID   int64
	deviceID string
	ctl      AndroidController
	fps      int
	quality  int

	mu      sync.Mutex
	cancel  context.CancelFunc
	seq     atomic.Uint32
	started atomic.Bool // a frame was produced
	polling bool        // H.264 failed to start
	lastLog time.Time
}

func newAndroidStream(srv *Server, userID int64, deviceID string, ctl AndroidController, fps, quality int) *androidStream {
	return &androidStream{srv: srv, userID: userID, deviceID: deviceID, ctl: ctl, fps: fps, quality: quality}
}

func (a *androidStream) start() {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.cancel != nil {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	a.cancel = cancel
	go a.run(ctx)
}

func (a *androidStream) stop() {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.cancel != nil {
		a.cancel()
		a.cancel = nil
	}
}

func (a *androidStream) logf(msg string, err error) {
	a.mu.Lock()
	if time.Since(a.lastLog) < logThrottle {
		a.mu.Unlock()
		return
	}
	a.lastLog = time.Now()
	a.mu.Unlock()
	a.srv.log.Warn("[AndroidStream] "+msg, "userId", a.userID, "deviceId", a.deviceID, "error", err)
}

func (a *androidStream) emit(jpeg []byte) {
	a.started.Store(true)
	a.srv.streams.HandleFrame(a.userID, a.deviceID, Frame{
		Platform: "android", JPEG: jpeg, Seq: a.seq.Add(1) - 1, TS: uint32(time.Now().UnixMilli()), Flags: 1,
	})
}

func (a *androidStream) run(ctx context.Context) {
	for ctx.Err() == nil {
		if a.polling {
			a.pollLoop(ctx)
			return
		}
		switch a.runH264(ctx) {
		case outcomeFallback:
			a.polling = true
		case outcomeRelaunch:
			select {
			case <-ctx.Done():
			case <-time.After(relaunchDelay):
			}
		}
	}
}

type outcome int

const (
	outcomeRestart  outcome = iota // the screenrecord time limit: start again at once
	outcomeRelaunch                // the pipeline ended: start again shortly
	outcomeFallback                // the pipeline cannot work: poll screenshots
)

func adbBinary(sdkDir string) string {
	name := "adb"
	if runtime.GOOS == "windows" {
		name = "adb.exe"
	}
	if sdkDir == "" {
		return name // from PATH
	}
	return filepath.Join(sdkDir, "platform-tools", name)
}

// runH264 runs one adb | ffmpeg pipeline until it ends and says what to do next.
func (a *androidStream) runH264(parent context.Context) outcome {
	ctx, cancel := context.WithCancel(parent)
	defer cancel()

	adb := exec.CommandContext(ctx, adbBinary(a.ctl.SDKDir()),
		"-s", a.deviceID, "exec-out", "screenrecord", "--output-format=h264", "--bit-rate=2000000", "--size=1280x720", "-")
	// Quality 30-95 maps to ffmpeg q:v 20-2 (lower is better).
	q := int(float64(2) + (float64(95-a.quality)/float64(95-30))*18 + 0.5)
	ffmpeg := exec.CommandContext(ctx, "ffmpeg", "-loglevel", "error", "-f", "h264", "-i", "pipe:0",
		"-f", "image2pipe", "-vcodec", "mjpeg", "-q:v", strconv.Itoa(q), "-vf", "fps="+strconv.Itoa(a.fps), "pipe:1")

	pipeR, pipeW, err := os.Pipe()
	if err != nil {
		a.logf("could not create the adb to ffmpeg pipe, falling back to screencap", err)
		return outcomeFallback
	}
	defer pipeR.Close()
	defer pipeW.Close()
	adb.Stdout = pipeW
	ffmpeg.Stdin = pipeR
	frames, err := ffmpeg.StdoutPipe()
	if err != nil {
		return outcomeFallback
	}
	if err := adb.Start(); err != nil {
		a.logf("Failed to spawn adb for H.264 streaming, falling back to screencap", err)
		return outcomeFallback
	}
	if err := ffmpeg.Start(); err != nil {
		a.logf("ffmpeg not found, falling back to screencap", err)
		cancel()
		_ = adb.Wait()
		return outcomeFallback
	}
	_ = pipeW.Close() // the children hold their own ends
	_ = pipeR.Close()

	var splitter jpegSplitter
	readDone := make(chan struct{})
	go func() {
		defer close(readDone)
		buf := make([]byte, 64*1024)
		for {
			n, err := frames.Read(buf)
			for _, f := range splitter.push(buf[:n]) {
				if ctx.Err() == nil {
					a.emit(f)
				}
			}
			if err != nil {
				return
			}
		}
	}()

	adbDone := make(chan error, 1)
	go func() { adbDone <- adb.Wait() }()
	ffmpegDone := make(chan error, 1)
	go func() { <-readDone; ffmpegDone <- ffmpeg.Wait() }()

	firstFrame := time.NewTimer(a.srv.firstFrameTimeout())
	defer firstFrame.Stop()
	restart := time.NewTimer(screenrecordRestart)
	defer restart.Stop()
	for {
		select {
		case <-parent.Done():
			cancel()
			return outcomeRestart
		case <-restart.C:
			cancel()
			<-adbDone
			return outcomeRestart
		case <-firstFrame.C:
			if !a.started.Load() {
				a.logf("H.264 stream produced no frames before timeout, using screencap fallback", nil)
				cancel()
				<-adbDone
				return outcomeFallback
			}
		case err := <-adbDone:
			cancel()
			if !a.started.Load() && err != nil {
				a.logf("screenrecord exited before producing any frames, using screencap fallback", err)
				return outcomeFallback
			}
			a.logf("adb screenrecord exited, restarting in 2 s", err)
			return outcomeRelaunch
		case err := <-ffmpegDone:
			if !a.started.Load() {
				cancel()
				<-adbDone
				a.logf("ffmpeg exited before producing any frames, using screencap fallback", err)
				return outcomeFallback
			}
			cancel()
			<-adbDone
			return outcomeRelaunch
		}
	}
}

// pollLoop is the fallback: capture screenshots back to back until stopped.
func (a *androidStream) pollLoop(ctx context.Context) {
	for ctx.Err() == nil {
		frame, err := a.captureJPEG(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			a.logf("screencap poll failed", err)
			select {
			case <-ctx.Done():
			case <-time.After(pollRetryDelay):
			}
			continue
		}
		if len(frame) > 0 && ctx.Err() == nil {
			a.emit(frame)
		}
	}
}

func (a *androidStream) captureJPEG(ctx context.Context) ([]byte, error) {
	data, err := a.ctl.CapturePNG(ctx, a.deviceID)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return nil, errors.New("empty screenshot")
	}
	return PNGToJPEG(data, a.quality)
}
