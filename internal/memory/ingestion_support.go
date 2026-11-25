package memory

import (
	"errors"
	"math"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// SourceTypes are the kinds of source material memory ingests.
var SourceTypes = []string{"email", "calendar", "chat", "docs", "tickets", "repos", "files", "crm", "payments", "notes"}

// integrationSourceTypes maps provider and app to what the app contributes.
var integrationSourceTypes = map[string]map[string][]string{
	"google_workspace": {
		"gmail": {"email"}, "calendar": {"calendar"}, "drive": {"files"}, "docs": {"docs"}, "sheets": {"docs", "files"},
	},
	"microsoft_365": {"outlook": {"email"}, "calendar": {"calendar"}, "onedrive": {"files"}, "teams": {"chat"}},
	"github":        {"repos": {"repos", "tickets"}},
	"slack":         {"slack": {"chat"}},
	"whatsapp":      {"personal": {"chat"}},
	"notion":        {"notion": {"notes", "docs"}},
	"trello":        {"trello": {"tickets"}},
}

func safeTrim(value any, maxLength int) string {
	return jsx.Head(jsx.Trim(jsx.StrOr(value)), maxLength)
}

// NormalizeSourceType maps a text onto SourceTypes; unknown types are notes.
func NormalizeSourceType(value string) string {
	normalized := jsx.Lower(jsx.Trim(value))
	for _, t := range SourceTypes {
		if t == normalized {
			return t
		}
	}
	return "notes"
}

// Document is source material: a mail thread, a file, a chat. Documents are
// stored as such and mined for facts; they never become memories themselves.
type Document struct {
	SourceType       string
	NormalizedType   string
	ProviderKey      string
	ConnectionID     int64
	ExternalObjectID string
	SourceAccount    string
	Title            string
	Content          string
	Summary          string
	Salience         float64
	SourceTimestamp  string // "" when unknown
	Metadata         *jsx.Obj
	Payload          *jsx.Obj
}

// DocumentDefaults fill what a raw document leaves out.
type DocumentDefaults struct {
	SourceType    any
	ProviderKey   any
	ConnectionID  any
	SourceAccount any
}

// ErrDocumentIncomplete is returned for a document without id or content.
var ErrDocumentIncomplete = errors.New("Normalized memory documents require externalObjectId and content.")

// asObject is parseJsonObject(value, {}): objects are copied, text is parsed.
func asObject(value any) *jsx.Obj {
	switch t := value.(type) {
	case *jsx.Obj:
		return t.Clone()
	case string:
		return jsx.ParseObject(t)
	}
	return jsx.NewObj()
}

func isInteger(f float64) bool { return jsx.IsFinite(f) && f == math.Trunc(f) }

// NormalizeDocument validates a raw document from a request or an integration.
// raw is a decoded JSON value.
func NormalizeDocument(raw any, d DocumentDefaults) (Document, error) {
	obj, isObj := raw.(*jsx.Obj)
	if raw == nil {
		return Document{}, errors.New("Cannot read properties of null (reading 'sourceType')")
	}
	if !isObj {
		obj = jsx.NewObj()
	}
	sourceType := NormalizeSourceType(jsx.StrOr(jsx.Or(obj.Lookup("sourceType"), d.SourceType)))
	externalObjectID := safeTrim(jsx.Or(obj.Lookup("externalObjectId"), obj.Lookup("id"), obj.Lookup("sourceId")), 180)
	content := safeTrim(jsx.Coalesce(obj.Lookup("content"), obj.Lookup("text"), obj.Lookup("body"), ""), 12000)
	if externalObjectID == "" || content == "" {
		return Document{}, ErrDocumentIncomplete
	}
	compacted := compactTextPayload(content, 2400, 50)

	connectionID := int64(0)
	if n := jsx.ToNumber(jsx.Coalesce(obj.Lookup("connectionId"), d.ConnectionID)); isInteger(n) {
		connectionID = int64(n)
	}
	salience := jsx.ToNumber(obj.Lookup("salience"))
	if !jsx.IsFinite(salience) || salience == 0 {
		salience = 5
	}
	metadata := asObject(obj.Lookup("metadata"))
	metadata.Set("compaction", compacted.Metrics)
	title := safeTrim(jsx.Or(obj.Lookup("title"), obj.Lookup("subject"), obj.Lookup("name"), externalObjectID), 220)
	return Document{
		SourceType:       sourceType,
		NormalizedType:   NormalizeSourceType(jsx.StrOr(jsx.Or(obj.Lookup("normalizedType"), obj.Lookup("memoryType"), sourceType))),
		ProviderKey:      safeTrim(jsx.Or(obj.Lookup("providerKey"), d.ProviderKey), 80),
		ConnectionID:     connectionID,
		ExternalObjectID: externalObjectID,
		SourceAccount:    safeTrim(jsx.Or(obj.Lookup("sourceAccount"), d.SourceAccount), 180),
		Title:            title,
		Content:          content,
		Summary:          safeTrim(jsx.Or(obj.Lookup("summary"), compacted.Text), 1200),
		Salience:         max(1, min(10, salience)),
		SourceTimestamp:  safeTrim(jsx.Or(obj.Lookup("sourceTimestamp"), obj.Lookup("updatedAt"), obj.Lookup("createdAt")), 80),
		Metadata:         metadata,
		Payload:          asObject(obj.Lookup("payload")),
	}, nil
}

// SourceTypesForConnection lists what a connected app contributes to memory.
func SourceTypesForConnection(providerKey, appKey string) []string {
	types := integrationSourceTypes[jsx.Trim(providerKey)][jsx.Trim(appKey)]
	return append([]string(nil), types...)
}

// Coverage says how a connection feeds memory.
type Coverage struct {
	Supported                  bool     `json:"supported"`
	ContributesToMemory        bool     `json:"contributesToMemory"`
	ContributesToTaskExecution bool     `json:"contributesToTaskExecution"`
	Status                     string   `json:"status"`
	DataDomains                []string `json:"dataDomains"`
	LastRefreshAt              *string  `json:"lastRefreshAt"`
	DocumentCount              int      `json:"documentCount"`
	Error                      *string  `json:"error"`
}

func buildCoverageForConnection(connectionStatus string, latest *IngestionJob, dataDomains []string) Coverage {
	supported := len(dataDomains) > 0
	if dataDomains == nil {
		dataDomains = []string{}
	}
	c := Coverage{
		Supported:                  supported,
		ContributesToMemory:        supported,
		ContributesToTaskExecution: connectionStatus == "connected",
		DataDomains:                dataDomains,
	}
	switch {
	case latest != nil && latest.Status != "":
		c.Status = latest.Status
	case supported:
		c.Status = "ready"
	default:
		c.Status = "not_supported"
	}
	if latest != nil {
		c.LastRefreshAt = firstNonNil(latest.CompletedAt, latest.UpdatedAt)
		c.DocumentCount = latest.DocumentCount
		c.Error = latest.Error
	}
	return c
}

func firstNonNil(values ...*string) *string {
	for _, v := range values {
		if v != nil && *v != "" {
			return v
		}
	}
	return nil
}
