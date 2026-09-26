package com.neoagent.flutter_app.widgets

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews
import com.neoagent.flutter_app.R

/** What NeoAgent is doing: the mascot's face, its state and the work it is on. */
class StatusWidgetProvider : HomeWidgetProvider() {
    override fun layouts(context: Context, status: HomeWidgetStatus?) = listOf(
        SizedLayout(SizeF(110f, 40f)) { compact(context, status) },
        SizedLayout(SizeF(200f, 100f)) { full(context, status) },
    )

    private fun compact(context: Context, status: HomeWidgetStatus?) =
        RemoteViews(context.packageName, R.layout.neoagent_widget_status_compact).apply {
            setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
            bindFace(R.id.neoagent_widget_face, status)
            bindLabel(context, R.id.neoagent_widget_label, status)
            bindFreshness(context, R.id.neoagent_widget_dot, R.id.neoagent_widget_freshness, status)
            bindText(R.id.neoagent_widget_detail, detail(context, status))
        }

    private fun full(context: Context, status: HomeWidgetStatus?) =
        RemoteViews(context.packageName, R.layout.neoagent_widget_status).apply {
            setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
            setOnClickPendingIntent(R.id.neoagent_widget_call_button, startCallIntent(context))
            bindFace(R.id.neoagent_widget_face, status)
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
