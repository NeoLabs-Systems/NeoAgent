package memory

import (
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// parseTimestamp is Date.parse on a stored timestamp, in milliseconds. The
// server's local zone applies to SQLite-style stamps, as it does in Node.
func parseTimestamp(value string) (int64, bool) {
	return jsx.ParseDate(value, time.Local)
}
