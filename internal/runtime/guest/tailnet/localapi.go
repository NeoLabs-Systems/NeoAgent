package tailnet

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"time"
)

const (
	maxStatusBytes = 4 << 20
	maxBodyBytes   = 512 << 10
)

// localRequest calls tailscaled's LocalAPI on its private Unix socket.
func localRequest(ctx context.Context, socketPath, method, endpoint string, body any) (map[string]any, error) {
	out, _, err := localRequestRaw(ctx, socketPath, method, endpoint, body)
	return out, err
}

// localRequestRaw also returns the answer as sent, for callers that need the
// order of its keys.
func localRequestRaw(ctx context.Context, socketPath, method, endpoint string, body any) (map[string]any, []byte, error) {
	var payload io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return nil, nil, err
		}
		payload = bytes.NewReader(raw)
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, method, "http://local-tailscaled.sock/localapi/v0/"+endpoint, payload)
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Transport: &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			return (&net.Dialer{}).DialContext(ctx, "unix", socketPath)
		},
		DisableKeepAlives: true,
	}}
	resp, err := client.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxStatusBytes+1))
	if err != nil {
		return nil, nil, err
	}
	if len(raw) > maxStatusBytes {
		return nil, nil, errors.New("Tailscale status exceeds limit.")
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, nil, errors.New("Tailscale local API operation failed.")
	}
	if len(raw) == 0 {
		return nil, nil, nil
	}
	var out map[string]any
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, nil, errors.New("Invalid Tailscale status response.")
	}
	return out, raw, nil
}

// dialPeer opens a TCP stream to a tailnet peer through tailscaled's dial
// API, so no proxy listener exists in the VM. LocalAPI's Dial-Self fallback
// (dial a non-tailnet address with ordinary networking) is never honoured.
func dialPeer(ctx context.Context, socketPath, address string, port int) (net.Conn, error) {
	conn, err := (&net.Dialer{}).DialContext(ctx, "unix", socketPath)
	if err != nil {
		return nil, err
	}
	stop := context.AfterFunc(ctx, func() { conn.Close() })
	defer stop()
	request := "POST /localapi/v0/dial HTTP/1.1\r\nHost: local-tailscaled.sock\r\nConnection: upgrade\r\nUpgrade: ts-dial\r\n" +
		"Dial-Host: " + address + "\r\nDial-Port: " + strconv.Itoa(port) + "\r\nDial-Network: tcp\r\nContent-Length: 0\r\n\r\n"
	if _, err := io.WriteString(conn, request); err != nil {
		conn.Close()
		return nil, err
	}
	reader := bufio.NewReader(conn)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		conn.Close()
		return nil, err
	}
	if resp.StatusCode != http.StatusSwitchingProtocols {
		conn.Close()
		if resp.Header.Get("Upgrade") == "" {
			return nil, errors.New("Tailscale did not provide a peer stream.")
		}
		return nil, errors.New("Peer dial refused.")
	}
	return &bufferedConn{Conn: conn, r: reader}, nil
}

type bufferedConn struct {
	net.Conn
	r *bufio.Reader
}

func (b *bufferedConn) Read(p []byte) (int, error) { return b.r.Read(p) }

var blockedHeaders = map[string]bool{"host": true, "connection": true, "content-length": true, "transfer-encoding": true, "upgrade": true, "proxy-authorization": true, "proxy-connection": true, "trailer": true, "te": true}

// peerTarget finds the peer and its tailnet address.
func peerTarget(status map[string]any, peerID string) (map[string]any, string, error) {
	peers, _ := status["Peer"].(map[string]any)
	for _, raw := range peers {
		peer, _ := raw.(map[string]any)
		if id, _ := peer["ID"].(string); id != peerID {
			continue
		}
		ips, _ := peer["TailscaleIPs"].([]any)
		for _, ip := range ips {
			s, _ := ip.(string)
			addr, err := netip.ParseAddr(s)
			if err != nil {
				continue
			}
			if addr.Is4() {
				b := addr.As4()
				if b[0] == 100 && b[1] >= 64 && b[1] < 128 {
					return peer, s, nil
				}
			} else if strings.HasPrefix(strings.ToLower(s), "fd7a:115c:a1e0:") {
				return peer, s, nil
			}
		}
		break
	}
	return nil, "", errors.New("The selected peer is no longer available.")
}

// pingResult is a reachable peer service.
type pingResult struct {
	Reachable bool  `json:"reachable"`
	LatencyMs int64 `json:"latencyMs"`
}

// httpResult is a peer service's HTTP answer.
type httpResult struct {
	Status    int            `json:"status"`
	Headers   map[string]any `json:"headers"`
	Body      string         `json:"body"`
	Truncated bool           `json:"truncated"`
}

// requestPeer pings a granted peer service or calls one granted HTTP
// operation on it over the peer stream.
func requestPeer(ctx context.Context, socketPath string, status map[string]any, op operation) (any, error) {
	peer, address, err := peerTarget(status, op.target.peerID)
	if err != nil {
		return nil, err
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	started := time.Now()
	conn, err := dialPeer(ctx, socketPath, address, op.target.port)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { conn.Close() })
	defer stop()
	if op.action == "ping" {
		return pingResult{Reachable: true, LatencyMs: time.Since(started).Milliseconds()}, nil
	}
	dnsName, _ := peer["DNSName"].(string)
	host := strings.TrimSuffix(dnsName, ".")
	if host == "" {
		host = address
	}
	for name := range op.target.headers {
		if blockedHeaders[strings.ToLower(name)] {
			return nil, errors.New("Unsupported request header.")
		}
	}
	var stream net.Conn = conn
	if op.target.scheme == "https" {
		// ServerName is the peer's MagicDNS name (or its IP, verified against
		// the certificate's IP addresses).
		cfg := &tls.Config{MinVersion: tls.VersionTLS12, ServerName: host}
		tlsConn := tls.Client(conn, cfg)
		if err := tlsConn.HandshakeContext(ctx); err != nil {
			return nil, errors.New("Peer request failed.")
		}
		stream = tlsConn
	}
	var body io.Reader
	if op.target.body != "" {
		body = strings.NewReader(op.target.body)
	}
	scheme := op.target.scheme
	req, err := http.NewRequestWithContext(ctx, op.target.method, scheme+"://"+net.JoinHostPort(host, strconv.Itoa(op.target.port))+op.target.path, body)
	if err != nil {
		return nil, errors.New("Peer request failed.")
	}
	for k, v := range op.target.headers {
		req.Header.Set(k, v)
	}
	used := false
	transport := &http.Transport{
		DisableKeepAlives:      true,
		MaxResponseHeaderBytes: 32768,
		DialContext: func(context.Context, string, string) (net.Conn, error) {
			if used {
				return nil, errors.New("peer stream already used")
			}
			used = true
			return stream, nil
		},
		DialTLSContext: func(context.Context, string, string) (net.Conn, error) {
			if used {
				return nil, errors.New("peer stream already used")
			}
			used = true
			return stream, nil
		},
	}
	defer transport.CloseIdleConnections()
	resp, err := (&http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}).Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, errors.New("Peer request failed.")
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes+1))
	truncated := len(raw) > maxBodyBytes
	if truncated {
		raw = raw[:maxBodyBytes]
	}
	headers := map[string]any{}
	for name, values := range resp.Header {
		lower := strings.ToLower(name)
		if lower == "set-cookie" || lower == "www-authenticate" || lower == "proxy-authenticate" {
			continue
		}
		headers[lower] = strings.Join(values, ", ")
	}
	return httpResult{Status: resp.StatusCode, Headers: headers, Body: strings.ToValidUTF8(string(raw), "�"), Truncated: truncated}, nil
}
