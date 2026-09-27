package com.neoagent.flutter_app.widgets

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.text.format.DateUtils
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.neoagent.flutter_app.MainActivity
import com.neoagent.flutter_app.R
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.text.DateFormat

/** Glue between the app and its home-screen widgets. */
object HomeWidgets {
    /** Launches the app straight into a voice call. */
    const val ACTION_START_CALL = "com.neoagent.flutter_app.action.START_CALL"

    private val providers = listOf(
        StatusWidgetProvider::class.java,
        CallWidgetProvider::class.java,
    )

    fun registerChannel(messenger: BinaryMessenger, activity: Activity) {
        val context = activity.applicationContext
        MethodChannel(messenger, "neoagent/home_widgets").setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> {
                    val mood = HomeWidgetMood.of(call.argument<String>("mood"))
                    val live = call.argument<Boolean>("live") == true
                    HomeWidgetRefresh.saveSession(
                        context,
                        backendUrl = call.argument<String>("backendUrl").orEmpty(),
                        cookie = call.argument<String>("sessionCookie").orEmpty(),
                        agentId = call.argument<String>("agentId").orEmpty(),
                    )
                    HomeWidgetStatus.publish(
                        context,
                        mood = mood,
                        detail = call.argument<String>("detail").orEmpty(),
                        live = live,
                        callStartedAtMs = call.argument<Number>("callStartedAtMs")?.toLong(),
                    )
                    refreshAll(context)
                    // Leaving the app mid-run: keep following it from the server.
                    HomeWidgetRefresh.sync(
                        context,
                        refreshInSeconds = HomeWidgetRefresh.UNDER_WAY_SECONDS.takeIf { !live && mood.changesSoon },
                    )
                    result.success(null)
                }
                "returnToHomeScreen" -> {
                    activity.moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun hasWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return providers.any { manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isEmpty()) continue
            context.sendBroadcast(
                Intent(context, provider)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }
}

/** Renders every instance from the last published [HomeWidgetStatus]. */
abstract class HomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val status = HomeWidgetStatus.read(context)
        for (id in ids) {
            manager.updateAppWidget(id, layouts(context, status).pick(manager, id))
        }
    }

    override fun onEnabled(context: Context) {
        HomeWidgetRefresh.sync(context, refreshInSeconds = 0)
    }

    override fun onDisabled(context: Context) {
        HomeWidgetRefresh.sync(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        manager.updateAppWidget(id, layouts(context, HomeWidgetStatus.read(context)).pick(manager, id))
    }

    /** One layout per size the widget adapts to, smallest first. */
    internal abstract fun layouts(context: Context, status: HomeWidgetStatus?): List<SizedLayout>
}

/** A layout used once the widget is at least [minSize] dp. */
internal class SizedLayout(val minSize: SizeF, val build: () -> RemoteViews)

/**
 * Android 12+ switches layouts itself as the widget is resized; older
 * launchers only report the size range, so the largest layout that fits the
 * portrait size is chosen here.
 */
private fun List<SizedLayout>.pick(manager: AppWidgetManager, id: Int): RemoteViews {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        return RemoteViews(associate { it.minSize to it.build() })
    }
    val options = manager.getAppWidgetOptions(id)
    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
    val fits = lastOrNull { it.minSize.width <= width && it.minSize.height <= height }
    return (fits ?: first()).build()
}

internal fun startCallIntent(context: Context): PendingIntent =
    activityIntent(context, 1, HomeWidgets.ACTION_START_CALL)

internal fun openAppIntent(context: Context): PendingIntent =
    activityIntent(context, 0, Intent.ACTION_MAIN)

private fun activityIntent(context: Context, requestCode: Int, action: String): PendingIntent =
    PendingIntent.getActivity(
        context,
        requestCode,
        Intent(context, MainActivity::class.java)
            .setAction(action)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

/** The mood's animated face; the launcher plays it without the app. */
internal fun RemoteViews.bindFace(context: Context, viewId: Int, status: HomeWidgetStatus?) {
    removeAllViews(viewId)
    addView(viewId, RemoteViews(context.packageName, (status?.mood ?: HomeWidgetMood.ASLEEP).face))
}

internal fun RemoteViews.bindLabel(context: Context, viewId: Int, status: HomeWidgetStatus?) {
    val label = when {
        status == null -> R.string.neoagent_widget_not_connected
        status.mood == HomeWidgetMood.IDLE && status.callStartedAtMs != null -> R.string.neoagent_widget_on_call
        else -> status.mood.label
    }
    setTextViewText(viewId, context.getString(label))
    val color = if (status?.mood == HomeWidgetMood.BLOCKED) {
        R.color.neoagent_widget_alert
    } else {
        R.color.neoagent_widget_text_primary
    }
    setTextColor(viewId, context.getColor(color))
}

internal fun RemoteViews.bindText(viewId: Int, text: CharSequence) {
    setTextViewText(viewId, text)
    setViewVisibility(viewId, if (text.isBlank()) View.GONE else View.VISIBLE)
}

/** "Live" while the app follows the agent, otherwise when it last did. */
internal fun RemoteViews.bindFreshness(
    context: Context,
    dotId: Int,
    textId: Int,
    status: HomeWidgetStatus?,
) {
    if (status == null) {
        setViewVisibility(dotId, View.GONE)
        setViewVisibility(textId, View.GONE)
        return
    }
    val text = if (status.live) {
        context.getString(R.string.neoagent_widget_live)
    } else {
        context.getString(
            R.string.neoagent_widget_seen,
            DateUtils.formatSameDayTime(
                status.updatedAtMs,
                System.currentTimeMillis(),
                DateFormat.MEDIUM,
                DateFormat.SHORT,
            ),
        )
    }
    val dotColor = if (status.live) R.color.neoagent_widget_success else R.color.neoagent_widget_text_muted
    setViewVisibility(dotId, View.VISIBLE)
    setInt(dotId, "setColorFilter", context.getColor(dotColor))
    bindText(textId, text)
}

/** Runs the call clock natively, so it ticks without the app. */
internal fun RemoteViews.bindCallTimer(viewId: Int, status: HomeWidgetStatus?) {
    val startedAt = status?.callStartedAtMs
    if (startedAt == null) {
        setChronometer(viewId, SystemClock.elapsedRealtime(), null, false)
        setViewVisibility(viewId, View.GONE)
        return
    }
    val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - startedAt)
    setChronometer(viewId, base, null, true)
    setViewVisibility(viewId, View.VISIBLE)
}
