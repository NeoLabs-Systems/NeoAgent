package com.neoagent.aurora.health

import android.content.Context
import android.util.Log
import com.neoagent.aurora.network.BackendSessionClient
import com.neoagent.aurora.settings.SettingsManager
import com.neoagent.aurora.ui.LogBuffer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.time.Duration
import java.time.Instant

private const val TAG = "HealthSyncManager"

/**
 * Periodically reads Health Connect records and posts them to the NeoAgent backend.
 *
 * The app already runs a persistent foreground service, so this manager hooks into that service
 * rather than relying on WorkManager's larger scheduling windows.
 */
class HealthSyncManager(
    context: Context,
    private val settings: SettingsManager,
    private val backendSessionClient: BackendSessionClient,
) {

    private val appContext = context.applicationContext
    private val gateway = HealthConnectGateway(appContext)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val syncMutex = Mutex()

    private var loopJob: Job? = null

    fun start() {
        if (loopJob?.isActive == true) return
        loopJob = scope.launch {
            while (isActive) {
                val delayMs = syncIfDue(reason = "scheduled")
                delay(delayMs)
            }
        }
    }

    fun stop() {
        loopJob?.cancel()
        loopJob = null
    }

    fun requestImmediateSync(reason: String = "manual") {
        scope.launch {
            syncNow(reason)
        }
    }

    private suspend fun syncIfDue(reason: String): Long {
        if (!settings.healthSyncEnabled) return DISABLED_POLL_INTERVAL_MS

        val lastAttempt = settings.healthLastAttemptAt?.let(::parseInstantOrNull)
        val now = Instant.now()
        if (lastAttempt != null) {
            val elapsedMs = Duration.between(lastAttempt, now).toMillis()
            if (elapsedMs in 0 until SYNC_INTERVAL_MS) {
                return SYNC_INTERVAL_MS - elapsedMs
            }
        }

        syncNow(reason)
        return SYNC_INTERVAL_MS
    }

    private suspend fun syncNow(reason: String) {
        if (!settings.healthSyncEnabled) return

        syncMutex.withLock {
            val startedAt = Instant.now()
            settings.healthLastAttemptAt = startedAt.toString()

            val sdkStatus = gateway.getSdkStatus()
            if (sdkStatus != androidx.health.connect.client.HealthConnectClient.SDK_AVAILABLE) {
                val message = "Health Connect unavailable on this device (status=$sdkStatus)"
                settings.healthLastError = message
                LogBuffer.warn("Health sync paused: $message")
                Log.w(TAG, message)
                return
            }

            val client = gateway.getClientOrNull()
            if (client == null) {
                val message = "Health Connect client unavailable"
                settings.healthLastError = message
                LogBuffer.warn("Health sync paused: $message")
                Log.w(TAG, message)
                return
            }

            val requiredPermissions = gateway.getRequestedPermissions(client)
            val grantedPermissions = client.permissionController.getGrantedPermissions()
            if (!grantedPermissions.containsAll(requiredPermissions)) {
                val message = "Health permissions missing"
                settings.healthLastError = message
                LogBuffer.warn("Health sync paused: request permissions in Settings")
                Log.w(TAG, "$message: ${requiredPermissions - grantedPermissions}")
                return
            }

            val windowEnd = Instant.now()
            val lastSuccess = settings.healthLastSuccessfulSyncAt?.let(::parseInstantOrNull)
            val windowStart = when {
                lastSuccess == null -> windowEnd.minus(INITIAL_LOOKBACK)
                else -> lastSuccess.minus(OVERLAP_BUFFER)
            }

            try {
                val payload = gateway.collectBatch(client, windowStart, windowEnd)
                backendSessionClient.postJson("/api/mobile/health/sync", payload.toJson())
                settings.healthLastSuccessfulSyncAt = windowEnd.toString()
                settings.healthLastError = null
                LogBuffer.success(
                    "Health sync sent ${payload.records.size} records (${reason.lowercase()})",
                )
                Log.i(TAG, "Health sync success: ${payload.records.size} records")
            } catch (err: Exception) {
                val message = err.message ?: err.javaClass.simpleName
                settings.healthLastError = message
                LogBuffer.error("Health sync failed: $message")
                Log.e(TAG, "Health sync failed", err)
            }
        }
    }

    private fun parseInstantOrNull(value: String): Instant? {
        return runCatching { Instant.parse(value) }.getOrNull()
    }

    companion object {
        private val INITIAL_LOOKBACK = Duration.ofHours(24)
        private val OVERLAP_BUFFER = Duration.ofMinutes(5)
        private const val SYNC_INTERVAL_MS = 10 * 60 * 1000L
        private const val DISABLED_POLL_INTERVAL_MS = 60 * 1000L
    }
}
