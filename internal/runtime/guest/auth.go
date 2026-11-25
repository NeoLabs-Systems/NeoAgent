package guest

import (
	"crypto/subtle"
	"net/http"
	"strings"
)

// safeEqual compares secrets in constant time (for equal lengths). An empty
// value never matches.
func safeEqual(left, right string) bool {
	if left == "" || right == "" {
		return false
	}
	return len(left) == len(right) && subtle.ConstantTimeCompare([]byte(left), []byte(right)) == 1
}

// auth requires the guest's bearer token.
func (s *Server) auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := strings.TrimSpace(r.Header.Get("Authorization"))
		provided := ""
		if strings.HasPrefix(header, "Bearer ") {
			provided = strings.TrimSpace(header[len("Bearer "):])
		}
		if !safeEqual(provided, s.cfg.Token) {
			writeJSON(w, http.StatusUnauthorized, errorBody("Unauthorized."))
			return
		}
		next.ServeHTTP(w, r)
	})
}
