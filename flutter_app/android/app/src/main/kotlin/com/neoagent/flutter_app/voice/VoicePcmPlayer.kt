package com.neoagent.flutter_app.voice

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.LinkedBlockingQueue

// Streams the live voice model's PCM16 mono audio. Voice-communication usage
// keeps it on the self-managed Telecom call's route (speaker, headset, car) and
// inside the platform echo canceller; media playback would be faded out while
// that call holds audio focus.
class VoicePcmPlayer {
    private val queue = LinkedBlockingQueue<ByteArray>()
    private var track: AudioTrack? = null
    private var writer: Thread? = null

    @Synchronized
    fun start(sampleRate: Int) {
        if (track != null) return
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(minBuffer * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        audioTrack.play()
        track = audioTrack
        // Blocking writes pace playback at the device clock.
        writer = Thread {
            try {
                while (true) {
                    val chunk = queue.take()
                    audioTrack.write(chunk, 0, chunk.size)
                }
            } catch (_: InterruptedException) {
            } catch (_: IllegalStateException) {
            }
        }.apply {
            name = "neoagent-voice-player"
            start()
        }
    }

    fun write(chunk: ByteArray) {
        if (track != null) queue.offer(chunk)
    }

    @Synchronized
    fun flush() {
        queue.clear()
        track?.let {
            it.pause()
            it.flush()
            it.play()
        }
    }

    @Synchronized
    fun stop() {
        queue.clear()
        writer?.interrupt()
        writer = null
        track?.let {
            it.stop()
            it.release()
        }
        track = null
    }
}
