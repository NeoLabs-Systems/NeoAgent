package com.neoagent.flutter_app.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import com.neoagent.flutter_app.MainActivity
import com.neoagent.flutter_app.R
import org.json.JSONObject

class AiHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        refreshAll(context, appWidgetManager, appWidgetIds)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val store = AiWidgetStore(context)
        appWidgetIds.forEach(store::clearBinding)
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, AiHomeWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            refreshAll(context, manager, ids)
        }

        fun refreshAll(
            context: Context,
            manager: AppWidgetManager,
            appWidgetIds: IntArray,
        ) {
            val store = AiWidgetStore(context)
            appWidgetIds.forEach { appWidgetId ->
                manager.updateAppWidget(
                    appWidgetId,
                    buildRemoteViews(context, store, appWidgetId),
                )
            }
        }

        private fun buildRemoteViews(
            context: Context,
            store: AiWidgetStore,
            appWidgetId: Int,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.neoagent_ai_widget)
            val widgetId = store.widgetIdForAppWidget(appWidgetId)
            if (widgetId.isNullOrBlank()) {
                bindEmptyState(
                    context,
                    views,
                    "Choose an AI widget",
                    "Add this widget again and select one from the list.",
                )
                return views
            }

            val widget = store.findWidget(widgetId)
            if (widget == null) {
                bindEmptyState(
                    context,
                    views,
                    "Widget unavailable",
                    "Open NeoAgent, refresh widgets, and configure this home widget again.",
                )
                return views
            }

            val snapshot = widget.latestSnapshot
            val accent = accentColor(snapshot?.optString("accentToken").orEmpty())
            val title = snapshot?.optString("title")?.ifBlank { widget.name } ?: widget.name
            val subtitle =
                snapshot?.optString("subtitle")?.ifBlank {
                    "${widget.template} · ${widget.layoutVariant}"
                } ?: "${widget.template} · ${widget.layoutVariant}"
            val metric = snapshot?.optString("metric").orEmpty()
            val body = snapshot?.optString("body").orEmpty()
            val chips = joinChips(snapshot)
            val rows = rows(snapshot)
            val updated = snapshot?.optString("updatedAt").orEmpty().ifBlank {
                formatUpdatedFallback(widget.refreshCron)
            }

            views.setTextViewText(R.id.widget_title, title)
            views.setTextColor(R.id.widget_title, Color.WHITE)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setTextColor(R.id.widget_subtitle, 0xFFD1D8E6.toInt())
            views.setTextViewText(R.id.widget_metric, metric)
            views.setTextColor(R.id.widget_metric, accent)
            views.setTextViewText(R.id.widget_body, if (body.isNotBlank()) body else chips)
            views.setTextColor(R.id.widget_body, 0xFFF4F6FA.toInt())
            views.setTextViewText(R.id.widget_meta, updated)
            views.setTextColor(R.id.widget_meta, 0xFF92A1BA.toInt())

            bindRow(views, R.id.widget_row_1, rows.getOrNull(0))
            bindRow(views, R.id.widget_row_2, rows.getOrNull(1))
            bindRow(views, R.id.widget_row_3, rows.getOrNull(2))

            val showMetric = metric.isNotBlank() && widget.template == "stat"
            views.setViewVisibility(R.id.widget_metric, if (showMetric) View.VISIBLE else View.GONE)
            views.setViewVisibility(
                R.id.widget_rows_group,
                if (rows.isNotEmpty() || widget.template == "list") View.VISIBLE else View.GONE,
            )

            val statusText = widget.lastError?.takeIf { it.isNotBlank() }
                ?: if (widget.enabled) "Live" else "Paused"
            val statusColor =
                if (!widget.lastError.isNullOrBlank()) {
                    0xFFFFB3A9.toInt()
                } else if (widget.enabled) {
                    0xFF8EE0AF.toInt()
                } else {
                    0xFF92A1BA.toInt()
                }
            views.setTextViewText(R.id.widget_status, statusText)
            views.setTextColor(R.id.widget_status, statusColor)
            views.setViewVisibility(R.id.widget_status, View.VISIBLE)

            val intent =
                Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_WIDGET
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(EXTRA_WIDGET_ID, widget.id)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
            val pendingIntent =
                PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            return views
        }

        private fun bindEmptyState(
            context: Context,
            views: RemoteViews,
            title: String,
            body: String,
        ) {
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, "")
            views.setTextViewText(R.id.widget_metric, "")
            views.setTextViewText(R.id.widget_body, body)
            views.setTextViewText(R.id.widget_meta, context.getString(R.string.app_name))
            views.setTextViewText(R.id.widget_status, "")
            views.setViewVisibility(R.id.widget_metric, View.GONE)
            views.setViewVisibility(R.id.widget_rows_group, View.GONE)
            views.setViewVisibility(R.id.widget_status, View.GONE)
        }

        private fun bindRow(
            views: RemoteViews,
            viewId: Int,
            row: Pair<String, String>?,
        ) {
            if (row == null) {
                views.setViewVisibility(viewId, View.GONE)
                return
            }
            views.setViewVisibility(viewId, View.VISIBLE)
            val text = if (row.first.isBlank()) row.second else "${row.first}: ${row.second}"
            views.setTextViewText(viewId, text)
        }

        private fun rows(snapshot: JSONObject?): List<Pair<String, String>> {
            val array = snapshot?.optJSONArray("rows") ?: return emptyList()
            return buildList {
                for (index in 0 until minOf(array.length(), 3)) {
                    val row = array.optJSONObject(index) ?: continue
                    val label = row.optString("label").trim()
                    val value = row.optString("value").trim()
                    if (label.isNotBlank() || value.isNotBlank()) {
                        add(label to value)
                    }
                }
            }
        }

        private fun formatUpdatedFallback(refreshCron: String): String {
            val normalized = refreshCron.trim()
            if (normalized.isBlank()) {
                return ""
            }

            val segments = normalized.split(" ").filter { it.isNotBlank() }
            val looksLikeCron =
                segments.size in 5..7 && normalized.any { it.isDigit() || it == '*' || it == '/' }
            if (!looksLikeCron) {
                return normalized
            }

            val hours = Regex("\\*/(\\d+)").find(normalized)?.groupValues?.getOrNull(1)?.toIntOrNull()
            return when {
                hours != null && hours > 0 -> "Every $hours hours"
                normalized.startsWith("0 0 ") -> "Daily"
                normalized.startsWith("0 0 1 ") -> "Monthly"
                else -> "Auto-refresh enabled"
            }
        }

        private fun joinChips(snapshot: JSONObject?): String {
            val array = snapshot?.optJSONArray("chips") ?: return ""
            return buildList {
                for (index in 0 until minOf(array.length(), 3)) {
                    val chip = array.optString(index).trim()
                    if (chip.isNotBlank()) {
                        add(chip)
                    }
                }
            }.joinToString("  •  ")
        }

        private fun accentColor(token: String): Int {
            return when (token.trim().lowercase()) {
                "warning", "sun", "weather" -> 0xFFFFC370.toInt()
                "success", "health", "growth" -> 0xFF8EE0AF.toInt()
                "alert", "error" -> 0xFFFF9A8A.toInt()
                "sky", "ocean", "summary" -> 0xFF81C7F5.toInt()
                else -> 0xFF7BC4FF.toInt()
            }
        }

        const val ACTION_OPEN_WIDGET = "com.neoagent.flutter_app.widgets.OPEN"
        const val EXTRA_WIDGET_ID = "widgetId"
    }
}
