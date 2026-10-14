package com.neoagent.flutter_app.widgets

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews
import com.neoagent.flutter_app.R

/** One tap into a voice call: the mascot with a call badge, at any size. */
class CallWidgetProvider : HomeWidgetProvider() {
    override fun layouts(context: Context, status: HomeWidgetStatus?, bounds: SizeF?) = listOf(
        SizedLayout(SizeF(40f, 40f)) {
            RemoteViews(context.packageName, R.layout.neoagent_widget_call).apply {
                setOnClickPendingIntent(android.R.id.background, startCallIntent(context))
                bindFace(context, R.id.neoagent_widget_face, status)
                fitAvatar(context, R.id.neoagent_widget_avatar, bounds, badgeId = R.id.neoagent_widget_call_badge)
            }
        },
    )
}
