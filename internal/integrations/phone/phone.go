// Package phone implements phone sharing: the calendars, contacts and Android
// alarms the NeoAgent phone app syncs (internal/mobilesync stores them). Reads
// come from the last sync; changes are queued for the phone to make, and a
// tool waits briefly for the phone to report back.
package phone

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

//go:embed provider.json
var specJSON []byte

const (
	label = "Phone sharing"
	day   = 24 * time.Hour
	// A phone with the app open makes a change within a second or two.
	commandWait = 12 * time.Second
)

// Waker nudges the user's phones to sync now (the device_sync:wake event).
type Waker func(userID int64, deviceID string)

// Options are the provider's collaborators.
type Options struct {
	Store *mobilesync.Phone
	Wake  Waker
	Now   func() time.Time
	// CommandWait overrides how long a change waits for the phone.
	CommandWait time.Duration
}

type provider struct {
	*integrations.AccountProvider
	o Options
}

// New builds the provider.
func New(svc *integrations.Services, o Options) integrations.Provider {
	if o.Now == nil {
		o.Now = time.Now
	}
	if o.CommandWait == 0 {
		o.CommandWait = commandWait
	}
	p := &provider{o: o}
	p.AccountProvider = integrations.NewAccountProvider(svc, integrations.LoadSpec(specJSON), integrations.AccountHooks{
		Env: func(integrations.Scope) integrations.Env {
			return integrations.Env{Configured: true, Missing: []string{}, Summary: "Set up from the NeoAgent app on your phone.", SetupMode: "device"}
		},
		Execute:    p.execute,
		Test:       p.test,
		Disconnect: p.disconnect,
		Summarize:  summarize,
	})
	return p
}

// BeginOAuth: phones connect from the app, never through a redirect.
func (p *provider) BeginOAuth(context.Context, integrations.BeginParams) (integrations.BeginResult, error) {
	return integrations.BeginResult{}, fmt.Errorf("%s is set up from the NeoAgent phone app.", label)
}

// FinishOAuth: there is no callback.
func (p *provider) FinishOAuth(context.Context, integrations.FinishParams) (integrations.FinishResult, error) {
	return integrations.FinishResult{}, fmt.Errorf("%s does not use an OAuth callback.", label)
}

func summarize(s integrations.Snapshot) string {
	if !s.Connection.Connected {
		return label + ": not shared yet. If the user wants their calendar or contacts, they can turn on sharing in the NeoAgent phone app."
	}
	var apps []string
	for _, a := range s.Apps {
		if a.Connection.Connected {
			apps = append(apps, a.Label)
		}
	}
	return fmt.Sprintf("%s: shared from the user's phone (%s). Reads come from the last sync; mention syncedAt when it matters. Changes are made by the phone and can be pending while it is offline.", label, strings.Join(apps, ", "))
}

func text(v any) string { return jsv.Trim(jsv.Text(v)) }

func requireText(v any, name string) (string, error) {
	t := text(v)
	if t == "" {
		return "", fmt.Errorf("%s is required.", name)
	}
	return t, nil
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func isoArg(v any, name string) (string, error) {
	t, ok := jsv.ParseDate(text(v))
	if !ok {
		return "", fmt.Errorf("%s must be an ISO date or datetime.", name)
	}
	return jsv.ISO(t), nil
}

func metadataOf(conn integrations.Connection) *jsv.Object {
	return jsv.ParseObject(conn.MetadataJSON)
}

func scopeOf(tc *integrations.ToolContext) mobilesync.Scope {
	return mobilesync.Scope{UserID: tc.Connection.UserID, AgentID: tc.Connection.AgentID, DeviceID: integrations.Str(tc.Credentials["deviceId"])}
}

// freshness says which phone answered and when it last synced.
func freshness(tc *integrations.ToolContext) *jsv.Object {
	synced := metadataOf(tc.Connection).Val("syncedAt")
	if !jsv.Truthy(synced) {
		synced = nil
	}
	return jsv.NewObject().Set("device", tc.Connection.AccountEmail).Set("syncedAt", synced)
}

// eventChanges are the event fields a call sets, as the phone expects them.
func eventChanges(args map[string]any, out *jsv.Object) error {
	for _, key := range []string{"title", "location", "notes"} {
		if v, ok := args[key]; ok {
			out.Set(key, text(v))
		}
	}
	for _, key := range []string{"start", "end"} {
		if v, ok := args[key]; ok {
			iso, err := isoArg(v, key)
			if err != nil {
				return err
			}
			out.Set(key, iso)
		}
	}
	if allDay, ok := args["all_day"].(bool); ok {
		out.Set("allDay", allDay)
	}
	return nil
}

// command is the change a write tool asks the phone to make.
func command(name string, args map[string]any) (string, *jsv.Object, bool, error) {
	switch name {
	case "phone_create_event":
		title, err := requireText(args["title"], "title")
		if err != nil {
			return "", nil, true, err
		}
		withTitle := map[string]any{}
		for k, v := range args {
			withTitle[k] = v
		}
		withTitle["title"] = title
		payload := jsv.NewObject().Set("calendarId", nullable(text(args["calendar_id"])))
		return "create_event", payload, true, eventChanges(withTitle, payload)
	case "phone_update_event":
		id, err := requireText(args["event_id"], "event_id")
		if err != nil {
			return "", nil, true, err
		}
		payload := jsv.NewObject().Set("eventId", id)
		return "update_event", payload, true, eventChanges(args, payload)
	case "phone_delete_event":
		id, err := requireText(args["event_id"], "event_id")
		return "delete_event", jsv.NewObject().Set("eventId", id), true, err
	case "phone_create_contact":
		name, err := requireText(args["name"], "name")
		if err != nil {
			return "", nil, true, err
		}
		return "create_contact", jsv.NewObject().Set("name", name).Set("email", nullable(text(args["email"]))).
			Set("phone", nullable(text(args["phone"]))).Set("organization", nullable(text(args["organization"]))), true, nil
	}
	return "", nil, false, nil
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	action, payload, isWrite, err := command(name, args)
	if err != nil {
		return nil, err
	}
	if isWrite {
		return p.write(ctx, action, payload, tc)
	}
	result, err := p.read(ctx, name, args, scopeOf(tc))
	if err != nil {
		return nil, err
	}
	if result == nil {
		return nil, fmt.Errorf("Unsupported %s tool: %s", label, name)
	}
	return freshness(tc).Assign(result), nil
}

func (p *provider) write(ctx context.Context, action string, payload *jsv.Object, tc *integrations.ToolContext) (any, error) {
	scope := scopeOf(tc)
	id, err := p.o.Store.Enqueue(ctx, scope, action, payload)
	if err != nil {
		return nil, err
	}
	if p.o.Wake != nil {
		p.o.Wake(scope.UserID, scope.DeviceID)
	}
	outcome, err := p.o.Store.Await(ctx, id, p.o.CommandWait)
	if err != nil {
		return nil, err
	}
	if outcome == nil {
		if ctx.Err() != nil {
			return nil, context.Cause(ctx)
		}
		return jsv.NewObject().Set("status", "queued").Assign(freshness(tc)).
			Set("note", "The phone has not picked this up yet. It will make the change the next time it syncs; tell the user it is pending, not done."), nil
	}
	if !outcome.OK {
		return nil, errors.New(outcome.Error)
	}
	out := jsv.NewObject().Set("status", "done").Assign(freshness(tc))
	if result, ok := outcome.Result.(*jsv.Object); ok {
		out.Assign(result)
	}
	return out, nil
}

func objects[T any](list []T) []any {
	out := make([]any, len(list))
	for i, v := range list {
		out[i] = v
	}
	return out
}

func (p *provider) read(ctx context.Context, name string, args map[string]any, scope mobilesync.Scope) (*jsv.Object, error) {
	s := p.o.Store
	switch name {
	case "phone_list_alarms":
		alarms, err := s.Alarms(ctx, scope)
		return jsv.NewObject().Set("alarms", objects(alarms)), err
	case "phone_list_calendars":
		calendars, err := s.Calendars(ctx, scope)
		return jsv.NewObject().Set("calendars", objects(calendars)), err
	case "phone_list_events":
		start := jsv.ISO(p.o.Now())
		if jsv.Truthy(args["start"]) {
			iso, err := isoArg(args["start"], "start")
			if err != nil {
				return nil, err
			}
			start = iso
		}
		var end string
		if jsv.Truthy(args["end"]) {
			iso, err := isoArg(args["end"], "end")
			if err != nil {
				return nil, err
			}
			end = iso
		} else {
			t, _ := jsv.ParseDate(start)
			end = jsv.ISO(t.Add(7 * day))
		}
		events, err := s.Events(ctx, scope, mobilesync.EventQuery{Start: start, End: end, Query: text(args["query"]), CalendarID: text(args["calendar_id"])})
		return jsv.NewObject().Set("events", objects(events)), err
	case "phone_search_contacts":
		n, ok := integrations.JSNumber(args["limit"])
		if !ok || n == 0 {
			n = 25
		}
		limit := int(math.Max(1, math.Min(n, 100)))
		contacts, err := s.Contacts(ctx, scope, text(args["query"]), limit)
		return jsv.NewObject().Set("contacts", objects(contacts)), err
	}
	return nil, nil
}

func (p *provider) test(_ context.Context, tc *integrations.ToolContext) error {
	if freshness(tc).Val("syncedAt") == nil {
		return errors.New("The phone has not synced yet. Open NeoAgent on it.")
	}
	return nil
}

func (p *provider) disconnect(ctx context.Context, tc *integrations.ToolContext) error {
	return p.o.Store.Forget(ctx, tc.Connection.UserID, tc.Connection.AgentID, integrations.Str(metadataOf(tc.Connection).Val("deviceId")))
}
