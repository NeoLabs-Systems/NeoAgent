// Package reqx is what the scheduling and device-data routes share: the signed-in
// session, Express's JSON body rules, the agent a request names and the error
// envelope. It keeps their routes about the routes.
package reqx

import (
	"crypto/rand"
	"encoding/hex"
	"io"
	"mime"
	"net/http"
	"os"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// BodyLimit is the size Express's JSON parser accepted ("10mb").
const BodyLimit = 10 << 20

// UserID returns the signed-in account of a request.
func UserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

// Guard answers 401 `{"error":"Unauthorized"}` unless the session belongs to an
// account, like Node's requireAuth on an API path.
func Guard(userID func(*http.Request) (int64, bool), next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := userID(r); !ok {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// Body is a request's parsed JSON body. Value is nil when the request carried
// none (Express leaves req.body undefined then), else an *jsv.Object or a list.
type Body struct {
	Raw   []byte
	Value any
}

// Object is the body as an object; a missing body or a list reads as nil.
func (b Body) Object() *jsv.Object {
	o, _ := b.Value.(*jsv.Object)
	return o
}

// ObjectOrEmpty is `req.body || {}` for a body whose members are read by name:
// a list has no members, so it reads as an empty object.
func (b Body) ObjectOrEmpty() *jsv.Object {
	if o := b.Object(); o != nil {
		return o
	}
	return jsv.NewObject()
}

// BodyError is a body Express's JSON parser refuses.
type BodyError struct {
	Status  int
	Message string
}

func (e *BodyError) Error() string { return e.Message }

func isJSON(contentType string) bool {
	mt, _, err := mime.ParseMediaType(contentType)
	return err == nil && (mt == "application/json" || strings.HasSuffix(mt, "+json"))
}

// ReadBody parses the JSON body as express.json() does: only a JSON content
// type is read, only an object or a list is accepted, and the raw text is kept
// (webhook signatures cover it).
func ReadBody(r *http.Request) (Body, error) {
	if !isJSON(r.Header.Get("Content-Type")) || r.Body == nil || r.ContentLength == 0 {
		return Body{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, BodyLimit))
	if err != nil {
		return Body{}, &BodyError{http.StatusRequestEntityTooLarge, "request entity too large"}
	}
	if len(raw) == 0 {
		return Body{}, nil
	}
	trimmed := strings.TrimLeft(string(raw), " \t\r\n")
	if trimmed == "" || (trimmed[0] != '{' && trimmed[0] != '[') {
		return Body{}, &BodyError{http.StatusBadRequest, "Invalid JSON body"}
	}
	value, err := jsv.Decode(raw)
	if err != nil {
		return Body{}, &BodyError{http.StatusBadRequest, "Invalid JSON body"}
	}
	return Body{Raw: raw, Value: value}, nil
}

// AgentCandidate is getAgentIdFromRequest: the first of body.agentId,
// body.agent_id, the same inside body.options, the agentId and agent_id query
// parameters and the X-Agent-Id header that is set.
func AgentCandidate(r *http.Request, body *jsv.Object) string {
	options, _ := body.Val("options").(*jsv.Object)
	for _, v := range []any{body.Val("agentId"), body.Val("agent_id"), options.Val("agentId"), options.Val("agent_id")} {
		if jsv.Truthy(v) {
			return jsv.String(v)
		}
	}
	query := r.URL.Query()
	for _, key := range []string{"agentId", "agent_id"} {
		if s := strings.Join(query[key], ","); s != "" {
			return s
		}
	}
	return r.Header.Get("X-Agent-Id")
}

// Message is sanitizeError: an error's text with home-directory and absolute
// paths hidden.
func Message(err error) string {
	if err == nil {
		return "An unexpected error occurred"
	}
	return publicerr.Sanitize(err.Error(), os.Getenv("HOME"), "")
}

// Fail answers status with `{"error": <sanitized message>}`.
func Fail(w http.ResponseWriter, status int, err error) {
	httpx.Error(w, status, Message(err))
}

// RefuseBody answers a body that could not be read.
func RefuseBody(w http.ResponseWriter, err error) {
	if be, ok := err.(*BodyError); ok {
		httpx.Error(w, be.Status, be.Message)
		return
	}
	httpx.Error(w, http.StatusBadRequest, err.Error())
}

// NewUUID returns a random version 4 UUID.
func NewUUID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b[:])
	return h[:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:], nil
}
