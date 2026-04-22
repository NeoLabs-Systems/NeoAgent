package com.neoagent.flutter_app.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.neoagent.flutter_app.MainActivity
import com.neoagent.flutter_app.R

class VoiceLaunchWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        refreshAll(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        const val ACTION_OPEN_VOICE_ASSISTANT =
            "com.neoagent.flutter_app.widgets.OPEN_VOICE_ASSISTANT"
        const val OPEN_TARGET_VOICE_ASSISTANT = "voice_assistant"

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, VoiceLaunchWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            refreshAll(context, manager, ids)
        }

        fun refreshAll(
            context: Context,
            manager: AppWidgetManager,
            appWidgetIds: IntArray,
        ) {
            appWidgetIds.forEach { appWidgetId ->
                manager.updateAppWidget(appWidgetId, buildRemoteViews(context, appWidgetId))
            }
        }

        private fun buildRemoteViews(context: Context, appWidgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.neoagent_voice_widget)
            val intent =
                Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_VOICE_ASSISTANT
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
            val pendingIntent =
                PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            views.setOnClickPendingIntent(R.id.voice_widget_root, pendingIntent)
            return views
        }
    }
}
