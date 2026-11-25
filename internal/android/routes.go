package android

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	apkUploadLimit = 512 << 20
	bodyLimit      = 1 << 20
)

// Service is one account's Android device as the routes use it. *Controller is
// the host implementation; a provider that talks to a guest agent implements
// the same methods.
type Service interface {
	GetStatus(ctx context.Context) (Status, error)
	RequestStartEmulator(ctx context.Context, opts StartOptions) (any, error)
	StopEmulator(ctx context.Context) (StopResult, error)
	ListDevices(ctx context.Context) ([]Device, error)
	Screenshot(ctx context.Context) (ShotResult, error)
	Observe(ctx context.Context, includeNodes bool) (Observation, error)
	DumpUI(ctx context.Context, includeNodes bool) (UIDump, error)
	ListApps(ctx context.Context, includeSystem bool) (AppsResult, error)
	OpenApp(ctx context.Context, p Params) (ShotResult, error)
	OpenIntent(ctx context.Context, p Params) (ShotResult, error)
	Tap(ctx context.Context, p Params) (TapResult, error)
	LongPress(ctx context.Context, p Params) (LongPressResult, error)
	Type(ctx context.Context, p Params) (TypeResult, error)
	Swipe(ctx context.Context, p Params) (SwipeResult, error)
	PressKey(ctx context.Context, key string) (SuccessResult, error)
	WaitFor(ctx context.Context, p Params) (WaitResult, error)
	InstallAPK(ctx context.Context, apkPath string) (InstallResult, error)
	Shell(ctx context.Context, req ShellRequest) (any, error)
}

// Provider returns the Android device of an account. The lead wires the
// runtime manager's getAndroidProviderForUser; Host is the default.
type Provider interface {
	AndroidFor(ctx context.Context, userID int64) (Service, error)
}

// AndroidFor serves the controller of an account.
func (h *Host) AndroidFor(_ context.Context, userID int64) (Service, error) {
	return h.Controller(strconv.FormatInt(userID, 10))
}

// APIConfig wires the /api/android routes.
type APIConfig struct {
	Provider Provider
	// ValidateIntentURL pre-checks /open-intent URIs; Host.ValidateIntentURL.
	ValidateIntentURL func(ctx context.Context, raw string) (allowed bool, reason string, err error)
	// UploadDir receives uploaded packages while they install
	// (<data>/uploads/android-apks).
	UploadDir string
	Log       *slog.Logger
}

// API serves /api/android.
type API struct {
	cfg  APIConfig
	home string
}

// NewAPI prepares the upload directory.
func NewAPI(cfg APIConfig) (*API, error) {
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	if err := os.MkdirAll(cfg.UploadDir, 0o700); err != nil {
		return nil, err
	}
	home, _ := os.UserHomeDir()
	return &API{cfg: cfg, home: home}, nil
}

type action func(ctx context.Context, svc Service, r *http.Request, body Params) (any, error)

// Routes registers the routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	handle := func(pattern string, fn action) {
		mux.Handle(pattern, a.guard(func(w http.ResponseWriter, r *http.Request, userID int64) {
			svc, err := a.cfg.Provider.AndroidFor(r.Context(), userID)
			if err != nil {
				a.fail(w, err)
				return
			}
			body, err := readParams(r)
			if err != nil {
				httpx.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			res, err := fn(r.Context(), svc, r, body)
			if err != nil {
				a.fail(w, err)
				return
			}
			httpx.WriteJSON(w, http.StatusOK, res)
		}))
	}
	handle("GET /api/android/status", func(ctx context.Context, s Service, _ *http.Request, _ Params) (any, error) {
		return s.GetStatus(ctx)
	})
	handle("POST /api/android/start", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		opts := StartOptions{}
		if headless, ok := b["headless"].(bool); ok {
			opts.Headless = &headless
		}
		return s.RequestStartEmulator(ctx, opts)
	})
	handle("POST /api/android/stop", func(ctx context.Context, s Service, _ *http.Request, _ Params) (any, error) {
		return s.StopEmulator(ctx)
	})
	handle("GET /api/android/devices", func(ctx context.Context, s Service, _ *http.Request, _ Params) (any, error) {
		devices, err := s.ListDevices(ctx)
		return map[string]any{"devices": devices}, err
	})
	handle("POST /api/android/screenshot", func(ctx context.Context, s Service, _ *http.Request, _ Params) (any, error) {
		return s.Screenshot(ctx)
	})
	handle("POST /api/android/observe", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.Observe(ctx, b["includeNodes"] != false)
	})
	handle("POST /api/android/ui-dump", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.DumpUI(ctx, b["includeNodes"] != false)
	})
	handle("GET /api/android/apps", func(ctx context.Context, s Service, r *http.Request, _ Params) (any, error) {
		return s.ListApps(ctx, r.URL.Query().Get("includeSystem") == "true")
	})
	handle("POST /api/android/open-app", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.OpenApp(ctx, b)
	})
	mux.Handle("POST /api/android/open-intent", a.guard(a.openIntent))
	handle("POST /api/android/tap", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.Tap(ctx, b)
	})
	handle("POST /api/android/long-press", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.LongPress(ctx, b)
	})
	handle("POST /api/android/type", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.Type(ctx, b)
	})
	handle("POST /api/android/swipe", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.Swipe(ctx, b)
	})
	handle("POST /api/android/press-key", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.PressKey(ctx, b.text("key"))
	})
	handle("POST /api/android/wait-for", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		return s.WaitFor(ctx, b)
	})
	handle("POST /api/android/shell", func(ctx context.Context, s Service, _ *http.Request, b Params) (any, error) {
		req := ShellRequest{Command: b.text("command"), Screenshot: b["screenshot"] == true}
		if ms, ok := b.number("timeoutMs"); ok && b["timeoutMs"] != nil {
			req.Timeout = time.Duration(ms) * time.Millisecond
		}
		return s.Shell(ctx, req)
	})
	mux.Handle("POST /api/android/install-apk", a.guard(a.installAPK))
}

// guard answers 401 unless a signed-in account made the request.
func (a *API) guard(next func(http.ResponseWriter, *http.Request, int64)) http.Handler {
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
		next(w, r, userID)
	})
}

func (a *API) fail(w http.ResponseWriter, err error) {
	msg := "An unexpected error occurred"
	if err != nil && err.Error() != "" {
		msg = publicerr.Sanitize(err.Error(), a.home, "")
	}
	httpx.Error(w, http.StatusInternalServerError, msg)
}

// readParams decodes a JSON object body; anything else reads as an empty body.
func readParams(r *http.Request) (Params, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return Params{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, errors.New("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] == '[' {
		return Params{}, nil
	}
	var p Params
	if err := json.Unmarshal(raw, &p); err != nil || p == nil {
		return nil, errors.New("Invalid JSON body")
	}
	return p, nil
}

// openIntent vets the URI first, answering 403 with the reason, then opens it.
func (a *API) openIntent(w http.ResponseWriter, r *http.Request, userID int64) {
	body, err := readParams(r)
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, err.Error())
		return
	}
	for _, key := range []string{"data", "url", "uri"} {
		if !truthy(body[key]) {
			continue
		}
		if uri, ok := body[key].(string); ok {
			allowed, reason, err := a.cfg.ValidateIntentURL(r.Context(), uri)
			if err != nil {
				a.fail(w, err)
				return
			}
			if !allowed {
				httpx.Error(w, http.StatusForbidden, reason)
				return
			}
		}
		break
	}
	svc, err := a.cfg.Provider.AndroidFor(r.Context(), userID)
	if err != nil {
		a.fail(w, err)
		return
	}
	res, err := svc.OpenIntent(r.Context(), body)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

var unsafeFilenameChars = regexp.MustCompile(`[^a-zA-Z0-9._-]+`)

// uploadName builds the stored name the way the multer storage did:
// <millis>-<random>-<stem><ext>.
func uploadName(original string) string {
	ext := strings.ToLower(filepath.Ext(original))
	stem := strings.TrimSuffix(filepath.Base(original), filepath.Ext(original))
	stem = strings.Trim(unsafeFilenameChars.ReplaceAllString(stem, "-"), "-")
	if len(stem) > 64 {
		stem = stem[:64]
	}
	if stem == "" {
		stem = "upload"
	}
	if ext == "" {
		ext = ".apk"
	}
	var b [6]byte
	_, _ = rand.Read(b[:])
	return fmt.Sprintf("%d-%s-%s%s", time.Now().UnixMilli(), hex.EncodeToString(b[:]), stem, ext)
}

type uploaded struct {
	path, name string
	size       int64
}

var errTooLarge = errors.New("Android app upload is too large. Limit is 512MB.")

// receiveAPK streams the "apk" file field of a multipart request to disk.
func (a *API) receiveAPK(r *http.Request) (*uploaded, error) {
	if !strings.HasPrefix(strings.ToLower(r.Header.Get("Content-Type")), "multipart/form-data") {
		return nil, nil
	}
	reader, err := r.MultipartReader()
	if err != nil {
		return nil, err
	}
	var file *uploaded
	for {
		part, err := reader.NextPart()
		if err == io.EOF {
			return file, nil
		}
		if err != nil {
			return nil, err
		}
		if part.FileName() == "" {
			_, _ = io.Copy(io.Discard, io.LimitReader(part, 1<<20))
			continue
		}
		if part.FormName() != "apk" || file != nil {
			if file != nil {
				_ = os.Remove(file.path)
			}
			return nil, errors.New("Unexpected field")
		}
		if file, err = a.saveUpload(part); err != nil {
			return nil, err
		}
	}
}

func (a *API) saveUpload(part *multipart.Part) (*uploaded, error) {
	ext := strings.ToLower(filepath.Ext(part.FileName()))
	if ext != ".apk" && ext != ".apks" {
		return nil, errors.New("Only .apk or .apks files can be installed.")
	}
	path := filepath.Join(a.cfg.UploadDir, uploadName(part.FileName()))
	dst, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, err
	}
	n, err := io.Copy(dst, io.LimitReader(part, apkUploadLimit+1))
	if cerr := dst.Close(); err == nil {
		err = cerr
	}
	if err == nil && n > apkUploadLimit {
		err = errTooLarge
	}
	if err != nil {
		_ = os.Remove(path)
		return nil, err
	}
	return &uploaded{path: path, name: part.FileName(), size: n}, nil
}

// installResponse is the install-apk body: the install result plus what was
// uploaded.
type installResponse struct {
	InstallResult
	Filename string `json:"filename"`
	Size     int64  `json:"size"`
}

func (a *API) installAPK(w http.ResponseWriter, r *http.Request, userID int64) {
	file, err := a.receiveAPK(r)
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, publicerr.Sanitize(err.Error(), a.home, ""))
		return
	}
	if file == nil {
		httpx.Error(w, http.StatusBadRequest, "No APK or APK bundle was uploaded.")
		return
	}
	defer os.Remove(file.path)
	svc, err := a.cfg.Provider.AndroidFor(r.Context(), userID)
	if err != nil {
		a.fail(w, err)
		return
	}
	res, err := svc.InstallAPK(r.Context(), file.path)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, installResponse{InstallResult: res, Filename: file.name, Size: file.size})
}
