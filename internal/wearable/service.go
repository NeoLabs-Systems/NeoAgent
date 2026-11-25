package wearable

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

// WebsocketURL is the socket address for a server's base URL: its scheme turned
// into ws or wss, the gateway path, and no query or fragment.
func WebsocketURL(baseURL string) (string, error) {
	u, err := url.Parse(baseURL)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return "", errors.New("Invalid URL")
	}
	if u.Scheme == "https" {
		u.Scheme = "wss"
	} else {
		u.Scheme = "ws"
	}
	u.Path, u.RawPath, u.RawQuery, u.Fragment = WSPath, "", "", ""
	return u.String(), nil
}

// VersionInfo is the server's version as the bootstrap reports it.
type VersionInfo struct {
	// Version is the human readable version, which a firmware needs at least.
	Version string
	// Info is the whole version object the bootstrap embeds (getVersionInfo).
	Info any
}

// Geo finds where an address is.
type Geo interface {
	// TimezoneForIP is the IANA time zone of a public address, or "".
	TimezoneForIP(ip string) string
}

// ServiceConfig wires the wearable service.
type ServiceConfig struct {
	// Voice runs the live calls the gateway opens.
	Voice Voice
	Geo   Geo
	// Version reports the running server version.
	Version func() VersionInfo
	// PublicURL is PUBLIC_URL; without it the request's own origin is used.
	PublicURL string
	Firmware  *FirmwareResolver
	Env       FirmwareEnv
	// TrustProxy honors X-Forwarded-For and X-Forwarded-Proto.
	TrustProxy bool
	Now        func() time.Time
}

// ConnectionChange is reported whenever a wearable connects or disconnects
// (the wearable_connection_changed trigger).
type ConnectionChange struct {
	UserID      int64
	DeviceID    string
	DeviceLabel string
	// Transition is "connected" or "disconnected".
	Transition string
	OccurredAt string
}

// Hello is what a wearable says about itself when it connects.
type Hello struct {
	Platform        string
	FirmwareVersion string
	DeviceLabel     string
}

// Connection is a connected wearable.
type Connection struct {
	DeviceID      string
	ConnectedAt   string
	LastSeenAt    string
	RemoteAddress string
	UserAgent     string
	Hello         Hello
	// owner identifies the socket that registered the connection.
	owner any
}

// Service is the registry of connected wearables and the builder of what they
// ask the server for: bootstrap, firmware manifest and local time.
type Service struct {
	cfg ServiceConfig

	mu          sync.Mutex
	byUser      map[int64][]*Connection
	subscribers []func(ConnectionChange)
}

// NewService builds the service.
func NewService(cfg ServiceConfig) *Service {
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	return &Service{cfg: cfg, byUser: map[int64][]*Connection{}}
}

// OnConnectionChanged registers a listener for connect and disconnect events.
func (s *Service) OnConnectionChanged(fn func(ConnectionChange)) {
	s.mu.Lock()
	s.subscribers = append(s.subscribers, fn)
	s.mu.Unlock()
}

func (s *Service) emit(userID int64, c *Connection, transition string) {
	s.mu.Lock()
	subscribers := append([]func(ConnectionChange){}, s.subscribers...)
	s.mu.Unlock()
	change := ConnectionChange{
		UserID: userID, DeviceID: c.DeviceID, DeviceLabel: c.Hello.DeviceLabel,
		Transition: transition, OccurredAt: isoTime(s.cfg.Now()),
	}
	for _, fn := range subscribers {
		fn(change)
	}
}

// RegisterParams describe a connecting wearable.
type RegisterParams struct {
	UserID int64
	// Owner identifies the socket; only it may unregister the connection.
	Owner         any
	RemoteAddress string
	// SocketAddress is the peer's address, the last resort for a device id.
	SocketAddress string
	UserAgent     string
	// Hello is the device object of the wearable:hello message.
	Hello map[string]any
}

// Register records a wearable. A device that reconnects registers its new
// socket before the old one closes, and replaces it.
func (s *Service) Register(p RegisterParams) *Connection {
	device, _ := p.Hello["device"].(map[string]any)
	deviceID := ""
	for _, candidate := range []string{
		trimmedString(device["deviceId"], 160),
		trimmedString(device["macAddress"], 64),
		trimmedString(p.SocketAddress, 120),
	} {
		if candidate != "" {
			deviceID = candidate
			break
		}
	}
	if deviceID == "" {
		deviceID = "wearable-" + strconv.FormatInt(s.cfg.Now().UnixMilli(), 10)
	}
	platform := trimmedString(device["platform"], 40)
	if platform == "" {
		platform = "esp32s3"
	}
	now := isoTime(s.cfg.Now())
	c := &Connection{
		DeviceID: deviceID, ConnectedAt: now, LastSeenAt: now,
		RemoteAddress: trimmedString(p.RemoteAddress, 120), UserAgent: trimmedString(p.UserAgent, 500),
		Hello: Hello{
			Platform:        platform,
			FirmwareVersion: trimmedString(device["firmwareVersion"], 120),
			DeviceLabel:     trimmedString(device["deviceLabel"], 120),
		},
		owner: p.Owner,
	}
	s.mu.Lock()
	list := s.byUser[p.UserID]
	replaced := false
	for i, existing := range list {
		if existing.DeviceID == deviceID {
			list[i] = c
			replaced = true
			break
		}
	}
	if !replaced {
		list = append(list, c)
	}
	s.byUser[p.UserID] = list
	s.mu.Unlock()
	s.emit(p.UserID, c, "connected")
	return c
}

// Touch records that a connected wearable was heard from.
func (s *Service) Touch(userID int64, deviceID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.byUser[userID] {
		if c.DeviceID == strings.TrimSpace(deviceID) {
			c.LastSeenAt = isoTime(s.cfg.Now())
		}
	}
}

// Unregister removes a connection. A device that reconnects registers its new
// socket before the old one closes, so only the socket that still owns the
// entry removes it.
func (s *Service) Unregister(userID int64, deviceID string, owner any) {
	s.mu.Lock()
	var removed *Connection
	list := s.byUser[userID]
	for i, c := range list {
		if c.DeviceID == strings.TrimSpace(deviceID) && c.owner == owner {
			removed = c
			list = append(list[:i:i], list[i+1:]...)
			break
		}
	}
	if removed != nil {
		if len(list) == 0 {
			delete(s.byUser, userID)
		} else {
			s.byUser[userID] = list
		}
	}
	s.mu.Unlock()
	if removed != nil {
		s.emit(userID, removed, "disconnected")
	}
}

// Connections lists the wearables an account has connected, oldest first.
func (s *Service) Connections(userID int64) []Connection {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Connection, 0, len(s.byUser[userID]))
	for _, c := range s.byUser[userID] {
		out = append(out, *c)
	}
	return out
}

// connectionJSON is how a connection is listed.
func connectionJSON(c Connection) fields {
	return fields{
		{"deviceId", c.DeviceID}, {"connectedAt", c.ConnectedAt}, {"lastSeenAt", c.LastSeenAt},
		{"remoteAddress", nullIfEmpty(c.RemoteAddress)}, {"userAgent", nullIfEmpty(c.UserAgent)},
		{"hello", fields{
			{"platform", c.Hello.Platform}, {"firmwareVersion", nullIfEmpty(c.Hello.FirmwareVersion)},
			{"deviceLabel", nullIfEmpty(c.Hello.DeviceLabel)},
		}},
	}
}

// baseURL is the URL clients should use to reach this server: PUBLIC_URL when
// configured, otherwise the origin the request came in on.
func (s *Service) baseURL(r *http.Request) string {
	if s.cfg.PublicURL != "" {
		return strings.TrimRight(s.cfg.PublicURL, "/")
	}
	proto := ""
	if s.cfg.TrustProxy {
		proto = strings.TrimSpace(r.Header.Get("X-Forwarded-Proto"))
	}
	if proto == "" {
		proto = "http"
		if r.TLS != nil {
			proto = "https"
		}
	}
	return proto + "://" + r.Host
}

// FirmwareManifest is the manifest a wearable checks for updates with.
func (s *Service) FirmwareManifest(ctx context.Context, r *http.Request) (any, error) {
	wsURL, err := WebsocketURL(s.baseURL(r))
	if err != nil {
		return nil, err
	}
	channel := r.URL.Query().Get("channel")
	if channel == "" {
		channel = s.cfg.Env.Channel
	}
	if channel == "" {
		channel = "stable"
	}
	manifest := s.cfg.Firmware.Resolve(ctx, channel, s.cfg.Env)
	version := s.cfg.Version().Version
	minimum, _ := manifest.get("minimumServerVersion")
	if minimum == nil || minimum == "" {
		minimum = version
	}
	var rollout any
	if raw := s.cfg.Env.RolloutJSON; raw != "" {
		if parsed, ok := parseJSONObject(raw); ok {
			rollout = parsed
		}
	}
	return manifest.set("websocketUrl", wsURL).set("minimumServerVersion", minimum).set("rollout", rollout), nil
}

// Bootstrap is everything a wearable needs to start: where the server is, how
// to pair, the voice protocol, the firmware manifest and the signed-in account.
func (s *Service) Bootstrap(ctx context.Context, r *http.Request, userID int64, username string) (any, error) {
	base := s.baseURL(r)
	wsURL, err := WebsocketURL(base)
	if err != nil {
		return nil, err
	}
	manifest, err := s.FirmwareManifest(ctx, r)
	if err != nil {
		return nil, err
	}
	return fields{
		{"server", fields{{"baseUrl", base}, {"websocketUrl", wsURL}, {"serverTime", isoTime(s.cfg.Now())}}},
		{"auth", fields{
			{"qrLoginChallengePath", "/api/auth/qr-login/challenge"},
			{"qrLoginStatusPathTemplate", "/api/auth/qr-login/challenge/{challengeId}/status"},
			{"qrLoginClaimPathTemplate", "/api/auth/qr-login/challenge/{challengeId}/claim"},
			{"qrLoginResolvePath", "/api/account/qr-login/resolve"},
			{"qrLoginApprovePath", "/api/account/qr-login/approve"},
		}},
		{"voice", fields{
			{"websocketPath", WSPath}, {"supportsAudioStreaming", true},
			{"events", []string{
				"voice:session_ready", "voice:state", "voice:audio", "voice:interrupted",
				"voice:transcript", "voice:task", "voice:error",
			}},
		}},
		{"firmware", manifest},
		{"version", s.cfg.Version().Info},
		{"user", fields{{"id", userID}, {"username", nullIfEmpty(username)}}},
		{"features", fields{{"qrPairing", true}, {"voice", true}, {"otaManifest", true}}},
	}, nil
}

// TimeConfig is the local time a wearable sets its clock from. It is public so
// an already provisioned wearable can sync before the user finishes pairing.
func (s *Service) TimeConfig(r *http.Request) any {
	now := s.cfg.Now()
	ip := clientIP(r, s.cfg.TrustProxy)
	detected := ""
	if s.cfg.Geo != nil && ip != "" {
		detected = strings.TrimSpace(s.cfg.Geo.TimezoneForIP(ip))
	}
	fallback := localZoneName()
	zone := detected
	if zone == "" {
		zone = fallback
	}
	offset, ok := utcOffsetSeconds(zone, now)
	if !ok {
		if offset, ok = utcOffsetSeconds(fallback, now); !ok {
			_, offset = now.In(time.Local).Zone()
		}
	}
	source := "server_fallback"
	if detected != "" {
		source = "client_ip_geoip"
	}
	return fields{
		{"timezone", zone}, {"utcOffsetSeconds", offset}, {"serverTime", isoTime(now)},
		{"source", source}, {"ipAddress", nullIfEmpty(ip)},
	}
}

// clientIP is the caller's address as the geo lookup wants it: IPv4-mapped
// addresses unwrapped and ::1 as the IPv4 loopback.
func clientIP(r *http.Request, trustProxy bool) string {
	ip := remoteAddress(r, trustProxy)
	ip = strings.TrimPrefix(strings.TrimSpace(ip), "::ffff:")
	if ip == "::1" {
		return "127.0.0.1"
	}
	return ip
}

func remoteAddress(r *http.Request, trustProxy bool) string {
	if trustProxy {
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			parts := strings.Split(xff, ",")
			if ip := strings.TrimSpace(parts[len(parts)-1]); ip != "" {
				return ip
			}
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func localZoneName() string {
	if name := time.Local.String(); name != "" && name != "Local" {
		return name
	}
	return "UTC"
}

// utcOffsetSeconds is the zone's offset from UTC at t.
func utcOffsetSeconds(zone string, t time.Time) (int, bool) {
	loc, err := time.LoadLocation(strings.TrimSpace(zone))
	if err != nil || strings.TrimSpace(zone) == "" {
		return 0, false
	}
	_, offset := t.In(loc).Zone()
	return offset, true
}

// parseJSONObject reads a JSON object, keeping its text apart from spacing.
// Anything else (a list, a scalar, invalid JSON) is not an object.
func parseJSONObject(raw string) (json.RawMessage, bool) {
	text := bytes.TrimSpace([]byte(raw))
	if len(text) == 0 || text[0] != '{' || !json.Valid(text) {
		return nil, false
	}
	var compact bytes.Buffer
	if err := json.Compact(&compact, text); err != nil {
		return nil, false
	}
	return json.RawMessage(compact.Bytes()), true
}
