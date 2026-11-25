package mobilesync

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// ProviderKey is the integration provider a paired phone connects as.
const ProviderKey = "phone"

// Kinds are the things a phone can share.
var Kinds = []string{"calendar", "contacts", "alarms"}

var deviceIDPattern = regexp.MustCompile(`^[A-Za-z0-9-]{8,64}$`)

const (
	maxCalendars = 200
	maxEvents    = 5000
	maxContacts  = 10000
)

// Phone keeps what paired phones share. The shared items and the commands
// waiting for a phone are sealed at rest.
type Phone struct {
	DB  *dbx.DB
	Box *secretbox.Box
}

// text is trimText: String(value || ”).trim().
func text(v any) string { return jsv.Trim(jsv.Text(v)) }

func clip(v any, max int) string { return jsv.Slice(text(v), max) }

// isoOrNull is `new Date(value).toISOString()` or "" for an invalid date; a
// value the phone left out is an invalid date.
func isoOrNull(o *jsv.Object, key string) string {
	v, present := o.Get(key)
	if !present {
		return ""
	}
	t, ok := jsv.ParseDate(v)
	if !ok {
		return ""
	}
	return jsv.ISO(t)
}

func list(v any, max, itemMax int) []any {
	items, _ := v.([]any)
	out := []any{}
	for _, item := range items {
		if s := clip(item, itemMax); s != "" {
			out = append(out, s)
		}
	}
	if len(out) > max {
		out = out[:max]
	}
	return out
}

// item is a normalized thing a phone shared, ready to store.
type item struct {
	key      string
	startsAt string
	endsAt   string
	payload  *jsv.Object
}

func nullIf(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func typeError(prop string) error {
	return fmt.Errorf("Cannot read properties of null (reading '%s')", prop)
}

// normalize trims what a phone may send to known fields and sizes. A kind's
// first property read is what Node's TypeError named for a null entry.
var normalize = map[string]func(raw any) (*item, error){
	"calendar": func(raw any) (*item, error) {
		if raw == nil {
			return nil, typeError("id")
		}
		o, ok := raw.(*jsv.Object)
		if !ok {
			return nil, nil
		}
		id := clip(o.Val("id"), 200)
		if id == "" {
			return nil, nil
		}
		name := clip(o.Val("name"), 200)
		if name == "" {
			name = "Calendar"
		}
		return &item{key: id, payload: jsv.NewObject().Set("id", id).Set("name", name).
			Set("account", nullIf(clip(o.Val("account"), 200))).
			Set("writable", o.Val("writable") == true).Set("primary", o.Val("primary") == true)}, nil
	},
	"event": func(raw any) (*item, error) {
		if raw == nil {
			return nil, typeError("start")
		}
		o, ok := raw.(*jsv.Object)
		if !ok {
			return nil, nil
		}
		start := isoOrNull(o, "start")
		end := isoOrNull(o, "end")
		if end == "" {
			end = start
		}
		key := clip(o.Val("key"), 300)
		if key == "" || start == "" {
			return nil, nil
		}
		return &item{key: key, startsAt: start, endsAt: end, payload: jsv.NewObject().
			Set("eventId", clip(o.Val("eventId"), 200)).Set("calendarId", clip(o.Val("calendarId"), 200)).
			Set("title", clip(o.Val("title"), 500)).Set("start", start).Set("end", end).
			Set("allDay", o.Val("allDay") == true).
			Set("location", nullIf(clip(o.Val("location"), 500))).Set("notes", nullIf(clip(o.Val("notes"), 2000))).
			Set("attendees", list(o.Val("attendees"), 30, 200))}, nil
	},
	"contact": func(raw any) (*item, error) {
		if raw == nil {
			return nil, typeError("key")
		}
		o, ok := raw.(*jsv.Object)
		if !ok {
			return nil, nil
		}
		key, name := clip(o.Val("key"), 200), clip(o.Val("name"), 300)
		if key == "" || name == "" {
			return nil, nil
		}
		return &item{key: key, payload: jsv.NewObject().Set("name", name).
			Set("emails", list(o.Val("emails"), 10, 200)).Set("phones", list(o.Val("phones"), 10, 60)).
			Set("organization", nullIf(clip(o.Val("organization"), 300)))}, nil
	},
}

func (p *Phone) seal(value string) (string, error) { return p.Box.Seal(value) }

// payloadOf reads a stored payload; anything but an object reads as empty.
func (p *Phone) payloadOf(stored string) *jsv.Object {
	plain, err := p.Box.Open(stored)
	if err != nil {
		return jsv.NewObject()
	}
	if o := jsv.ParseObject(plain); o != nil {
		return o
	}
	return jsv.NewObject()
}

type connection struct {
	id       int64
	appKey   string
	email    sql.NullString
	metadata *jsv.Object
}

type querier interface {
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// deviceConnections are the phone's connection rows (one per shared kind).
func deviceConnections(ctx context.Context, q querier, userID int64, agentID, deviceID string) ([]connection, error) {
	rows, err := q.QueryContext(ctx, `SELECT id, app_key, account_email, metadata_json FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=?`, userID, agentID, ProviderKey)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []connection
	for rows.Next() {
		var c connection
		var metadata sql.NullString
		if err := rows.Scan(&c.id, &c.appKey, &c.email, &metadata); err != nil {
			return nil, err
		}
		c.metadata = jsv.ParseObject(metadata.String)
		if c.metadata == nil {
			c.metadata = jsv.NewObject()
		}
		if c.metadata.Val("deviceId") == deviceID {
			out = append(out, c)
		}
	}
	return out, rows.Err()
}

func deleteDeviceData(ctx context.Context, q querier, userID int64, agentID, deviceID string, kinds ...string) error {
	if len(kinds) == 0 {
		kinds = []string{"calendar", "event", "contact", "alarm"}
	}
	args := []any{userID, agentID, deviceID}
	for _, k := range kinds {
		args = append(args, k)
	}
	_, err := q.ExecContext(ctx, `DELETE FROM device_sync_items WHERE user_id=? AND agent_id=? AND device_id=? AND kind IN (`+
		strings.TrimSuffix(strings.Repeat("?,", len(kinds)), ",")+`)`, args...)
	return err
}

type device struct{ id, platform, name string }

func parseDevice(o *jsv.Object) (device, error) {
	id := text(o.Val("id"))
	if !deviceIDPattern.MatchString(id) {
		return device{}, errors.New("A valid device id is required.")
	}
	platform := strings.ToLower(text(o.Val("platform")))
	if platform != "android" && platform != "ios" {
		return device{}, errors.New("Phone sync runs on Android and iOS.")
	}
	name := clip(o.Val("name"), 60)
	if name == "" {
		name = "Android phone"
		if platform == "ios" {
			name = "iPhone"
		}
	}
	return device{id, platform, name}, nil
}

// accountLabel keeps two phones with the same name apart in the account list.
func accountLabel(ctx context.Context, q querier, userID int64, agentID string, d device) (string, error) {
	rows, err := q.QueryContext(ctx, `SELECT metadata_json FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND account_email=?`, userID, agentID, ProviderKey, d.name)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	for rows.Next() {
		var metadata sql.NullString
		if err := rows.Scan(&metadata); err != nil {
			return "", err
		}
		if o := jsv.ParseObject(metadata.String); o == nil || o.Val("deviceId") != d.id {
			return fmt.Sprintf("%s (%s)", d.name, d.id[len(d.id)-4:]), rows.Err()
		}
	}
	return d.name, rows.Err()
}

// Registration is what a phone is told after it starts sharing.
type Registration struct {
	Connected    bool     `json:"connected"`
	Kinds        []string `json:"kinds"`
	AccountEmail string   `json:"accountEmail"`
}

// Register starts sharing the chosen kinds from a phone, or changes which it
// shares. deviceObj holds id, name and platform; rawKinds is the list the phone
// sent.
func (p *Phone) Register(ctx context.Context, userID int64, agentID string, deviceObj *jsv.Object, rawKinds any) (*Registration, error) {
	d, err := parseDevice(deviceObj)
	if err != nil {
		return nil, err
	}
	asked, _ := rawKinds.([]any)
	var kinds []string
	for _, kind := range Kinds {
		if slices.Contains(asked, any(kind)) {
			kinds = append(kinds, kind)
		}
	}
	if len(kinds) == 0 {
		return nil, errors.New("Choose what to share.")
	}
	if d.platform != "android" && slices.Contains(kinds, "alarms") {
		return nil, errors.New("Alarm sharing requires Android.")
	}
	tx, err := p.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	existing, err := deviceConnections(ctx, tx, userID, agentID, d.id)
	if err != nil {
		return nil, err
	}
	var email string
	if len(existing) > 0 && existing[0].email.Valid && existing[0].email.String != "" {
		email = existing[0].email.String
	} else if email, err = accountLabel(ctx, tx, userID, agentID, d); err != nil {
		return nil, err
	}
	for _, kind := range kinds {
		if err := p.upsertAccountApp(ctx, tx, userID, agentID, kind, email, d); err != nil {
			return nil, err
		}
	}
	removed := map[string][]string{"calendar": {"calendar", "event"}, "contacts": {"contact"}, "alarms": {"alarm"}}
	for _, row := range existing {
		if slices.Contains(kinds, row.appKey) {
			continue
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM integration_connections WHERE id=?`, row.id); err != nil {
			return nil, err
		}
		if err := deleteDeviceData(ctx, tx, userID, agentID, d.id, removed[row.appKey]...); err != nil {
			return nil, err
		}
	}
	return &Registration{Connected: true, Kinds: kinds, AccountEmail: email}, tx.Commit()
}

const (
	defaultAccessMode = "read_write"
	accessModeKey     = "access_mode"
)

func accessMode(metadata *jsv.Object) string {
	mode := strings.ToLower(text(metadata.Val(accessModeKey)))
	if mode == "read_write" || mode == "read_only" {
		return mode
	}
	return defaultAccessMode
}

// upsertAccountApp connects one app of the phone's account, keeping the Read
// Only / Read Write choice already made for it.
func (p *Phone) upsertAccountApp(ctx context.Context, q querier, userID int64, agentID, kind, email string, d device) error {
	rows, err := q.QueryContext(ctx, `SELECT metadata_json FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND app_key=? AND account_email=?`, userID, agentID, ProviderKey, kind, email)
	if err != nil {
		return err
	}
	var existing *jsv.Object
	if rows.Next() {
		var metadata sql.NullString
		if err := rows.Scan(&metadata); err != nil {
			rows.Close()
			return err
		}
		if existing = jsv.ParseObject(metadata.String); existing == nil {
			existing = jsv.NewObject()
		}
	}
	rows.Close()
	metadata := existing.Clone()
	metadata.Set("deviceId", d.id).Set("platform", d.platform)
	mode := defaultAccessMode
	if existing != nil {
		mode = accessMode(existing)
	}
	metadata.Set(accessModeKey, mode)
	credentials, err := p.seal(jsv.Stringify(jsv.NewObject().Set("deviceId", d.id)))
	if err != nil {
		return err
	}
	_, err = q.ExecContext(ctx, `INSERT INTO integration_connections (
       user_id, agent_id, provider_key, app_key, status, account_email, scopes_json,
       credentials_json, metadata_json, last_connected_at, updated_at
     ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
       status = 'connected',
       scopes_json = excluded.scopes_json,
       credentials_json = excluded.credentials_json,
       metadata_json = excluded.metadata_json,
       last_connected_at = excluded.last_connected_at,
       updated_at = excluded.updated_at`,
		userID, agentID, ProviderKey, kind, email, jsv.Stringify([]string{kind}), credentials, jsv.Stringify(metadata))
	return err
}

// Forget removes everything a phone shared, from either side.
func (p *Phone) Forget(ctx context.Context, userID int64, agentID, deviceID string) error {
	tx, err := p.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	rows, err := deviceConnections(ctx, tx, userID, agentID, deviceID)
	if err != nil {
		return err
	}
	for _, row := range rows {
		if _, err := tx.ExecContext(ctx, `DELETE FROM integration_connections WHERE id=?`, row.id); err != nil {
			return err
		}
	}
	if err := deleteDeviceData(ctx, tx, userID, agentID, deviceID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM device_sync_commands WHERE user_id=? AND agent_id=? AND device_id=?`, userID, agentID, deviceID); err != nil {
		return err
	}
	return tx.Commit()
}

func (p *Phone) replaceItems(ctx context.Context, q querier, userID int64, agentID, deviceID, kind string, items []any, limit int) error {
	if err := deleteDeviceData(ctx, q, userID, agentID, deviceID, kind); err != nil {
		return err
	}
	if len(items) > limit {
		items = items[:limit]
	}
	var kept []*item
	for _, raw := range items {
		it, err := normalize[kind](raw)
		if err != nil {
			return err
		}
		if it != nil {
			kept = append(kept, it)
		}
	}
	for _, it := range kept {
		sealed, err := p.seal(jsv.Stringify(it.payload))
		if err != nil {
			return err
		}
		if _, err := q.ExecContext(ctx, `INSERT OR REPLACE INTO device_sync_items
    (user_id, agent_id, device_id, kind, item_key, starts_at, ends_at, payload_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			userID, agentID, deviceID, kind, it.key, nullIf(it.startsAt), nullIf(it.endsAt), sealed); err != nil {
			return err
		}
	}
	return nil
}

// Sync handles one sync from a phone: it replaces what the phone sent (a list
// left out means unchanged), records the results of changes it made and hands
// back the changes still waiting for it.
func (p *Phone) Sync(ctx context.Context, userID int64, agentID string, body *jsv.Object) (*jsv.Object, error) {
	deviceID := text(body.Val("deviceId"))
	tx, err := p.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	connections, err := deviceConnections(ctx, tx, userID, agentID, deviceID)
	if err != nil {
		return nil, err
	}
	if len(connections) == 0 {
		return jsv.NewObject().Set("connected", false), nil
	}
	kinds := make([]string, len(connections))
	for i, c := range connections {
		kinds[i] = c.appKey
	}
	if slices.Contains(kinds, "calendar") {
		if cals, ok := body.Val("calendars").([]any); ok {
			if err := p.replaceItems(ctx, tx, userID, agentID, deviceID, "calendar", cals, maxCalendars); err != nil {
				return nil, err
			}
		}
		if events, ok := body.Val("events").([]any); ok {
			if err := p.replaceItems(ctx, tx, userID, agentID, deviceID, "event", events, maxEvents); err != nil {
				return nil, err
			}
		}
	}
	if contacts, ok := body.Val("contacts").([]any); ok && slices.Contains(kinds, "contacts") {
		if err := p.replaceItems(ctx, tx, userID, agentID, deviceID, "contact", contacts, maxContacts); err != nil {
			return nil, err
		}
	}
	if slices.Contains(kinds, "alarms") && body.Has("nextAlarm") {
		if err := p.syncAlarm(ctx, tx, userID, agentID, deviceID, body.Val("nextAlarm")); err != nil {
			return nil, err
		}
	}
	if err := p.completeCommands(ctx, tx, userID, agentID, deviceID, body.Val("results")); err != nil {
		return nil, err
	}
	syncedAt := jsv.ISO(time.Now())
	for _, c := range connections {
		metadata := c.metadata.Clone().Set("syncedAt", syncedAt)
		if _, err := tx.ExecContext(ctx, `UPDATE integration_connections SET metadata_json=? WHERE id=?`, jsv.Stringify(metadata), c.id); err != nil {
			return nil, err
		}
	}
	commands, err := p.pendingCommands(ctx, tx, userID, agentID, deviceID)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	kindList := make([]any, len(kinds))
	for i, k := range kinds {
		kindList[i] = k
	}
	return jsv.NewObject().Set("connected", true).Set("kinds", kindList).Set("commands", commands), nil
}

func (p *Phone) syncAlarm(ctx context.Context, q querier, userID int64, agentID, deviceID string, raw any) error {
	var next string
	if raw != nil {
		o := jsv.NewObject().Set("v", raw)
		if next = isoOrNull(o, "v"); next == "" {
			return errors.New("Invalid next alarm time.")
		}
	}
	now := jsv.ISO(time.Now())
	// Alarms that are already due stay until polling tasks have consumed them.
	// A change or cancellation removes only the ones that have not happened yet.
	if _, err := q.ExecContext(ctx, `DELETE FROM device_sync_items WHERE user_id=? AND agent_id=? AND device_id=? AND kind='alarm' AND starts_at>?`,
		userID, agentID, deviceID, now); err != nil {
		return err
	}
	if _, err := q.ExecContext(ctx, `DELETE FROM device_sync_items WHERE user_id=? AND agent_id=? AND device_id=? AND kind='alarm' AND starts_at<?`,
		userID, agentID, deviceID, jsv.ISO(time.Now().Add(-7*24*time.Hour))); err != nil {
		return err
	}
	if next == "" || next <= now {
		return nil
	}
	sealed, err := p.seal(jsv.Stringify(jsv.NewObject().Set("time", next)))
	if err != nil {
		return err
	}
	_, err = q.ExecContext(ctx, `INSERT OR IGNORE INTO device_sync_items
        (user_id, agent_id, device_id, kind, item_key, starts_at, payload_json) VALUES (?, ?, ?, 'alarm', ?, ?, ?)`,
		userID, agentID, deviceID, next, next, sealed)
	return err
}

func (p *Phone) completeCommands(ctx context.Context, q querier, userID int64, agentID, deviceID string, raw any) error {
	results, _ := raw.([]any)
	for _, r := range results {
		result, ok := r.(*jsv.Object)
		if !ok {
			if r == nil {
				return typeError("ok")
			}
			result = jsv.NewObject()
		}
		status, errText := "failed", any(nil)
		if result.Val("ok") == true {
			status = "done"
		} else if msg := clip(result.Val("error"), 500); msg != "" {
			errText = msg
		} else {
			errText = "The phone could not make this change."
		}
		payload := result.Val("result")
		sealed, err := p.seal(jsv.Stringify(payload))
		if err != nil {
			return err
		}
		id := jsv.Number(result.Val("id"))
		if !jsv.IsInteger(id) || math.Abs(id) > 1<<53 {
			id = -1 // no command has this id, so nothing is completed
		}
		if _, err := q.ExecContext(ctx, `UPDATE device_sync_commands
    SET status=?, result_json=?, error=?, completed_at=datetime('now')
    WHERE id=? AND user_id=? AND agent_id=? AND device_id=? AND status='pending'`,
			status, sealed, errText, int64(id), userID, agentID, deviceID); err != nil {
			return err
		}
	}
	return nil
}

func (p *Phone) pendingCommands(ctx context.Context, q querier, userID int64, agentID, deviceID string) ([]any, error) {
	rows, err := q.QueryContext(ctx, `SELECT id, action, payload_json FROM device_sync_commands
    WHERE user_id=? AND agent_id=? AND device_id=? AND status='pending' ORDER BY id`, userID, agentID, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	commands := []any{}
	for rows.Next() {
		var id int64
		var action, payload string
		if err := rows.Scan(&id, &action, &payload); err != nil {
			return nil, err
		}
		commands = append(commands, jsv.NewObject().Set("id", float64(id)).Set("action", action).Set("payload", p.payloadOf(payload)))
	}
	return commands, rows.Err()
}

// Scope names one phone of one agent, for reading what it shared.
type Scope struct {
	UserID   int64
	AgentID  string
	DeviceID string
}

func (p *Phone) itemsOf(ctx context.Context, s Scope, kind, extraSQL string, args ...any) ([]*jsv.Object, error) {
	rows, err := p.DB.R.QueryContext(ctx, `SELECT payload_json FROM device_sync_items
    WHERE user_id=? AND agent_id=? AND device_id=? AND kind=? `+extraSQL,
		append([]any{s.UserID, s.AgentID, s.DeviceID, kind}, args...)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*jsv.Object
	for rows.Next() {
		var payload string
		if err := rows.Scan(&payload); err != nil {
			return nil, err
		}
		out = append(out, p.payloadOf(payload))
	}
	return out, rows.Err()
}

// matches is a case-insensitive substring search over the text of values;
// lists are searched item by item.
func matches(query string, values ...any) bool {
	needle := strings.ToLower(text(query))
	if needle == "" {
		return true
	}
	for _, v := range values {
		if items, ok := v.([]any); ok {
			for _, item := range items {
				if strings.Contains(strings.ToLower(text(item)), needle) {
					return true
				}
			}
			continue
		}
		if strings.Contains(strings.ToLower(text(v)), needle) {
			return true
		}
	}
	return false
}

// Calendars lists the calendars the phone shared.
func (p *Phone) Calendars(ctx context.Context, s Scope) ([]*jsv.Object, error) {
	return p.itemsOf(ctx, s, "calendar", "")
}

// Alarms lists the phone's upcoming and recently due alarms, earliest first.
func (p *Phone) Alarms(ctx context.Context, s Scope) ([]*jsv.Object, error) {
	return p.itemsOf(ctx, s, "alarm", "ORDER BY starts_at")
}

// EventQuery selects calendar events overlapping [Start, End) (ISO times).
type EventQuery struct {
	Start, End string
	Query      string
	CalendarID string
	Limit      int
}

// Events lists shared calendar events in a window, earliest first.
func (p *Phone) Events(ctx context.Context, s Scope, q EventQuery) ([]*jsv.Object, error) {
	events, err := p.itemsOf(ctx, s, "event", "AND starts_at < ? AND ends_at >= ? ORDER BY starts_at", q.End, q.Start)
	if err != nil {
		return nil, err
	}
	limit := q.Limit
	if limit == 0 {
		limit = 100
	}
	var out []*jsv.Object
	for _, e := range events {
		if q.CalendarID != "" && e.Val("calendarId") != q.CalendarID {
			continue
		}
		if matches(q.Query, e.Val("title"), e.Val("location"), e.Val("notes"), e.Val("attendees")) {
			out = append(out, e)
		}
	}
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

// Contacts searches the phone's shared contacts by name, address, number or
// organization; limit 0 means 25.
func (p *Phone) Contacts(ctx context.Context, s Scope, query string, limit int) ([]*jsv.Object, error) {
	contacts, err := p.itemsOf(ctx, s, "contact", "ORDER BY item_key")
	if err != nil {
		return nil, err
	}
	if limit == 0 {
		limit = 25
	}
	var out []*jsv.Object
	for _, c := range contacts {
		if matches(query, c.Val("name"), c.Val("emails"), c.Val("phones"), c.Val("organization")) {
			out = append(out, c)
		}
	}
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

// Enqueue stores a change for the phone to make on its next sync.
func (p *Phone) Enqueue(ctx context.Context, s Scope, action string, payload any) (int64, error) {
	sealed, err := p.seal(jsv.Stringify(payload))
	if err != nil {
		return 0, err
	}
	res, err := p.DB.W.ExecContext(ctx, `INSERT INTO device_sync_commands (user_id, agent_id, device_id, action, payload_json)
    VALUES (?, ?, ?, ?, ?)`, s.UserID, s.AgentID, s.DeviceID, action, sealed)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// CommandResult is how a phone answered a change: ok with its result, or a
// failure with the reason.
type CommandResult struct {
	OK     bool
	Result any
	Error  string
}

const commandPoll = 500 * time.Millisecond

// Await waits for the phone to report a change. It returns nil when the change
// is still pending after timeout, or when ctx ends first.
func (p *Phone) Await(ctx context.Context, id int64, timeout time.Duration) (*CommandResult, error) {
	for waited := time.Duration(0); waited <= timeout; waited += commandPoll {
		var status string
		var result, failure sql.NullString
		err := p.DB.R.QueryRowContext(ctx, `SELECT status, result_json, error FROM device_sync_commands WHERE id=?`, id).Scan(&status, &result, &failure)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return nil, err
		}
		if err == nil && status != "pending" {
			if status != "done" {
				return &CommandResult{Error: failure.String}, nil
			}
			plain, err := p.Box.Open(result.String)
			if err != nil {
				return nil, err
			}
			if plain == "" {
				plain = "null"
			}
			value, err := jsv.Decode([]byte(plain))
			return &CommandResult{OK: true, Result: value}, err
		}
		select {
		case <-ctx.Done():
			return nil, nil
		case <-time.After(commandPoll):
		}
	}
	return nil, nil
}
