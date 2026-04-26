package com.neoagent.flutter_app.widgets

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class CachedAiWidgetTask(
    val id: String,
    val name: String,
    val triggerSummary: String,
)

data class CachedAiWidget(
    val id: String,
    val name: String,
    val template: String,
    val layoutVariant: String,
    val refreshCron: String,
    val enabled: Boolean,
    val lastError: String?,
    val latestSnapshot: JSONObject?,
    val tasks: List<CachedAiWidgetTask>,
)

internal object AiWidgetPrefs {
    const val PREFS_NAME = "neoagent_ai_widgets"
    const val KEY_ENABLED = "enabled"
    const val KEY_BACKEND_URL = "backend_url"
    const val KEY_SESSION_COOKIE = "session_cookie"
    const val KEY_CACHED_WIDGETS = "cached_widgets"
    const val KEY_LAST_SYNC_AT = "last_sync_at"
    const val KEY_LAST_ERROR = "last_error"
    const val KEY_PENDING_OPEN_WIDGET_ID = "pending_open_widget_id"
    const val KEY_BINDING_PREFIX = "binding_"
    const val KEY_EXPANDED_PREFIX = "expanded_"

    fun read(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}

class AiWidgetStore(private val context: Context) {

    private val pendingOpenLock = Any()

    fun saveConfig(
        enabled: Boolean,
        backendUrl: String,
        sessionCookie: String,
    ) {
        AiWidgetPrefs.read(context)
            .edit()
            .putBoolean(AiWidgetPrefs.KEY_ENABLED, enabled)
            .putString(AiWidgetPrefs.KEY_BACKEND_URL, backendUrl.trim())
            .putString(AiWidgetPrefs.KEY_SESSION_COOKIE, sessionCookie.trim())
            .apply()
    }

    fun isEnabled(): Boolean =
        AiWidgetPrefs.read(context).getBoolean(AiWidgetPrefs.KEY_ENABLED, false)

    fun backendUrl(): String =
        AiWidgetPrefs.read(context)
            .getString(AiWidgetPrefs.KEY_BACKEND_URL, "")
            ?.trim()
            .orEmpty()

    fun sessionCookie(): String =
        AiWidgetPrefs.read(context)
            .getString(AiWidgetPrefs.KEY_SESSION_COOKIE, "")
            ?.trim()
            .orEmpty()

    fun saveCachedWidgets(rawJson: String) {
        AiWidgetPrefs.read(context)
            .edit()
            .putString(AiWidgetPrefs.KEY_CACHED_WIDGETS, rawJson)
            .putString(AiWidgetPrefs.KEY_LAST_SYNC_AT, java.time.Instant.now().toString())
            .remove(AiWidgetPrefs.KEY_LAST_ERROR)
            .apply()
    }

    fun setLastError(message: String) {
        AiWidgetPrefs.read(context)
            .edit()
            .putString(AiWidgetPrefs.KEY_LAST_ERROR, message)
            .apply()
    }

    fun cachedWidgets(): List<CachedAiWidget> {
        val raw =
            AiWidgetPrefs.read(context).getString(AiWidgetPrefs.KEY_CACHED_WIDGETS, null)
                ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    add(
                        CachedAiWidget(
                            id = item.optString("id").trim(),
                            name = item.optString("name").trim(),
                            template = item.optString("template", "summary").trim(),
                            layoutVariant =
                                item.optString("layoutVariant", item.optString("layout_variant"))
                                    .trim(),
                            refreshCron =
                                item.optString("refreshCron", item.optString("refresh_cron"))
                                    .trim(),
                            enabled = item.optBoolean("enabled", true),
                            lastError =
                                item.optString("lastError")
                                    .trim()
                                    .ifEmpty { item.optString("last_error").trim() }
                                    .ifEmpty { "" }
                                    .let { if (it.isBlank()) null else it },
                            latestSnapshot = item.optJSONObject("latestSnapshot"),
                            tasks = buildList {
                                val tasksArray = item.optJSONArray("tasks")
                                if (tasksArray != null) {
                                    for (t in 0 until tasksArray.length()) {
                                        val tItem = tasksArray.optJSONObject(t) ?: continue
                                        add(
                                            CachedAiWidgetTask(
                                                id = tItem.optString("id"),
                                                name = tItem.optString("name", "Task"),
                                                triggerSummary = tItem.optString("triggerSummary"),
                                            )
                                        )
                                    }
                                }
                            },
                        ),
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun findWidget(widgetId: String): CachedAiWidget? =
        cachedWidgets().firstOrNull { it.id == widgetId }

    fun bindAppWidget(appWidgetId: Int, widgetId: String) {
        AiWidgetPrefs.read(context)
            .edit()
            .putString("${AiWidgetPrefs.KEY_BINDING_PREFIX}$appWidgetId", widgetId)
            .apply()
    }

    fun widgetIdForAppWidget(appWidgetId: Int): String? =
        AiWidgetPrefs.read(context)
            .getString("${AiWidgetPrefs.KEY_BINDING_PREFIX}$appWidgetId", null)
            ?.trim()
            ?.let { if (it.isBlank()) null else it }

    fun clearBinding(appWidgetId: Int) {
        AiWidgetPrefs.read(context)
            .edit()
            .remove("${AiWidgetPrefs.KEY_BINDING_PREFIX}$appWidgetId")
            .apply()
    }

    fun setPendingOpenWidgetId(widgetId: String?) {
        AiWidgetPrefs.read(context)
            .edit()
            .putString(AiWidgetPrefs.KEY_PENDING_OPEN_WIDGET_ID, widgetId?.trim())
            .apply()
    }

    fun consumePendingOpenWidgetId(): String? {
        synchronized(pendingOpenLock) {
            val prefs = AiWidgetPrefs.read(context)
            val widgetId =
                prefs.getString(AiWidgetPrefs.KEY_PENDING_OPEN_WIDGET_ID, null)
                    ?.trim()
                    ?.let { if (it.isBlank()) null else it }
            if (widgetId != null) {
                prefs.edit().remove(AiWidgetPrefs.KEY_PENDING_OPEN_WIDGET_ID).commit()
            }
            return widgetId
        }
    }

    fun isTasksExpanded(appWidgetId: Int): Boolean =
        AiWidgetPrefs.read(context).getBoolean("${AiWidgetPrefs.KEY_EXPANDED_PREFIX}$appWidgetId", false)

    fun toggleTasksExpanded(appWidgetId: Int) {
        val prefs = AiWidgetPrefs.read(context)
        val key = "${AiWidgetPrefs.KEY_EXPANDED_PREFIX}$appWidgetId"
        val current = prefs.getBoolean(key, false)
        prefs.edit().putBoolean(key, !current).apply()
    }
}
