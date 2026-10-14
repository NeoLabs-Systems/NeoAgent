package com.neoagent.flutter_app.widgets

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews
import com.neoagent.flutter_app.R

/**
 * What NeoAgent is doing. Small and one-row sizes sit on the wallpaper as the
 * mascot alone (with its state beside it when there is room); the full size
 * is a panel with the work it is on and a call button.
 */
class StatusWidgetProvider : HomeWidgetProvider() {
    override fun layouts(context: Context, status: HomeWidgetStatus?, bounds: SizeF?) = listOf(
        SizedLayout(SizeF(40f, 40f)) { avatar(context, status, bounds) },
        SizedLayout(SizeF(180f, 40f)) { compact(context, status, bounds) },
        SizedLayout(SizeF(200f, 100f)) { full(context, status) },
    )

    private fun avatar(context: Context, status: HomeWidgetStatus?, bounds: SizeF?) =
        RemoteViews(context.packageName, R.layout.neoagent_widget_status_avatar).apply {
            setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
            setContentDescription(android.R.id.background, context.getString(labelOf(status)))
            bindFace(context, R.id.neoagent_widget_face, status)
            fitAvatar(context, R.id.neoagent_widget_avatar, bounds)
        }

    private fun compact(context: Context, status: HomeWidgetStatus?, bounds: SizeF?) =
        RemoteViews(context.packageName, R.layout.neoagent_widget_status_compact).apply {
            setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
            bindFace(context, R.id.neoagent_widget_face, status)
            fitAvatar(context, R.id.neoagent_widget_avatar, bounds)
            bindLabel(
                context,
                R.id.neoagent_widget_label,
                status,
                color = R.color.neoagent_widget_wallpaper_text,
                alertColor = R.color.neoagent_widget_wallpaper_alert,
            )
            bindText(R.id.neoagent_widget_detail, detail(context, status))
        }

    private fun full(context: Context, status: HomeWidgetStatus?) =
        RemoteViews(context.packageName, R.layout.neoagent_widget_status).apply {
            setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
            setOnClickPendingIntent(R.id.neoagent_widget_call_button, startCallIntent(context))
            bindFace(context, R.id.neoagent_widget_face, status)
            bindLabel(context, R.id.neoagent_widget_label, status)
            bindFreshness(context, R.id.neoagent_widget_dot, R.id.neoagent_widget_freshness, status)
            bindText(R.id.neoagent_widget_detail, detail(context, status))
            bindCallTimer(R.id.neoagent_widget_call_timer, status)
            setTextViewText(
                R.id.neoagent_widget_call_label,
                context.getString(
                    if (status?.callStartedAtMs != null) {
                        R.string.neoagent_widget_return_to_call
                    } else {
                        R.string.neoagent_widget_talk
                    },
                ),
            )
        }

    private fun detail(context: Context, status: HomeWidgetStatus?): String =
        status?.detail ?: context.getString(R.string.neoagent_widget_open_to_connect)
}
