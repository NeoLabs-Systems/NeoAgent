// Package mobilesync stores what a phone shares with the server: Health Connect
// samples (/api/mobile/health) and the calendars, contacts and alarms of a
// paired phone (/api/mobile/device-sync). It serves the same tables and the
// same request and response shapes as the Node server's services/health and
// services/integrations/phone/store.
package mobilesync

import (
	"context"
	"crypto/sha1"
	"database/sql"
	"encoding/hex"
	"errors"
	"math"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/reqx"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// HealthRecord is one normalized sample of a health sync.
type HealthRecord struct {
	MetricType       string
	RecordID         string
	StartTime        *string
	EndTime          *string
	RecordedAt       *string
	NumericValue     *float64
	TextValue        *string
	Unit             *string
	SourceAppID      *string
	SourceDevice     *string
	LastModifiedTime *string
	PayloadJSON      string
}

// SyncResult is what a stored health sync reports back to the phone.
type SyncResult struct {
	RunID          string   `json:"runId"`
	Source         string   `json:"source"`
	Provider       *string  `json:"provider"`
	WindowStart    *string  `json:"windowStart"`
	WindowEnd      *string  `json:"windowEnd"`
	RecordCount    int      `json:"recordCount"`
	AcceptedMetric []string `json:"acceptedMetrics"`
	// Records are the stored samples; they are announced to event triggers and
	// not part of the response.
	Records []HealthRecord `json:"-"`
}

// Health stores health syncs.
type Health struct{ DB *dbx.DB }

func asText(v any, present bool) *string {
	if !present || v == nil {
		return nil
	}
	text := jsv.Trim(jsv.String(v))
	if text == "" {
		return nil
	}
	return &text
}

// firstTruthy is `a || b || ...` over members of record and payload.
func firstTruthy(values ...any) (any, bool) {
	for _, v := range values {
		if jsv.Truthy(v) {
			return v, true
		}
	}
	return nil, false
}

func isoOrNil(v any) *string {
	if !jsv.Truthy(v) {
		return nil
	}
	t, ok := jsv.ParseDate(v)
	if !ok {
		return nil
	}
	s := jsv.ISO(t)
	return &s
}

func fallbackRecordID(metricType string, record *jsv.Object) string {
	sum := sha1.Sum([]byte(metricType + "\n" + jsv.Stringify(record)))
	return hex.EncodeToString(sum[:])
}

// errNullRecord is the TypeError Node raised for a null entry in records.
var errNullRecord = errors.New("Cannot read properties of null (reading 'metricType')")

func normalizeRecord(raw any) (*HealthRecord, error) {
	if raw == nil {
		return nil, errNullRecord
	}
	record, ok := raw.(*jsv.Object)
	if !ok {
		return nil, nil
	}
	payload := jsv.NewObject()
	var payloadValue any = payload
	if p := record.Val("payload"); jsv.Truthy(p) {
		switch p.(type) {
		case *jsv.Object, []any:
			payloadValue = p
		}
	}
	payloadObj, _ := payloadValue.(*jsv.Object)

	metric, _ := firstTruthy(record.Val("metricType"), record.Val("type"))
	metricType := asText(metric, true)
	if metricType == nil {
		return nil, nil
	}
	rec := &HealthRecord{MetricType: *metricType}

	id, hasID := firstTruthy(record.Val("recordId"), payloadObj.Val("recordId"))
	if text := asText(id, hasID); text != nil {
		rec.RecordID = *text
	} else {
		rec.RecordID = fallbackRecordID(rec.MetricType, record)
	}
	start, _ := firstTruthy(record.Val("startTime"), payloadObj.Val("startTime"))
	end, _ := firstTruthy(record.Val("endTime"), payloadObj.Val("endTime"))
	recorded, _ := firstTruthy(record.Val("recordedAt"), payloadObj.Val("recordedAt"), record.Val("endTime"), record.Val("startTime"))
	rec.StartTime, rec.EndTime, rec.RecordedAt = isoOrNil(start), isoOrNil(end), isoOrNil(recorded)

	if v, present := record.Get("numericValue"); present {
		if n := jsv.Number(v); jsv.Finite(n) {
			rec.NumericValue = &n
		}
	}
	text, present := record.Get("textValue")
	rec.TextValue = asText(text, present)
	unit, present := record.Get("unit")
	rec.Unit = asText(unit, present)
	app, hasApp := firstTruthy(record.Val("sourceAppId"), payloadObj.Val("sourceAppId"))
	rec.SourceAppID = asText(app, hasApp)
	device, hasDevice := firstTruthy(record.Val("sourceDevice"), payloadObj.Val("sourceDevice"))
	rec.SourceDevice = asText(device, hasDevice)
	modified, _ := firstTruthy(record.Val("lastModifiedTime"), payloadObj.Val("lastModifiedTime"))
	rec.LastModifiedTime = isoOrNil(modified)
	rec.PayloadJSON = jsv.Stringify(payloadValue)
	return rec, nil
}

// ErrPayload is returned for a body that is not a JSON object.
var ErrPayload = errors.New("Health sync payload must be a JSON object")

// Ingest stores one health sync of a phone.
func (h *Health) Ingest(ctx context.Context, userID int64, body any) (*SyncResult, error) {
	if userID == 0 {
		return nil, errors.New("Missing user")
	}
	obj, isObject := body.(*jsv.Object)
	if body == nil {
		obj, isObject = jsv.NewObject(), true
	}
	if !isObject {
		return nil, ErrPayload
	}
	runID, err := reqx.NewUUID()
	if err != nil {
		return nil, err
	}
	source := "android-health-connect"
	if s := asText(obj.Val("source"), obj.Has("source")); s != nil {
		source = *s
	}
	provider := asText(obj.Val("provider"), obj.Has("provider"))
	result := &SyncResult{
		RunID: runID, Source: source, Provider: provider,
		WindowStart: isoOrNil(obj.Val("windowStart")), WindowEnd: isoOrNil(obj.Val("windowEnd")),
		AcceptedMetric: []string{},
	}
	if list, ok := obj.Val("records").([]any); ok {
		for _, raw := range list {
			rec, err := normalizeRecord(raw)
			if err != nil {
				return nil, err
			}
			if rec != nil {
				result.Records = append(result.Records, *rec)
			}
		}
	}
	result.RecordCount = len(result.Records)
	seen := map[string]bool{}
	for _, rec := range result.Records {
		if !seen[rec.MetricType] {
			seen[rec.MetricType] = true
			result.AcceptedMetric = append(result.AcceptedMetric, rec.MetricType)
		}
	}
	summary := obj.Val("summary")
	if !jsv.Truthy(summary) {
		summary = jsv.NewObject()
	}
	err = h.store(ctx, userID, result, jsv.Stringify(summary), jsv.Stringify(obj))
	return result, err
}

func (h *Health) store(ctx context.Context, userID int64, run *SyncResult, summaryJSON, payloadJSON string) error {
	tx, err := h.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `
  INSERT INTO health_sync_runs (
    id, user_id, source, provider, sync_window_start, sync_window_end,
    record_count, summary_json, payload_json
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		run.RunID, userID, run.Source, run.Provider, run.WindowStart, run.WindowEnd, run.RecordCount, summaryJSON, payloadJSON); err != nil {
		return err
	}
	upsert, err := tx.PrepareContext(ctx, `
  INSERT INTO health_metric_samples (
    user_id, sync_run_id, metric_type, record_id, start_time, end_time, recorded_at,
    numeric_value, text_value, unit, source_app_id, source_device, last_modified_time, payload_json
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT(user_id, metric_type, record_id) DO UPDATE SET
    sync_run_id = excluded.sync_run_id,
    start_time = excluded.start_time,
    end_time = excluded.end_time,
    recorded_at = excluded.recorded_at,
    numeric_value = excluded.numeric_value,
    text_value = excluded.text_value,
    unit = excluded.unit,
    source_app_id = excluded.source_app_id,
    source_device = excluded.source_device,
    last_modified_time = excluded.last_modified_time,
    payload_json = excluded.payload_json,
    updated_at = datetime('now')`)
	if err != nil {
		return err
	}
	defer upsert.Close()
	for _, r := range run.Records {
		if _, err := upsert.ExecContext(ctx, userID, run.RunID, r.MetricType, r.RecordID, r.StartTime, r.EndTime, r.RecordedAt,
			r.NumericValue, r.TextValue, r.Unit, r.SourceAppID, r.SourceDevice, r.LastModifiedTime, r.PayloadJSON); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (h *Health) lastRun(ctx context.Context, userID int64, nonEmpty bool) (any, error) {
	query := `
    SELECT id, source, provider, sync_window_start, sync_window_end, record_count, summary_json, created_at
    FROM health_sync_runs
    WHERE user_id = ?` + map[bool]string{true: " AND record_count > 0", false: ""}[nonEmpty] + `
    ORDER BY created_at DESC, rowid DESC
    LIMIT 1`
	var id, source string
	var provider, start, end, summaryJSON, created sql.NullString
	var count sql.NullInt64
	err := h.DB.R.QueryRowContext(ctx, query, userID).Scan(&id, &source, &provider, &start, &end, &count, &summaryJSON, &created)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var summary any = jsv.NewObject()
	if text := summaryJSON.String; summaryJSON.Valid && text != "" {
		if v, err := jsv.Decode([]byte(text)); err == nil {
			summary = v
		}
	}
	row := jsv.NewObject().Set("id", id).Set("source", source).
		Set("provider", nullable(provider)).Set("sync_window_start", nullable(start)).Set("sync_window_end", nullable(end))
	if count.Valid {
		row.Set("record_count", float64(count.Int64))
	} else {
		row.Set("record_count", nil)
	}
	row.Set("summary_json", nullable(summaryJSON)).Set("created_at", nullable(created)).Set("summary", summary)
	return row, nil
}

func nullable(s sql.NullString) any {
	if !s.Valid {
		return nil
	}
	return s.String
}

// Status describes the phone's latest syncs and what it has sent.
func (h *Health) Status(ctx context.Context, userID int64) (*jsv.Object, error) {
	last, err := h.lastRun(ctx, userID, false)
	if err != nil {
		return nil, err
	}
	lastNonEmpty, err := h.lastRun(ctx, userID, true)
	if err != nil {
		return nil, err
	}
	metrics, err := h.Metrics(ctx, userID)
	if err != nil {
		return nil, err
	}
	list := []any{}
	for _, m := range metrics {
		list = append(list, jsv.NewObject().Set("metricType", m.MetricType).Set("sampleCount", float64(m.SampleCount)).Set("lastSeenAt", m.LastSeenAt))
	}
	return jsv.NewObject().Set("lastRun", last).Set("lastNonEmptyRun", lastNonEmpty).Set("metrics", list), nil
}

// Metric counts the samples stored for one kind of measurement.
type Metric struct {
	MetricType  string
	SampleCount int64
	LastSeenAt  any // the newest sample time, nil when unknown
}

// Metrics lists every metric the phone has sent, by name.
func (h *Health) Metrics(ctx context.Context, userID int64) ([]Metric, error) {
	rows, err := h.DB.R.QueryContext(ctx, `
    SELECT metric_type, COUNT(*) AS sample_count, MAX(COALESCE(end_time, recorded_at, start_time)) AS last_seen_at
    FROM health_metric_samples
    WHERE user_id = ?
    GROUP BY metric_type
    ORDER BY metric_type ASC
  `, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var metrics []Metric
	for rows.Next() {
		var m Metric
		var seen sql.NullString
		if err := rows.Scan(&m.MetricType, &m.SampleCount, &seen); err != nil {
			return nil, err
		}
		m.LastSeenAt = nullable(seen)
		metrics = append(metrics, m)
	}
	return metrics, rows.Err()
}

var (
	camelBoundary = regexp.MustCompile(`([a-z])([A-Z])`)
	separators    = regexp.MustCompile(`[\s-]+`)
)

// metricAliases map synonym forms to the stored metric_type values.
var metricAliases = map[string]string{
	"heartbeat": "heart_rate", "heartrate": "heart_rate", "heart_beat": "heart_rate", "bpm": "heart_rate", "pulse": "heart_rate",
	"sleep": "sleep_session", "sleeping": "sleep_session",
	"exercise": "exercise_session", "workout": "exercise_session", "activity": "exercise_session",
	"body_weight": "weight", "bodyweight": "weight", "mass": "weight",
	"step_count": "steps", "stepcount": "steps", "step": "steps",
}

// NormalizeMetricType maps any casing or spelling of a metric ("HeartRate",
// "Heart Rate", "bpm") to the name it is stored under ("heart_rate").
func NormalizeMetricType(raw string) string {
	normalized := strings.ToLower(separators.ReplaceAllString(camelBoundary.ReplaceAllString(jsv.Trim(raw), "${1}_${2}"), "_"))
	if alias, ok := metricAliases[normalized]; ok {
		return alias
	}
	return normalized
}

// HealthData is what ReadData reports for one metric.
type HealthData struct {
	MetricType    string
	Summary       map[string]any
	RecentRecords []map[string]any
}

// ReadData summarizes the stored samples of one metric and lists the most
// recent ones, for the agent's health tool. limit is capped at 200.
func (h *Health) ReadData(ctx context.Context, userID int64, metricType string, limit int) (*HealthData, error) {
	normalized := NormalizeMetricType(metricType)
	var count int64
	var total, avg, lowest, highest sql.NullFloat64
	var windowStart, windowEnd sql.NullString
	if err := h.DB.R.QueryRowContext(ctx, `
    SELECT
      COUNT(*), SUM(numeric_value), AVG(numeric_value), MIN(numeric_value), MAX(numeric_value),
      MIN(COALESCE(start_time, recorded_at)), MAX(COALESCE(end_time, recorded_at, start_time))
    FROM health_metric_samples
    WHERE user_id = ? AND metric_type = ?`, userID, normalized).Scan(&count, &total, &avg, &lowest, &highest, &windowStart, &windowEnd); err != nil {
		return nil, err
	}
	rows, err := h.DB.R.QueryContext(ctx, `
    SELECT start_time, end_time, recorded_at, numeric_value, text_value, unit, payload_json
    FROM health_metric_samples
    WHERE user_id = ? AND metric_type = ?
    ORDER BY COALESCE(end_time, recorded_at, start_time) DESC
    LIMIT ?`, userID, normalized, min(limit, 200))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	data := &HealthData{MetricType: normalized, RecentRecords: []map[string]any{}}
	var firstUnit any
	for rows.Next() {
		var start, end, recorded, text, unit, payload sql.NullString
		var value sql.NullFloat64
		if err := rows.Scan(&start, &end, &recorded, &value, &text, &unit, &payload); err != nil {
			return nil, err
		}
		if len(data.RecentRecords) == 0 {
			firstUnit = nullable(unit)
		}
		var parsed any
		if payload.Valid && payload.String != "" {
			if v, err := jsv.Decode([]byte(payload.String)); err == nil {
				parsed = v
			}
		}
		data.RecentRecords = append(data.RecentRecords, map[string]any{
			"startTime": nullable(start), "endTime": nullable(end), "recordedAt": nullable(recorded),
			"value": nullableFloat(value), "text": nullable(text), "unit": nullable(unit), "payload": parsed,
		})
	}
	var rounded any
	if avg.Valid {
		rounded = roundTo(avg.Float64)
	}
	data.Summary = map[string]any{
		"recordCount": float64(count), "total": nullableFloat(total), "avg": rounded, "min": nullableFloat(lowest),
		"max": nullableFloat(highest), "windowStart": nullable(windowStart), "windowEnd": nullable(windowEnd), "unit": firstUnit,
	}
	return data, rows.Err()
}

// roundTo is Math.round(f * 100) / 100.
func roundTo(f float64) float64 { return math.Floor(f*100+0.5) / 100 }

func nullableFloat(f sql.NullFloat64) any {
	if !f.Valid {
		return nil
	}
	return f.Float64
}
