package com.neoagent.flutter_app.recording

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.OutputStreamWriter
import java.time.Instant

class RecordingForegroundService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val stateStore by lazy { RecordingStateStore(this) }
    private val uploadClient = RecordingUploadClient()
    private val uploadMutex = Mutex()

    private var config: RecordingConfig? = null
    private var audioRecord: AudioRecord? = null
    private var captureJob: Job? = null
    private var noiseSuppressor: NoiseSuppressor? = null
    private var automaticGainControl: AutomaticGainControl? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startNewRecording(intent)
            ACTION_RESTORE -> restoreRecording()
            ACTION_PAUSE -> pauseRecording()
            ACTION_RESUME -> resumeRecording()
            ACTION_STOP -> stopRecording(finalize = true)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        captureJob?.cancel()
        stopRecorder()
        serviceScope.cancel()
        super.onDestroy()
    }

    private fun startNewRecording(intent: Intent) {
        ensureMicPermission()
        val backendUrl = intent.getStringExtra(EXTRA_BACKEND_URL).orEmpty()
        val sessionCookie = intent.getStringExtra(EXTRA_SESSION_COOKIE).orEmpty()
        val sessionId = intent.getStringExtra(EXTRA_SESSION_ID).orEmpty()
        require(backendUrl.isNotBlank()) { "Backend URL is required." }
        require(sessionCookie.isNotBlank()) { "Session cookie is required." }
        require(sessionId.isNotBlank()) { "Session ID is required." }

        config = RecordingConfig(
            backendUrl = backendUrl,
            sessionCookie = sessionCookie,
            sessionId = sessionId,
            active = true,
            paused = false,
            nextSequence = 0,
            capturedAudioMs = 0L,
            startedAt = Instant.now().toString(),
            errorMessage = null,
        )
        stateStore.saveConfig(config!!)
        startForegroundServiceUi()
        serviceScope.launch {
            drainPendingUploads()
            startCaptureLoop()
        }
    }

    private fun restoreRecording() {
        ensureMicPermission()
        val restored = stateStore.loadConfig() ?: return
        config = restored.copy(active = true, paused = false, errorMessage = null)
        stateStore.saveConfig(config!!)
        startForegroundServiceUi()
        serviceScope.launch {
            drainPendingUploads()
            startCaptureLoop()
        }
    }

    private fun pauseRecording() {
        val current = config ?: return
        config = current.copy(active = true, paused = true)
        stateStore.saveConfig(config!!)
        captureJob?.cancel()
        stopRecorder()
        updateNotification()
    }

    private fun resumeRecording() {
        val current = config ?: stateStore.loadConfig() ?: return
        config = current.copy(active = true, paused = false, errorMessage = null)
        stateStore.saveConfig(config!!)
        startForegroundServiceUi()
        serviceScope.launch {
            drainPendingUploads()
            startCaptureLoop()
        }
    }

    private fun stopRecording(finalize: Boolean) {
        val current = config ?: stateStore.loadConfig() ?: return
        serviceScope.launch {
            captureJob?.cancel()
            stopRecorder()
            try {
                drainPendingUploads()
                if (finalize) {
                    uploadClient.finalizeSession(
                        backendUrl = current.backendUrl,
                        sessionCookie = current.sessionCookie,
                        sessionId = current.sessionId,
                        stopReason = "stopped",
                    )
                }
                stateStore.clear()
                config = null
            } catch (error: Exception) {
                config = current.copy(
                    active = false,
                    paused = false,
                    errorMessage = error.message,
                )
                stateStore.saveConfig(config!!)
            } finally {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }

    private suspend fun startCaptureLoop() {
        if (captureJob?.isActive == true) {
            return
        }
        val current = config ?: return
        val recorderConfig = buildRecorderConfig()
        val sampleRate = recorderConfig.sampleRate
        val record = recorderConfig.audioRecord
        audioRecord = record
        attachAudioEnhancers(record.audioSessionId)
        record.startRecording()
        if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            stopRecorder()
            throw IllegalStateException("Microphone capture did not start correctly.")
        }

        captureJob = serviceScope.launch {
            val readBuffer = ByteArray(maxOf(recorderConfig.bufferSize, 4096))
            val chunkBuffer = ByteArrayOutputStream()
            var chunkStartMs = config?.capturedAudioMs ?: 0L
            var chunkBytes = 0L
            var capturedBytes = millisToBytes(current.capturedAudioMs, sampleRate)

            while (isActive) {
                val read = record.read(readBuffer, 0, readBuffer.size)
                if (read <= 0) {
                    delay(20)
                    continue
                }
                chunkBuffer.write(readBuffer, 0, read)
                chunkBytes += read.toLong()
                capturedBytes += read.toLong()
                val currentConfig = config ?: break
                val updatedCaptured = bytesToMillis(capturedBytes, sampleRate)
                config = currentConfig.copy(capturedAudioMs = updatedCaptured)
                stateStore.saveConfig(config!!)

                if (bytesToMillis(chunkBytes, sampleRate) >= CHUNK_DURATION_MS) {
                    val chunkEndMs = chunkStartMs + bytesToMillis(chunkBytes, sampleRate)
                    flushChunk(
                        bytes = chunkBuffer.toByteArray(),
                        startMs = chunkStartMs,
                        endMs = chunkEndMs,
                        sampleRate = sampleRate,
                    )
                    chunkBuffer.reset()
                    chunkStartMs = chunkEndMs
                    chunkBytes = 0L
                }
            }

            if (chunkBuffer.size() > 0) {
                flushChunk(
                    bytes = chunkBuffer.toByteArray(),
                    startMs = chunkStartMs,
                    endMs = chunkStartMs + bytesToMillis(chunkBytes, sampleRate),
                    sampleRate = sampleRate,
                )
            }
        }
        updateNotification()
    }

    private fun flushChunk(bytes: ByteArray, startMs: Long, endMs: Long, sampleRate: Int) {
        if (bytes.isEmpty()) {
            return
        }
        val current = config ?: return
        val sequence = current.nextSequence
        val pendingDir = pendingDir(current.sessionId)
        pendingDir.mkdirs()
        val audioFile = File(pendingDir, "${sequence.toString().padStart(6, '0')}.wav")
        val metaFile = File(pendingDir, "${sequence.toString().padStart(6, '0')}.json")
        audioFile.writeBytes(wrapPcmAsWav(bytes, sampleRate))
        val meta = JSONObject()
            .put("sequence", sequence)
            .put("startMs", startMs)
            .put("endMs", endMs)
            .put("mimeType", "audio/wav")
            .put("sampleRate", sampleRate)
        OutputStreamWriter(metaFile.outputStream(), Charsets.UTF_8).use { writer ->
            writer.write(meta.toString())
        }
        config = current.copy(nextSequence = sequence + 1)
        stateStore.saveConfig(config!!)
        serviceScope.launch {
            drainPendingUploads()
        }
    }

    private suspend fun drainPendingUploads() {
        val current = config ?: return
        uploadMutex.withLock {
            val pendingDir = pendingDir(current.sessionId)
            if (!pendingDir.exists()) {
                return
            }
            val metaFiles = pendingDir.listFiles { _, name -> name.endsWith(".json") }
                ?.sortedBy { it.nameWithoutExtension }
                ?: emptyList()

            for (metaFile in metaFiles) {
                val audioFile = File(pendingDir, "${metaFile.nameWithoutExtension}.wav")
                if (!audioFile.exists()) {
                    metaFile.delete()
                    continue
                }
                val metaJson = JSONObject(metaFile.readText())
                val meta = PendingChunkMeta(
                    sequence = metaJson.getInt("sequence"),
                    startMs = metaJson.getLong("startMs"),
                    endMs = metaJson.getLong("endMs"),
                    mimeType = metaJson.optString("mimeType", "audio/wav"),
                )
                retryUpload(audioFile, meta)
                audioFile.delete()
                metaFile.delete()
            }
        }
    }

    private suspend fun retryUpload(audioFile: File, meta: PendingChunkMeta) {
        val current = config ?: return
        var lastError: Exception? = null
        repeat(5) { attempt ->
            try {
                uploadClient.uploadChunk(
                    backendUrl = current.backendUrl,
                    sessionCookie = current.sessionCookie,
                    sessionId = current.sessionId,
                    meta = meta,
                    file = audioFile,
                )
                return
            } catch (error: Exception) {
                lastError = error
                config = current.copy(errorMessage = error.message)
                stateStore.saveConfig(config!!)
                delay((attempt + 1) * 600L)
            }
        }
        throw lastError ?: IllegalStateException("Upload failed.")
    }

    private fun startForegroundServiceUi() {
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val current = config
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val paused = current?.paused == true
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(if (paused) "NeoAgent recording paused" else "NeoAgent recording")
            .setContentText(
                if (paused) {
                    "Background microphone capture is paused."
                } else {
                    "Background microphone capture is running."
                },
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "NeoAgent recordings",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun stopRecorder() {
        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }
        noiseSuppressor?.release()
        noiseSuppressor = null
        automaticGainControl?.release()
        automaticGainControl = null
        audioRecord?.release()
        audioRecord = null
    }

    private fun pendingDir(sessionId: String): File =
        File(filesDir, "recording-pending/$sessionId")

    private fun wrapPcmAsWav(pcmBytes: ByteArray, sampleRate: Int): ByteArray {
        val byteRate = sampleRate * CHANNEL_COUNT * BYTES_PER_SAMPLE
        val totalDataLen = pcmBytes.size + 36
        return ByteArrayOutputStream().use { output ->
            output.write("RIFF".toByteArray())
            output.write(intToLittleEndian(totalDataLen))
            output.write("WAVE".toByteArray())
            output.write("fmt ".toByteArray())
            output.write(intToLittleEndian(16))
            output.write(shortToLittleEndian(1))
            output.write(shortToLittleEndian(CHANNEL_COUNT.toShort()))
            output.write(intToLittleEndian(sampleRate))
            output.write(intToLittleEndian(byteRate))
            output.write(shortToLittleEndian((CHANNEL_COUNT * BYTES_PER_SAMPLE).toShort()))
            output.write(shortToLittleEndian((BYTES_PER_SAMPLE * 8).toShort()))
            output.write("data".toByteArray())
            output.write(intToLittleEndian(pcmBytes.size))
            output.write(pcmBytes)
            output.toByteArray()
        }
    }

    private fun intToLittleEndian(value: Int): ByteArray = byteArrayOf(
        (value and 0xff).toByte(),
        (value shr 8 and 0xff).toByte(),
        (value shr 16 and 0xff).toByte(),
        (value shr 24 and 0xff).toByte(),
    )

    private fun shortToLittleEndian(value: Short): ByteArray = byteArrayOf(
        (value.toInt() and 0xff).toByte(),
        (value.toInt() shr 8 and 0xff).toByte(),
    )

    private fun ensureMicPermission() {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        require(granted) { "Microphone permission is required." }
    }

    private fun buildRecorderConfig(): RecorderConfig {
        val sampleRates = listOf(16_000, 48_000, 44_100)
        val audioSources = listOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
        )
        var lastError: String? = null

        for (audioSource in audioSources) {
            for (sampleRate in sampleRates) {
                val minBufferSize = AudioRecord.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
                if (minBufferSize <= 0) {
                    lastError = "Unsupported buffer size for ${sampleRate} Hz."
                    continue
                }

                val bufferSize = maxOf(minBufferSize * 2, 4096)
                val record = try {
                    AudioRecord(
                        audioSource,
                        sampleRate,
                        AudioFormat.CHANNEL_IN_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        bufferSize,
                    )
                } catch (error: Exception) {
                    lastError = error.message
                    null
                }

                if (record?.state == AudioRecord.STATE_INITIALIZED) {
                    return RecorderConfig(
                        audioRecord = record,
                        sampleRate = sampleRate,
                        bufferSize = bufferSize,
                    )
                }

                record?.release()
                lastError = "AudioRecord could not initialize for ${sampleRate} Hz."
            }
        }

        throw IllegalStateException(lastError ?: "Unable to initialize microphone capture.")
    }

    private fun attachAudioEnhancers(audioSessionId: Int) {
        if (NoiseSuppressor.isAvailable()) {
            noiseSuppressor = NoiseSuppressor.create(audioSessionId)?.apply {
                enabled = true
            }
        }
        if (AutomaticGainControl.isAvailable()) {
            automaticGainControl = AutomaticGainControl.create(audioSessionId)?.apply {
                enabled = true
            }
        }
    }

    private fun bytesToMillis(byteCount: Long, sampleRate: Int): Long {
        val bytesPerSecond = sampleRate.toLong() * CHANNEL_COUNT * BYTES_PER_SAMPLE
        if (bytesPerSecond <= 0L) {
            return 0L
        }
        return (byteCount * 1000L) / bytesPerSecond
    }

    private fun millisToBytes(durationMs: Long, sampleRate: Int): Long {
        return (durationMs * sampleRate.toLong() * CHANNEL_COUNT * BYTES_PER_SAMPLE) / 1000L
    }

    companion object {
        private const val ACTION_START = "neoagent.recordings.START"
        private const val ACTION_RESTORE = "neoagent.recordings.RESTORE"
        private const val ACTION_PAUSE = "neoagent.recordings.PAUSE"
        private const val ACTION_RESUME = "neoagent.recordings.RESUME"
        private const val ACTION_STOP = "neoagent.recordings.STOP"
        private const val EXTRA_BACKEND_URL = "backend_url"
        private const val EXTRA_SESSION_COOKIE = "session_cookie"
        private const val EXTRA_SESSION_ID = "session_id"
        private const val CHANNEL_ID = "neoagent_recordings"
        private const val NOTIFICATION_ID = 4021
        private const val CHANNEL_COUNT = 1
        private const val BYTES_PER_SAMPLE = 2
        private const val CHUNK_DURATION_MS = 4_000L

        fun buildStartIntent(
            context: Context,
            backendUrl: String,
            sessionCookie: String,
            sessionId: String,
        ): Intent = Intent(context, RecordingForegroundService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_BACKEND_URL, backendUrl)
            putExtra(EXTRA_SESSION_COOKIE, sessionCookie)
            putExtra(EXTRA_SESSION_ID, sessionId)
        }

        fun buildRestoreIntent(context: Context): Intent =
            Intent(context, RecordingForegroundService::class.java).apply {
                action = ACTION_RESTORE
            }

        fun buildPauseIntent(context: Context): Intent =
            Intent(context, RecordingForegroundService::class.java).apply {
                action = ACTION_PAUSE
            }

        fun buildResumeIntent(context: Context): Intent =
            Intent(context, RecordingForegroundService::class.java).apply {
                action = ACTION_RESUME
            }

        fun buildStopIntent(context: Context): Intent =
            Intent(context, RecordingForegroundService::class.java).apply {
                action = ACTION_STOP
            }
    }
}

private data class RecorderConfig(
    val audioRecord: AudioRecord,
    val sampleRate: Int,
    val bufferSize: Int,
)
