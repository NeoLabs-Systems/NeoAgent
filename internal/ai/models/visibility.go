package models

import (
	"slices"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Environment keys of the admin's model switches.
const (
	DisabledModelsKey = "NEOAGENT_DISABLED_MODELS"
	AutoEnableNewKey  = "NEOAGENT_AUTO_ENABLE_NEW_MODELS"
	knownLLMModelsKey = "NEOAGENT_KNOWN_MODELS"
	knownDecisionsKey = "NEOAGENT_KNOWN_SYSTEM_ONE_MODELS"
)

// EnvStore is the server's environment file plus the process environment: the
// admin's model lists live there.
type EnvStore interface {
	// Lookup returns the value and whether the key is set at all.
	Lookup(key string) (string, bool)
	// Set writes the value to the environment file and the process.
	Set(key, value string) error
}

// Visibility tracks which auto-fetched models the admin has explicitly disabled,
// and reconciles that list as providers add or retire models over time.
//
// Policy for models the admin has never seen before is an explicit admin setting
// (auto-enable new models). When off, new models are added to the disabled list
// so a curating admin isn't silently opted into everything a provider adds.
// Defaults to on.
type Visibility struct{ Env EnvStore }

func parseIDList(raw string) []string {
	var ids []string
	if raw == "" {
		return ids
	}
	for _, id := range strings.Split(raw, ",") {
		if id = textx.Trim(id); id != "" {
			ids = append(ids, id)
		}
	}
	return ids
}

func (v Visibility) persist(key string, ids []string) error {
	return v.Env.Set(key, strings.Join(ids, ","))
}

// DisabledIDs are the models switched off for everyone.
func (v Visibility) DisabledIDs() []string {
	raw, _ := v.Env.Lookup(DisabledModelsKey)
	return parseIDList(raw)
}

// SetDisabledIDs replaces the disabled list with its unique, trimmed entries.
func (v Visibility) SetDisabledIDs(ids []string) ([]string, error) {
	var unique []string
	for _, id := range ids {
		if id = textx.Trim(id); id != "" && !slices.Contains(unique, id) {
			unique = append(unique, id)
		}
	}
	return unique, v.persist(DisabledModelsKey, unique)
}

// AutoEnableNew reports whether models the admin has not seen are enabled.
func (v Visibility) AutoEnableNew() bool {
	raw, _ := v.Env.Lookup(AutoEnableNewKey)
	return raw != "false"
}

// SetAutoEnableNew stores the policy for new models.
func (v Visibility) SetAutoEnableNew(enabled bool) error {
	return v.persist(AutoEnableNewKey, []string{strconv.FormatBool(enabled)})
}

// Catalogs that keep their own list of known models, so one never retires the
// other's models.
const (
	CatalogLLM       = "llm"
	CatalogDecisions = "decisions"
)

// Reconcile adopts models a provider added since the last look: as enabled, or
// as disabled when the admin turned auto-enable off. It returns the disabled
// list. The first run only records the current catalog as the baseline, so
// shipping the feature does not retroactively disable models an admin already
// had enabled. Models missing from this fetch are left alone in both lists: a
// provider hiccup or partial catalog must not erase the admin's choices, or the
// model would come back as "new" and be re-enabled. An empty catalog usually
// means a transient provider failure, so it is skipped rather than pruned.
func (v Visibility) Reconcile(currentIDs []string, catalog string) ([]string, error) {
	knownKey := knownLLMModelsKey
	if catalog == CatalogDecisions {
		knownKey = knownDecisionsKey
	}
	var current []string
	for _, id := range currentIDs {
		if id = textx.Trim(id); id != "" && !slices.Contains(current, id) {
			current = append(current, id)
		}
	}
	disabled := v.DisabledIDs()
	if len(current) == 0 {
		return disabled, nil
	}
	raw, set := v.Env.Lookup(knownKey)
	if !set {
		return disabled, v.persist(knownKey, current)
	}
	known := parseIDList(raw)
	var added []string
	for _, id := range current {
		if !slices.Contains(known, id) {
			added = append(added, id)
		}
	}
	if len(added) == 0 {
		return disabled, nil
	}
	autoDisable := !v.AutoEnableNew()
	for _, id := range added {
		known = append(known, id)
		if autoDisable && !slices.Contains(disabled, id) {
			disabled = append(disabled, id)
		}
	}
	if err := v.persist(knownKey, known); err != nil {
		return nil, err
	}
	if autoDisable {
		if err := v.persist(DisabledModelsKey, disabled); err != nil {
			return nil, err
		}
	}
	return disabled, nil
}
