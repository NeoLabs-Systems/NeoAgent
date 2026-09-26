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
                    HomeWidgetStatus.write(
                        context,
                        mood = call.argument<String>("mood").orEmpty(),
                        label = call.argument<String>("label").orEmpty(),
                        detail = call.argument<String>("detail").orEmpty(),
                        live = call.argument<Boolean>("live") == true,
                        callStartedAtMs = call.argument<Number>("callStartedAtMs")?.toLong(),
                        face = call.argument<ByteArray>("face"),
                    )
                    refreshAll(context)
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

    private fun refreshAll(context: Context) {
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

internal fun RemoteViews.bindFace(viewId: Int, status: HomeWidgetStatus?) {
    status?.face?.let { setImageViewBitmap(viewId, it) }
}

internal fun RemoteViews.bindLabel(context: Context, viewId: Int, status: HomeWidgetStatus?) {
    setTextViewText(viewId, status?.label ?: context.getString(R.string.neoagent_widget_not_connected))
    val color = if (status?.isAlert == true) R.color.neoagent_widget_alert else R.color.neoagent_widget_text_primary
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
