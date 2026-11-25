package integrations

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"syscall"
	"time"
)

// NewSelfHostedClient reaches servers a person configured themselves. Like the
// Node server it allows the local network and the machine itself (a Nextcloud
// next to NeoAgent is common), but never link-local addresses such as the
// cloud metadata service, multicast or unspecified addresses. Redirects are
// returned, not followed: callers decide whether a hop may be taken.
func NewSelfHostedClient() *http.Client {
	dialer := &net.Dialer{
		Timeout: 10 * time.Second,
		Control: func(_, address string, _ syscall.RawConn) error {
			host, _, err := net.SplitHostPort(address)
			if err != nil {
				return err
			}
			addr, err := netip.ParseAddr(host)
			if err != nil {
				return err
			}
			return checkSelfHostedAddr(addr)
		},
	}
	return &http.Client{
		Timeout: 60 * time.Second,
		Transport: &http.Transport{
			Proxy:               nil,
			TLSHandshakeTimeout: 10 * time.Second,
			DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
				return dialer.DialContext(ctx, network, address)
			},
		},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
}

func checkSelfHostedAddr(addr netip.Addr) error {
	addr = addr.Unmap()
	if !addr.IsValid() || addr.IsLinkLocalUnicast() || addr.IsLinkLocalMulticast() ||
		addr.IsInterfaceLocalMulticast() || addr.IsMulticast() || addr.IsUnspecified() {
		return fmt.Errorf("integrations: destination %s is not allowed", addr)
	}
	return nil
}
