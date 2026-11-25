package integrations

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	qrcode "github.com/skip2/go-qrcode"
)

// extraRoutes registers the QR image the connect page shows and the service
// access of a connection.
func (a *API) extraRoutes(mux *http.ServeMux) {
	mux.Handle("GET /api/integrations/qr-image", a.authed(a.qrImage))
	mux.Handle("GET /api/integrations/{provider}/connections/{connectionId}/services", a.authed(a.getServices))
	mux.Handle("PUT /api/integrations/{provider}/connections/{connectionId}/services", a.authed(a.putServices))
}

func sendHTML(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(body))
}

func (a *API) qrImage(w http.ResponseWriter, r *http.Request, _ request) {
	data := strings.TrimSpace(r.URL.Query().Get("data"))
	if data == "" {
		sendHTML(w, http.StatusBadRequest, "Missing QR data.")
		return
	}
	svg, err := qrSVG(data)
	if err != nil {
		sendHTML(w, http.StatusBadRequest, escapeHTML(a.message(err)))
		return
	}
	w.Header().Set("Content-Type", "image/svg+xml; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store, max-age=0")
	_, _ = w.Write([]byte(svg))
}

// qrSVG draws a QR code (error correction M, one module of margin, 320 px) the
// way the Node qrcode package's SVG renderer does: one stroked path of runs.
func qrSVG(data string) (string, error) {
	code, err := qrcode.New(data, qrcode.Medium)
	if err != nil {
		return "", err
	}
	code.DisableBorder = true
	bitmap := code.Bitmap()
	const margin = 1
	size := len(bitmap)
	full := size + 2*margin
	var path strings.Builder
	for row := 0; row < size; row++ {
		moveBy, run, newRow := 0, 0, true
		for col := 0; col < size; col++ {
			if !bitmap[row][col] {
				moveBy++
				continue
			}
			run++
			if col == 0 || !bitmap[row][col-1] {
				if newRow {
					fmt.Fprintf(&path, "M%d %s", col+margin, strconv.FormatFloat(0.5+float64(row+margin), 'f', -1, 64))
				} else {
					fmt.Fprintf(&path, "m%d 0", moveBy)
				}
				moveBy, newRow = 0, false
			}
			if col+1 >= size || !bitmap[row][col+1] {
				fmt.Fprintf(&path, "h%d", run)
				run = 0
			}
		}
	}
	return fmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 %d %d" shape-rendering="crispEdges"><path fill="#ffffff" d="M0 0h%dv%dH0z"/><path stroke="#000000" d="%s"/></svg>`+"\n", full, full, full, full, path.String()), nil
}

func (a *API) getServices(w http.ResponseWriter, r *http.Request, req request) {
	s, ok := a.m.Provider(r.PathValue("provider")).(ServiceAccessProvider)
	if !ok {
		httpx.Error(w, http.StatusNotFound, errNoServices.Error())
		return
	}
	res, err := s.ServiceAccess(r.Context(), req.scope(), r.PathValue("connectionId"))
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) putServices(w http.ResponseWriter, r *http.Request, req request) {
	s, ok := a.m.Provider(r.PathValue("provider")).(ServiceAccessProvider)
	if !ok {
		httpx.Error(w, http.StatusNotFound, errNoServices.Error())
		return
	}
	res, err := s.SetServiceAccess(r.Context(), req.scope(), r.PathValue("connectionId"), req.value("services"))
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}
