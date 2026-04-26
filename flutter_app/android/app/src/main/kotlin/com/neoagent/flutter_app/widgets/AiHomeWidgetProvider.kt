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


    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE_TASKS) {
            val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val store = AiWidgetStore(context)
                store.toggleTasksExpanded(appWidgetId)
                refreshAll(context, AppWidgetManager.getInstance(context), intArrayOf(appWidgetId))
            }
        } else if (intent.action == ACTION_RUN_TASK) {
            val taskId = intent.getStringExtra(EXTRA_TASK_ID)
            if (taskId != null) {
                WidgetTaskRunWorker.enqueue(context, taskId)
            }
        }
    }

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
            val accent = accentColor(
                cleanText(snapshot?.optString("accentToken")),
                cleanText(snapshot?.optString("surfaceColor")),
            )
            val displayName = displayName(widget.name)
            val kicker = cleanText(snapshot?.optString("kicker"))
            val metricLabel = cleanText(snapshot?.optString("metricLabel"))
            val secondaryMetric = cleanText(snapshot?.optString("secondaryMetric"))
            val secondaryLabel = cleanText(snapshot?.optString("secondaryLabel"))
            val tertiaryMetric = cleanText(snapshot?.optString("tertiaryMetric"))
            val tertiaryLabel = cleanText(snapshot?.optString("tertiaryLabel"))
            val title =
                cleanText(snapshot?.optString("title"))
                    .ifBlank { displayName }
            val subtitle =
                sequenceOf(
                    listOf(kicker, cleanText(snapshot?.optString("subtitle"))).filter { it.isNotBlank() }
                        .joinToString(" • ")
                        .trim(),
                    metricLabel,
                    displayName,
                ).firstOrNull { it.isNotBlank() }
                    ?: cadenceLabel(widget.refreshCron)
            val metric = cleanText(snapshot?.optString("metric"))
            val body = cleanText(snapshot?.optString("body"))
            val chips = joinChips(snapshot)
            val rows = supportingRows(snapshot, secondaryLabel, secondaryMetric, tertiaryLabel, tertiaryMetric)
            val updated = snapshot?.optString("updatedAt").orEmpty().ifBlank {
                formatUpdatedFallback(widget.refreshCron)
            }
            val hasSnapshot = snapshot != null
            val supportSummary =
                listOf(
                    labeledValue(secondaryLabel, secondaryMetric),
                    labeledValue(tertiaryLabel, tertiaryMetric),
                    chips,
                ).firstOrNull { it.isNotBlank() }.orEmpty()
            val bodyText =
                when {
                    body.isNotBlank() -> body
                    supportSummary.isNotBlank() -> supportSummary
                    !hasSnapshot -> "Waiting for first update"
                    else -> "Open in NeoAgent for the full view"
                }

            views.setTextViewText(R.id.widget_title, title)
            views.setTextColor(R.id.widget_title, Color.WHITE)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setTextColor(R.id.widget_subtitle, 0xFFD1D8E6.toInt())
            views.setTextViewText(R.id.widget_metric, metric)
            views.setTextColor(R.id.widget_metric, accent)
            views.setTextViewText(R.id.widget_body, bodyText)
            views.setTextColor(R.id.widget_body, 0xFFF4F6FA.toInt())
            views.setTextViewText(R.id.widget_meta, updated)
            views.setTextColor(R.id.widget_meta, 0xFF92A1BA.toInt())

            bindRow(views, R.id.widget_row_1, rows.getOrNull(0))
            bindRow(views, R.id.widget_row_2, rows.getOrNull(1))
            bindRow(views, R.id.widget_row_3, rows.getOrNull(2))

            val showMetric = metric.isNotBlank()
            views.setViewVisibility(R.id.widget_metric, if (showMetric) View.VISIBLE else View.GONE)
            views.setViewVisibility(
                R.id.widget_rows_group,
                if (rows.isNotEmpty()) View.VISIBLE else View.GONE,
            )

            val statusText = widget.lastError?.takeIf { it.isNotBlank() }
                ?: if (widget.enabled) cadenceLabel(widget.refreshCron) else "Paused"
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

            // Tasks Rendering
            val tasks = widget.tasks
            if (tasks.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_tasks_toggle_group, View.VISIBLE)
                val isExpanded = store.isTasksExpanded(appWidgetId)
                views.setTextViewText(R.id.widget_tasks_toggle_text, if (isExpanded) "Tasks (${tasks.size}) ▲" else "Tasks (${tasks.size}) ▼")
                views.setTextColor(R.id.widget_tasks_toggle_text, accent)
                
                val toggleIntent = Intent(context, AiHomeWidgetProvider::class.java).apply {
                    action = ACTION_TOGGLE_TASKS
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val togglePendingIntent = PendingIntent.getBroadcast(
                    context, appWidgetId, toggleIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_tasks_toggle_group, togglePendingIntent)
                
                if (isExpanded) {
                    views.setViewVisibility(R.id.widget_tasks_container, View.VISIBLE)
                    views.removeAllViews(R.id.widget_tasks_container)
                    tasks.forEach { task ->
                        val taskView = RemoteViews(context.packageName, R.layout.neoagent_ai_widget_task_row)
                        taskView.setTextViewText(R.id.task_name, task.name)
                        if (task.triggerSummary.isNotBlank()) {
                            taskView.setTextViewText(R.id.task_schedule, task.triggerSummary)
                            taskView.setViewVisibility(R.id.task_schedule, View.VISIBLE)
                        } else {
                            taskView.setViewVisibility(R.id.task_schedule, View.GONE)
                        }
                        
                        val runIntent = Intent(context, AiHomeWidgetProvider::class.java).apply {
                            action = ACTION_RUN_TASK
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                            putExtra(EXTRA_TASK_ID, task.id)
                        }
                        val bucket = kotlin.math.abs(task.id.hashCode()) % 1000
                        val runPendingIntent = PendingIntent.getBroadcast(
                            context, appWidgetId * 1000 + bucket, runIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        taskView.setOnClickPendingIntent(R.id.task_run_btn, runPendingIntent)
                        
                        views.addView(R.id.widget_tasks_container, taskView)
                    }
                } else {
                    views.setViewVisibility(R.id.widget_tasks_container, View.GONE)
                    views.removeAllViews(R.id.widget_tasks_container)
                }
            } else {
                views.setViewVisibility(R.id.widget_tasks_toggle_group, View.GONE)
                views.setViewVisibility(R.id.widget_tasks_container, View.GONE)
            }


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
                    val label = cleanText(row.optString("label"))
                    val value = cleanText(row.optString("value"))
                    if (label.isNotBlank() || value.isNotBlank()) {
                        add(label to value)
                    }
                }
            }
        }

        private fun supportingRows(
            snapshot: JSONObject?,
            secondaryLabel: String,
            secondaryMetric: String,
            tertiaryLabel: String,
            tertiaryMetric: String,
        ): List<Pair<String, String>> {
            val explicitRows = rows(snapshot)
            if (explicitRows.isNotEmpty()) {
                return explicitRows
            }
            val progress = progressRow(snapshot)
            return listOfNotNull(
                rowOrNull(secondaryLabel, secondaryMetric),
                rowOrNull(tertiaryLabel, tertiaryMetric),
                progress,
            ).take(3)
        }

        private fun rowOrNull(label: String, value: String): Pair<String, String>? {
            val safeLabel = cleanText(label)
            val safeValue = cleanText(value)
            if (safeLabel.isBlank() && safeValue.isBlank()) {
                return null
            }
            return safeLabel to safeValue
        }

        private fun labeledValue(label: String, value: String): String {
            val safeLabel = cleanText(label)
            val safeValue = cleanText(value)
            return when {
                safeLabel.isBlank() -> safeValue
                safeValue.isBlank() -> safeLabel
                else -> "$safeLabel $safeValue"
            }
        }

        private fun progressRow(snapshot: JSONObject?): Pair<String, String>? {
            val progress = snapshot?.optJSONObject("progress") ?: return null
            val value = cleanText(progress.opt("value")?.toString())
            val max = cleanText(progress.opt("max")?.toString())
            val label = cleanText(progress.optString("label")).ifBlank { "Progress" }
            if (value.isBlank() || max.isBlank()) {
                return null
            }
            return label to "$value / $max"
        }

        private fun cleanText(value: String?): String {
            val normalized = value?.trim().orEmpty()
            return if (normalized.isBlank() || normalized.equals("null", ignoreCase = true)) {
                ""
            } else {
                normalized
            }
        }

        private fun displayName(raw: String): String {
            val normalized =
                raw.trim()
                    .replace(Regex("[_-]+"), " ")
                    .replace(Regex("\\s+"), " ")
            if (normalized.isBlank()) {
                return "AI Widget"
            }
            return normalized.split(" ")
                .filter { it.isNotBlank() }
                .joinToString(" ") { part ->
                    if (part.length <= 2 && part.uppercase() == part) {
                        part
                    } else {
                        part.substring(0, 1).uppercase() + part.substring(1)
                    }
                }
        }

        private fun cadenceLabel(refreshCron: String): String {
            val normalized = refreshCron.trim()
            if (normalized == "0 * * * *") {
                return "Updates hourly"
            }
            val hours = Regex("\\*/(\\d+)").find(normalized)?.groupValues?.getOrNull(1)?.toIntOrNull()
            if (hours != null && hours > 1) {
                return "Every $hours hours"
            }
            return "Refreshes automatically"
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

        private fun accentColor(token: String, surfaceColor: String): Int {
            parseColor(surfaceColor)?.let { return it }
            return when (token.trim().lowercase()) {
                "warning", "sun", "sunny", "weather" -> 0xFFFFC370.toInt()
                "success", "health", "growth", "battery", "electric" -> 0xFF8EE0AF.toInt()
                "alert", "error", "storm" -> 0xFFFF9A8A.toInt()
                "sky", "ocean", "summary", "rain", "cloud" -> 0xFF81C7F5.toInt()
                "night" -> 0xFFB7C9FF.toInt()
                else -> 0xFF7BC4FF.toInt()
            }
        }

        private fun parseColor(raw: String): Int? {
            val normalized = cleanText(raw)
            if (normalized.isBlank()) {
                return null
            }
            val hex = if (normalized.startsWith("#")) normalized else "#$normalized"
            return try {
                Color.parseColor(hex)
            } catch (_: IllegalArgumentException) {
                null
            }
        }


        const val ACTION_OPEN_WIDGET = "com.neoagent.flutter_app.widgets.OPEN"
        const val ACTION_TOGGLE_TASKS = "com.neoagent.flutter_app.widgets.TOGGLE_TASKS"
        const val ACTION_RUN_TASK = "com.neoagent.flutter_app.widgets.RUN_TASK"
        const val EXTRA_WIDGET_ID = "widgetId"
        const val EXTRA_TASK_ID = "taskId"

    }
}
