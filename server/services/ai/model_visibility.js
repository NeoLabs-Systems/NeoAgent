'use strict';

// Tracks which auto-fetched models the admin has explicitly disabled, and
// reconciles that list as providers add or retire models over time.
//
// Policy for models the admin has never seen before:
//   - If nothing is currently disabled, new models default to enabled.
//   - If at least one model is already disabled, new models default to
//     disabled too, so an admin who is curating the list isn't silently
//     opted back into everything a provider adds.

const { ENV_FILE, upsertEnvValue } = require('../../../runtime/paths');

const DISABLED_MODELS_ENV_KEY = 'NEOAGENT_DISABLED_MODELS';
const KNOWN_MODELS_ENV_KEY = 'NEOAGENT_KNOWN_MODELS';

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

// null means "never bootstrapped" -- distinct from an empty list.
function getKnownModelIds() {
    return process.env[KNOWN_MODELS_ENV_KEY] === undefined
        ? null
        : parseIdList(process.env[KNOWN_MODELS_ENV_KEY]);
}

function reconcileModelVisibility(currentModelIds) {
    const currentSet = new Set((currentModelIds || []).map((id) => String(id).trim()).filter(Boolean));
    const disabledIds = getDisabledModelIds();
    // An empty catalog usually means a transient provider fetch failure, not
    // that every model vanished -- skip reconciliation rather than pruning.
    if (currentSet.size === 0) return disabledIds;

    const knownIds = getKnownModelIds();
    if (knownIds === null) {
        // First run: adopt the current catalog as the known baseline without
        // touching enablement, so shipping this feature doesn't retroactively
        // disable models an admin already had enabled.
        persistIdList(KNOWN_MODELS_ENV_KEY, Array.from(currentSet));
        return disabledIds;
    }

    const knownSet = new Set(knownIds);
    const newIds = Array.from(currentSet).filter((id) => !knownSet.has(id));
    const staleIds = knownIds.filter((id) => !currentSet.has(id));
    if (!newIds.length && !staleIds.length) return disabledIds;

    const disabledSet = new Set(disabledIds);
    const autoDisableNewModels = disabledSet.size > 0;
    let disabledChanged = false;

    for (const id of newIds) {
        knownSet.add(id);
        if (autoDisableNewModels) {
            disabledSet.add(id);
            disabledChanged = true;
        }
    }
    for (const id of staleIds) {
        knownSet.delete(id);
        disabledChanged = disabledSet.delete(id) || disabledChanged;
    }

    persistIdList(KNOWN_MODELS_ENV_KEY, Array.from(knownSet));
    if (disabledChanged) persistIdList(DISABLED_MODELS_ENV_KEY, Array.from(disabledSet));
    return Array.from(disabledSet);
}

module.exports = {
    getDisabledModelIds,
    setDisabledModelIds,
    reconcileModelVisibility,
};
