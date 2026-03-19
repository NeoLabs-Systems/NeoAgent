package com.neoagent.flutter_app.health

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.time.Instant

class HealthSyncWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val prefs = HealthSyncPrefs.read(applicationContext)
        val enabled = prefs.getBoolean(HealthSyncPrefs.KEY_ENABLED, false)
        val backendUrl =
            prefs.getString(HealthSyncPrefs.KEY_BACKEND_URL, "")?.trim().orEmpty()
        if (!enabled || backendUrl.isBlank()) {
            return Result.success()
        }

        HealthSyncNotifications.register(applicationContext)
        setForeground(
            HealthSyncNotifications.foregroundInfo(
                applicationContext,
                "Checking Health Connect permissions…",
            ),
        )

        return try {
            val gateway = HealthConnectGateway(applicationContext)
            val client = gateway.getClientOrNull()
                ?: return finishFailure(
                    retry = false,
                    message = "Health Connect is unavailable on this device.",
                )
            val requiredPermissions = gateway.getRequestedPermissions(client)
            val grantedPermissions = client.permissionController.getGrantedPermissions()
            if (!grantedPermissions.containsAll(requiredPermissions)) {
                return finishFailure(
                    retry = false,
                    message = "Health permissions are missing. Open NeoAgent and grant Health Connect access.",
                )
            }

            var cookie =
                prefs.getString(HealthSyncPrefs.KEY_SESSION_COOKIE, "")?.trim().orEmpty()
            cookie = ensureSessionCookie(backendUrl, cookie)
                ?: return finishFailure(
                    retry = true,
                    message = "NeoAgent background sync could not refresh your session.",
                )

            var statusResponse = request(
                method = "GET",
                baseUrl = backendUrl,
                path = "/api/mobile/health/status",
                cookie = cookie,
            )

            if (statusResponse.code == HttpURLConnection.HTTP_UNAUTHORIZED) {
                cookie = ensureSessionCookie(backendUrl, "")
                    ?: return finishFailure(
                        retry = true,
                        message = "NeoAgent background sync could not refresh your session.",
                    )
                statusResponse = request(
                    method = "GET",
                    baseUrl = backendUrl,
                    path = "/api/mobile/health/status",
                    cookie = cookie,
                )
            }

            if (statusResponse.code !in 200..299) {
                return finishFailure(
                    retry = statusResponse.code >= 500,
                    message =
                        "NeoAgent server rejected health status check (${statusResponse.code}).",
                )
            }

            val lastWindowEndRaw = JSONObject(statusResponse.body)
                .optJSONObject("lastRun")
                ?.optString("sync_window_end")
                ?.takeIf { it.isNotBlank() }

            val windowEnd = Instant.now()
            val windowStart = lastWindowEndRaw?.let {
                runCatching { Instant.parse(it) }.getOrNull()
            }?.minusSeconds(300) ?: windowEnd.minusSeconds(24 * 60 * 60)

            setForeground(
                HealthSyncNotifications.foregroundInfo(
                    applicationContext,
                    "Syncing steps, heart rate, sleep, exercise, and weight…",
                ),
            )
            val payload = gateway.collectBatch(client, windowStart, windowEnd)
            val uploadResponse = request(
                method = "POST",
                baseUrl = backendUrl,
                path = "/api/mobile/health/sync",
                cookie = cookie,
                jsonBody = payload.toJson().toString(),
            )

            if (uploadResponse.code !in 200..299) {
                return finishFailure(
                    retry = uploadResponse.code >= 500,
                    message =
                        "NeoAgent server rejected health upload (${uploadResponse.code}).",
                )
            }

            prefs.edit()
                .putString(HealthSyncPrefs.KEY_SESSION_COOKIE, cookie)
                .putString(HealthSyncPrefs.KEY_LAST_SUCCESS_AT, Instant.now().toString())
                .putInt(HealthSyncPrefs.KEY_CONSECUTIVE_FAILURES, 0)
                .remove(HealthSyncPrefs.KEY_LAST_ERROR)
                .apply()
            HealthSyncNotifications.clearFailure(applicationContext)
            Result.success()
        } catch (err: IOException) {
            finishFailure(
                retry = true,
                message = err.message ?: "Network error while syncing health data.",
            )
        } catch (err: Exception) {
            finishFailure(
                retry = false,
                message = err.message ?: err.javaClass.simpleName,
            )
        }
    }

    private fun finishFailure(retry: Boolean, message: String): Result {
        val prefs = HealthSyncPrefs.read(applicationContext)
        val failures =
            prefs.getInt(HealthSyncPrefs.KEY_CONSECUTIVE_FAILURES, 0) + 1
        prefs.edit()
            .putInt(HealthSyncPrefs.KEY_CONSECUTIVE_FAILURES, failures)
            .putString(HealthSyncPrefs.KEY_LAST_ERROR, message)
            .apply()

        if (!retry || failures >= 2) {
            HealthSyncNotifications.showFailure(applicationContext, message)
        }

        return if (retry) Result.retry() else Result.failure()
    }

    private fun ensureSessionCookie(
        backendUrl: String,
        currentCookie: String,
    ): String? {
        if (currentCookie.isNotBlank()) {
            return currentCookie
        }

        val flutterPrefs =
            applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
        val username = flutterPrefs.getString("flutter.username", "")?.trim().orEmpty()
        val password = flutterPrefs.getString("flutter.password", "")?.trim().orEmpty()
        if (username.isBlank() || password.isBlank()) {
            return null
        }

        val response = request(
            method = "POST",
            baseUrl = backendUrl,
            path = "/api/auth/login",
            jsonBody =
                JSONObject()
                    .put("username", username)
                    .put("password", password)
                    .toString(),
        )
        if (response.code !in 200..299 || response.cookie.isNullOrBlank()) {
            return null
        }

        val cookie = response.cookie.substringBefore(";")
        HealthSyncPrefs.read(applicationContext)
            .edit()
            .putString(HealthSyncPrefs.KEY_SESSION_COOKIE, cookie)
            .apply()
        return cookie
    }

    private fun request(
        method: String,
        baseUrl: String,
        path: String,
        cookie: String? = null,
        jsonBody: String? = null,
    ): HttpResponse {
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
            HttpResponse(
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

    private data class HttpResponse(
        val code: Int,
        val body: String,
        val cookie: String? = null,
    )
}
