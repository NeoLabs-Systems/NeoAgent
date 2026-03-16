package com.neoagent.aurora.network

import com.neoagent.aurora.settings.SettingsManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Shared backend client for authenticated REST calls.
 *
 * The Android app already authenticates with NeoAgent for the socket connection; this helper
 * centralizes the same login flow so other modules, such as background health sync, can reuse it.
 */
class BackendSessionClient(
    private val settings: SettingsManager,
) {

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .followRedirects(false)
        .build()

    private val sessionMutex = Mutex()

    @Volatile
    private var sessionCookie: String? = null

    suspend fun getSessionCookie(forceRefresh: Boolean = false): String {
        if (!forceRefresh) {
            sessionCookie?.let { return it }
        }

        return sessionMutex.withLock {
            if (!forceRefresh) {
                sessionCookie?.let { return@withLock it }
            }
            val cookie = login()
            sessionCookie = cookie
            cookie
        }
    }

    suspend fun postJson(path: String, body: JSONObject): String {
        return executeJsonRequest(path, body.toString(), retryOnUnauthorized = true)
    }

    fun clearSession() {
        sessionCookie = null
    }

    private suspend fun executeJsonRequest(
        path: String,
        body: String,
        retryOnUnauthorized: Boolean,
    ): String = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${settings.backendUrl}$path")
            .header("Cookie", getSessionCookie())
            .post(body.toRequestBody(JSON_MEDIA_TYPE))
            .build()

        http.newCall(request).execute().use { response ->
            if (response.code == 401 && retryOnUnauthorized) {
                clearSession()
                return@withContext executeJsonRequest(path, body, retryOnUnauthorized = false)
            }
            if (!response.isSuccessful) {
                throw IOException("Backend request failed: HTTP ${response.code}")
            }
            return@withContext response.body?.string().orEmpty()
        }
    }

    private suspend fun login(): String = withContext(Dispatchers.IO) {
        val requestBody = JSONObject().apply {
            put("username", settings.username)
            put("password", settings.password)
        }.toString().toRequestBody(JSON_MEDIA_TYPE)

        val request = Request.Builder()
            .url("${settings.backendUrl}/api/auth/login")
            .post(requestBody)
            .build()

        http.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IOException("Login failed: HTTP ${response.code}")
            }
            val cookies = response.headers.values("Set-Cookie")
            if (cookies.isEmpty()) {
                throw IOException("No session cookie returned from login")
            }
            return@withContext cookies.joinToString("; ") { it.substringBefore(";") }
        }
    }

    companion object {
        private val JSON_MEDIA_TYPE = "application/json".toMediaType()
    }
}
