package com.neoagent.flutter_app.widgets

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews
import com.neoagent.flutter_app.R

/** One tap into a voice call; during a call it shows the clock and leads back to it. */
class CallWidgetProvider : HomeWidgetProvider() {
    override fun layouts(context: Context, status: HomeWidgetStatus?) = listOf(
        SizedLayout(SizeF(40f, 40f)) { base(context, status, R.layout.neoagent_widget_call_tile) },
        SizedLayout(SizeF(100f, 100f)) { square(context, status) },
        SizedLayout(SizeF(180f, 40f)) { wide(context, status) },
    )

    private fun square(context: Context, status: HomeWidgetStatus?) =
        wide(context, status, R.layout.neoagent_widget_call).apply {
            setTextViewText(
                R.id.neoagent_widget_call_label,
                context.getString(
                    if (status?.callStartedAtMs != null) {
                        R.string.neoagent_widget_return_to_call
                    } else {
                        R.string.neoagent_widget_call
                    },
                ),
            )
        }

    private fun wide(
        context: Context,
        status: HomeWidgetStatus?,
        layout: Int = R.layout.neoagent_widget_call_wide,
    ) = base(context, status, layout).apply {
        setTextViewText(
            R.id.neoagent_widget_title,
            context.getString(
                if (status?.callStartedAtMs != null) {
                    R.string.neoagent_widget_on_call
                } else {
                    R.string.neoagent_widget_talk
                },
            ),
        )
        bindLabel(context, R.id.neoagent_widget_label, status)
        bindCallTimer(R.id.neoagent_widget_call_timer, status)
    }

    private fun base(context: Context, status: HomeWidgetStatus?, layout: Int) =
        RemoteViews(context.packageName, layout).apply {
            setOnClickPendingIntent(android.R.id.background, startCallIntent(context))
            bindFace(R.id.neoagent_widget_face, status)
        }
}
