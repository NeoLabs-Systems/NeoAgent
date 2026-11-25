// Package weather is the keyless Weather integration on Open-Meteo's public
// geocoding and forecast APIs.
package weather

import (
	"context"
	"crypto/rand"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

const (
	appID          = "forecast"
	accountEmail   = "public@open-meteo"
	sessionTTL     = 30 * time.Minute
	geocodingURL   = "https://geocoding-api.open-meteo.com/v1/search"
	forecastURL    = "https://api.open-meteo.com/v1/forecast"
	currentFields  = "temperature_2m,apparent_temperature,precipitation,rain,showers,snowfall,weather_code,wind_speed_10m,wind_gusts_10m,wind_direction_10m,is_day"
	hourlyFields   = "temperature_2m,precipitation,rain,showers,snowfall,weather_code,wind_speed_10m,wind_gusts_10m,is_day"
	defaultHorizon = 24
)

var codeLabels = map[int]string{
	0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 48: "Depositing rime fog",
	51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle", 56: "Light freezing drizzle", 57: "Dense freezing drizzle",
	61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain", 66: "Light freezing rain", 67: "Heavy freezing rain",
	71: "Slight snowfall", 73: "Moderate snowfall", 75: "Heavy snowfall", 77: "Snow grains",
	80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
	85: "Slight snow showers", 86: "Heavy snow showers",
	95: "Thunderstorm", 96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail",
}

type session struct {
	scope        integrations.Scope
	connectionID *int64
	created      time.Time
}

// Provider is the Weather integration. Connecting stores one public
// connection and opens a session the connect page reports as connected.
type Provider struct {
	*integrations.AccountProvider
	svc *integrations.Services

	mu       sync.Mutex
	sessions map[string]session
}

// New builds the provider.
func New(svc *integrations.Services) *Provider {
	p := &Provider{svc: svc, sessions: map[string]session{}}
	p.AccountProvider = integrations.NewAccountProvider(svc, integrations.LoadSpec(specJSON), integrations.AccountHooks{
		Env: func(integrations.Scope) integrations.Env {
			return integrations.Env{Configured: true, Missing: []string{}, Summary: "Weather is ready for account connections."}
		},
		Execute: p.execute,
		Summarize: func(s integrations.Snapshot) string {
			if !s.Connection.Connected {
				return "Weather: available but not connected yet. Ask the user to connect Weather in Official Integrations."
			}
			return "Weather: connected with keyless Open-Meteo tools for geocoding, current conditions, and hourly forecast."
		},
		Decorate: func(s *integrations.Snapshot, _ integrations.Scope) {
			s.Extra = map[string]any{"connectPrompt": s.Extra["connectPrompt"]}
		},
	})
	return p
}

// BeginConnection stores the public connection; there is nothing to approve.
func (p *Provider) BeginConnection(ctx context.Context, scope integrations.Scope, appKey string) (integrations.ConnectionStart, error) {
	if _, ok := p.App(appKey); !ok {
		return integrations.ConnectionStart{}, fmt.Errorf("Unknown Weather app: %s", orMissing(appKey))
	}
	// The connection holds no secret; Node stores its credentials unsealed.
	if err := p.svc.UpsertConnection(ctx, integrations.ConnectedAccount{
		UserID: scope.UserID, AgentID: scope.AgentID, ProviderKey: "weather", AppKey: appID, AccountEmail: accountEmail,
		Scopes: []string{"open-meteo:public"}, CredentialsJSON: "{}",
		Metadata: map[string]any{"source": "open-meteo", "mode": "public"},
	}); err != nil {
		return integrations.ConnectionStart{}, err
	}
	conn, err := p.svc.FindAppConnection(ctx, scope.UserID, scope.AgentID, "weather", appID, accountEmail)
	if err != nil {
		return integrations.ConnectionStart{}, err
	}
	raw := make([]byte, 18)
	if _, err := rand.Read(raw); err != nil {
		return integrations.ConnectionStart{}, err
	}
	id := hex.EncodeToString(raw)
	s := session{scope: scope, created: p.svc.Now()}
	if conn != nil {
		s.connectionID = &conn.ID
	}
	p.mu.Lock()
	p.prune()
	p.sessions[id] = s
	p.mu.Unlock()
	return integrations.ConnectionStart{Status: "interactive_connect", SessionID: id, URL: "/api/integrations/weather/connect/" + id}, nil
}

// prune drops expired sessions; the caller holds mu.
func (p *Provider) prune() {
	now := p.svc.Now()
	for id, s := range p.sessions {
		if now.Sub(s.created) > sessionTTL {
			delete(p.sessions, id)
		}
	}
}

// ConnectionSession reports a session of the signed-in account.
func (p *Provider) ConnectionSession(scope integrations.Scope, id string) (*integrations.ConnectionSession, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.prune()
	s, ok := p.sessions[id]
	if !ok || s.scope != scope {
		return nil, false
	}
	return &integrations.ConnectionSession{ID: id, Provider: "weather", AppID: appID, Status: "connected",
		ConnectionID: s.connectionID, AccountEmail: accountEmail}, true
}

func orMissing(s string) string {
	if strings.TrimSpace(s) == "" {
		return "missing app key"
	}
	return s
}

// number is Number(value) with Number.isFinite, from a decoded member that
// may be absent (NaN) or null (0).
func number(m map[string]any, key string) (float64, bool) {
	v, present := m[key]
	if !present {
		return 0, false
	}
	n, ok := integrations.JSNumber(v)
	return n, ok && !math.IsInf(n, 0)
}

func numberOr(m map[string]any, key string, fallback any) any {
	if n, ok := number(m, key); ok {
		return n
	}
	return fallback
}

func at(list any, i int) map[string]any {
	l, _ := list.([]any)
	if i >= len(l) {
		return map[string]any{}
	}
	return map[string]any{"v": l[i]}
}

func label(code float64, ok bool) string {
	if !ok || code != math.Trunc(code) {
		return "Unknown"
	}
	if l, found := codeLabels[int(code)]; found {
		return l
	}
	return "Unknown"
}

func orNil(v any) any {
	if integrations.Truthy(v) {
		return v
	}
	return nil
}

func decode(raw json.RawMessage) map[string]any {
	var m map[string]any
	if json.Unmarshal(raw, &m) != nil || m == nil {
		return map[string]any{}
	}
	return m
}

func (p *Provider) geocode(ctx context.Context, query string, limit float64) ([]dyn.Ordered, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, errors.New("location is required when latitude/longitude are not provided.")
	}
	count := math.Max(1, math.Min(limitOr(limit, 1), 10))
	target := geocodingURL + "?name=" + encodeURIComponent(query) + "&count=" + dyn.Number(count) + "&language=en&format=json"
	raw, err := p.svc.Client("Open-Meteo geocoding").JSON(ctx, oauthclient.Request{URL: target})
	if err != nil {
		return nil, err
	}
	results, _ := decode(raw)["results"].([]any)
	if len(results) == 0 {
		return nil, fmt.Errorf("No location match found for \"%s\".", query)
	}
	out := make([]dyn.Ordered, 0, len(results))
	for _, r := range results {
		item, _ := r.(map[string]any)
		if item == nil {
			item = map[string]any{}
		}
		out = append(out, dyn.Ordered{
			{Key: "name", Value: orNil(item["name"])},
			{Key: "latitude", Value: numberOr(item, "latitude", nil)},
			{Key: "longitude", Value: numberOr(item, "longitude", nil)},
			{Key: "country", Value: orNil(item["country"])},
			{Key: "admin1", Value: orNil(item["admin1"])},
			{Key: "timezone", Value: orNil(item["timezone"])},
			{Key: "population", Value: numberOr(item, "population", nil)},
		})
	}
	return out, nil
}

// limitOr is Number(v) || fallback for an already-converted number.
func limitOr(n, fallback float64) float64 {
	if n == 0 || math.IsNaN(n) {
		return fallback
	}
	return n
}

func argNumber(args map[string]any, key string) float64 {
	n, ok := number(args, key)
	if !ok {
		return math.NaN()
	}
	return n
}

// encodeURIComponent is JavaScript's encodeURIComponent.
func encodeURIComponent(s string) string {
	const keep = "-_.!~*'()"
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte(keep, c) >= 0 {
			b.WriteByte(c)
			continue
		}
		fmt.Fprintf(&b, "%%%02X", c)
	}
	return b.String()
}

type location struct {
	latitude, longitude float64
	label               string
	timezone            string
}

func fixed4(f float64) string { return strconv.FormatFloat(f, 'f', 4, 64) }

func (p *Provider) resolve(ctx context.Context, args map[string]any, conn integrations.Connection) (location, error) {
	lat, latOK := number(args, "latitude")
	lon, lonOK := number(args, "longitude")
	if latOK && lonOK {
		return location{latitude: lat, longitude: lon, label: fixed4(lat) + ", " + fixed4(lon)}, nil
	}
	if name := strings.TrimSpace(integrations.Str(args["location"])); name != "" {
		matches, err := p.geocode(ctx, name, 1)
		if err != nil {
			return location{}, err
		}
		best := matches[0]
		var parts []string
		for _, k := range []string{"name", "admin1", "country"} {
			if v := best.Get(k); integrations.Truthy(v) {
				parts = append(parts, integrations.Str(v))
			}
		}
		loc := location{label: strings.Join(parts, ", ")}
		if loc.label == "" {
			loc.label = name
		}
		loc.latitude, _ = best.Get("latitude").(float64)
		loc.longitude, _ = best.Get("longitude").(float64)
		if tz, ok := best.Get("timezone").(string); ok {
			loc.timezone = tz
		}
		return loc, nil
	}
	var meta map[string]any
	if json.Unmarshal([]byte(conn.MetadataJSON), &meta) == nil && meta != nil {
		mLat, okLat := number(meta, "latitude")
		mLon, okLon := number(meta, "longitude")
		if okLat && okLon {
			label := integrations.Str(meta["locationLabel"])
			if !integrations.Truthy(meta["locationLabel"]) {
				label = fixed4(mLat) + ", " + fixed4(mLon)
			}
			tz := ""
			if integrations.Truthy(meta["timezone"]) {
				tz = integrations.Str(meta["timezone"])
			}
			return location{latitude: mLat, longitude: mLon, label: label, timezone: tz}, nil
		}
	}
	return location{}, errors.New("Provide either location or latitude/longitude for weather tools.")
}

type forecast struct {
	location dyn.Ordered
	current  dyn.Ordered
	hourly   []dyn.Ordered
}

func (p *Provider) forecast(ctx context.Context, loc location, horizon float64) (forecast, error) {
	tz := loc.timezone
	if tz == "" {
		tz = "auto"
	}
	target, err := oauthclient.SetParams(forecastURL, oauthclient.Query{
		{"latitude", jsNumberText(loc.latitude)}, {"longitude", jsNumberText(loc.longitude)},
		{"current", currentFields}, {"hourly", hourlyFields},
		{"forecast_hours", dyn.Number(math.Max(1, math.Min(limitOr(horizon, defaultHorizon), 72)))}, {"timezone", tz},
	})
	if err != nil {
		return forecast{}, err
	}
	raw, err := p.svc.Client("Open-Meteo forecast").JSON(ctx, oauthclient.Request{URL: target})
	if err != nil {
		return forecast{}, err
	}
	result := decode(raw)
	hourly, _ := result["hourly"].(map[string]any)
	if hourly == nil {
		hourly = map[string]any{}
	}
	times, _ := hourly["time"].([]any)
	rows := make([]dyn.Ordered, 0, len(times))
	for i, t := range times {
		code, codeOK := number(at(hourly["weather_code"], i), "v")
		var weatherCode any
		if codeOK {
			weatherCode = code
		}
		isDay, _ := number(at(hourly["is_day"], i), "v")
		rows = append(rows, dyn.Ordered{
			{Key: "time", Value: t},
			{Key: "temperature", Value: numberOr(at(hourly["temperature_2m"], i), "v", nil)},
			{Key: "precipitation", Value: numberOr(at(hourly["precipitation"], i), "v", 0.0)},
			{Key: "rain", Value: numberOr(at(hourly["rain"], i), "v", 0.0)},
			{Key: "showers", Value: numberOr(at(hourly["showers"], i), "v", 0.0)},
			{Key: "snowfall", Value: numberOr(at(hourly["snowfall"], i), "v", 0.0)},
			{Key: "windSpeed", Value: numberOr(at(hourly["wind_speed_10m"], i), "v", 0.0)},
			{Key: "windGust", Value: numberOr(at(hourly["wind_gusts_10m"], i), "v", 0.0)},
			{Key: "weatherCode", Value: weatherCode},
			{Key: "weatherLabel", Value: label(code, codeOK)},
			{Key: "isDay", Value: isDay == 1},
		})
	}
	var tzOut any
	if integrations.Truthy(result["timezone"]) {
		tzOut = result["timezone"]
	} else if loc.timezone != "" {
		tzOut = loc.timezone
	}
	current := dyn.Ordered{}
	cur, _ := result["current"].(map[string]any)
	// Members keep the server's order, as the spread in Node does.
	for _, k := range orderedKeys(raw, "current") {
		current = append(current, dyn.KV{Key: k, Value: cur[k]})
	}
	code, codeOK := number(cur, "weather_code")
	current = current.Set("weather_label", label(code, codeOK))
	return forecast{
		location: dyn.Ordered{
			{Key: "label", Value: loc.label},
			{Key: "latitude", Value: numberOr(result, "latitude", loc.latitude)},
			{Key: "longitude", Value: numberOr(result, "longitude", loc.longitude)},
			{Key: "timezone", Value: tzOut},
			{Key: "elevation", Value: numberOr(result, "elevation", nil)},
		},
		current: current,
		hourly:  rows,
	}, nil
}

// jsNumberText is String(number).
func jsNumberText(f float64) string { return dyn.Number(f) }

// orderedKeys lists the members of the object at key in document order.
func orderedKeys(raw json.RawMessage, key string) []string {
	var top map[string]json.RawMessage
	if json.Unmarshal(raw, &top) != nil {
		return nil
	}
	inner, ok := top[key]
	if !ok {
		return nil
	}
	dec := json.NewDecoder(strings.NewReader(string(inner)))
	if tok, err := dec.Token(); err != nil || tok != json.Delim('{') {
		return nil
	}
	var keys []string
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return keys
		}
		k, _ := tok.(string)
		keys = append(keys, k)
		var skip json.RawMessage
		if dec.Decode(&skip) != nil {
			return keys
		}
	}
	return keys
}

func (p *Provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	switch name {
	case "weather_search_locations":
		query := strings.TrimSpace(integrations.Str(args["query"]))
		if query == "" {
			return nil, errors.New("query is required.")
		}
		limit := math.Max(1, math.Min(limitOr(argNumber(args, "limit"), 5), 10))
		results, err := p.geocode(ctx, query, limit)
		if err != nil {
			return nil, err
		}
		return dyn.Ordered{{Key: "query", Value: query}, {Key: "count", Value: len(results)}, {Key: "results", Value: results}}, nil
	case "weather_get_current":
		loc, err := p.resolve(ctx, args, tc.Connection)
		if err != nil {
			return nil, err
		}
		f, err := p.forecast(ctx, loc, 1)
		if err != nil {
			return nil, err
		}
		return dyn.Ordered{{Key: "location", Value: f.location}, {Key: "current", Value: f.current}}, nil
	case "weather_get_forecast":
		loc, err := p.resolve(ctx, args, tc.Connection)
		if err != nil {
			return nil, err
		}
		hours := math.Max(1, math.Min(limitOr(argNumber(args, "forecast_hours"), defaultHorizon), 72))
		f, err := p.forecast(ctx, loc, hours)
		if err != nil {
			return nil, err
		}
		return dyn.Ordered{{Key: "location", Value: f.location}, {Key: "current", Value: f.current},
			{Key: "hourly", Value: f.hourly}, {Key: "horizonHours", Value: hours}}, nil
	}
	return nil, fmt.Errorf("Unsupported Weather tool: %s", name)
}
