package com.neoagent.flutter_app.recording

import android.content.Context
import android.content.SharedPreferences

class RecordingStateStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveConfig(config: RecordingConfig) {
        prefs.edit()
            .putString(KEY_BACKEND_URL, config.backendUrl)
            .putString(KEY_SESSION_COOKIE, config.sessionCookie)
            .putString(KEY_SESSION_ID, config.sessionId)
            .putBoolean(KEY_ACTIVE, config.active)
            .putBoolean(KEY_PAUSED, config.paused)
            .putInt(KEY_NEXT_SEQUENCE, config.nextSequence)
            .putLong(KEY_CAPTURED_AUDIO_MS, config.capturedAudioMs)
            .putString(KEY_STARTED_AT, config.startedAt)
            .putString(KEY_ERROR_MESSAGE, config.errorMessage)
            .apply()
    }

    fun loadConfig(): RecordingConfig? {
        val sessionId = prefs.getString(KEY_SESSION_ID, null) ?: return null
        return RecordingConfig(
            backendUrl = prefs.getString(KEY_BACKEND_URL, "").orEmpty(),
            sessionCookie = prefs.getString(KEY_SESSION_COOKIE, "").orEmpty(),
            sessionId = sessionId,
            active = prefs.getBoolean(KEY_ACTIVE, false),
            paused = prefs.getBoolean(KEY_PAUSED, false),
            nextSequence = prefs.getInt(KEY_NEXT_SEQUENCE, 0),
            capturedAudioMs = prefs.getLong(KEY_CAPTURED_AUDIO_MS, 0L),
            startedAt = prefs.getString(KEY_STARTED_AT, null),
            errorMessage = prefs.getString(KEY_ERROR_MESSAGE, null),
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    fun statusMap(): Map<String, Any?> {
        val config = loadConfig()
        return mapOf(
            "active" to (config?.active == true),
            "paused" to (config?.paused == true),
            "sessionId" to config?.sessionId,
            "startedAt" to config?.startedAt,
            "errorMessage" to config?.errorMessage,
        )
    }

    companion object {
        private const val PREFS_NAME = "neoagent_recordings"
        private const val KEY_BACKEND_URL = "backend_url"
        private const val KEY_SESSION_COOKIE = "session_cookie"
        private const val KEY_SESSION_ID = "session_id"
        private const val KEY_ACTIVE = "active"
        private const val KEY_PAUSED = "paused"
        private const val KEY_NEXT_SEQUENCE = "next_sequence"
        private const val KEY_CAPTURED_AUDIO_MS = "captured_audio_ms"
        private const val KEY_STARTED_AT = "started_at"
        private const val KEY_ERROR_MESSAGE = "error_message"
    }
}

data class RecordingConfig(
    val backendUrl: String,
    val sessionCookie: String,
    val sessionId: String,
    val active: Boolean,
    val paused: Boolean,
    val nextSequence: Int,
    val capturedAudioMs: Long,
    val startedAt: String?,
    val errorMessage: String?,
)
