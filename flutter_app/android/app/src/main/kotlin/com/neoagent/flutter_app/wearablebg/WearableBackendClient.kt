package com.neoagent.flutter_app.wearablebg

import org.json.JSONObject
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder

class WearableBackendClient {
    fun registerDevice(config: WearableBridgeConfig) {
        val url = URI(config.backendUrl.trimEnd('/') + "/api/wearables").toURL()
        val body = JSONObject()
            .put("macAddress", config.macAddress)
            .put("protocol", config.protocolId)
            .put("name", config.deviceName)
            .toString()
            .toByteArray(Charsets.UTF_8)

        val conn = (url.openConnection() as HttpURLConnection)
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000
            conn.doOutput = true
            conn.setRequestProperty("Cookie", config.sessionCookie)
            conn.setRequestProperty("Content-Type", "application/json")
            conn.outputStream.use { it.write(body) }

            val code = conn.responseCode
            if (code !in 200..299 && code != 409) {
                throw IllegalStateException("Wearable register failed: HTTP $code")
            }
        } finally {
            conn.disconnect()
        }
    }

    fun streamChunk(
        config: WearableBridgeConfig,
        characteristicUuid: String,
        payload: ByteArray,
    ) {
        if (payload.isEmpty()) {
            return
        }

        val macEncoded = encodePathSegment(config.macAddress)
        val url = URI(config.backendUrl.trimEnd('/') + "/api/wearables/$macEncoded/stream").toURL()

        val conn = (url.openConnection() as HttpURLConnection)
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 15_000
            conn.readTimeout = 20_000
            conn.doOutput = true
            conn.setRequestProperty("Cookie", config.sessionCookie)
            conn.setRequestProperty("x-characteristic-uuid", characteristicUuid)
            conn.setRequestProperty("Content-Type", "application/octet-stream")

            conn.outputStream.use { out: OutputStream ->
                out.write(payload)
            }

            val code = conn.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("Wearable stream failed: HTTP $code")
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun encodePathSegment(value: String): String {
        return URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")
    }
}
