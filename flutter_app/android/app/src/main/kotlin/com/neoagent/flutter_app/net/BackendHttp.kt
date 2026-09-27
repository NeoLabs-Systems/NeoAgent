package com.neoagent.flutter_app.net

import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

/** Plain HTTP to the NeoAgent backend for native background work. */
internal object BackendHttp {
    fun request(
        method: String,
        baseUrl: String,
        path: String,
        cookie: String? = null,
        jsonBody: String? = null,
    ): Response {
        val url = resolveUrl(baseUrl, path)
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 20_000
            doInput = true
            instanceFollowRedirects = false
            setRequestProperty("Accept", "application/json")
            if (!cookie.isNullOrBlank()) {
                setRequestProperty("Cookie", cookie)
            }
            if (jsonBody != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                outputStream.use { stream ->
                    stream.write(jsonBody.toByteArray(Charsets.UTF_8))
                }
            }
        }

        return try {
            val code = connection.responseCode
            val body = (if (code in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()
                ?.use { it.readText() }
                .orEmpty()
            Response(
                code = code,
                body = body,
                cookie = connection.getHeaderField("Set-Cookie"),
            )
        } finally {
            connection.disconnect()
        }
    }

    private fun resolveUrl(baseUrl: String, path: String): URL {
        return URI(baseUrl.trim().ifBlank { "http://localhost:3333" })
            .resolve(path)
            .toURL()
    }

    data class Response(
        val code: Int,
        val body: String,
        val cookie: String? = null,
    )
}
