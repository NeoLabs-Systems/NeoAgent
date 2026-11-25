package guest

import (
	"errors"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

var (
	proxyTarget = regexp.MustCompile(`(?s)^/(\d{1,5})(/.*)?$`)
	hopByHop    = map[string]bool{
		"connection": true, "keep-alive": true, "proxy-authenticate": true, "proxy-authorization": true,
		"te": true, "trailer": true, "transfer-encoding": true, "upgrade": true, "authorization": true,
	}
)

func withoutHopByHop(in http.Header) http.Header {
	out := http.Header{}
	for name, values := range in {
		if !hopByHop[strings.ToLower(name)] {
			out[name] = values
		}
	}
	return out
}

// proxyTransport keeps the request exactly as the page sent it: no added
// compression, no redirects followed.
var proxyTransport = &http.Transport{DisableCompression: true, ResponseHeaderTimeout: 0, IdleConnTimeout: 30 * time.Second}

// proxy relays /proxy/<port>/<path> to a web page the agent started on a port
// inside this computer. The server decides what is shared and filters
// headers; this only relays. Bodies stream both ways.
func (s *Server) proxy(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.EscapedPath(), "/proxy")
	if r.URL.RawQuery != "" {
		rest += "?" + r.URL.RawQuery
	}
	if rest == "" {
		rest = "/"
	}
	match := proxyTarget.FindStringSubmatch(rest)
	port := 0
	if match != nil {
		port, _ = strconv.Atoi(match[1])
	}
	if match == nil || port < 1 || port > 65535 || port == s.cfg.Port {
		writeJSON(w, http.StatusBadRequest, errorBody("Invalid port."))
		return
	}
	target := match[2]
	if target == "" {
		target = "/"
	}
	out, err := http.NewRequestWithContext(r.Context(), r.Method, "http://localhost:"+match[1]+target, r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, errorBody(err.Error()))
		return
	}
	out.Header = withoutHopByHop(r.Header)
	out.Host = "localhost:" + match[1]
	out.ContentLength = r.ContentLength
	if r.ContentLength == 0 {
		out.Body = http.NoBody
	}
	resp, err := proxyTransport.RoundTrip(out)
	if err != nil {
		unreachable := errors.Is(err, syscall.ECONNREFUSED) || errors.Is(err, syscall.ECONNRESET) || errors.Is(err, syscall.EHOSTUNREACH)
		kind := "failed"
		if unreachable {
			kind = "unreachable"
		}
		w.Header().Set("x-neoagent-proxy", kind)
		writeJSON(w, http.StatusBadGateway, errorBody(err.Error()))
		return
	}
	defer resp.Body.Close()
	for name, values := range withoutHopByHop(resp.Header) {
		w.Header()[name] = values
	}
	w.WriteHeader(resp.StatusCode)
	flusher, _ := w.(http.Flusher)
	buf := make([]byte, 32*1024)
	for {
		n, err := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := w.Write(buf[:n]); werr != nil {
				return
			}
			if flusher != nil {
				flusher.Flush()
			}
		}
		if err != nil {
			if err != io.EOF {
				panic(http.ErrAbortHandler)
			}
			return
		}
	}
}
