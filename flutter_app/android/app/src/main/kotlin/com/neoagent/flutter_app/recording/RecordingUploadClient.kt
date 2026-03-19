package com.neoagent.flutter_app.recording

import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

class RecordingUploadClient {
    fun uploadChunk(
        backendUrl: String,
        sessionCookie: String,
        sessionId: String,
        meta: PendingChunkMeta,
        file: File,
    ) {
        val url = URL(resolveUrl(backendUrl, "/api/recordings/$sessionId/chunks"))
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 20_000
            readTimeout = 60_000
            setRequestProperty("Cookie", sessionCookie)
            setRequestProperty("Content-Type", meta.mimeType)
            setRequestProperty("X-Recording-Source-Key", SOURCE_KEY)
            setRequestProperty("X-Recording-Sequence", meta.sequence.toString())
            setRequestProperty("X-Recording-Start-Ms", meta.startMs.toString())
            setRequestProperty("X-Recording-End-Ms", meta.endMs.toString())
        }

        file.inputStream().use { input ->
            connection.outputStream.use { output ->
                input.copyTo(output)
            }
        }

        val statusCode = connection.responseCode
        if (statusCode !in 200..299) {
            val body = readResponse(connection)
            connection.disconnect()
            throw IllegalStateException("Chunk upload failed ($statusCode): $body")
        }
        connection.disconnect()
    }

    fun finalizeSession(
        backendUrl: String,
        sessionCookie: String,
        sessionId: String,
        stopReason: String,
    ) {
        val url = URL(resolveUrl(backendUrl, "/api/recordings/$sessionId/finalize"))
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 20_000
            readTimeout = 60_000
            setRequestProperty("Cookie", sessionCookie)
            setRequestProperty("Content-Type", "application/json")
        }

        val payload = JSONObject()
            .put("stopReason", stopReason)
            .toString()
        OutputStreamWriter(connection.outputStream, StandardCharsets.UTF_8).use { writer ->
            writer.write(payload)
        }

        val statusCode = connection.responseCode
        if (statusCode !in 200..299) {
            val body = readResponse(connection)
            connection.disconnect()
            throw IllegalStateException("Finalize failed ($statusCode): $body")
        }
        connection.disconnect()
    }

    private fun readResponse(connection: HttpURLConnection): String {
        val stream = connection.errorStream ?: connection.inputStream ?: return ""
        return stream.bufferedReader().use(BufferedReader::readText)
    }

    private fun resolveUrl(baseUrl: String, path: String): String {
        val trimmed = baseUrl.trim().removeSuffix("/")
        return if (trimmed.isEmpty()) {
            path
        } else {
            "$trimmed$path"
        }
    }

    companion object {
        const val SOURCE_KEY = "microphone"
    }
}

data class PendingChunkMeta(
    val sequence: Int,
    val startMs: Long,
    val endMs: Long,
    val mimeType: String = "audio/wav",
)
