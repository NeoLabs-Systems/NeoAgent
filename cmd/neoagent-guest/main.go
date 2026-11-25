// Command neoagent-guest is the agent inside a NeoAgent computer. It is one
// static binary that replaces the Node guest agent in QEMU images and the
// Docker image.
package main

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guest"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guest/browser"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guest/tailnet"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

func guestToken() string {
	if raw := strings.TrimSpace(os.Getenv(guestproto.EnvToken)); raw != "" {
		return raw
	}
	encoded := strings.TrimSpace(os.Getenv(guestproto.EnvTokenB64))
	if encoded == "" {
		return ""
	}
	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(decoded))
}

func envInt(name string, fallback int64) int64 {
	if n, err := strconv.ParseInt(strings.TrimSpace(os.Getenv(name)), 10, 64); err == nil && n > 0 {
		return n
	}
	return fallback
}

func run() error {
	token := guestToken()
	if token == "" {
		return errors.New("[GuestAgent] NEOAGENT_VM_GUEST_TOKEN or NEOAGENT_VM_GUEST_TOKEN_B64 is required.")
	}
	port := int(envInt(guestproto.EnvPort, guestproto.DefaultPort))
	server, err := guest.New(guest.Config{
		Token:            token,
		Port:             port,
		Profile:          os.Getenv(guestproto.EnvProfile),
		MinFreeDiskBytes: envInt("NEOAGENT_GUEST_MIN_FREE_DISK_BYTES", 0),
		MaxImportBytes:   envInt("NEOAGENT_GUEST_MAX_WORKSPACE_IMPORT_BYTES", 0),
	})
	if err != nil {
		return err
	}
	var browserController *browser.Controller
	if profile := guestproto.NormalizeProfile(os.Getenv(guestproto.EnvProfile)); profile == guestproto.ProfileBrowser || profile == guestproto.ProfileBrowserCLI {
		if browserController, err = browser.New(browser.Config{DataDir: server.DataDir()}); err != nil {
			return err
		}
		defer browserController.Shutdown()
	}
	browser.Mount(server.Handle, browserController)
	tailscale := tailnet.New(tailnet.Config{})
	defer tailscale.Shutdown()
	tailnet.Mount(server.Handle, tailscale)
	httpServer := &http.Server{Addr: net.JoinHostPort("0.0.0.0", strconv.Itoa(port)), Handler: server.Handler(), ReadHeaderTimeout: 10 * time.Second}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	failed := make(chan error, 1)
	go func() { failed <- httpServer.ListenAndServe() }()
	fmt.Printf("NeoAgent guest agent listening on http://%s\n", httpServer.Addr)
	select {
	case err := <-failed:
		return err
	case <-ctx.Done():
	}
	server.Shutdown()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return httpServer.Shutdown(shutdownCtx)
}

func main() {
	if err := run(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
