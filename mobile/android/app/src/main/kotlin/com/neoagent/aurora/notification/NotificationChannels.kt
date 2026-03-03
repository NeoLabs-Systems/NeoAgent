package com.neoagent.aurora.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.content.getSystemService

object NotificationChannels {

    /** Service heartbeat — low-key, no sound, just keeps the service alive. */
    const val SERVICE = "aurora_service"

    /**
     * Live task updates — HIGH importance so the system considers promoting
     * the notification. The channel must NOT be IMPORTANCE_MIN for live updates.
     */
    const val LIVE = "aurora_live_tasks"

    /** Completion summaries — DEFAULT importance, plays a soft sound. */
    const val EVENTS = "aurora_events"

    fun register(context: Context) {
        val nm = context.getSystemService<NotificationManager>() ?: return

        nm.createNotificationChannel(
            NotificationChannel(
                SERVICE,
                "NeoAgent Service",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Keeps NeoAgent running in the background (no sound)"
                setShowBadge(false)
            },
        )

        nm.createNotificationChannel(
            NotificationChannel(
                LIVE,
                "Live Tasks",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Real-time task progress — shown as a Live Update on Android 16"
                setShowBadge(true)
                enableVibration(false)
                setBypassDnd(false)
            },
        )

        nm.createNotificationChannel(
            NotificationChannel(
                EVENTS,
                "Task Results",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Completion and error summaries from NeoAgent"
                setShowBadge(true)
            },
        )
    }
}
