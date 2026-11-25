package desktop

import (
	"context"
	"database/sql"
	"encoding/json"
	"log/slog"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

const (
	defaultCommandTimeout  = 30 * time.Second
	defaultHeartbeat       = 25 * time.Second
	defaultHeartbeatTimout = 75 * time.Second
	defaultPresenceTouch   = 15 * time.Second
	maxCommandTimeout      = 30 * time.Minute
)

// Hello is what a companion announces when it connects.
type Hello struct {
	DeviceID, ActivationID, Label, Hostname, Platform, PlatformVersion, AppVersion string
	CompanionEnabled, Paused                                                       bool
	Permissions, Capabilities, Metadata                                            map[string]any
	Displays                                                                       []any
	ActiveDisplayID                                                                string
}

func objectOr(v any) map[string]any {
	if m, ok := v.(map[string]any); ok {
		return m
	}
	return map[string]any{}
}

func trimmedString(v any) string {
	if !truthy(v) {
		return ""
	}
	return strings.TrimSpace(jsText(v))
}

// ParseHello normalizes a hello message; ok is false when it is not one.
func ParseHello(raw []byte) (Hello, bool) {
	var m struct {
		Type   string `json:"type"`
		Device any    `json:"device"`
	}
	if json.Unmarshal(raw, &m) != nil || m.Type != "hello" {
		return Hello{}, false
	}
	device, ok := m.Device.(map[string]any)
	if !ok {
		return Hello{}, false
	}
	displays, _ := device["displays"].([]any)
	return Hello{
		DeviceID: trimmedString(device["deviceId"]), ActivationID: trimmedString(device["activationId"]),
		Label: trimmedString(device["label"]), Hostname: trimmedString(device["hostname"]),
		Platform: trimmedString(device["platform"]), PlatformVersion: trimmedString(device["platformVersion"]),
		AppVersion:       trimmedString(device["appVersion"]),
		CompanionEnabled: device["companionEnabled"] == true, Paused: device["paused"] == true,
		Permissions: objectOr(device["permissions"]), Capabilities: objectOr(device["capabilities"]),
		Displays: displays, ActiveDisplayID: trimmedString(device["activeDisplayId"]), Metadata: objectOr(device["metadata"]),
	}, true
}

// CheckHello rejects a hello the server must not accept.
func CheckHello(h Hello) error {
	switch {
	case !h.CompanionEnabled:
		return &Error{Message: "Companion mode is not enabled on this desktop app.", Status: 403}
	case h.DeviceID == "":
		return &Error{Message: "deviceId is required.", Status: 400}
	case h.ActivationID == "":
		return &Error{Message: "activationId is required.", Status: 400}
	}
	return nil
}

// Display is one screen of a device.
type Display struct {
	ID          string  `json:"id"`
	Label       string  `json:"label"`
	Width       float64 `json:"width"`
	Height      float64 `json:"height"`
	ScaleFactor float64 `json:"scaleFactor"`
	Primary     bool    `json:"primary"`
}

func compactDisplay(v any) Display {
	d := objectOr(v)
	id := trimmedString(d["id"])
	label := trimmedString(firstTruthy(d["label"], d["name"], id))
	if label == "" {
		label = "Display"
	}
	if id == "" {
		id = "primary"
	}
	scale := number(d["scaleFactor"])
	if scale == 0 {
		scale = 1
	}
	return Display{ID: id, Label: label, Width: number(d["width"]), Height: number(d["height"]), ScaleFactor: scale, Primary: d["primary"] == true}
}

func firstTruthy(values ...any) any {
	for _, v := range values {
		if truthy(v) {
			return v
		}
	}
	return ""
}

// Device is a registered companion device, as clients see it.
type Device struct {
	ID               string          `json:"id"`
	UserID           int64           `json:"userId"`
	DeviceID         string          `json:"deviceId"`
	ActivationID     *string         `json:"activationId"`
	Label            string          `json:"label"`
	Hostname         *string         `json:"hostname"`
	Platform         *string         `json:"platform"`
	PlatformVersion  *string         `json:"platformVersion"`
	AppVersion       *string         `json:"appVersion"`
	CompanionEnabled bool            `json:"companionEnabled"`
	Paused           bool            `json:"paused"`
	Status           string          `json:"status"`
	DisplayCount     float64         `json:"displayCount"`
	ActiveDisplayID  *string         `json:"activeDisplayId"`
	Permissions      json.RawMessage `json:"permissions"`
	Capabilities     json.RawMessage `json:"capabilities"`
	Metadata         json.RawMessage `json:"metadata"`
	SessionID        *string         `json:"sessionId"`
	LastConnectedAt  *string         `json:"lastConnectedAt"`
	LastSeenAt       *string         `json:"lastSeenAt"`
	RevokedAt        *string         `json:"revokedAt"`
	CreatedAt        string          `json:"createdAt"`
	UpdatedAt        string          `json:"updatedAt"`
	Displays         []Display       `json:"displays"`
	Online           bool            `json:"online"`
}

// PermissionsMap and friends decode the JSON columns.
func (d *Device) object(raw json.RawMessage) map[string]any {
	out := map[string]any{}
	_ = json.Unmarshal(raw, &out)
	if out == nil {
		out = map[string]any{}
	}
	return out
}

// PermissionsMap is the device's permissions.
func (d *Device) PermissionsMap() map[string]any { return d.object(d.Permissions) }

// MetadataMap is the device's metadata.
func (d *Device) MetadataMap() map[string]any { return d.object(d.Metadata) }

// Registry keeps the live companion connections and their device records.
type Registry struct {
	db               *dbx.DB
	log              *slog.Logger
	commandTimeout   time.Duration
	heartbeat        time.Duration
	heartbeatTimeout time.Duration
	presenceTouch    time.Duration

	mu     sync.Mutex
	conns  map[int64]map[string]*Connection
	closed bool
	// OnConnectionChange runs when a user's devices connect or disconnect.
	OnConnectionChange func(userID int64)
}

// Options tune a Registry; zero values use the defaults and NEOAGENT_DESKTOP_* env.
type Options struct {
	DB                                                         *dbx.DB
	Log                                                        *slog.Logger
	Getenv                                                     func(string) string
	CommandTimeout, Heartbeat, HeartbeatTimeout, PresenceTouch time.Duration
}

func durationSetting(explicit time.Duration, getenv func(string) string, name string, fallback time.Duration) time.Duration {
	if explicit > 0 {
		return explicit
	}
	if getenv != nil {
		if ms, err := strconv.ParseFloat(strings.TrimSpace(getenv(name)), 64); err == nil && ms > 0 {
			return time.Duration(ms * float64(time.Millisecond))
		}
	}
	return fallback
}

// NewRegistry creates the registry.
func NewRegistry(o Options) *Registry {
	if o.Log == nil {
		o.Log = slog.Default()
	}
	return &Registry{
		db: o.DB, log: o.Log, conns: map[int64]map[string]*Connection{},
		commandTimeout:   durationSetting(o.CommandTimeout, o.Getenv, "NEOAGENT_DESKTOP_COMMAND_TIMEOUT_MS", defaultCommandTimeout),
		heartbeat:        durationSetting(o.Heartbeat, o.Getenv, "NEOAGENT_DESKTOP_HEARTBEAT_INTERVAL_MS", defaultHeartbeat),
		heartbeatTimeout: durationSetting(o.HeartbeatTimeout, o.Getenv, "NEOAGENT_DESKTOP_HEARTBEAT_TIMEOUT_MS", defaultHeartbeatTimout),
		presenceTouch:    durationSetting(o.PresenceTouch, o.Getenv, "NEOAGENT_DESKTOP_PRESENCE_TOUCH_INTERVAL_MS", defaultPresenceTouch),
	}
}

func safeJSON(v any) string {
	if v == nil {
		return "{}"
	}
	raw, err := json.Marshal(v)
	if err != nil {
		return "{}"
	}
	return string(raw)
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func isoNow() string { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }

const deviceColumns = `id, user_id, device_id, activation_id, label, hostname, platform, platform_version, app_version,
 companion_enabled, paused, status, display_count, active_display_id, permissions_json, capabilities_json,
 metadata_json, session_id, last_connected_at, last_seen_at, revoked_at, created_at, updated_at`

func objectJSON(s sql.NullString) json.RawMessage {
	var m map[string]any
	if !s.Valid || json.Unmarshal([]byte(s.String), &m) != nil || m == nil {
		return json.RawMessage("{}")
	}
	return json.RawMessage(s.String)
}

func ptr(s sql.NullString) *string {
	if !s.Valid || s.String == "" {
		return nil
	}
	return &s.String
}

func scanDevice(scan func(...any) error) (*Device, error) {
	var d Device
	var activation, hostname, platform, platformVersion, appVersion, status, activeDisplay, perms, caps, meta, session, lastConnected, lastSeen, revoked, created, updated sql.NullString
	var enabled, paused, displays sql.NullInt64
	var label sql.NullString
	if err := scan(&d.ID, &d.UserID, &d.DeviceID, &activation, &label, &hostname, &platform, &platformVersion, &appVersion,
		&enabled, &paused, &status, &displays, &activeDisplay, &perms, &caps, &meta, &session, &lastConnected, &lastSeen, &revoked, &created, &updated); err != nil {
		return nil, err
	}
	d.ActivationID, d.Label, d.Hostname, d.Platform, d.PlatformVersion, d.AppVersion = ptr(activation), label.String, ptr(hostname), ptr(platform), ptr(platformVersion), ptr(appVersion)
	d.CompanionEnabled, d.Paused = enabled.Int64 == 1, paused.Int64 == 1
	d.Status = status.String
	if d.Status == "" {
		d.Status = "offline"
	}
	d.DisplayCount = float64(displays.Int64)
	d.ActiveDisplayID = ptr(activeDisplay)
	d.Permissions, d.Capabilities, d.Metadata = objectJSON(perms), objectJSON(caps), objectJSON(meta)
	d.SessionID, d.LastConnectedAt, d.LastSeenAt, d.RevokedAt = ptr(session), ptr(lastConnected), ptr(lastSeen), ptr(revoked)
	d.CreatedAt = created.String
	d.UpdatedAt = updated.String
	if d.UpdatedAt == "" {
		d.UpdatedAt = d.CreatedAt
	}
	var m struct {
		Displays []any `json:"displays"`
	}
	_ = json.Unmarshal(d.Metadata, &m)
	d.Displays = make([]Display, 0, len(m.Displays))
	for _, raw := range m.Displays {
		d.Displays = append(d.Displays, compactDisplay(raw))
	}
	d.Online = d.Status == "online"
	return &d, nil
}

// Device returns one device record, or nil.
func (r *Registry) Device(ctx context.Context, userID int64, deviceID string) *Device {
	d, err := scanDevice(r.db.R.QueryRowContext(ctx, `SELECT `+deviceColumns+` FROM desktop_companion_devices WHERE user_id = ? AND device_id = ?`, userID, strings.TrimSpace(deviceID)).Scan)
	if err != nil {
		return nil
	}
	return d
}

func (r *Registry) upsertDevice(ctx context.Context, userID int64, h Hello, sessionID string) (*Device, error) {
	existing := r.Device(ctx, userID, h.DeviceID)
	if existing != nil && existing.RevokedAt != nil && existing.ActivationID != nil && *existing.ActivationID == h.ActivationID {
		return nil, &Error{Message: "This desktop device was revoked. Disable and re-enable Companion Mode on that machine before reconnecting.", Code: "DESKTOP_DEVICE_REVOKED", Status: 403}
	}
	displays := make([]Display, 0, len(h.Displays))
	for _, d := range h.Displays {
		displays = append(displays, compactDisplay(d))
	}
	metadata := map[string]any{}
	for k, v := range h.Metadata {
		metadata[k] = v
	}
	metadata["displays"] = displays
	now := isoNow()
	rowID, created := uuid.NewString(), now
	if existing != nil {
		rowID, created = existing.ID, existing.CreatedAt
	}
	label := firstNonEmpty(h.Label, h.Hostname, firstNonEmpty(h.Platform, "Desktop")+" device")
	active := h.ActiveDisplayID
	if active == "" && len(displays) > 0 {
		active = displays[0].ID
	}
	enabled, paused := 0, 0
	if h.CompanionEnabled {
		enabled = 1
	}
	if h.Paused {
		paused = 1
	}
	_, err := r.db.W.ExecContext(ctx, `INSERT INTO desktop_companion_devices (
         id, user_id, device_id, activation_id, label, hostname, platform, platform_version, app_version,
         companion_enabled, paused, status, display_count, active_display_id, permissions_json, capabilities_json,
         metadata_json, session_id, last_connected_at, last_seen_at, revoked_at, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'online', ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
       ON CONFLICT(user_id, device_id) DO UPDATE SET
         activation_id = excluded.activation_id, revoked_at = NULL, label = excluded.label, hostname = excluded.hostname,
         platform = excluded.platform, platform_version = excluded.platform_version, app_version = excluded.app_version,
         companion_enabled = excluded.companion_enabled, paused = excluded.paused, status = 'online',
         display_count = excluded.display_count, active_display_id = excluded.active_display_id,
         permissions_json = excluded.permissions_json, capabilities_json = excluded.capabilities_json,
         metadata_json = excluded.metadata_json, session_id = excluded.session_id,
         last_connected_at = excluded.last_connected_at, last_seen_at = excluded.last_seen_at, updated_at = excluded.updated_at`,
		rowID, userID, h.DeviceID, h.ActivationID, label, nullable(h.Hostname), nullable(h.Platform), nullable(h.PlatformVersion), nullable(h.AppVersion),
		enabled, paused, len(displays), nullable(active), safeJSON(h.Permissions), safeJSON(h.Capabilities), safeJSON(metadata),
		nullable(sessionID), now, now, created, now)
	if err != nil {
		return nil, err
	}
	// A reinstall makes a new device id on the same machine; drop the old offline one.
	if h.Hostname != "" {
		_, _ = r.db.W.ExecContext(ctx, `DELETE FROM desktop_companion_devices WHERE user_id = ? AND hostname = ? AND device_id != ? AND status = 'offline'`, userID, h.Hostname, h.DeviceID)
	}
	return r.Device(ctx, userID, h.DeviceID), nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// Register installs a companion connection; one replaced by it is closed.
func (r *Registry) Register(ctx context.Context, userID int64, sessionID string, t Transport, h Hello) (*Connection, *Device, error) {
	r.mu.Lock()
	closed := r.closed
	r.mu.Unlock()
	if closed {
		return nil, nil, Unavailable("Desktop companion registry is shutting down.")
	}
	record, err := r.upsertDevice(ctx, userID, h, sessionID)
	if err != nil {
		return nil, nil, err
	}
	c := newConnection(r, t, userID, sessionID, record.DeviceID)
	r.mu.Lock()
	m := r.conns[userID]
	if m == nil {
		m = map[string]*Connection{}
		r.conns[userID] = m
	}
	// The new connection owns the device before the old one closes, so the
	// old socket's close does not mark the device offline.
	old := m[record.DeviceID]
	m[record.DeviceID] = c
	r.mu.Unlock()
	if old != nil && old.t != t {
		old.Close("replaced by a newer desktop companion connection")
	}
	c.start()
	r.notify(userID)
	return c, r.Device(ctx, userID, record.DeviceID), nil
}

func (r *Registry) unregister(c *Connection) {
	r.mu.Lock()
	m := r.conns[c.userID]
	owner := m != nil && m[c.deviceID] == c
	if owner {
		delete(m, c.deviceID)
		if len(m) == 0 {
			delete(r.conns, c.userID)
		}
	}
	r.mu.Unlock()
	if !owner {
		return
	}
	if _, err := r.db.W.Exec(`UPDATE desktop_companion_devices SET status = 'offline', updated_at = datetime('now') WHERE user_id = ? AND device_id = ?`, c.userID, c.deviceID); err != nil {
		r.log.Warn("Failed to record desktop companion disconnect", "error", err)
	}
	r.notify(c.userID)
}

func (r *Registry) notify(userID int64) {
	if r.OnConnectionChange != nil {
		r.OnConnectionChange(userID)
	}
}

// TouchConnection records a device's reported state.
func (r *Registry) TouchConnection(ctx context.Context, userID int64, deviceID string, patch map[string]any) {
	existing := r.Device(ctx, userID, deviceID)
	if existing == nil {
		return
	}
	displays := existing.Displays
	if list, ok := patch["displays"].([]any); ok {
		displays = make([]Display, 0, len(list))
		for _, d := range list {
			displays = append(displays, compactDisplay(d))
		}
	}
	metadata := existing.MetadataMap()
	for k, v := range objectOr(patch["metadata"]) {
		metadata[k] = v
	}
	metadata["displays"] = displays
	paused := 0
	if p, ok := patch["paused"].(bool); ok {
		if p {
			paused = 1
		}
	} else if existing.Paused {
		paused = 1
	}
	label := trimmedOr(patch["label"], existing.Label)
	status := trimmedOr(patch["status"], "online")
	active := patch["activeDisplayId"]
	if !truthy(active) {
		active = existing.ActiveDisplayID
	}
	perms, caps := patch["permissions"], patch["capabilities"]
	if !truthy(perms) {
		perms = existing.PermissionsMap()
	}
	if !truthy(caps) {
		caps = existing.object(existing.Capabilities)
	}
	_, err := r.db.W.ExecContext(ctx, `UPDATE desktop_companion_devices
       SET label = ?, paused = ?, status = ?, display_count = ?, active_display_id = ?, permissions_json = ?,
           capabilities_json = ?, metadata_json = ?, last_seen_at = datetime('now'), updated_at = datetime('now')
       WHERE user_id = ? AND device_id = ?`, label, paused, status, len(displays), active, safeJSON(perms), safeJSON(caps), safeJSON(metadata), userID, deviceID)
	if err != nil {
		r.log.Warn("Failed to record desktop companion state", "error", err)
	}
}

func trimmedOr(v any, fallback string) string {
	if !truthy(v) {
		return fallback
	}
	return jsText(v)
}

func (r *Registry) touchPresence(userID int64, deviceID string) {
	if c := r.connection(userID, deviceID); c == nil || !c.Open() {
		return
	}
	if _, err := r.db.W.Exec(`UPDATE desktop_companion_devices SET status = 'online', last_seen_at = datetime('now'), updated_at = datetime('now')
         WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL`, userID, deviceID); err != nil {
		r.log.Warn("Failed to update desktop companion presence", "error", err)
	}
}

// IsConnected reports an open companion connection for the user.
func (r *Registry) IsConnected(userID int64) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, c := range r.conns[userID] {
		if c.Open() {
			return true
		}
	}
	return false
}

func (r *Registry) connection(userID int64, deviceID string) *Connection {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.conns[userID][deviceID]
}

// ListDevices lists the user's devices, online first, latest first.
func (r *Registry) ListDevices(ctx context.Context, userID int64) []Device {
	rows, err := r.db.R.QueryContext(ctx, `SELECT `+deviceColumns+` FROM desktop_companion_devices WHERE user_id = ?
       ORDER BY CASE WHEN status = 'online' THEN 0 ELSE 1 END, datetime(last_seen_at) DESC, datetime(created_at) DESC`, userID)
	if err != nil {
		return []Device{}
	}
	defer rows.Close()
	out := []Device{}
	for rows.Next() {
		if d, err := scanDevice(rows.Scan); err == nil {
			out = append(out, *d)
		}
	}
	return out
}

// SelectedDeviceID is the device the user picked, or "".
func (r *Registry) SelectedDeviceID(ctx context.Context, userID int64) string {
	var v sql.NullString
	_ = r.db.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = 'selected_desktop_device_id'`, userID).Scan(&v)
	return v.String
}

// SetSelectedDeviceID picks a device.
func (r *Registry) SetSelectedDeviceID(ctx context.Context, userID int64, deviceID string) error {
	_, err := r.db.W.ExecContext(ctx, `INSERT INTO user_settings (user_id, key, value) VALUES (?, 'selected_desktop_device_id', ?)
       ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`, userID, strings.TrimSpace(deviceID))
	return err
}

// ResolveDevice picks the device a command goes to: the named one, the only
// online one, or the selected one.
func (r *Registry) ResolveDevice(ctx context.Context, userID int64, deviceID string) (*Device, error) {
	var online []Device
	for _, d := range r.ListDevices(ctx, userID) {
		if d.Online && d.RevokedAt == nil {
			online = append(online, d)
		}
	}
	if explicit := strings.TrimSpace(deviceID); explicit != "" {
		for i := range online {
			if online[i].DeviceID == explicit {
				return &online[i], nil
			}
		}
		return nil, Unavailable("")
	}
	if len(online) == 1 {
		return &online[0], nil
	}
	if saved := r.SelectedDeviceID(ctx, userID); saved != "" {
		for i := range online {
			if online[i].DeviceID == saved {
				return &online[i], nil
			}
		}
	}
	if len(online) == 0 {
		return nil, Unavailable("")
	}
	type choice struct {
		DeviceID string  `json:"deviceId"`
		Label    string  `json:"label"`
		Hostname *string `json:"hostname"`
		Platform *string `json:"platform"`
	}
	devices := make([]choice, 0, len(online))
	for _, d := range online {
		devices = append(devices, choice{d.DeviceID, d.Label, d.Hostname, d.Platform})
	}
	return nil, &Error{Message: "Multiple desktop companions are online. Select a device first.", Code: "DESKTOP_COMPANION_SELECTION_REQUIRED", Details: map[string]any{"devices": devices}}
}

// Dispatch sends a command to the user's device and returns its result with
// the refreshed device record under "device".
func (r *Registry) Dispatch(ctx context.Context, userID int64, deviceID, command string, payload any, timeout time.Duration) (*jsonobj.Object, error) {
	device, err := r.ResolveDevice(ctx, userID, deviceID)
	if err != nil {
		return nil, err
	}
	c := r.connection(userID, device.DeviceID)
	if c == nil || !c.Open() {
		return nil, Unavailable("")
	}
	result, err := c.Send(ctx, command, payload, timeout)
	if err != nil {
		return nil, err
	}
	var reported struct {
		Device          map[string]any `json:"device"`
		Paused          any            `json:"paused"`
		ActiveDisplayID any            `json:"activeDisplayId"`
		Permissions     any            `json:"permissions"`
		Capabilities    any            `json:"capabilities"`
		Displays        any            `json:"displays"`
	}
	raw, _ := json.Marshal(result)
	_ = json.Unmarshal(raw, &reported)
	patch := map[string]any{"label": reported.Device["label"], "permissions": reported.Permissions, "capabilities": reported.Capabilities, "metadata": reported.Device["metadata"]}
	if _, ok := reported.Paused.(bool); ok {
		patch["paused"] = reported.Paused
	}
	patch["activeDisplayId"] = firstTruthy(reported.ActiveDisplayID, reported.Device["activeDisplayId"])
	if d := firstTruthy(reported.Displays, reported.Device["displays"]); truthy(d) {
		patch["displays"] = d
	}
	r.TouchConnection(ctx, userID, device.DeviceID, patch)
	return result.Clone().Set("device", r.Device(ctx, userID, device.DeviceID)), nil
}

// Status is the user's devices and the selection, choosing the most recently
// online device when the selection is not online.
func (r *Registry) Status(ctx context.Context, userID int64) Status {
	devices := r.ListDevices(ctx, userID)
	var online []Device
	for _, d := range devices {
		if d.Online {
			online = append(online, d)
		}
	}
	selected := r.SelectedDeviceID(ctx, userID)
	selectionOnline := false
	for _, d := range online {
		if selected != "" && d.DeviceID == selected {
			selectionOnline = true
		}
	}
	if !selectionOnline && len(online) > 0 {
		selected = online[0].DeviceID
		_ = r.SetSelectedDeviceID(ctx, userID, selected)
	}
	return Status{Connected: len(online) > 0, SelectedDeviceID: nullable(selected), OnlineCount: len(online), Devices: devices}
}

// Status is a user's companion devices.
type Status struct {
	Connected        bool     `json:"connected"`
	SelectedDeviceID any      `json:"selectedDeviceId"`
	OnlineCount      int      `json:"onlineCount"`
	Devices          []Device `json:"devices"`
}

// Selected is the selected (or first online) device.
func (s Status) Selected() *Device {
	for i := range s.Devices {
		if s.SelectedDeviceID != nil && s.Devices[i].DeviceID == s.SelectedDeviceID {
			return &s.Devices[i]
		}
	}
	for i := range s.Devices {
		if s.Devices[i].Online {
			return &s.Devices[i]
		}
	}
	return nil
}

// Pause pauses or resumes agent control on a device.
func (r *Registry) Pause(ctx context.Context, userID int64, deviceID string, paused bool) (*jsonobj.Object, error) {
	deviceID = strings.TrimSpace(deviceID)
	if deviceID == "" || r.Device(ctx, userID, deviceID) == nil {
		return nil, Unavailable("")
	}
	c := r.connection(userID, deviceID)
	if c == nil || !c.Open() {
		return nil, Unavailable("")
	}
	result, err := c.Send(ctx, CmdPauseControl, map[string]any{"paused": paused}, 0)
	if err != nil {
		return nil, err
	}
	success := !isFalse(result, "success")
	if success {
		p := 0
		if paused {
			p = 1
		}
		_, _ = r.db.W.ExecContext(ctx, `UPDATE desktop_companion_devices SET paused = ?, updated_at = datetime('now') WHERE user_id = ? AND device_id = ?`, p, userID, deviceID)
	}
	return result.Clone().Set("success", success).Set("deviceId", deviceID).Set("paused", paused), nil
}

// Revoke disconnects a device until Companion Mode is re-enabled on it.
func (r *Registry) Revoke(ctx context.Context, userID int64, deviceID string) error {
	deviceID = strings.TrimSpace(deviceID)
	existing := r.Device(ctx, userID, deviceID)
	if deviceID == "" || existing == nil || existing.RevokedAt != nil {
		return Unavailable("")
	}
	if _, err := r.db.W.ExecContext(ctx, `UPDATE desktop_companion_devices SET revoked_at = datetime('now'), status = 'revoked', updated_at = datetime('now') WHERE user_id = ? AND device_id = ?`, userID, deviceID); err != nil {
		return err
	}
	if c := r.connection(userID, deviceID); c != nil {
		c.Close("desktop device revoked")
	}
	return nil
}

// OutputClaim ties an uploaded command output to its running command.
type OutputClaim struct {
	CommandID, DeviceID, SessionID string
	RunID, StepID                  any
}

// ClaimCommandOutput lets a companion upload a running command's output once.
func (r *Registry) ClaimCommandOutput(userID int64, deviceID, commandID string) (OutputClaim, bool) {
	c := r.connection(userID, deviceID)
	if c == nil || !c.Open() {
		return OutputClaim{}, false
	}
	commandID = strings.TrimSpace(commandID)
	runID, stepID, ok := c.claimOutput(commandID)
	return OutputClaim{CommandID: commandID, DeviceID: c.deviceID, SessionID: c.sessionID, RunID: runID, StepID: stepID}, ok
}

// FinishCommandOutput releases a claim; a failed upload may be retried.
func (r *Registry) FinishCommandOutput(userID int64, deviceID, commandID string, success bool) bool {
	c := r.connection(userID, deviceID)
	return c != nil && c.finishOutput(strings.TrimSpace(commandID), success)
}

// CloseAll disconnects every companion.
func (r *Registry) CloseAll() {
	r.mu.Lock()
	r.closed = true
	var all []*Connection
	for _, m := range r.conns {
		for _, c := range m {
			all = append(all, c)
		}
	}
	r.mu.Unlock()
	for _, c := range all {
		c.Close("server shutdown")
	}
	r.mu.Lock()
	r.conns = map[int64]map[string]*Connection{}
	r.mu.Unlock()
}

func isFalse(o *jsonobj.Object, key string) bool {
	var b bool
	return o.Has(key) && o.Decode(key, &b) && !b
}
