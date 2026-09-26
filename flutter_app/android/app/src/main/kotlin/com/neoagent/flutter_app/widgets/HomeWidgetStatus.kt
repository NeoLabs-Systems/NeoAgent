package com.neoagent.flutter_app.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

/** What the app last published for the home-screen widgets. */
internal class HomeWidgetStatus(
    val mood: String,
    val label: String,
    val detail: String,
    val live: Boolean,
    val callStartedAtMs: Long?,
    val updatedAtMs: Long,
    val face: Bitmap?,
) {
    val isAlert: Boolean get() = mood == "blocked"

    companion object {
        private const val PREFS_NAME = "neoagent_home_widgets"
        private const val KEY_MOOD = "mood"
        private const val KEY_LABEL = "label"
        private const val KEY_DETAIL = "detail"
        private const val KEY_LIVE = "live"
        private const val KEY_CALL_STARTED_AT = "call_started_at_ms"
        private const val KEY_UPDATED_AT = "updated_at_ms"
        private const val FACE_FILE = "home_widget_face.png"

        /**
         * True once the running app published in this process. A widget
         * rendered in a fresh process shows a snapshot from an app that has
         * since died: it is not live and no call is open.
         */
        @Volatile
        private var publishedInThisProcess = false

        fun write(
            context: Context,
            mood: String,
            label: String,
            detail: String,
            live: Boolean,
            callStartedAtMs: Long?,
            face: ByteArray?,
        ) {
            if (face != null) {
                File(context.noBackupFilesDir, FACE_FILE).writeBytes(face)
            }
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_MOOD, mood)
                .putString(KEY_LABEL, label)
                .putString(KEY_DETAIL, detail)
                .putBoolean(KEY_LIVE, live)
                .putLong(KEY_CALL_STARTED_AT, callStartedAtMs ?: 0L)
                .putLong(KEY_UPDATED_AT, System.currentTimeMillis())
                .apply()
            publishedInThisProcess = true
        }

        /** Null until the app has published once. */
        fun read(context: Context): HomeWidgetStatus? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val updatedAt = prefs.getLong(KEY_UPDATED_AT, 0L)
            if (updatedAt == 0L) return null
            val appRunning = publishedInThisProcess
            val faceFile = File(context.noBackupFilesDir, FACE_FILE)
            return HomeWidgetStatus(
                mood = prefs.getString(KEY_MOOD, null).orEmpty(),
                label = prefs.getString(KEY_LABEL, null).orEmpty(),
                detail = prefs.getString(KEY_DETAIL, null).orEmpty(),
                live = appRunning && prefs.getBoolean(KEY_LIVE, false),
                callStartedAtMs = prefs.getLong(KEY_CALL_STARTED_AT, 0L)
                    .takeIf { appRunning && it > 0L },
                updatedAtMs = updatedAt,
                face = if (faceFile.exists()) BitmapFactory.decodeFile(faceFile.path) else null,
            )
        }
    }
}
