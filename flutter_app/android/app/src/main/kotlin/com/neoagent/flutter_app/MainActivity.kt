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
import com.neoagent.flutter_app.wearablebg.WearableBleForegroundService
import com.neoagent.flutter_app.wearablebg.WearableBridgeConfig
import com.neoagent.flutter_app.wearablebg.WearableBridgeStateStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import android.os.Build
import java.time.Instant

class MainActivity : FlutterFragmentActivity() {

    private lateinit var healthGateway: HealthConnectGateway
    private lateinit var healthSyncScheduler: HealthSyncScheduler
    private lateinit var recordingStateStore: RecordingStateStore
    private lateinit var wearableBridgeStateStore: WearableBridgeStateStore
    private lateinit var permissionLauncher: ActivityResultLauncher<Set<String>>
    private lateinit var microphonePermissionLauncher: ActivityResultLauncher<String>
    private lateinit var bluetoothPermissionLauncher: ActivityResultLauncher<Array<String>>
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRecordingResult: MethodChannel.Result? = null
    private var pendingRecordingArgs: Map<*, *>? = null
    private var pendingWearableBridgeResult: MethodChannel.Result? = null
    private var pendingWearableBridgeArgs: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        healthGateway = HealthConnectGateway(this)
        healthSyncScheduler = HealthSyncScheduler(this)
        recordingStateStore = RecordingStateStore(this)
        wearableBridgeStateStore = WearableBridgeStateStore(this)
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
        bluetoothPermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions(),
        ) { grants ->
            val pending = pendingWearableBridgeResult
            val args = pendingWearableBridgeArgs
            pendingWearableBridgeResult = null
            pendingWearableBridgeArgs = null

            val allGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                grants[android.Manifest.permission.BLUETOOTH_CONNECT] == true &&
                    grants[android.Manifest.permission.BLUETOOTH_SCAN] == true
            } else {
                true
            }

            if (!allGranted) {
                pending?.error(
                    "wearable_bridge_permission_denied",
                    "Bluetooth permissions are required for the wearable background bridge.",
                    null,
                )
                return@registerForActivityResult
            }

            try {
                val config = parseWearableBridgeConfig(args)
                if (config == null || !isValidWearableBridgeConfig(config)) {
                    pending?.error(
                        "wearable_bridge_invalid_args",
                        "backendUrl, sessionCookie, macAddress, serviceUuid, and audioNotifyUuid are required.",
                        null,
                    )
                    return@registerForActivityResult
                }
                ContextCompat.startForegroundService(
                    this,
                    WearableBleForegroundService.buildStartIntent(this, config),
                )
                pending?.success(wearableBridgeStateStore.statusMap())
            } catch (err: Exception) {
                pending?.error(
                    "wearable_bridge_start_failed",
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
                        val windowStartRaw = args?.get("windowStart")?.toString()
                        val windowEndRaw = args?.get("windowEnd")?.toString()
                        if (windowStartRaw.isNullOrBlank() || windowEndRaw.isNullOrBlank()) {
                            result.error(
                                "health_sync_window",
                                "windowStart and windowEnd are required.",
                                null,
                            )
                            return@launch
                        }
                        val windowStart =
                            try {
                                Instant.parse(windowStartRaw)
                            } catch (_: Exception) {
                                result.error(
                                    "health_sync_window",
                                    "windowStart must be an ISO-8601 timestamp.",
                                    null,
                                )
                                return@launch
                            }
                        val windowEnd =
                            try {
                                Instant.parse(windowEndRaw)
                            } catch (_: Exception) {
                                result.error(
                                    "health_sync_window",
                                    "windowEnd must be an ISO-8601 timestamp.",
                                    null,
                                )
                                return@launch
                            }
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/wearables_background",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundBridge" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val config = parseWearableBridgeConfig(args)
                        if (config == null || !isValidWearableBridgeConfig(config)) {
                            result.error(
                                "wearable_bridge_invalid_args",
                                "backendUrl, sessionCookie, macAddress, serviceUuid, and audioNotifyUuid are required.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        if (!hasWearableBridgePermissions()) {
                            pendingWearableBridgeResult = result
                            pendingWearableBridgeArgs = args
                            bluetoothPermissionLauncher.launch(
                                arrayOf(
                                    android.Manifest.permission.BLUETOOTH_CONNECT,
                                    android.Manifest.permission.BLUETOOTH_SCAN,
                                ),
                            )
                            return@setMethodCallHandler
                        }

                        ContextCompat.startForegroundService(
                            this,
                            WearableBleForegroundService.buildStartIntent(this, config),
                        )
                        result.success(wearableBridgeStateStore.statusMap())
                    } catch (err: Exception) {
                        result.error(
                            "wearable_bridge_start_failed",
                            err.message ?: err.javaClass.simpleName,
                            null,
                        )
                    }
                }

                "stopBackgroundBridge" -> {
                    val args = call.arguments as? Map<*, *>
                    val sendStop = args?.get("sendStop") == true
                    startService(WearableBleForegroundService.buildStopIntent(this, sendStop))
                    result.success(wearableBridgeStateStore.statusMap())
                }

                "backgroundBridgeStatus" -> {
                    result.success(wearableBridgeStateStore.statusMap())
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

    private fun parseWearableBridgeConfig(args: Map<*, *>?): WearableBridgeConfig? {
        if (args == null) {
            return null
        }
        return WearableBridgeConfig(
            backendUrl = args["backendUrl"]?.toString().orEmpty(),
            sessionCookie = args["sessionCookie"]?.toString().orEmpty(),
            macAddress = args["macAddress"]?.toString().orEmpty(),
            deviceName = args["deviceName"]?.toString().orEmpty(),
            protocolId = args["protocolId"]?.toString().orEmpty().ifBlank { "heypocket" },
            serviceUuid = args["serviceUuid"]?.toString().orEmpty(),
            audioNotifyUuid = args["audioNotifyUuid"]?.toString().orEmpty(),
            controlNotifyUuid = args["controlNotifyUuid"]?.toString(),
            controlWriteUuid = args["controlWriteUuid"]?.toString(),
            autoStartRecording = args["autoStartRecording"] == true,
        )
    }

    private fun isValidWearableBridgeConfig(config: WearableBridgeConfig): Boolean {
        return config.backendUrl.isNotBlank() &&
            config.sessionCookie.isNotBlank() &&
            config.macAddress.isNotBlank() &&
            config.serviceUuid.isNotBlank() &&
            config.audioNotifyUuid.isNotBlank()
    }

    private fun hasWearableBridgePermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val connectGranted = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.BLUETOOTH_CONNECT,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val scanGranted = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.BLUETOOTH_SCAN,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        return connectGranted && scanGranted
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
