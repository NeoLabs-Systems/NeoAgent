package guest

import (
	"errors"
	"fmt"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	crand "crypto/rand"
	"encoding/hex"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

var (
	dimensions = regexp.MustCompile(`dimensions:\s+(\d+x\d+)`)
	keyName    = regexp.MustCompile(`^[A-Za-z0-9_+\-]{1,64}$`)
)

func osEnviron() []string { return os.Environ() }

func (s *Server) displayEnv() []string {
	if os.Getenv("DISPLAY") != "" {
		return nil
	}
	return []string{"DISPLAY=" + defaultDisplay}
}

// desktopCommand runs a helper on the guest's display and returns its trimmed
// stdout, or an error carrying what it printed.
func (s *Server) desktopCommand(timeout time.Duration, name string, args ...string) (string, error) {
	res := s.desktop.run(name, args, timeout, s.displayEnv())
	if res.Err != nil || res.Status != 0 {
		detail := strings.TrimSpace(res.Stderr)
		if detail == "" {
			detail = strings.TrimSpace(res.Stdout)
		}
		if detail == "" && res.Err != nil {
			detail = res.Err.Error()
		}
		if detail == "" {
			detail = fmt.Sprintf("%s failed with exit code %d.", name, res.Status)
		}
		return "", errors.New(detail)
	}
	return strings.TrimSpace(res.Stdout), nil
}

const defaultDesktopTimeout = 15 * time.Second

func (s *Server) runDesktop(name string, args ...string) (string, error) {
	return s.desktopCommand(defaultDesktopTimeout, name, args...)
}

func (s *Server) displayServerAlive() bool {
	res := s.desktop.run("xdpyinfo", []string{"-display", defaultDisplay}, 3*time.Second, []string{"DISPLAY=" + defaultDisplay})
	return res.Err == nil && res.Status == 0
}

func (s *Server) desktopStatus(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) {
		var activeWindow, resolution any
		if out, err := s.runDesktop("xdotool", "getactivewindow", "getwindowname"); err == nil {
			activeWindow = out
		}
		if out, err := s.runDesktop("xdpyinfo"); err == nil {
			if m := dimensions.FindStringSubmatch(out); m != nil {
				resolution = m[1]
			}
		}
		return obj("available", s.displayServerAlive(), "display", defaultDisplay, "activeWindow", activeWindow, "resolution", resolution), nil
	})
}

type point struct{ x, y int }

func desktopPoint(body map[string]any) (point, error) {
	x, y := number(body, "x"), number(body, "y")
	if !finite(x) || !finite(y) {
		return point{}, errors.New("x and y must be finite coordinates.")
	}
	return point{round(x), round(y)}, nil
}

// bodyWork reads the JSON body and runs fn as a Node handle() would.
func bodyWork(w http.ResponseWriter, r *http.Request, fn func(body map[string]any) (any, error)) {
	body, err := readBody(r)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, errorBody(err.Error()))
		return
	}
	work(w, func() (any, error) { return fn(body) })
}

func (s *Server) desktopScreenshot(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) {
		if err := os.MkdirAll(s.fileRoot, 0o777); err != nil {
			return nil, err
		}
		var suffix [4]byte
		if _, err := crand.Read(suffix[:]); err != nil {
			return nil, err
		}
		out := filepath.Join(s.fileRoot, fmt.Sprintf("desktop-%d-%s.png", time.Now().UnixMilli(), hex.EncodeToString(suffix[:])))
		if _, err := s.desktopCommand(30*time.Second, "scrot", "--silent", out); err != nil {
			return nil, err
		}
		return obj("success", true, "path", out), nil
	})
}

func (s *Server) desktopClick(w http.ResponseWriter, r *http.Request) {
	bodyWork(w, r, func(body map[string]any) (any, error) {
		p, err := desktopPoint(body)
		if err != nil {
			return nil, err
		}
		button := number(body, "button")
		if !truthy(body["button"]) {
			button = 1
		}
		if _, err := s.runDesktop("xdotool", "mousemove", "--sync", strconv.Itoa(p.x), strconv.Itoa(p.y), "click", jsInt(button)); err != nil {
			return nil, err
		}
		return obj("success", true, "x", p.x, "y", p.y), nil
	})
}

// jsInt prints a number the way String(Number(x)) does for whole values.
func jsInt(f float64) string {
	if f == math.Trunc(f) && math.Abs(f) < 1e21 {
		return strconv.FormatFloat(f, 'f', -1, 64)
	}
	return strconv.FormatFloat(f, 'g', -1, 64)
}

func (s *Server) desktopMouseMove(w http.ResponseWriter, r *http.Request) {
	bodyWork(w, r, func(body map[string]any) (any, error) {
		p, err := desktopPoint(body)
		if err != nil {
			return nil, err
		}
		if _, err := s.runDesktop("xdotool", "mousemove", "--sync", strconv.Itoa(p.x), strconv.Itoa(p.y)); err != nil {
			return nil, err
		}
		return obj("success", true, "x", p.x, "y", p.y), nil
	})
}

func (s *Server) desktopDrag(w http.ResponseWriter, r *http.Request) {
	bodyWork(w, r, func(body map[string]any) (any, error) {
		sx, sy, ex, ey := number(body, "startX"), number(body, "startY"), number(body, "endX"), number(body, "endY")
		if !finite(sx) || !finite(sy) || !finite(ex) || !finite(ey) {
			return nil, errors.New("Drag coordinates are required.")
		}
		_, err := s.runDesktop("xdotool",
			"mousemove", "--sync", strconv.Itoa(round(sx)), strconv.Itoa(round(sy)),
			"mousedown", "1",
			"mousemove", "--sync", strconv.Itoa(round(ex)), strconv.Itoa(round(ey)),
			"mouseup", "1")
		if err != nil {
			return nil, err
		}
		return obj("success", true), nil
	})
}

func (s *Server) desktopScroll(w http.ResponseWriter, r *http.Request) {
	bodyWork(w, r, func(body map[string]any) (any, error) {
		deltaY := number(body, "deltaY")
		if !truthy(body["deltaY"]) {
			deltaY = 0
		}
		button := "5"
		if deltaY < 0 {
			button = "4"
		}
		count := math.Min(20, math.Max(1, math.Ceil(math.Abs(deltaY)/120)))
		if math.IsNaN(count) {
			count = 1
		}
		if _, err := s.runDesktop("xdotool", "click", "--repeat", jsInt(count), button); err != nil {
			return nil, err
		}
		return obj("success", true, "deltaY", deltaY), nil
	})
}

func (s *Server) desktopTypeText(w http.ResponseWriter, r *http.Request) {
	bodyWork(w, r, func(body map[string]any) (any, error) {
		value := text(body, "text")
		if utf16Len(value) > 10000 {
			return nil, errors.New("Desktop text exceeds the input limit.")
		}
		if _, err := s.desktopCommand(30*time.Second, "xdotool", "type", "--clearmodifiers", "--delay", "1", "--", value); err != nil {
			return nil, err
		}
		return obj("success", true, "length", utf16Len(value)), nil
	})
}

func (s *Server) desktopPressKey(w http.ResponseWriter, r *http.Request) {
	bodyWork(w, r, func(body map[string]any) (any, error) {
		key := strings.TrimSpace(text(body, "key"))
		if !keyName.MatchString(key) {
			return nil, errors.New("Desktop key is invalid.")
		}
		if _, err := s.runDesktop("xdotool", "key", "--clearmodifiers", key); err != nil {
			return nil, err
		}
		return obj("success", true, "key", key), nil
	})
}

// launchDetached starts an application on the desktop that outlives the request.
func launchDetached(name string, args []string, env []string) error {
	cmd := exec.Command(name, args...)
	cmd.Env = append(os.Environ(), env...)
	detach(cmd)
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}

func (s *Server) desktopLaunchApp(w http.ResponseWriter, r *http.Request) {
	bodyWork(w, r, func(body map[string]any) (any, error) {
		application := strings.ToLower(strings.TrimSpace(text(body, "application", "app")))
		profileDir := filepath.Join(s.cfg.DataDir, "browser-profiles", "default")
		guestproto.MarkChromiumSessionClean(profileDir)
		commands := map[string][]string{
			"browser":  append([]string{"chromium"}, guestproto.ChromiumDesktopArgs(profileDir)...),
			"files":    {"pcmanfm", s.ws.root},
			"terminal": {"lxterminal", "--working-directory=" + s.ws.root},
			"editor":   {"mousepad"},
		}
		command, ok := commands[application]
		if !ok {
			return nil, errors.New("Application must be browser, files, terminal, or editor.")
		}
		if err := s.launch(command[0], command[1:], s.displayEnv()); err != nil {
			return nil, err
		}
		return obj("success", true, "application", application), nil
	})
}
