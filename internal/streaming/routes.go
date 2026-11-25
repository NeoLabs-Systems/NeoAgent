package streaming

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// StartInfo is what a started stream reports to the hub.
type StartInfo struct {
	FPS, Quality int
}

// Hub is the realtime stream hub as /api/stream uses it. The socket.io layer
// implements it (StreamHub in Node).
type Hub interface {
	FrameSink
	// MarkStarted registers an active stream; stop is called with the reason
	// when the hub ends it (no subscribers, socket gone, restart, shutdown).
	MarkStarted(userID, deviceID, platform string, info StartInfo, stop func(reason string))
	StopStream(ctx context.Context, userID, platform, deviceID, reason string) bool
	Status(userID, platform, deviceID string) any
	ListStatus(userID string) any
}

// DesktopStreamer starts and stops the screen stream of a desktop companion
// (desktop.Provider).
type DesktopStreamer interface {
	// StartStream returns the device id the companion actually streams from.
	StartStream(ctx context.Context, deviceID string, fps, quality int, displayID string) (resolvedDeviceID string, err error)
	StopStream(ctx context.Context, deviceID string) error
}

// AndroidDevice is the emulator of an account (android.Controller).
type AndroidDevice interface {
	PNGSource
	LiveAdbSerial() string
	ADBBin() string
}

// Devices resolves the capture source of an account for each platform; the
// lead wires the runtime manager.
type Devices interface {
	Desktop(ctx context.Context, userID int64) (DesktopStreamer, error)
	Android(ctx context.Context, userID int64) (AndroidDevice, error)
	Browser(ctx context.Context, userID int64) (JPEGSource, error)
}

// APIConfig wires the /api/stream routes.
type APIConfig struct {
	Hub     Hub
	Devices Devices
	// FirstFrameTimeout is the Android H.264 start-up wait
	// (NEOAGENT_ANDROID_STREAM_FIRST_FRAME_TIMEOUT_MS); zero means 6 s.
	FirstFrameTimeout time.Duration
	Log               *slog.Logger
}

// API serves /api/stream.
type API struct {
	cfg  APIConfig
	home string
}

// NewAPI builds the routes.
func NewAPI(cfg APIConfig) *API {
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	home, _ := os.UserHomeDir()
	return &API{cfg: cfg, home: home}
}

// Routes registers /api/stream/{start,stop,status}.
func (a *API) Routes(mux *http.ServeMux) {
	mux.Handle("POST /api/stream/start", a.guard(a.start))
	mux.Handle("POST /api/stream/stop", a.guard(a.stop))
	mux.Handle("GET /api/stream/status", a.guard(a.status))
}

// statusError carries an HTTP status for a refused request.
type statusError struct {
	status int
	msg    string
}

func (e *statusError) Error() string { return e.msg }

func (a *API) guard(next func(http.ResponseWriter, *http.Request, int64) error) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sess := sessionx.FromContext(r.Context())
		var userID int64
		var ok bool
		if sess != nil {
			userID, ok = sess.Int64("userId")
		}
		if !ok || userID == 0 {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		if err := next(w, r, userID); err != nil {
			status := http.StatusInternalServerError
			var se *statusError
			if errors.As(err, &se) {
				status = se.status
			}
			msg := "An unexpected error occurred"
			if err.Error() != "" {
				msg = publicerr.Sanitize(err.Error(), a.home, "")
			}
			httpx.Error(w, status, msg)
		}
	})
}

type body map[string]any

func readBody(r *http.Request) body {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return body{}
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, 1<<20))
	if err != nil {
		return body{}
	}
	raw = bytes.TrimSpace(raw)
	var b body
	if len(raw) == 0 || raw[0] != '{' || json.Unmarshal(raw, &b) != nil || b == nil {
		return body{}
	}
	return b
}

// text is String(value || ”).trim().
func (b body) text(key string) string {
	switch v := b[key].(type) {
	case string:
		return strings.TrimSpace(v)
	case float64:
		if v != 0 {
			return strings.TrimSpace(strconv.FormatFloat(v, 'f', -1, 64))
		}
	case bool:
		if v {
			return "true"
		}
	}
	return ""
}

// boundedInt is Node's boundedInt: a non-numeric value takes the fallback.
func boundedInt(b body, key string, fallback, lo, hi int) int {
	v, present := b[key]
	if !present {
		return fallback
	}
	var f float64
	switch x := v.(type) {
	case nil:
		f = 0
	case float64:
		f = x
	case bool:
		if x {
			f = 1
		}
	case string:
		t := strings.TrimSpace(x)
		if t == "" {
			f = 0
			break
		}
		parsed, err := strconv.ParseFloat(t, 64)
		if err != nil {
			return fallback
		}
		f = parsed
	default:
		return fallback
	}
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return fallback
	}
	return min(hi, max(lo, int(math.Floor(f))))
}

func normalizePlatform(v string) (string, error) {
	p := strings.ToLower(strings.TrimSpace(v))
	if p == "desktop" || p == "android" || p == "browser" {
		return p, nil
	}
	return "", &statusError{http.StatusBadRequest, "platform must be desktop, android, or browser."}
}

func normalizeDeviceID(platform, v string) (string, error) {
	if id := strings.TrimSpace(v); id != "" {
		return id, nil
	}
	if platform == "browser" {
		return "browser", nil
	}
	return "", &statusError{http.StatusBadRequest, "deviceId is required."}
}

func userKey(userID int64) string { return strconv.FormatInt(userID, 10) }

func (a *API) start(w http.ResponseWriter, r *http.Request, userID int64) error {
	ctx, b := r.Context(), readBody(r)
	platform, err := normalizePlatform(b.text("platform"))
	if err != nil {
		return err
	}
	android := platform == "android"
	fps := boundedInt(b, "fps", pick(android, 12, 15), 1, pick(android, 30, 20))
	quality := boundedInt(b, "quality", pick(android, 75, 80), 30, 95)
	user := userKey(userID)
	rawDevice := b.text("deviceId")

	switch platform {
	case "desktop":
		deviceID, err := normalizeDeviceID(platform, rawDevice)
		if err != nil {
			return err
		}
		provider, err := a.cfg.Devices.Desktop(ctx, userID)
		if err != nil {
			return err
		}
		a.cfg.Hub.StopStream(ctx, user, platform, deviceID, "restart")
		displayID := ""
		if truthy(b["displayId"]) {
			displayID = b.text("displayId")
		}
		resolved, err := provider.StartStream(ctx, deviceID, fps, quality, displayID)
		if err != nil {
			return err
		}
		if resolved == "" {
			resolved = deviceID
		}
		a.cfg.Hub.MarkStarted(user, resolved, platform, StartInfo{FPS: fps, Quality: quality}, func(string) {
			sctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			if err := provider.StopStream(sctx, resolved); err != nil {
				a.cfg.Log.Error("[StreamRoute] failed to stop desktop stream", "user", user, "device", resolved, "error", err)
			}
		})
		return a.started(w, platform, resolved, fps, quality)
	case "android":
		device, err := a.cfg.Devices.Android(ctx, userID)
		if err != nil {
			return err
		}
		serial := strings.TrimSpace(device.LiveAdbSerial())
		if serial == "" {
			return &statusError{http.StatusConflict, "No emulator is running for this account."}
		}
		if rawDevice != "" && rawDevice != serial {
			return &statusError{http.StatusBadRequest, "Android deviceId does not match the active emulator serial."}
		}
		a.cfg.Hub.StopStream(ctx, user, platform, serial, "restart")
		stream := NewAndroidStream(AndroidConfig{
			UserID: user, DeviceID: serial, ADBBin: device.ADBBin(), Source: device, Sink: a.cfg.Hub,
			FPS: fps, Quality: quality, FirstFrameTimeout: a.cfg.FirstFrameTimeout, Log: a.cfg.Log,
		})
		stream.Start()
		a.cfg.Hub.MarkStarted(user, serial, platform, StartInfo{FPS: fps, Quality: quality}, func(string) { stream.Stop() })
		return a.started(w, platform, serial, fps, quality)
	}
	source, err := a.cfg.Devices.Browser(ctx, userID)
	if err != nil {
		return err
	}
	a.cfg.Hub.StopStream(ctx, user, platform, "browser", "restart")
	stream := NewBrowserStream(BrowserConfig{
		UserID: user, DeviceID: "browser", Source: source, Sink: a.cfg.Hub, FPS: fps, Quality: quality, Log: a.cfg.Log,
	})
	stream.Start()
	a.cfg.Hub.MarkStarted(user, "browser", platform, StartInfo{FPS: fps, Quality: quality}, func(string) { stream.Stop() })
	return a.started(w, platform, "browser", fps, quality)
}

func pick(cond bool, yes, no int) int {
	if cond {
		return yes
	}
	return no
}

func truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case float64:
		return x != 0
	case string:
		return x != ""
	}
	return true
}

type startedBody struct {
	OK       bool   `json:"ok"`
	Platform string `json:"platform"`
	DeviceID string `json:"deviceId"`
	FPS      int    `json:"fps"`
	Quality  int    `json:"quality"`
}

func (a *API) started(w http.ResponseWriter, platform, deviceID string, fps, quality int) error {
	httpx.WriteJSON(w, http.StatusOK, startedBody{OK: true, Platform: platform, DeviceID: deviceID, FPS: fps, Quality: quality})
	return nil
}

type stoppedBody struct {
	OK       bool   `json:"ok"`
	Stopped  bool   `json:"stopped"`
	Platform string `json:"platform"`
	DeviceID string `json:"deviceId"`
}

func (a *API) stop(w http.ResponseWriter, r *http.Request, userID int64) error {
	ctx, b := r.Context(), readBody(r)
	platform, err := normalizePlatform(b.text("platform"))
	if err != nil {
		return err
	}
	deviceID := b.text("deviceId")
	if deviceID == "" {
		switch platform {
		case "browser":
			deviceID = "browser"
		case "android":
			device, err := a.cfg.Devices.Android(ctx, userID)
			if err != nil {
				return err
			}
			deviceID = strings.TrimSpace(device.LiveAdbSerial())
		}
	}
	if deviceID == "" {
		return &statusError{http.StatusBadRequest, "deviceId is required."}
	}
	stopped := a.cfg.Hub.StopStream(ctx, userKey(userID), platform, deviceID, "api_stop")
	httpx.WriteJSON(w, http.StatusOK, stoppedBody{OK: true, Stopped: stopped, Platform: platform, DeviceID: deviceID})
	return nil
}

type listBody struct {
	Streams  any     `json:"streams"`
	Platform *string `json:"platform"`
}

func (a *API) status(w http.ResponseWriter, r *http.Request, userID int64) error {
	q := r.URL.Query()
	var platform *string
	if raw := q.Get("platform"); raw != "" {
		p, err := normalizePlatform(raw)
		if err != nil {
			return err
		}
		platform = &p
	}
	if raw := q.Get("deviceId"); raw != "" {
		p := "desktop"
		if platform != nil {
			p = *platform
		}
		deviceID, err := normalizeDeviceID(p, raw)
		if err != nil {
			return err
		}
		httpx.WriteJSON(w, http.StatusOK, a.cfg.Hub.Status(userKey(userID), p, deviceID))
		return nil
	}
	httpx.WriteJSON(w, http.StatusOK, listBody{Streams: a.cfg.Hub.ListStatus(userKey(userID)), Platform: platform})
	return nil
}
