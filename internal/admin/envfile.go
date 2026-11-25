package admin

import (
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neolabs-go/runtimecfg"
)

// EnvStore keeps the server-wide settings the admin API edits. Each change is
// written to the .env file and applied to the process environment, so code
// that reads a value at use time sees it without a restart.
type EnvStore struct {
	File string

	mu sync.Mutex
}

var lineBreaks = strings.NewReplacer("\r", "", "\n", "")

// put sets KEY=fileValue in the file and the process environment to envValue.
// An empty envValue removes the variable unless keepEmpty is set.
func (e *EnvStore) put(key, fileValue, envValue string, keepEmpty bool) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if err := upsertEnvValue(e.File, key, fileValue); err != nil {
		return err
	}
	if envValue == "" && !keepEmpty {
		return os.Unsetenv(key)
	}
	return os.Setenv(key, envValue)
}

// Persist stores a value; an empty value clears the setting.
func (e *EnvStore) Persist(key, value string) error {
	return e.put(key, value, value, false)
}

// PersistQuoted stores the value as a JSON string in the file, which is how the
// email settings keep SMTP text safe, and as plain text in the environment.
func (e *EnvStore) PersistQuoted(key, value string) error {
	return e.put(key, jsonText(value), value, false)
}

// PersistList stores a comma-separated id list. An empty list stays set (as an
// empty variable) rather than being removed.
func (e *EnvStore) PersistList(key string, ids []string) error {
	value := strings.Join(ids, ",")
	return e.put(key, value, value, true)
}

// upsertEnvValue replaces the first KEY= line of the file, or appends one, and
// rewrites the file atomically with mode 0600.
func upsertEnvValue(file, key, value string) error {
	safe := lineBreaks.Replace(value)
	var lines []string
	if raw, err := os.ReadFile(file); err == nil && len(raw) > 0 {
		lines = strings.Split(string(raw), "\n")
	}
	replaced := false
	for i, line := range lines {
		if strings.HasPrefix(line, key+"=") {
			lines[i] = key + "=" + safe
			replaced = true
			break
		}
	}
	if !replaced {
		lines = append(lines, key+"="+safe)
	}
	if lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		return err
	}
	return runtimecfg.WritePrivateFile(file, []byte(strings.Join(lines, "\n")+"\n"))
}
