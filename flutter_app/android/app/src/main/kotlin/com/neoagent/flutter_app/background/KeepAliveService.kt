package com.neoagent.flutter_app.background

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.neoagent.flutter_app.MainActivity
import com.neoagent.flutter_app.R
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps the app process, and with it the Flutter engine holding the server
 * connection, alive in the background so agent calls and approvals can still
 * arrive. It has no work of its own.
 *
 * Android 15 stops data sync services after six hours a day, so from Android
 * 14 on it runs as a special use service. During a call it also takes the
 * phone call and microphone types: without them Android silences the
 * microphone once the call screen leaves the foreground.
 */
class KeepAliveService : Service() {

    companion object {
        private const val TAG = "KeepAliveService"
        private const val CHANNEL = "neoagent/background"

        // Minimum importance: no status bar icon, off the lock screen, collapsed
        // at the bottom of the shade. Importance cannot change once a channel
        // exists, so the old louder channel is removed.
        private const val NOTIFICATION_CHANNEL_ID = "neoagent_background"
        private const val LEGACY_NOTIFICATION_CHANNEL_ID = "neoagent_keepalive"
        private const val NOTIFICATION_ID = 7412

        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"

        @Volatile
        private var running = false

        @Volatile
        private var inCall = false

        fun register(messenger: BinaryMessenger, context: Context) {
            val appContext = context.applicationContext
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        start(
                            appContext,
                            call.argument<String>("title") ?: "NeoAgent",
                            call.argument<String>("body") ?: "",
                        )
                        result.success(null)
                    }
                    "stop" -> {
                        appContext.stopService(Intent(appContext, KeepAliveService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        /** A call started or ended: the service changes its types to match. */
        fun setInCall(context: Context, active: Boolean) {
            if (inCall == active) return
            inCall = active
            if (!running) return
            try {
                context.startService(Intent(context, KeepAliveService::class.java))
            } catch (error: Exception) {
                Log.w(TAG, "Could not update the background service for the call", error)
            }
        }

        private fun start(context: Context, title: String, body: String) {
            if (running) return
            try {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, KeepAliveService::class.java)
                        .putExtra(EXTRA_TITLE, title)
                        .putExtra(EXTRA_BODY, body),
                )
            } catch (error: Exception) {
                // Android refuses to start one from the background; the next
                // connect from the foreground starts it.
                Log.w(TAG, "Background service unavailable", error)
            }
        }
    }

    private var title = "NeoAgent"
    private var body = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra(EXTRA_TITLE)?.let { title = it }
        intent?.getStringExtra(EXTRA_BODY)?.let { body = it }
        running = true
        val notification = buildNotification()
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, serviceType(inCall))
        } catch (error: Exception) {
            // The call types need the app in the foreground; the connection
            // still stays up without them.
            Log.w(TAG, "Foreground service types refused", error)
            try {
                ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, serviceType(false))
            } catch (fallbackError: Exception) {
                Log.w(TAG, "Foreground service refused", fallbackError)
                stopSelf()
            }
        }
        // A restarted service would hold no connection, the engine having
        // died with the process.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun serviceType(call: Boolean): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        var type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        }
        if (call) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            val microphone = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            if (microphone) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        return type
    }

    private fun buildNotification(): android.app.Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
            manager.deleteNotificationChannel(LEGACY_NOTIFICATION_CHANNEL_ID)
            manager.createNotificationChannel(
                NotificationChannel(NOTIFICATION_CHANNEL_ID, title, NotificationManager.IMPORTANCE_MIN).apply {
                    setShowBadge(false)
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
