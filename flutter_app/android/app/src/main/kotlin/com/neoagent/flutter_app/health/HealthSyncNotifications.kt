package com.neoagent.flutter_app.health

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.ForegroundInfo
import com.neoagent.flutter_app.MainActivity
import com.neoagent.flutter_app.R

object HealthSyncNotifications {
    private const val ACTIVE_CHANNEL_ID = "neoagent_health_sync_active"
    private const val ALERT_CHANNEL_ID = "neoagent_health_sync_alerts"
    private const val ACTIVE_NOTIFICATION_ID = 4201
    private const val ALERT_NOTIFICATION_ID = 4202

    fun register(context: Context) {
        val manager =
            context.getSystemService(NotificationManager::class.java) ?: return

        manager.createNotificationChannel(
            NotificationChannel(
                ACTIVE_CHANNEL_ID,
                "NeoAgent Health Sync",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description =
                    "Low-key notification shown while NeoAgent health sync is actively running."
                setShowBadge(false)
            },
        )

        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "NeoAgent Health Alerts",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description =
                    "Shown when background health sync needs attention."
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            },
        )
    }

    fun foregroundInfo(
        context: Context,
        message: String,
    ): ForegroundInfo {
        val notification =
            NotificationCompat.Builder(context, ACTIVE_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("NeoAgent health sync")
                .setContentText(message)
                .setOngoing(true)
                .setSilent(true)
                .setOnlyAlertOnce(true)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setContentIntent(buildLaunchIntent(context))
                .build()

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(
                ACTIVE_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            ForegroundInfo(ACTIVE_NOTIFICATION_ID, notification)
        }
    }

    fun showFailure(context: Context, message: String) {
        NotificationManagerCompat.from(context).notify(
            ALERT_NOTIFICATION_ID,
            NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setContentTitle("Health sync needs attention")
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(buildLaunchIntent(context))
                .build(),
        )
    }

    fun clearFailure(context: Context) {
        NotificationManagerCompat.from(context).cancel(ALERT_NOTIFICATION_ID)
    }

    private fun buildLaunchIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
