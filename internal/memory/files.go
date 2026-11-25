package memory

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

const localSecretPrefix = "enc:local:v1:"

func (m *Manager) userDir(userID int64) (string, error) {
	if m.dataDir == "" {
		return "", errors.New("memory: no agent data directory configured")
	}
	dir := filepath.Join(m.dataDir, "users", strconv.FormatInt(userID, 10))
	if err := os.MkdirAll(filepath.Join(dir, "daily"), 0o700); err != nil {
		return "", err
	}
	return dir, nil
}

func (m *Manager) apiKeysPath(userID int64) (string, error) {
	dir, err := m.userDir(userID)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "API_KEYS.json"), nil
}

func (m *Manager) sharedKeysPath() string { return filepath.Join(m.dataDir, "API_KEYS.json") }

func (m *Manager) decryptLocal(value string) string {
	if value == "" || !strings.HasPrefix(value, localSecretPrefix) {
		return value
	}
	plain, err := m.localBox.OpenSealed(value)
	if err != nil {
		return ""
	}
	return plain
}

// ReadAPIKeys reads the agent-managed API keys of a user, decrypted, in file
// order. Keys stored in plain text are re-written sealed. A user without a
// file starts from a copy of the shared one.
func (m *Manager) ReadAPIKeys(userID int64) (*jsx.Obj, error) {
	path, err := m.apiKeysPath(userID)
	if err != nil {
		return nil, err
	}
	if _, err := os.Stat(path); os.IsNotExist(err) {
		shared, readErr := os.ReadFile(m.sharedKeysPath())
		if readErr != nil {
			return jsx.NewObj(), nil
		}
		if err := os.WriteFile(path, shared, 0o600); err != nil {
			return nil, err
		}
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return jsx.NewObj(), nil
	}
	parsed, ok := mustObject(string(raw))
	if !ok {
		return jsx.NewObj(), nil
	}
	shouldMigrate := false
	normalized := jsx.NewObj()
	for _, service := range parsed.Keys() {
		value := jsx.StrOr(parsed.Value(service))
		if value == "" {
			normalized.Set(service, "")
			continue
		}
		if !strings.HasPrefix(value, localSecretPrefix) {
			shouldMigrate = true
		}
		normalized.Set(service, m.decryptLocal(value))
	}
	if shouldMigrate {
		if err := m.writeAPIKeys(userID, normalized); err != nil {
			return nil, err
		}
	}
	return normalized, nil
}

func mustObject(text string) (*jsx.Obj, bool) {
	v, err := jsx.Parse(text)
	if err != nil {
		return nil, false
	}
	o, ok := v.(*jsx.Obj)
	return o, ok
}

func (m *Manager) writeAPIKeys(userID int64, keys *jsx.Obj) error {
	path, err := m.apiKeysPath(userID)
	if err != nil {
		return err
	}
	sealed := jsx.NewObj()
	for _, service := range keys.Keys() {
		value := jsx.StrOr(keys.Value(service))
		if value != "" {
			var err error
			if value, err = m.localBox.Seal(value); err != nil {
				return err
			}
		}
		sealed.Set(service, value)
	}
	return os.WriteFile(path, []byte(jsx.MarshalIndent(sealed)), 0o600)
}

// SetAPIKey stores one service's API key.
func (m *Manager) SetAPIKey(userID int64, service, key string) error {
	keys, err := m.ReadAPIKeys(userID)
	if err != nil {
		return err
	}
	// Assigning to __proto__ never stored anything in the Node code.
	if service != "__proto__" {
		keys.Set(service, key)
	}
	return m.writeAPIKeys(userID, keys)
}

// DeleteAPIKey removes one service's API key.
func (m *Manager) DeleteAPIKey(userID int64, service string) error {
	keys, err := m.ReadAPIKeys(userID)
	if err != nil {
		return err
	}
	keys.Delete(service)
	return m.writeAPIKeys(userID, keys)
}

// DailyLog is the notes of one day.
type DailyLog struct {
	Date    string `json:"date"`
	Content string `json:"content"`
}

// dailyName is the file name of a day's log: the UTC date of the instant.
func dailyName(date time.Time) string { return date.UTC().Format("2006-01-02") + ".md" }

// ParseLogDate is new Date(text) for a date path parameter; ok is false for
// text that is not a date.
func ParseLogDate(text string) (time.Time, bool) {
	ms, ok := jsx.ParseDate(text, time.Local)
	if !ok {
		return time.Time{}, false
	}
	return time.UnixMilli(ms), true
}

func (m *Manager) dailyDir(userID int64) (string, error) {
	dir, err := m.userDir(userID)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "daily"), nil
}

// ReadDailyLog reads the log of the day date falls on; "" when there is none.
func (m *Manager) ReadDailyLog(date time.Time, userID int64) (string, error) {
	dir, err := m.dailyDir(userID)
	if err != nil {
		return "", err
	}
	raw, err := os.ReadFile(filepath.Join(dir, dailyName(date)))
	if os.IsNotExist(err) {
		return "", nil
	}
	return string(raw), err
}

// AppendDailyLog adds a timestamped line to today's log and returns the line.
func (m *Manager) AppendDailyLog(entry string, userID int64) (string, error) {
	dir, err := m.dailyDir(userID)
	if err != nil {
		return "", err
	}
	now := m.clock()
	hour := now.Hour()
	if hour == 0 {
		hour = 24 // en-US with hour12: false writes midnight as 24
	}
	line := fmt.Sprintf("\n- [%02d:%02d:%02d] %s", hour, now.Minute(), now.Second(), entry)
	f, err := os.OpenFile(filepath.Join(dir, dailyName(now)), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return "", err
	}
	defer f.Close()
	if _, err := f.WriteString(line); err != nil {
		return "", err
	}
	return jsx.Trim(line), nil
}

// ListDailyLogs lists the newest daily logs of a user. A user without logs
// starts from a copy of the shared ones.
func (m *Manager) ListDailyLogs(limit int, userID int64) ([]DailyLog, error) {
	dir, err := m.dailyDir(userID)
	if err != nil {
		return nil, err
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	if len(entries) == 0 {
		shared, readErr := os.ReadDir(filepath.Join(m.dataDir, "daily"))
		if readErr == nil {
			for _, e := range shared {
				if !strings.HasSuffix(e.Name(), ".md") {
					continue
				}
				dest := filepath.Join(dir, e.Name())
				if _, err := os.Stat(dest); os.IsNotExist(err) {
					content, err := os.ReadFile(filepath.Join(m.dataDir, "daily", e.Name()))
					if err == nil {
						if err := os.WriteFile(dest, content, 0o600); err != nil {
							return nil, err
						}
					}
				}
			}
			if entries, err = os.ReadDir(dir); err != nil {
				return nil, err
			}
		}
	}
	var names []string
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".md") {
			names = append(names, e.Name())
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(names)))
	if len(names) > limit {
		names = names[:limit]
	}
	logs := make([]DailyLog, 0, len(names))
	for _, name := range names {
		content, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return nil, err
		}
		logs = append(logs, DailyLog{Date: strings.Replace(name, ".md", "", 1), Content: string(content)})
	}
	return logs, nil
}

// DecryptLocal opens a value sealed for API_KEYS.json; plain values pass through.
func (m *Manager) DecryptLocal(value string) string { return m.decryptLocal(value) }
