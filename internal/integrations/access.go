package integrations

import (
	"encoding/json"
	"strings"
)

// Access modes of a connection: whether the agent may change anything.
const (
	AccessReadWrite = "read_write"
	AccessReadOnly  = "read_only"
)

func normalizeAccessMode(value, fallback string) string {
	switch v := strings.ToLower(strings.TrimSpace(value)); v {
	case AccessReadWrite, AccessReadOnly:
		return v
	}
	return fallback
}

// parseMetadata reads a metadata_json column; anything but an object is empty.
func parseMetadata(raw string) map[string]any {
	if raw == "" {
		return map[string]any{}
	}
	var m map[string]any
	if json.Unmarshal([]byte(raw), &m) != nil || m == nil {
		return map[string]any{}
	}
	return m
}

// AccessMode is the access mode stored on a connection row (read_write when
// none is).
func AccessMode(c *Connection) string {
	if c == nil {
		return AccessReadWrite
	}
	mode, _ := parseMetadata(c.MetadataJSON)["access_mode"].(string)
	return normalizeAccessMode(mode, AccessReadWrite)
}

func withAccessMode(metadataJSON, mode string) map[string]any {
	m := parseMetadata(metadataJSON)
	m["access_mode"] = normalizeAccessMode(mode, AccessReadWrite)
	return m
}
