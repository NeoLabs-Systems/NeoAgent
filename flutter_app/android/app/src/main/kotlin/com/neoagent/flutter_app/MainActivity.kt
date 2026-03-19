package com.neoagent.flutter_app

import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import com.neoagent.flutter_app.health.HealthConnectGateway
import com.neoagent.flutter_app.health.HealthSyncScheduler
import com.neoagent.flutter_app.recording.RecordingForegroundService
import com.neoagent.flutter_app.recording.RecordingStateStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Instant

class MainActivity : FlutterFragmentActivity() {

    private lateinit var healthGateway: HealthConnectGateway
    private lateinit var healthSyncScheduler: HealthSyncScheduler
    private lateinit var recordingStateStore: RecordingStateStore
    private lateinit var permissionLauncher: ActivityResultLauncher<Set<String>>
    private lateinit var microphonePermissionLauncher: ActivityResultLauncher<String>
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRecordingResult: MethodChannel.Result? = null
    private var pendingRecordingArgs: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        healthGateway = HealthConnectGateway(this)
        healthSyncScheduler = HealthSyncScheduler(this)
        recordingStateStore = RecordingStateStore(this)
        permissionLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) {
            val pending = pendingPermissionResult
            pendingPermissionResult = null
            lifecycleScope.launch {
                pending?.success(buildStatusMap())
            }
        }
        microphonePermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted ->
            val pending = pendingRecordingResult
            val args = pendingRecordingArgs
            pendingRecordingResult = null
            pendingRecordingArgs = null
            if (!granted) {
                pending?.error(
                    "recording_permission_denied",
                    "Microphone permission is required for background recording.",
                    null,
                )
                return@registerForActivityResult
            }
            try {
                startRecordingService(args)
                pending?.success(recordingStateStore.statusMap())
            } catch (err: Exception) {
                pending?.error(
                    "recording_start_failed",
                    err.message ?: err.javaClass.simpleName,
                    null,
                )
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/health",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> lifecycleScope.launch {
                    result.success(buildStatusMap())
                }

                "requestPermissions" -> lifecycleScope.launch {
                    val client = healthGateway.getClientOrNull()
                    if (client == null) {
                        result.error(
                            "health_unavailable",
                            "Health Connect is unavailable on this device.",
                            null,
                        )
                        return@launch
                    }

                    pendingPermissionResult = result
                    permissionLauncher.launch(healthGateway.getRequestedPermissions(client))
                }

                "collectBatch" -> lifecycleScope.launch {
                    try {
                        val client = healthGateway.getClientOrNull()
                        if (client == null) {
                            result.error(
                                "health_unavailable",
                                "Health Connect is unavailable on this device.",
                                null,
                            )
                            return@launch
                        }

                        val required = healthGateway.getRequestedPermissions(client)
                        val granted = client.permissionController.getGrantedPermissions()
                        if (!granted.containsAll(required)) {
                            result.error(
                                "health_permissions",
                                "Grant Health Connect permissions before syncing.",
                                null,
                            )
                            return@launch
                        }

                        val args = call.arguments as? Map<*, *>
                        val windowStart = Instant.parse(args?.get("windowStart")?.toString())
                        val windowEnd = Instant.parse(args?.get("windowEnd")?.toString())
                        val payload = healthGateway.collectBatch(client, windowStart, windowEnd)
                        result.success(payload.toJson().toString())
                    } catch (err: Exception) {
                        result.error(
                            "health_sync_failed",
                            err.message ?: err.javaClass.simpleName,
                            null,
                        )
                    }
                }

                "configureBackgroundSync" -> {
                    val args = call.arguments as? Map<*, *>
                    val enabled = args?.get("enabled") == true
                    val backendUrl = args?.get("backendUrl")?.toString().orEmpty()
                    val sessionCookie = args?.get("sessionCookie")?.toString().orEmpty()
                    healthSyncScheduler.configure(
                        enabled = enabled,
                        backendUrl = backendUrl,
                        sessionCookie = sessionCookie,
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/recordings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(recordingStateStore.statusMap())

                "startBackgroundRecording" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        if (ContextCompat.checkSelfPermission(
                                this,
                                android.Manifest.permission.RECORD_AUDIO,
                            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        ) {
                            startRecordingService(args)
                            result.success(recordingStateStore.statusMap())
                        } else {
                            pendingRecordingResult = result
                            pendingRecordingArgs = args
                            microphonePermissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                        }
                    } catch (err: Exception) {
                        result.error(
                            "recording_start_failed",
                            err.message ?: err.javaClass.simpleName,
                            null,
                        )
                    }
                }

                "pauseBackgroundRecording" -> {
                    startService(RecordingForegroundService.buildPauseIntent(this))
                    result.success(recordingStateStore.statusMap())
                }

                "resumeBackgroundRecording" -> {
                    startService(RecordingForegroundService.buildResumeIntent(this))
                    result.success(recordingStateStore.statusMap())
                }

                "stopBackgroundRecording" -> {
                    startService(RecordingForegroundService.buildStopIntent(this))
                    result.success(recordingStateStore.statusMap())
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startRecordingService(args: Map<*, *>?) {
        val backendUrl = args?.get("backendUrl")?.toString().orEmpty()
        val sessionCookie = args?.get("sessionCookie")?.toString().orEmpty()
        val sessionId = args?.get("sessionId")?.toString().orEmpty()
        val intent = RecordingForegroundService.buildStartIntent(
            this,
            backendUrl = backendUrl,
            sessionCookie = sessionCookie,
            sessionId = sessionId,
        )
        ContextCompat.startForegroundService(this, intent)
    }

    private suspend fun buildStatusMap(): Map<String, Any?> {
        val available = healthGateway.isAvailable()
        val client = healthGateway.getClientOrNull()
        val required = if (client != null) {
            healthGateway.getRequestedPermissions(client).toList()
        } else {
            emptyList()
        }
        val granted = if (client != null) {
            client.permissionController.getGrantedPermissions().toList()
        } else {
            emptyList()
        }

        val message = when {
            !available -> "Health Connect is unavailable on this device."
            !granted.containsAll(required) -> "Permissions are required for sync."
            else -> "Health sync is ready."
        }

        return mapOf(
            "available" to available,
            "permissionsGranted" to granted.containsAll(required),
            "requiredPermissions" to required,
            "grantedPermissions" to granted,
            "message" to message,
        )
    }
}
