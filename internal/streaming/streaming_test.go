package streaming

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

type recorder struct {
	mu     sync.Mutex
	frames []Frame
	users  []string
	devs   []string
}

func (r *recorder) HandleFrame(user, device string, f Frame) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.frames = append(r.frames, f)
	r.users = append(r.users, user)
	r.devs = append(r.devs, device)
}

func (r *recorder) count() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.frames)
}

func (r *recorder) waitFor(t *testing.T, n int, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if r.count() >= n {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("got %d frames, want %d", r.count(), n)
}

var quiet = slog.New(slog.NewTextHandler(io.Discard, nil))

func solidJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for x := 0; x < w; x++ {
		for y := 0; y < h; y++ {
			img.Set(x, y, color.RGBA{uint8(x), uint8(y), 90, 255})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 80}); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func solidPNG(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for x := 0; x < w; x++ {
		for y := 0; y < h; y++ {
			img.Set(x, y, color.RGBA{uint8(x * 3), uint8(y * 3), 40, 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func TestJPEGParserSplitsStream(t *testing.T) {
	a, b := solidJPEG(t, 16, 16), solidJPEG(t, 24, 8)
	stream := append(append([]byte{0x00, 0x01, 0x02}, a...), append([]byte{0x77}, b...)...)
	// Feed one byte at a time and in odd chunks: the result must not depend on it.
	for _, chunk := range []int{1, 3, 7, len(stream)} {
		p := &JPEGParser{}
		var got [][]byte
		for i := 0; i < len(stream); i += chunk {
			got = append(got, p.Push(stream[i:min(i+chunk, len(stream))])...)
		}
		if len(got) != 2 || !bytes.Equal(got[0], a) || !bytes.Equal(got[1], b) {
			t.Fatalf("chunk %d: %d frames", chunk, len(got))
		}
	}
	p := &JPEGParser{}
	if frames := p.Push([]byte("no markers at all")); len(frames) != 0 || p.buf != nil {
		t.Fatal("garbage was kept")
	}
	if frames := p.Push(a[:len(a)-3]); len(frames) != 0 {
		t.Fatal("partial image emitted")
	}
	if frames := p.Push(a[len(a)-3:]); len(frames) != 1 || !bytes.Equal(frames[0], a) {
		t.Fatal("completed image not emitted")
	}
	if p.Push(nil) != nil {
		t.Fatal("empty push returned frames")
	}
}

func TestFFmpegQualityMapping(t *testing.T) {
	// Node: Math.round(2 + ((95 - quality) / (95 - 30)) * 18).
	for q, want := range map[int]int{95: 2, 75: 8, 30: 20, 80: 6, 50: 14} {
		if got := ffmpegQuality(q); got != want {
			t.Errorf("ffmpegQuality(%d) = %d, want %d", q, got, want)
		}
	}
}

type jpegSource struct {
	mu      sync.Mutex
	calls   []int
	failing bool
	delay   time.Duration
	jpeg    []byte
}

func (s *jpegSource) ScreenshotJPEG(ctx context.Context, quality int) ([]byte, error) {
	s.mu.Lock()
	s.calls = append(s.calls, quality)
	failing, delay := s.failing, s.delay
	s.mu.Unlock()
	if delay > 0 {
		select {
		case <-time.After(delay):
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	if failing {
		return nil, errors.New("page is closed")
	}
	return s.jpeg, nil
}

func TestBrowserStreamPublishesAtLimitedRate(t *testing.T) {
	src := &jpegSource{jpeg: solidJPEG(t, 8, 8)}
	rec := &recorder{}
	s := NewBrowserStream(BrowserConfig{UserID: "7", Source: src, Sink: rec, FPS: 100, Quality: 5, Log: quiet})
	if s.cfg.FPS != 20 || s.cfg.Quality != 30 || s.cfg.DeviceID != "browser" {
		t.Fatalf("limits = %+v", s.cfg)
	}
	s.Start()
	s.Start() // a second start is a no-op
	rec.waitFor(t, 4, 3*time.Second)
	s.Stop()
	n := rec.count()
	time.Sleep(150 * time.Millisecond)
	if rec.count() != n {
		t.Fatal("frames kept coming after Stop")
	}
	for i, f := range rec.frames {
		if f.Platform != "browser" || f.Seq != uint32(i) || f.Flags != 1 || rec.users[i] != "7" || rec.devs[i] != "browser" {
			t.Fatalf("frame %d = %+v (%s/%s)", i, f, rec.users[i], rec.devs[i])
		}
	}
	if src.calls[0] != 30 {
		t.Fatalf("quality = %d", src.calls[0])
	}
}

func TestBrowserStreamSkipsSlowCapturesAndSurvivesErrors(t *testing.T) {
	src := &jpegSource{jpeg: solidJPEG(t, 8, 8), delay: 120 * time.Millisecond}
	rec := &recorder{}
	s := NewBrowserStream(BrowserConfig{UserID: "1", Source: src, Sink: rec, FPS: 20, Log: quiet})
	s.Start()
	time.Sleep(500 * time.Millisecond)
	s.Stop()
	src.mu.Lock()
	calls := len(src.calls)
	src.mu.Unlock()
	if calls > 6 {
		t.Fatalf("%d overlapping captures started in 500ms with 120ms captures", calls)
	}

	failing := &jpegSource{failing: true}
	rec2 := &recorder{}
	s2 := NewBrowserStream(BrowserConfig{UserID: "1", Source: failing, Sink: rec2, FPS: 20, Log: quiet})
	s2.Start()
	time.Sleep(200 * time.Millisecond)
	s2.Stop()
	if rec2.count() != 0 {
		t.Fatal("failed captures were published")
	}
}

type pngSource struct {
	png   []byte
	fails int
	mu    sync.Mutex
	calls int
}

func (p *pngSource) CapturePNG(ctx context.Context) ([]byte, error) {
	p.mu.Lock()
	p.calls++
	failing := p.calls <= p.fails
	p.mu.Unlock()
	if failing {
		return nil, errors.New("device offline")
	}
	select {
	case <-time.After(10 * time.Millisecond):
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	return p.png, nil
}

func TestAndroidFallsBackToScreencapPolling(t *testing.T) {
	rec := &recorder{}
	src := &pngSource{png: solidPNG(t, 40, 30), fails: 1}
	s := NewAndroidStream(AndroidConfig{
		UserID: "3", DeviceID: "emulator-5554", ADBBin: "/nonexistent/adb", Source: src, Sink: rec, FPS: 99, Quality: 80, Log: quiet,
	})
	if s.cfg.FPS != 12 && s.cfg.FPS != 30 {
		t.Fatalf("fps = %d", s.cfg.FPS)
	}
	s.Start()
	rec.waitFor(t, 3, 5*time.Second)
	s.Stop()
	f := rec.frames[0]
	cfg, err := jpeg.DecodeConfig(bytes.NewReader(f.JPEG))
	if err != nil || cfg.Width != 40 || cfg.Height != 30 {
		t.Fatalf("jpeg = %+v, %v", cfg, err)
	}
	if f.Platform != "android" || rec.users[0] != "3" || rec.devs[0] != "emulator-5554" || f.Seq != 0 || rec.frames[2].Seq != 2 {
		t.Fatalf("frame = %+v", f)
	}
}

func TestAndroidH264PipelineThroughFFmpeg(t *testing.T) {
	ffmpeg, err := exec.LookPath("ffmpeg")
	if err != nil {
		t.Skip("ffmpeg not installed")
	}
	// A fake adb whose screenrecord is a real H.264 test pattern.
	dir := t.TempDir()
	adb := filepath.Join(dir, "adb")
	script := "#!/bin/sh\nfor a in \"$@\"; do echo \"$a\" >> " + filepath.Join(dir, "args") + "; done\n" +
		"exec " + ffmpeg + " -loglevel error -re -f lavfi -i testsrc=size=320x240:rate=10 -t 30 -pix_fmt yuv420p -f h264 -\n"
	if err := os.WriteFile(adb, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	rec := &recorder{}
	s := NewAndroidStream(AndroidConfig{
		UserID: "1", DeviceID: "emulator-5556", ADBBin: adb, FFmpeg: ffmpeg, Source: &pngSource{png: solidPNG(t, 4, 4)},
		Sink: rec, FPS: 5, Quality: 75, FirstFrameTimeout: 20 * time.Second, Log: quiet,
	})
	s.Start()
	rec.waitFor(t, 3, 20*time.Second)
	s.Stop()
	cfg, err := jpeg.DecodeConfig(bytes.NewReader(rec.frames[0].JPEG))
	if err != nil || cfg.Width != 320 || cfg.Height != 240 {
		t.Fatalf("jpeg = %+v, %v", cfg, err)
	}
	args, _ := os.ReadFile(filepath.Join(dir, "args"))
	want := "-s\nemulator-5556\nexec-out\nscreenrecord\n--output-format=h264\n--bit-rate=2000000\n--size=1280x720\n-\n"
	if string(args) != want {
		t.Fatalf("adb args:\n%s", args)
	}
}

func TestAndroidFallsBackWhenScreenrecordFailsImmediately(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not installed")
	}
	dir := t.TempDir()
	adb := filepath.Join(dir, "adb")
	if err := os.WriteFile(adb, []byte("#!/bin/sh\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	rec := &recorder{}
	s := NewAndroidStream(AndroidConfig{
		UserID: "1", DeviceID: "emulator-5556", ADBBin: adb, Source: &pngSource{png: solidPNG(t, 8, 8)}, Sink: rec, Log: quiet,
	})
	s.Start()
	rec.waitFor(t, 2, 10*time.Second)
	s.Stop()
}
