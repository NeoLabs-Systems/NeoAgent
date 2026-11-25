package sockets

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// The controllers behind the stream routes belong to the runtime domains; the
// routes only need these slices of them.

// DesktopStart is what a desktop companion is asked to start streaming.
type DesktopStart struct {
	DeviceID  string
	FPS       int
	Quality   int
	DisplayID any // the request's displayId, nil when absent
}

// DesktopProvider is a user's desktop companion provider.
type DesktopProvider interface {
	// StartStream returns the device id the companion resolved, "" to keep the requested one.
	StartStream(ctx context.Context, o DesktopStart) (deviceID string, err error)
	StopStream(ctx context.Context, deviceID string) error
}

// AndroidController is a user's Android emulator controller.
type AndroidController interface {
	LiveADBSerial() string // "" when no emulator runs
	SDKDir() string        // Android SDK directory, "" to find adb on PATH
	CapturePNG(ctx context.Context, deviceID string) ([]byte, error)
}

// BrowserController is a user's browser runtime.
type BrowserController interface {
	ScreenshotJPEG(ctx context.Context, quality int) ([]byte, error)
}

// Controllers resolve a user's controllers. Each may be nil when the
// runtime is not available; the routes then answer like Node does.
type Controllers struct {
	Desktop interface {
		ForUser(ctx context.Context, userID int64) (DesktopProvider, error)
	}
	Android interface {
		ForUser(ctx context.Context, userID int64) (AndroidController, error)
	}
	Browser interface {
		ForUser(ctx context.Context, userID int64) (BrowserController, error)
	}
	// AndroidFirstFrameTimeout is how long the H.264 pipeline may take to
	// produce its first frame before streaming falls back to screenshots.
	AndroidFirstFrameTimeout time.Duration
}

// statusError is a failure that carries the HTTP status of its answer.
type statusError struct {
	status int
	msg    string
}

func (e *statusError) Error() string { return e.msg }

func badRequest(msg string) error { return &statusError{http.StatusBadRequest, msg} }

func (s *Server) streamRoutes(mux *http.ServeMux) {
	mux.Handle("POST /api/stream/start", s.authed(s.streamStart))
	mux.Handle("POST /api/stream/stop", s.authed(s.streamStop))
	mux.Handle("GET /api/stream/status", s.authed(s.streamStatus))
}

type streamHandler func(w http.ResponseWriter, r *http.Request, userID int64)

// authed is requireAuth: 401 JSON unless the session belongs to an account.
func (s *Server) authed(fn streamHandler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sess := sessionx.FromContext(r.Context())
		if sess == nil {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		userID, ok := sess.Int64("userId")
		if !ok || userID == 0 {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		fn(w, r, userID)
	})
}

// sendError answers `res.status(err.status || 500).json({error: sanitizeError(err)})`.
func (s *Server) sendError(w http.ResponseWriter, err error) {
	status := http.StatusInternalServerError
	var coded interface{ HTTPStatus() int }
	var plain *statusError
	switch {
	case errors.As(err, &plain):
		status = plain.status
	case errors.As(err, &coded) && coded.HTTPStatus() > 0:
		status = coded.HTTPStatus()
	}
	httpx.WriteJSON(w, status, map[string]any{"error": publicerr.Sanitize(err.Error(), s.cfg.Home, s.cfg.Root)})
}

const streamBodyLimit = 10 << 20

// streamBody is req.body: the JSON object of a JSON request, else empty.
func streamBody(r *http.Request) (map[string]any, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return map[string]any{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, streamBodyLimit))
	if err != nil {
		return nil, badRequest("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 {
		return map[string]any{}, nil
	}
	var body map[string]any
	if err := json.Unmarshal(raw, &body); err != nil {
		if raw[0] == '[' {
			return map[string]any{}, nil
		}
		return nil, badRequest("Invalid JSON body")
	}
	if body == nil {
		body = map[string]any{}
	}
	return body, nil
}

// routePlatform is the route's normalizePlatform: no default, three platforms.
func routePlatform(value string) (string, error) {
	p := strings.ToLower(strings.TrimFunc(value, jsSpace))
	switch p {
	case "desktop", "android", "browser":
		return p, nil
	}
	return "", badRequest("platform must be desktop, android, or browser.")
}

func routeDeviceID(platform, value string) (string, error) {
	if id := strings.TrimFunc(value, jsSpace); id != "" {
		return id, nil
	}
	if platform == "browser" {
		return "browser", nil
	}
	return "", badRequest("deviceId is required.")
}

func (s *Server) android(ctx context.Context, userID int64) (AndroidController, error) {
	if s.cfg.Controllers.Android == nil {
		return nil, errors.New("Android controller is unavailable.")
	}
	return s.cfg.Controllers.Android.ForUser(ctx, userID)
}

func (s *Server) liveSerial(c AndroidController) string {
	return strings.TrimFunc(c.LiveADBSerial(), jsSpace)
}

func (s *Server) streamStart(w http.ResponseWriter, r *http.Request, userID int64) {
	ctx := r.Context()
	body, err := streamBody(r)
	var platform string
	if err == nil {
		platform, err = routePlatform(truthyString(body["platform"]))
	}
	if err != nil {
		s.sendError(w, err)
		return
	}
	rawDeviceID := strings.TrimFunc(truthyString(body["deviceId"]), jsSpace)
	isAndroid := platform == "android"

	var deviceID string
	var androidCtl AndroidController
	switch {
	case platform == "browser":
		deviceID = "browser"
	case isAndroid:
		if androidCtl, err = s.android(ctx, userID); err != nil {
			break
		}
		serial := s.liveSerial(androidCtl)
		switch {
		case serial == "":
			err = &statusError{http.StatusConflict, "No emulator is running for this account."}
		case rawDeviceID != "" && rawDeviceID != serial:
			err = badRequest("Android deviceId does not match the active emulator serial.")
		default:
			deviceID = serial
		}
	case rawDeviceID != "":
		deviceID = rawDeviceID
	default:
		_, err = routeDeviceID(platform, "")
	}
	if err != nil {
		s.sendError(w, err)
		return
	}

	fpsDefault, fpsMax, qualityDefault := 15, 20, 80
	if isAndroid {
		fpsDefault, fpsMax, qualityDefault = 12, 30, 75
	}
	fps := boundedInt(body, "fps", fpsDefault, 1, fpsMax)
	quality := boundedInt(body, "quality", qualityDefault, 30, 95)
	s.streams.StopStream(userID, platform, deviceID, "restart")

	switch platform {
	case "desktop":
		err = s.startDesktop(ctx, w, userID, deviceID, fps, quality, body["displayId"])
	case "android":
		stream := newAndroidStream(s, userID, deviceID, androidCtl, fps, quality)
		stream.start()
		s.streams.MarkStarted(userID, deviceID, platform, fps, quality, func(string) error { stream.stop(); return nil })
		s.writeStarted(w, platform, deviceID, fps, quality)
	default:
		err = s.startBrowser(ctx, w, userID, deviceID, fps, quality)
	}
	if err != nil {
		s.sendError(w, err)
	}
}

// startResponse and stopResponse are the answers of the start and stop routes.
type startResponse struct {
	OK       bool   `json:"ok"`
	Platform string `json:"platform"`
	DeviceID string `json:"deviceId"`
	FPS      int    `json:"fps"`
	Quality  int    `json:"quality"`
}

type stopResponse struct {
	OK       bool   `json:"ok"`
	Stopped  bool   `json:"stopped"`
	Platform string `json:"platform"`
	DeviceID string `json:"deviceId"`
}

type listResponse struct {
	Streams  []StreamStatus `json:"streams"`
	Platform *string        `json:"platform"`
}

func (s *Server) writeStarted(w http.ResponseWriter, platform, deviceID string, fps, quality int) {
	httpx.WriteJSON(w, http.StatusOK, startResponse{true, platform, deviceID, fps, quality})
}

func (s *Server) startDesktop(ctx context.Context, w http.ResponseWriter, userID int64, deviceID string, fps, quality int, displayID any) error {
	if s.cfg.Controllers.Desktop == nil {
		return errors.New("Desktop provider is unavailable.")
	}
	provider, err := s.cfg.Controllers.Desktop.ForUser(ctx, userID)
	if err != nil {
		return err
	}
	if displayID != nil && truthyString(displayID) == "" {
		displayID = nil // `req.body.displayId || null`
	}
	resolved, err := provider.StartStream(ctx, DesktopStart{DeviceID: deviceID, FPS: fps, Quality: quality, DisplayID: displayID})
	if err != nil {
		return err
	}
	if resolved == "" {
		resolved = deviceID
	}
	s.streams.MarkStarted(userID, resolved, "desktop", fps, quality, func(string) error {
		if err := provider.StopStream(context.Background(), resolved); err != nil {
			s.log.Error("[StreamRoute] failed to stop desktop stream", "userId", userID, "deviceId", resolved, "error", err)
		}
		return nil
	})
	s.writeStarted(w, "desktop", resolved, fps, quality)
	return nil
}

func (s *Server) startBrowser(ctx context.Context, w http.ResponseWriter, userID int64, deviceID string, fps, quality int) error {
	if s.cfg.Controllers.Browser == nil {
		return errors.New("Browser controller is unavailable.")
	}
	controller, err := s.cfg.Controllers.Browser.ForUser(ctx, userID)
	if err != nil {
		return err
	}
	stream := newBrowserStream(s, userID, deviceID, controller, fps, quality)
	stream.start()
	s.streams.MarkStarted(userID, deviceID, "browser", fps, quality, func(string) error { stream.stop(); return nil })
	s.writeStarted(w, "browser", deviceID, fps, quality)
	return nil
}

func (s *Server) streamStop(w http.ResponseWriter, r *http.Request, userID int64) {
	body, err := streamBody(r)
	var platform, deviceID string
	if err == nil {
		platform, err = routePlatform(truthyString(body["platform"]))
	}
	if err == nil {
		deviceID, err = s.stopDeviceID(r.Context(), platform, userID, strings.TrimFunc(truthyString(body["deviceId"]), jsSpace))
	}
	if err != nil {
		s.sendError(w, err)
		return
	}
	stopped := s.streams.StopStream(userID, platform, deviceID, "api_stop")
	httpx.WriteJSON(w, http.StatusOK, stopResponse{true, stopped, platform, deviceID})
}

func (s *Server) stopDeviceID(ctx context.Context, platform string, userID int64, raw string) (string, error) {
	if raw != "" {
		return raw, nil
	}
	if platform == "browser" {
		return "browser", nil
	}
	if platform == "android" {
		controller, err := s.android(ctx, userID)
		if err != nil {
			return "", err
		}
		if serial := s.liveSerial(controller); serial != "" {
			return serial, nil
		}
	}
	return "", badRequest("deviceId is required.")
}

func (s *Server) streamStatus(w http.ResponseWriter, r *http.Request, userID int64) {
	q := r.URL.Query()
	platform := ""
	var err error
	if raw := strings.Join(q["platform"], ","); raw != "" {
		platform, err = routePlatform(raw)
	}
	var deviceID string
	if err == nil && strings.Join(q["deviceId"], ",") != "" {
		fallback := platform
		if fallback == "" {
			fallback = "desktop"
		}
		deviceID, err = routeDeviceID(fallback, strings.Join(q["deviceId"], ","))
	}
	if err != nil {
		s.sendError(w, err)
		return
	}
	if deviceID != "" {
		if platform == "" {
			platform = "desktop"
		}
		httpx.WriteJSON(w, http.StatusOK, s.streams.Status(userID, platform, deviceID))
		return
	}
	list := listResponse{Streams: s.streams.ListStatus(userID)}
	if platform != "" {
		list.Platform = &platform
	}
	httpx.WriteJSON(w, http.StatusOK, list)
}
