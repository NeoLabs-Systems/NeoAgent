package com.neoagent.flutter_app

import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.view.KeyEvent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import com.neoagent.flutter_app.health.HealthConnectGateway
import com.neoagent.flutter_app.health.HealthSyncScheduler
import com.neoagent.flutter_app.recording.RecordingForegroundService
import com.neoagent.flutter_app.recording.RecordingStateStore
import com.neoagent.flutter_app.widgets.AiHomeWidgetProvider
import com.neoagent.flutter_app.widgets.AiWidgetStore
import com.neoagent.flutter_app.widgets.WidgetSyncScheduler
import com.neoagent.flutter_app.wearablebg.WearableBleForegroundService
import com.neoagent.flutter_app.wearablebg.WearableBridgeConfig
import com.neoagent.flutter_app.wearablebg.WearableBridgeStateStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.launch
import java.time.Instant

class MainActivity : FlutterFragmentActivity() {

    private lateinit var healthGateway: HealthConnectGateway
    private lateinit var healthSyncScheduler: HealthSyncScheduler
    private lateinit var widgetSyncScheduler: WidgetSyncScheduler
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
    private var launcherButtonSink: EventChannel.EventSink? = null
    private var widgetEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        healthGateway = HealthConnectGateway(this)
        healthSyncScheduler = HealthSyncScheduler(this)
        widgetSyncScheduler = WidgetSyncScheduler(this)
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
	                            if (pendingWearableBridgeResult != null || pendingWearableBridgeArgs != null) {
	                                result.error(
	                                    "wearable_bridge_request_pending",
	                                    "Another wearable background bridge request is already waiting for Bluetooth permissions.",
	                                    null,
	                                )
	                                return@setMethodCallHandler
	                            }
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/launcher_device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVolumeState" -> {
                    val audioManager = getSystemService(AudioManager::class.java)
                    if (audioManager == null) {
                        result.error(
                            "launcher_audio_unavailable",
                            "Audio manager is unavailable on this device.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(buildVolumeState(audioManager))
                }

                "setVolume" -> {
                    val audioManager = getSystemService(AudioManager::class.java)
                    if (audioManager == null) {
                        result.error(
                            "launcher_audio_unavailable",
                            "Audio manager is unavailable on this device.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    val args = call.arguments as? Map<*, *>
                    val target = (args?.get("value") as? Number)?.toInt()
                    if (target == null) {
                        result.error(
                            "launcher_volume_invalid_args",
                            "value is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    val minVolume =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
                        } else {
                            0
                        }
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    audioManager.setStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        target.coerceIn(minVolume, maxVolume),
                        0,
                    )
                    result.success(buildVolumeState(audioManager))
                }

                "adjustVolume" -> {
                    val audioManager = getSystemService(AudioManager::class.java)
                    if (audioManager == null) {
                        result.error(
                            "launcher_audio_unavailable",
                            "Audio manager is unavailable on this device.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    val args = call.arguments as? Map<*, *>
                    val delta = (args?.get("delta") as? Number)?.toInt() ?: 0
                    val minVolume =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
                        } else {
                            0
                        }
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    audioManager.setStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        (currentVolume + delta).coerceIn(minVolume, maxVolume),
                        0,
                    )
                    result.success(buildVolumeState(audioManager))
                }

                "openWifiSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (err: Exception) {
                        result.error(
                            "launcher_wifi_settings_failed",
                            err.message ?: err.javaClass.simpleName,
                            null,
                        )
                    }
                }

                "openDateSettings", "openTimeSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_DATE_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                        } else {
                            startActivity(
                                Intent(Settings.ACTION_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        }
                        result.success(null)
                    } catch (err: Exception) {
                        result.error(
                            "launcher_date_settings_failed",
                            err.message ?: err.javaClass.simpleName,
                            null,
                        )
                    }
                }

                "openSystemSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    } catch (err: Exception) {
                        result.error(
                            "launcher_settings_failed",
                            err.message ?: err.javaClass.simpleName,
                            null,
                        )
                    }
                }

                "getDeviceStatus", "getBatteryState" -> {
                    result.success(buildDeviceStatusMap())
                }

                "getAppMode" -> result.success(currentAppMode())

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/widgets",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configureHomeWidgets" -> {
                    val args = call.arguments as? Map<*, *>
                    widgetSyncScheduler.configure(
                        enabled = args?.get("enabled") == true,
                        backendUrl = args?.get("backendUrl")?.toString().orEmpty(),
                        sessionCookie = args?.get("sessionCookie")?.toString().orEmpty(),
                    )
                    result.success(null)
                }

                "syncHomeWidgetsNow" -> {
                    widgetSyncScheduler.syncNow()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/launcher_buttons",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    launcherButtonSink = events
                }

                override fun onCancel(arguments: Any?) {
                    launcherButtonSink = null
                }
            },
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/widgets/events",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    widgetEventSink = events
                    emitPendingWidgetIntent()
                }

                override fun onCancel(arguments: Any?) {
                    widgetEventSink = null
                }
            },
        )

        captureWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetIntent(intent)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        emitLauncherButtonEvent(event, "down")
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        emitLauncherButtonEvent(event, "up")
        return super.onKeyUp(keyCode, event)
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

    private fun currentAppMode(): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            appInfo.metaData?.getString("com.neoagent.APP_MODE")?.trim().orEmpty()
                .ifBlank { "standard" }
        } catch (_: Exception) {
            "standard"
        }
    }

    private fun shouldEmitLauncherButtonEvent(keyCode: Int): Boolean {
        if (currentAppMode() != "launcher") {
            return false
        }
        return keyCode != KeyEvent.KEYCODE_BACK &&
            keyCode != KeyEvent.KEYCODE_HOME &&
            keyCode != KeyEvent.KEYCODE_VOLUME_DOWN &&
            keyCode != KeyEvent.KEYCODE_VOLUME_UP &&
            keyCode != KeyEvent.KEYCODE_VOLUME_MUTE &&
            keyCode != KeyEvent.KEYCODE_APP_SWITCH &&
            keyCode != KeyEvent.KEYCODE_MENU
    }

    private fun emitLauncherButtonEvent(event: KeyEvent, action: String) {
        if (!shouldEmitLauncherButtonEvent(event.keyCode)) {
            return
        }
        launcherButtonSink?.success(
            mapOf(
                "keyCode" to event.keyCode,
                "scanCode" to event.scanCode,
                "repeatCount" to event.repeatCount,
                "action" to action,
                "eventTimeMs" to event.eventTime,
            ),
        )
    }

    private fun captureWidgetIntent(intent: Intent?) {
        if (intent?.action != AiHomeWidgetProvider.ACTION_OPEN_WIDGET) {
            return
        }
        val widgetId =
            intent.getStringExtra(AiHomeWidgetProvider.EXTRA_WIDGET_ID)?.trim().orEmpty()
        if (widgetId.isBlank()) {
            return
        }
        AiWidgetStore(this).setPendingOpenWidgetId(widgetId)
        emitPendingWidgetIntent()
    }

    private fun emitPendingWidgetIntent() {
        val sink = widgetEventSink ?: return
        val widgetId = AiWidgetStore(this).consumePendingOpenWidgetId() ?: return
        sink.success(mapOf("widgetId" to widgetId))
    }

    private fun buildVolumeState(audioManager: AudioManager): Map<String, Any> {
        val minVolume =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
            } else {
                0
            }
        return mapOf(
            "current" to audioManager.getStreamVolume(AudioManager.STREAM_MUSIC),
            "max" to audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
            "min" to minVolume,
            "muted" to audioManager.isStreamMute(AudioManager.STREAM_MUSIC),
        )
    }

    private fun buildDeviceStatusMap(): Map<String, Any?> {
        val batteryStateIntent = registerReceiver(
            null,
            android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        )
        val batteryLevel = batteryStateIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val batteryScale = batteryStateIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPercentFromIntent =
            if (batteryLevel >= 0 && batteryScale > 0) {
                ((batteryLevel * 100f) / batteryScale).toInt().coerceIn(0, 100)
            } else {
                null
            }
        val batteryManager = getSystemService(BatteryManager::class.java)
        val batteryPercentFromManager = batteryManager
            ?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?.takeIf { it in 0..100 }
        val batteryPercent = batteryPercentFromIntent ?: batteryPercentFromManager
        val batteryStatus = batteryStateIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = batteryStateIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val charging =
            batteryStatus == BatteryManager.BATTERY_STATUS_CHARGING ||
                batteryStatus == BatteryManager.BATTERY_STATUS_FULL ||
                plugged != 0
        return mapOf(
            "batteryPercent" to batteryPercent,
            "charging" to charging,
        )
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
