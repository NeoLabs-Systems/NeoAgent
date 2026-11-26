package wiring

import (
	"context"
	"os"
	"strconv"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/android"
	"github.com/NeoLabs-Systems/neoagent/internal/desktop"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
)

// desktopCommandTimeout bounds one stream command to a desktop companion.
const desktopCommandTimeout = 30 * time.Second

// streamControllers gives /api/stream each user's desktop companion, Android
// emulator and browser.
func streamControllers(c *computer, androidHost *android.Host) sockets.Controllers {
	return sockets.Controllers{
		Desktop: streamDesktops{c.Devices},
		Android: streamAndroids{androidHost},
		Browser: streamBrowsers{c.Manager},

		AndroidFirstFrameTimeout: sockets.FirstFrameTimeout(os.Getenv),
	}
}

type streamDesktops struct{ devices *desktop.Registry }

func (s streamDesktops) ForUser(_ context.Context, userID int64) (sockets.DesktopProvider, error) {
	return streamDesktop{devices: s.devices, userID: userID}, nil
}

type streamDesktop struct {
	devices *desktop.Registry
	userID  int64
}

func (s streamDesktop) StartStream(ctx context.Context, o sockets.DesktopStart) (string, error) {
	device, err := s.devices.ResolveDevice(ctx, s.userID, o.DeviceID)
	if err != nil {
		return "", err
	}
	display := o.DisplayID
	if display == nil && device.ActiveDisplayID != nil {
		display = *device.ActiveDisplayID
	}
	_, err = s.devices.Dispatch(ctx, s.userID, device.DeviceID, desktop.CmdStreamStart,
		map[string]any{"fps": o.FPS, "quality": o.Quality, "displayId": display}, desktopCommandTimeout)
	return device.DeviceID, err
}

func (s streamDesktop) StopStream(ctx context.Context, deviceID string) error {
	_, err := s.devices.Dispatch(ctx, s.userID, deviceID, desktop.CmdStreamStop, map[string]any{}, desktopCommandTimeout)
	return err
}

type streamAndroids struct{ host *android.Host }

func (s streamAndroids) ForUser(_ context.Context, userID int64) (sockets.AndroidController, error) {
	c, err := s.host.Controller(strconv.FormatInt(userID, 10))
	if err != nil {
		return nil, err
	}
	return streamAndroid{c}, nil
}

type streamAndroid struct{ c *android.Controller }

func (s streamAndroid) LiveADBSerial() string { return s.c.LiveAdbSerial() }
func (s streamAndroid) SDKDir() string        { return s.c.SDKDir() }

// CapturePNG captures the account's emulator; there is only the one device.
func (s streamAndroid) CapturePNG(ctx context.Context, _ string) ([]byte, error) {
	return s.c.CapturePNG(ctx)
}

type streamBrowsers struct{ m *runtime.Manager }

func (s streamBrowsers) ForUser(ctx context.Context, userID int64) (sockets.BrowserController, error) {
	b, err := s.m.Browser(ctx, strconv.FormatInt(userID, 10), "")
	if err != nil {
		return nil, err
	}
	return streamBrowser{b}, nil
}

type streamBrowser struct{ b runtime.Browser }

func (s streamBrowser) ScreenshotJPEG(ctx context.Context, quality int) ([]byte, error) {
	return s.b.ScreenshotJPEG(ctx, quality, nil)
}
