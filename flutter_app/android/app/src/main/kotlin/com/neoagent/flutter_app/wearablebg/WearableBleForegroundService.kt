package com.neoagent.flutter_app.wearablebg

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.neoagent.flutter_app.MainActivity
import com.neoagent.flutter_app.R
import com.neoagent.flutter_app.wearablebg.protocol.WearableProtocolHandler
import com.neoagent.flutter_app.wearablebg.protocol.WearableProtocolRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.Locale
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import android.util.Log

class WearableBleForegroundService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val stateStore by lazy { WearableBridgeStateStore(this) }
    private val backendClient = WearableBackendClient()

    private var config: WearableBridgeConfig? = null
    private var protocol: WearableProtocolHandler? = null
    private val gattLock = Any()
    private var gatt: BluetoothGatt? = null
    private var reconnectJob: Job? = null
    private val registerDone = AtomicBoolean(false)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            val restored = stateStore.load()
            if (restored != null) {
                config = restored
                protocol = WearableProtocolRegistry.resolve(
                    protocolId = restored.protocolId,
                    serviceUuid = restored.serviceUuid,
                    audioNotifyUuid = restored.audioNotifyUuid,
                    controlNotifyUuid = restored.controlNotifyUuid,
                    controlWriteUuid = restored.controlWriteUuid,
                )
                registerDone.set(false)
                startForegroundUi("Restoring wearable bridge")
                connectOrRetry()
            }
            return START_STICKY
        }

        when (intent?.action) {
            ACTION_START -> {
                val next = parseConfig(intent)
                if (next != null) {
                    config = next
                    protocol = WearableProtocolRegistry.resolve(
                        protocolId = next.protocolId,
                        serviceUuid = next.serviceUuid,
                        audioNotifyUuid = next.audioNotifyUuid,
                        controlNotifyUuid = next.controlNotifyUuid,
                        controlWriteUuid = next.controlWriteUuid,
                    )
                    stateStore.save(next)
                    stateStore.setConnected(false)
                    registerDone.set(false)
                    startForegroundUi("Connecting to ${next.deviceName.ifBlank { next.macAddress }}")

                    // If the bridge is already connected, service discovery will not rerun,
                    // so honor autoStartRecording immediately instead of waiting for callbacks.
                    if (next.autoStartRecording && currentGatt() != null) {
                        serviceScope.launch {
                            sendStartCommand()
                        }
                    }

                    connectOrRetry()
                }
            }

            ACTION_STOP -> {
                val sendStop = intent.getBooleanExtra(EXTRA_SEND_STOP, false)
                if (sendStop) {
                    serviceScope.launch {
                        sendStopCommand()
                    }
                }
                stopSelfSafely(clearState = true)
            }

            ACTION_RESTORE -> {
                val restored = stateStore.load()
                if (restored != null) {
                    config = restored
                    protocol = WearableProtocolRegistry.resolve(
                        protocolId = restored.protocolId,
                        serviceUuid = restored.serviceUuid,
                        audioNotifyUuid = restored.audioNotifyUuid,
                        controlNotifyUuid = restored.controlNotifyUuid,
                        controlWriteUuid = restored.controlWriteUuid,
                    )
                    registerDone.set(false)
                    stateStore.setConnected(false)
                    startForegroundUi("Restoring wearable bridge")
                    connectOrRetry()
                } else {
                    stopSelfSafely(clearState = false)
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        reconnectJob?.cancel()
        reconnectJob = null
        closeGatt()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            if (stateStore.isActive()) {
                ContextCompat.startForegroundService(
                    this,
                    buildRestoreIntent(this),
                )
            }
        } catch (err: Exception) {
            Log.w(TAG, "Failed to restart wearable bridge after task removal", err)
        }
        super.onTaskRemoved(rootIntent)
    }

    private fun parseConfig(intent: Intent): WearableBridgeConfig? {
        val backendUrl = intent.getStringExtra(EXTRA_BACKEND_URL).orEmpty()
        val sessionCookie = intent.getStringExtra(EXTRA_SESSION_COOKIE).orEmpty()
        val macAddress = intent.getStringExtra(EXTRA_MAC_ADDRESS).orEmpty()
        val deviceName = intent.getStringExtra(EXTRA_DEVICE_NAME).orEmpty()
        val protocolId = intent.getStringExtra(EXTRA_PROTOCOL_ID).orEmpty().ifBlank { "heypocket" }
        val serviceUuid = intent.getStringExtra(EXTRA_SERVICE_UUID).orEmpty()
        val audioNotifyUuid = intent.getStringExtra(EXTRA_AUDIO_NOTIFY_UUID).orEmpty()
        val controlNotifyUuid = intent.getStringExtra(EXTRA_CONTROL_NOTIFY_UUID)
        val controlWriteUuid = intent.getStringExtra(EXTRA_CONTROL_WRITE_UUID)
        val autoStartRecording = intent.getBooleanExtra(EXTRA_AUTO_START_RECORDING, false)

        if (backendUrl.isBlank() || sessionCookie.isBlank() || macAddress.isBlank() || serviceUuid.isBlank() || audioNotifyUuid.isBlank()) {
            return null
        }

        return WearableBridgeConfig(
            backendUrl = backendUrl,
            sessionCookie = sessionCookie,
            macAddress = macAddress,
            deviceName = deviceName,
            protocolId = protocolId,
            serviceUuid = serviceUuid,
            audioNotifyUuid = audioNotifyUuid,
            controlNotifyUuid = controlNotifyUuid,
            controlWriteUuid = controlWriteUuid,
            autoStartRecording = autoStartRecording,
        )
    }

    @SuppressLint("MissingPermission")
    private fun connectOrRetry() {
        reconnectJob?.cancel()
        reconnectJob = serviceScope.launch {
            while (isActive) {
                val current = config
                if (current == null) {
                    delay(1_000)
                    continue
                }

                if (currentGatt() != null) {
                    delay(1_500)
                    continue
                }

                val adapter = bluetoothAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    updateNotification("Bluetooth unavailable")
                    delay(3_000)
                    continue
                }

                val device = try {
                    adapter.getRemoteDevice(current.macAddress)
                } catch (_: Exception) {
                    null
                }

                if (device == null) {
                    updateNotification("Invalid device address")
                    delay(3_000)
                    continue
                }

                try {
                    updateNotification("Connecting to ${current.deviceName.ifBlank { current.macAddress }}")
                    val nextGatt = device.connectGatt(this@WearableBleForegroundService, false, gattCallback)
                    synchronized(gattLock) {
                        gatt = nextGatt
                    }
                } catch (_: Exception) {
                    closeGatt()
                }

                delay(3_000)
            }
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == android.bluetooth.BluetoothProfile.STATE_CONNECTED) {
                stateStore.setConnected(true)
                updateNotification("Connected. Discovering services")
                serviceScope.launch {
                    try {
                        if (!registerDone.get()) {
                            config?.let { backendClient.registerDevice(it) }
                            registerDone.set(true)
                        }
                    } catch (_: Exception) {
                        // Keep running even when backend register fails temporarily.
                    }
                }
                gatt.discoverServices()
                return
            }

            if (newState == android.bluetooth.BluetoothProfile.STATE_DISCONNECTED) {
                stateStore.setConnected(false)
                updateNotification("Disconnected. Reconnecting")
                closeGatt()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                updateNotification("Service discovery failed")
                return
            }

            val handler = protocol ?: return
            val service = findService(gatt, handler.serviceUuid) ?: run {
                updateNotification("Protocol service missing")
                return
            }

            val audioChar = findCharacteristic(service, handler.audioNotifyUuid)
            val controlNotify = handler.controlNotifyUuid?.let { findCharacteristic(service, it) }
            if (audioChar != null) {
                enableNotifications(gatt, audioChar)
            }
            if (controlNotify != null) {
                enableNotifications(gatt, controlNotify)
            }

            updateNotification("Wearable bridge active")

            val shouldAutoStart = config?.autoStartRecording == true
            if (shouldAutoStart) {
                serviceScope.launch {
                    sendStartCommand()
                }
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            handleCharacteristic(characteristic.uuid, characteristic.value)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            handleCharacteristic(characteristic.uuid, value)
        }
    }

    private fun handleCharacteristic(uuid: UUID, value: ByteArray) {
        val current = config ?: return
        val handler = protocol ?: return
        val characteristicUuid = uuid.toString().lowercase(Locale.US)
        val audio = handler.parseAudioPayload(characteristicUuid, value) ?: return

        serviceScope.launch {
            var lastErr: Exception? = null
            repeat(4) { attempt ->
                try {
                    backendClient.streamChunk(
                        config = current,
                        characteristicUuid = characteristicUuid,
                        payload = audio,
                    )
                    return@launch
                } catch (err: Exception) {
                    lastErr = err
                    delay((attempt + 1) * 400L)
                }
            }
            val errMessage = lastErr?.message ?: "unknown error"
            Log.w(TAG, "Dropping wearable audio chunk after retries: $errMessage", lastErr)
            updateNotification("Upload failed: $errMessage")
        }
    }

    @SuppressLint("MissingPermission")
    private fun sendStartCommand() {
        sendControlCommand(protocol?.startRecordingCommand())
    }

    @SuppressLint("MissingPermission")
    private fun sendStopCommand() {
        sendControlCommand(protocol?.stopRecordingCommand())
    }

    @SuppressLint("MissingPermission")
    private fun sendControlCommand(command: String?) {
        val cmd = command?.trim().orEmpty()
        if (cmd.isEmpty()) {
            return
        }

        val currentGatt = currentGatt() ?: return
        val handler = protocol ?: return
        val service = findService(currentGatt, handler.serviceUuid) ?: return
        val writeUuid = handler.controlWriteUuid ?: return
        val characteristic = findCharacteristic(service, writeUuid) ?: return
        val payload = cmd.toByteArray(Charsets.UTF_8)
        currentGatt.writeCharacteristic(
            characteristic,
            payload,
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
        )
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun findService(gatt: BluetoothGatt, uuid: String): BluetoothGattService? {
        val normalized = uuid.trim().lowercase(Locale.US)
        return gatt.services.firstOrNull { it.uuid.toString().lowercase(Locale.US) == normalized }
    }

    private fun findCharacteristic(service: BluetoothGattService, uuid: String): BluetoothGattCharacteristic? {
        val normalized = uuid.trim().lowercase(Locale.US)
        return service.characteristics.firstOrNull { it.uuid.toString().lowercase(Locale.US) == normalized }
    }

    @SuppressLint("MissingPermission")
    private fun enableNotifications(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        gatt.setCharacteristicNotification(characteristic, true)
        val ccc = characteristic.getDescriptor(UUID_CCC)
        if (ccc != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(ccc, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else {
                ccc.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                gatt.writeDescriptor(ccc)
            }
        }
    }

    private fun closeGatt() {
        val toClose = synchronized(gattLock) {
            val current = gatt
            gatt = null
            current
        }
        try {
            toClose?.close()
        } catch (_: Exception) {
        }
    }

    private fun currentGatt(): BluetoothGatt? {
        return synchronized(gattLock) {
            gatt
        }
    }

    private fun startForegroundUi(message: String) {
        ensureNotificationChannel()
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = android.app.PendingIntent.getActivity(
            this,
            200,
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("NeoAgent Wearable Bridge")
            .setContentText(message)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun updateNotification(message: String) {
        ensureNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("NeoAgent Wearable Bridge")
            .setContentText(message)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        val manager = ContextCompat.getSystemService(this, NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, notification)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = ContextCompat.getSystemService(this, NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Wearable Bridge",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Keeps BLE wearable bridge active in background."
        manager.createNotificationChannel(channel)
    }

    private fun stopSelfSafely(clearState: Boolean) {
        reconnectJob?.cancel()
        reconnectJob = null
        closeGatt()
        stateStore.setConnected(false)
        if (clearState) {
            stateStore.clear()
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    companion object {
        private const val TAG = "WearableBleForeground"
        private const val CHANNEL_ID = "wearable_bridge"
        private const val NOTIFICATION_ID = 4812
        private val UUID_CCC: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        const val ACTION_START = "com.neoagent.flutter_app.wearablebg.START"
        const val ACTION_STOP = "com.neoagent.flutter_app.wearablebg.STOP"
        const val ACTION_RESTORE = "com.neoagent.flutter_app.wearablebg.RESTORE"

        const val EXTRA_BACKEND_URL = "backendUrl"
        const val EXTRA_SESSION_COOKIE = "sessionCookie"
        const val EXTRA_MAC_ADDRESS = "macAddress"
        const val EXTRA_DEVICE_NAME = "deviceName"
        const val EXTRA_PROTOCOL_ID = "protocolId"
        const val EXTRA_SERVICE_UUID = "serviceUuid"
        const val EXTRA_AUDIO_NOTIFY_UUID = "audioNotifyUuid"
        const val EXTRA_CONTROL_NOTIFY_UUID = "controlNotifyUuid"
        const val EXTRA_CONTROL_WRITE_UUID = "controlWriteUuid"
        const val EXTRA_AUTO_START_RECORDING = "autoStartRecording"
        const val EXTRA_SEND_STOP = "sendStop"

        fun buildStartIntent(
            context: Context,
            config: WearableBridgeConfig,
        ): Intent {
            return Intent(context, WearableBleForegroundService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_BACKEND_URL, config.backendUrl)
                .putExtra(EXTRA_SESSION_COOKIE, config.sessionCookie)
                .putExtra(EXTRA_MAC_ADDRESS, config.macAddress)
                .putExtra(EXTRA_DEVICE_NAME, config.deviceName)
                .putExtra(EXTRA_PROTOCOL_ID, config.protocolId)
                .putExtra(EXTRA_SERVICE_UUID, config.serviceUuid)
                .putExtra(EXTRA_AUDIO_NOTIFY_UUID, config.audioNotifyUuid)
                .putExtra(EXTRA_CONTROL_NOTIFY_UUID, config.controlNotifyUuid)
                .putExtra(EXTRA_CONTROL_WRITE_UUID, config.controlWriteUuid)
                .putExtra(EXTRA_AUTO_START_RECORDING, config.autoStartRecording)
        }

        fun buildStopIntent(context: Context, sendStop: Boolean): Intent {
            return Intent(context, WearableBleForegroundService::class.java)
                .setAction(ACTION_STOP)
                .putExtra(EXTRA_SEND_STOP, sendStop)
        }

        fun buildRestoreIntent(context: Context): Intent {
            return Intent(context, WearableBleForegroundService::class.java)
                .setAction(ACTION_RESTORE)
        }
    }
}
