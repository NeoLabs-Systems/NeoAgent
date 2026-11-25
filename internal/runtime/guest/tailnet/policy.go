package tailnet

import (
	"encoding/json"
	"errors"
	"math"
	"regexp"
	"strconv"
	"strings"
)

// The guest enforces the operation policy again, on top of the server: a
// compromised or buggy server still cannot reach an ungranted service. The
// rules are the server's (internal/integrations/tailscale/policy.go).

var allowedMethods = map[string]bool{"GET": true, "HEAD": true, "OPTIONS": true, "POST": true, "PUT": true, "PATCH": true, "DELETE": true}

var badPath = regexp.MustCompile(`[\s\\#]`)

type service struct {
	peerID, scheme, path string
	port                 int
	methods              []string
}

func truthy(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case bool:
		return t
	case float64:
		return t != 0 && !math.IsNaN(t)
	case string:
		return t != ""
	}
	return true
}

// text is String(value) for a JSON value.
func text(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case string:
		return t
	case bool:
		return strconv.FormatBool(t)
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case []any:
		parts := make([]string, len(t))
		for i, e := range t {
			if e != nil {
				parts[i] = text(e)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

func str(v any) string {
	if !truthy(v) {
		return ""
	}
	return text(v)
}

// number is Number(value) for a JSON value.
func number(v any) float64 {
	switch t := v.(type) {
	case nil:
		return 0
	case float64:
		return t
	case bool:
		if t {
			return 1
		}
		return 0
	case string:
		s := strings.TrimSpace(t)
		if s == "" {
			return 0
		}
		if f, err := strconv.ParseFloat(s, 64); err == nil {
			return f
		}
	}
	return math.NaN()
}

func normalizeServices(value any) ([]service, error) {
	list, ok := value.([]any)
	if !ok || len(list) > 64 {
		return nil, errors.New("Provide at most 64 service operations.")
	}
	out := make([]service, 0, len(list))
	for _, raw := range list {
		entry, _ := raw.(map[string]any)
		peerID := strings.TrimSpace(str(entry["peerId"]))
		port := number(entry["port"])
		if peerID == "" || len(peerID) > 256 || math.IsNaN(port) || port != math.Trunc(port) || port < 1 || port > 65535 {
			return nil, errors.New("Select a peer and a port from 1 to 65535.")
		}
		scheme := str(entry["scheme"])
		if scheme == "" {
			scheme = "https"
		}
		if scheme != "http" && scheme != "https" {
			return nil, errors.New("Service scheme must be http or https.")
		}
		path := str(entry["path"])
		if !strings.HasPrefix(path, "/") || strings.HasPrefix(path, "//") || badPath.MatchString(path) || len([]rune(path)) > 2048 {
			return nil, errors.New("Provide an exact service path, including any query string.")
		}
		methods, ok := entry["methods"].([]any)
		if !ok || len(methods) == 0 {
			return nil, errors.New("Select valid HTTP methods for each service operation.")
		}
		var unique []string
		seen := map[string]bool{}
		for _, m := range methods {
			name, isString := m.(string)
			if !isString || !allowedMethods[name] {
				return nil, errors.New("Select valid HTTP methods for each service operation.")
			}
			if !seen[name] {
				seen[name] = true
				unique = append(unique, name)
			}
		}
		out = append(out, service{peerID: peerID, port: int(port), scheme: scheme, path: path, methods: unique})
	}
	return out, nil
}

// target is an authorized peer request.
type target struct {
	peerID, method, scheme, path, body string
	port                               int
	headers                            map[string]string
}

func authorize(action string, args map[string]any, grants any) (target, error) {
	port := number(args["port"])
	t := target{
		peerID: text(orDefault(args["peer_id"], "")),
		method: strings.ToUpper(text(orDefault(args["method"], "GET"))),
		scheme: text(orDefault(args["scheme"], "https")),
		path:   text(orDefault(args["path"], "/")),
	}
	if grants == nil {
		grants = []any{}
	}
	services, err := normalizeServices(grants)
	if err != nil {
		return target{}, err
	}
	allowed := false
	for _, g := range services {
		if g.peerID == t.peerID && float64(g.port) == port &&
			(action == "ping" || (g.scheme == t.scheme && g.path == t.path && contains(g.methods, t.method))) {
			allowed = true
			break
		}
	}
	if !allowed {
		return target{}, errors.New("This service operation has not been granted. Configure service access in the Tailscale integration.")
	}
	t.port = int(port)
	if args["body"] != nil {
		t.body = text(args["body"])
	}
	if len(t.body) > 512*1024 {
		return target{}, errors.New("Request body exceeds limit.")
	}
	headers := args["headers"]
	if !truthy(headers) {
		headers = map[string]any{}
	}
	obj, ok := headers.(map[string]any)
	if !ok {
		return target{}, errors.New("Invalid request headers.")
	}
	t.headers = map[string]string{}
	for k, v := range obj {
		s, isString := v.(string)
		if !isString || strings.ContainsAny(k+s, "\r\n") {
			return target{}, errors.New("Invalid request headers.")
		}
		t.headers[k] = s
	}
	if raw, _ := json.Marshal(obj); len(raw) > 16384 {
		return target{}, errors.New("Invalid request headers.")
	}
	return t, nil
}

// orDefault is `value || fallback` before String().
func orDefault(v, fallback any) any {
	if !truthy(v) {
		return fallback
	}
	return v
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}
