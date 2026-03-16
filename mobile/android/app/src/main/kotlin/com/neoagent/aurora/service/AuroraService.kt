package com.neoagent.aurora.service

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.lifecycle.LifecycleService
import com.neoagent.aurora.health.HealthSyncManager
import com.neoagent.aurora.R
import com.neoagent.aurora.network.BackendSessionClient
import com.neoagent.aurora.network.ConnectionState
import com.neoagent.aurora.network.NeoSocketManager
import com.neoagent.aurora.network.RunEvent
import com.neoagent.aurora.network.RunEventListener
import com.neoagent.aurora.notification.LiveUpdateManager
import com.neoagent.aurora.notification.NotificationChannels
import com.neoagent.aurora.settings.SettingsManager
import com.neoagent.aurora.ui.LogBuffer
import java.util.concurrent.CopyOnWriteArrayList

private const val TAG = "AuroraService"

/** Notification ID for the persistent service notification (low-key). */
const val SERVICE_NOTIF_ID = 1

/**
 * 24/7 persistent foreground service.
 *
 * Responsibilities:
 *  - Holds a socket connection alive at all times
 *  - Delegates incoming run events to [LiveUpdateManager]
 *  - Survives process death via [stopWithTask = false] and [BootReceiver]
 */
class AuroraService : LifecycleService(), RunEventListener {

    private lateinit var backendSessionClient: BackendSessionClient
    private lateinit var healthSyncManager: HealthSyncManager
    private lateinit var socketManager: NeoSocketManager
    private lateinit var liveUpdateManager: LiveUpdateManager
    private lateinit var settings: SettingsManager

    // ── Lifecycle ───────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        settings          = SettingsManager(this)
        backendSessionClient = BackendSessionClient(settings)
        liveUpdateManager = LiveUpdateManager(this)
        socketManager     = NeoSocketManager(
            listener = this,
            settings = settings,
            backendSessionClient = backendSessionClient,
        )
        healthSyncManager = HealthSyncManager(
            context = this,
            settings = settings,
            backendSessionClient = backendSessionClient,
        )

        startForeground(SERVICE_NOTIF_ID, buildServiceNotification(
            text = getString(R.string.notif_service_reconnecting),
            connected = false,
        ))

        LogBuffer.info("▶ Aurora service starting")
        socketManager.connect()
        healthSyncManager.start()
        Log.i(TAG, "Aurora service started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            ACTION_HEALTH_SYNC_NOW -> healthSyncManager.requestImmediateSync(reason = "manual")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        socketManager.disconnect()
        healthSyncManager.stop()
        liveUpdateManager.cancelAll()
        notifyState(ConnectionState.DISCONNECTED)
        LogBuffer.warn("■ Aurora service stopped")
        Log.i(TAG, "Aurora service destroyed — will be restarted by system")
    }

    // ── RunEventListener ────────────────────────────────────────────────────

    override fun onEvent(event: RunEvent) {
        liveUpdateManager.handleEvent(event)
        // Mirror significant events to the in-app log
        when (event) {
            is RunEvent.Start     -> LogBuffer.event("▶ Run: ${event.title.take(60)}")
            is RunEvent.Thinking  -> LogBuffer.info("💭 Thinking (iter ${event.iteration})")
            is RunEvent.ToolStart -> LogBuffer.info("⚙  ${event.tool}")
            is RunEvent.ToolEnd   -> LogBuffer.info("⚙  ${event.tool} done (${event.durationMs}ms)")
            is RunEvent.Interim   -> LogBuffer.info("│  ${event.message.take(80)}")
            is RunEvent.Complete  -> LogBuffer.success("✓ Done: ${event.content.take(70)}")
            is RunEvent.Error     -> LogBuffer.error("✗ Error: ${event.error.take(80)}")
            is RunEvent.Stream    -> { /* too noisy — skip */ }
        }
    }

    override fun onConnectionStateChanged(state: ConnectionState, detail: String?) {
        Log.d(TAG, "Connection state: $state${if (detail != null) " — $detail" else ""}")

        notifyState(state)   // update static + broadcast to MainActivity

        val (text, connected) = when (state) {
            ConnectionState.CONNECTED    -> getString(R.string.notif_service_text) to true
            ConnectionState.CONNECTING   -> "Connecting to NeoAgent…"             to false
            ConnectionState.RECONNECTING ->
                (if (detail != null) "Reconnecting: $detail"
                 else getString(R.string.notif_service_reconnecting))             to false
            ConnectionState.DISCONNECTED -> "Disconnected"                         to false
        }
        val logMsg = if (detail != null) "$text ($detail)" else text
        LogBuffer.info("○ $logMsg")

        updateServiceNotification(text, connected)
    }

    // ── Service notification ────────────────────────────────────────────────

    private fun updateServiceNotification(text: String, connected: Boolean) {
        val nm = getSystemService(android.app.NotificationManager::class.java)
        nm.notify(SERVICE_NOTIF_ID, buildServiceNotification(text, connected))
    }

    private fun buildServiceNotification(text: String, connected: Boolean): Notification {
        val icon = if (connected) R.drawable.ic_notification else R.drawable.ic_thinking
        return Notification.Builder(this, NotificationChannels.SERVICE)
            .setSmallIcon(icon)
            .setContentTitle(getString(R.string.notif_service_title))
            .setContentText(text)
            .setOngoing(true)
            .setShowWhen(false)
            .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    // ── Static state + listeners (used by MainActivity) ─────────────────────

    companion object {
        private const val ACTION_HEALTH_SYNC_NOW = "com.neoagent.aurora.action.HEALTH_SYNC_NOW"

        @Volatile var currentState: ConnectionState = ConnectionState.DISCONNECTED
            private set

        private val stateListeners = CopyOnWriteArrayList<(ConnectionState) -> Unit>()

        fun addStateListener(l: (ConnectionState) -> Unit)    = stateListeners.add(l)
        fun removeStateListener(l: (ConnectionState) -> Unit) = stateListeners.remove(l)

        internal fun notifyState(state: ConnectionState) {
            currentState = state
            stateListeners.forEach { it(state) }
        }

        fun start(context: Context) {
            context.startForegroundService(Intent(context, AuroraService::class.java))
        }

        fun requestImmediateHealthSync(context: Context) {
            context.startService(
                Intent(context, AuroraService::class.java).apply {
                    action = ACTION_HEALTH_SYNC_NOW
                },
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AuroraService::class.java))
        }
    }
}
