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

    companion object {
        private const val PREFS_NAME = "aurora_settings"
        private const val KEY_URL    = "backend_url"
        private const val KEY_USER   = "username"
        private const val KEY_PASS   = "password"
    }
}
