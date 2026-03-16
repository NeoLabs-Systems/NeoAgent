package com.neoagent.aurora.settings

import android.content.Context
import com.neoagent.aurora.BuildConfig

/**
 * Persists user-editable settings in SharedPreferences.
 * Falls back to the build-time [BuildConfig] values when a key has never been set.
 */
class SettingsManager(context: Context) {

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var backendUrl: String
        get() = prefs.getString(KEY_URL, BuildConfig.BACKEND_URL) ?: BuildConfig.BACKEND_URL
        set(v) = prefs.edit().putString(KEY_URL, v.trimEnd('/')).apply()

    var username: String
        get() = prefs.getString(KEY_USER, BuildConfig.AUTH_USERNAME) ?: BuildConfig.AUTH_USERNAME
        set(v) = prefs.edit().putString(KEY_USER, v).apply()

    var password: String
        get() = prefs.getString(KEY_PASS, BuildConfig.AUTH_PASSWORD) ?: BuildConfig.AUTH_PASSWORD
        set(v) = prefs.edit().putString(KEY_PASS, v).apply()

    var healthSyncEnabled: Boolean
        get() = prefs.getBoolean(KEY_HEALTH_SYNC_ENABLED, false)
        set(v) = prefs.edit().putBoolean(KEY_HEALTH_SYNC_ENABLED, v).apply()

    var healthLastAttemptAt: String?
        get() = prefs.getString(KEY_HEALTH_LAST_ATTEMPT_AT, null)
        set(v) = prefs.edit().putString(KEY_HEALTH_LAST_ATTEMPT_AT, v).apply()

    var healthLastSuccessfulSyncAt: String?
        get() = prefs.getString(KEY_HEALTH_LAST_SUCCESS_AT, null)
        set(v) = prefs.edit().putString(KEY_HEALTH_LAST_SUCCESS_AT, v).apply()

    var healthLastError: String?
        get() = prefs.getString(KEY_HEALTH_LAST_ERROR, null)
        set(v) = prefs.edit().putString(KEY_HEALTH_LAST_ERROR, v).apply()

    companion object {
        private const val PREFS_NAME                  = "aurora_settings"
        private const val KEY_URL                     = "backend_url"
        private const val KEY_USER                    = "username"
        private const val KEY_PASS                    = "password"
        private const val KEY_HEALTH_SYNC_ENABLED     = "health_sync_enabled"
        private const val KEY_HEALTH_LAST_ATTEMPT_AT  = "health_last_attempt_at"
        private const val KEY_HEALTH_LAST_SUCCESS_AT  = "health_last_success_at"
        private const val KEY_HEALTH_LAST_ERROR       = "health_last_error"
    }
}
