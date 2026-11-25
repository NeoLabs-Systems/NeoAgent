package tailscale

import (
	"encoding/json"
	"errors"
	"math"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

var allowedMethods = map[string]bool{"GET": true, "HEAD": true, "OPTIONS": true, "POST": true, "PUT": true, "PATCH": true, "DELETE": true}

// Service is one granted HTTP operation on a peer.
type Service struct {
	PeerID  string   `json:"peerId"`
	Port    int      `json:"port"`
	Scheme  string   `json:"scheme"`
	Path    string   `json:"path"`
	Methods []string `json:"methods"`
}

var badPath = regexp.MustCompile(`[\s\\#]`)

// str is the String of a truthy value, else "".
func str(v any) string {
	if !integrations.Truthy(v) {
		return ""
	}
	return integrations.Str(v)
}

// NormalizeServices validates the grants a person configured.
func NormalizeServices(value any) ([]Service, error) {
	list, ok := value.([]any)
	if !ok || len(list) > 64 {
		return nil, errors.New("Provide at most 64 service operations.")
	}
	out := make([]Service, 0, len(list))
	for _, raw := range list {
		entry, _ := raw.(map[string]any)
		peerID := strings.TrimSpace(str(entry["peerId"]))
		port, portOK := integrations.JSNumber(entry["port"])
		if peerID == "" || len(peerID) > 256 || !portOK || port != math.Trunc(port) || port < 1 || port > 65535 {
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
		out = append(out, Service{PeerID: peerID, Port: int(port), Scheme: scheme, Path: path, Methods: unique})
	}
	return out, nil
}

// servicesFor reads a connection's grants from its metadata.
func servicesFor(conn integrations.Connection) ([]Service, error) {
	var meta map[string]any
	_ = json.Unmarshal([]byte(conn.MetadataJSON), &meta)
	services := meta["services"]
	if !integrations.Truthy(services) {
		services = []any{}
	}
	return NormalizeServices(services)
}

// operation is a request the grants allow.
type operation struct {
	grants []Service
}

// authorizeRequest checks a ping or request against the grants; the guest
// checks it again.
func authorizeRequest(conn integrations.Connection, action string, args map[string]any) (operation, error) {
	port, _ := integrations.JSNumber(args["port"])
	peerID := str(args["peer_id"])
	method := "GET"
	if v := str(args["method"]); v != "" {
		method = strings.ToUpper(v)
	}
	scheme := "https"
	if v := str(args["scheme"]); v != "" {
		scheme = v
	}
	path := "/"
	if v := str(args["path"]); v != "" {
		path = v
	}
	grants, err := servicesFor(conn)
	if err != nil {
		return operation{}, err
	}
	allowed := false
	for _, g := range grants {
		if g.PeerID != peerID || float64(g.Port) != port {
			continue
		}
		if action == "ping" {
			allowed = true
			break
		}
		if g.Scheme == scheme && g.Path == path && contains(g.Methods, method) {
			allowed = true
			break
		}
	}
	if !allowed {
		return operation{}, errors.New("This service operation has not been granted. Configure service access in the Tailscale integration.")
	}
	body := ""
	if args["body"] != nil {
		body = integrations.Str(args["body"])
	}
	if len(body) > 512*1024 {
		return operation{}, errors.New("Request body exceeds limit.")
	}
	headers := args["headers"]
	if !integrations.Truthy(headers) {
		headers = map[string]any{}
	}
	h, ok := headers.(map[string]any)
	if !ok {
		return operation{}, errors.New("Invalid request headers.")
	}
	for k, v := range h {
		value, isString := v.(string)
		if !isString || strings.ContainsAny(k+value, "\r\n") {
			return operation{}, errors.New("Invalid request headers.")
		}
	}
	if raw, _ := json.Marshal(h); len(raw) > 16384 {
		return operation{}, errors.New("Invalid request headers.")
	}
	return operation{grants: grants}, nil
}

func contains(list []string, v string) bool {
	for _, s := range list {
		if s == v {
			return true
		}
	}
	return false
}
