'use strict';

// Tracks which auto-fetched models the admin has explicitly disabled, and
// reconciles that list as providers add or retire models over time.
//
// Policy for models the admin has never seen before is an explicit admin
// setting (auto-enable new models). When off, new models are added to the
// disabled list so a curating admin isn't silently opted into everything a
// provider adds. Defaults to on.

const { ENV_FILE, upsertEnvValue } = require('../../../runtime/paths');

const DISABLED_MODELS_ENV_KEY = 'NEOAGENT_DISABLED_MODELS';
const AUTO_ENABLE_NEW_ENV_KEY = 'NEOAGENT_AUTO_ENABLE_NEW_MODELS';
// Chat models and SystemOne decision models share the disabled list, but each
// catalog keeps its own known list so one never retires the other's models.
const KNOWN_MODELS_ENV_KEYS = Object.freeze({
    llm: 'NEOAGENT_KNOWN_MODELS',
    decisions: 'NEOAGENT_KNOWN_SYSTEM_ONE_MODELS',
});

function parseIdList(raw) {
    return raw ? raw.split(',').map((id) => id.trim()).filter(Boolean) : [];
}

function persistIdList(envKey, ids) {
    const value = ids.join(',');
    upsertEnvValue(ENV_FILE, envKey, value);
    process.env[envKey] = value;
}

function getDisabledModelIds() {
    return parseIdList(process.env[DISABLED_MODELS_ENV_KEY]);
}

function setDisabledModelIds(disabledIds) {
    if (!Array.isArray(disabledIds)) throw new TypeError('disabledIds must be an array');
    const unique = Array.from(new Set(disabledIds.map((id) => String(id).trim()).filter(Boolean)));
    persistIdList(DISABLED_MODELS_ENV_KEY, unique);
    return unique;
}

function getAutoEnableNewModels() {
    return process.env[AUTO_ENABLE_NEW_ENV_KEY] !== 'false';
}

function setAutoEnableNewModels(enabled) {
    persistIdList(AUTO_ENABLE_NEW_ENV_KEY, [String(Boolean(enabled))]);
    return Boolean(enabled);
}

// null means "never bootstrapped" -- distinct from an empty list.
function getKnownModelIds(knownEnvKey) {
    return process.env[knownEnvKey] === undefined
        ? null
        : parseIdList(process.env[knownEnvKey]);
}

function reconcileModelVisibility(currentModelIds, catalog = 'llm') {
    const knownEnvKey = KNOWN_MODELS_ENV_KEYS[catalog];
    const currentSet = new Set((currentModelIds || []).map((id) => String(id).trim()).filter(Boolean));
    const disabledIds = getDisabledModelIds();
    // An empty catalog usually means a transient provider fetch failure, not
    // that every model vanished -- skip reconciliation rather than pruning.
    if (currentSet.size === 0) return disabledIds;

    const knownIds = getKnownModelIds(knownEnvKey);
    if (knownIds === null) {
        // First run: adopt the current catalog as the known baseline without
        // touching enablement, so shipping this feature doesn't retroactively
        // disable models an admin already had enabled.
        persistIdList(knownEnvKey, Array.from(currentSet));
        return disabledIds;
    }

    const knownSet = new Set(knownIds);
    const newIds = Array.from(currentSet).filter((id) => !knownSet.has(id));
    // Models missing from this fetch are left alone in both lists: a provider
    // hiccup or partial catalog must not erase the admin's choices, or the
    // model would come back as "new" and be re-enabled.
    if (!newIds.length) return disabledIds;

    const disabledSet = new Set(disabledIds);
    const autoDisableNewModels = !getAutoEnableNewModels();
    let disabledChanged = false;

    for (const id of newIds) {
        knownSet.add(id);
        if (autoDisableNewModels) {
            disabledSet.add(id);
            disabledChanged = true;
        }
    }

    persistIdList(knownEnvKey, Array.from(knownSet));
    if (disabledChanged) persistIdList(DISABLED_MODELS_ENV_KEY, Array.from(disabledSet));
    return Array.from(disabledSet);
}

module.exports = {
    getDisabledModelIds,
    getAutoEnableNewModels,
    setAutoEnableNewModels,
    setDisabledModelIds,
    reconcileModelVisibility,
};
