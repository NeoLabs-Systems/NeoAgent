package com.neoagent.flutter_app.widgets

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

class WidgetSyncWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val store = AiWidgetStore(applicationContext)
        if (!store.isEnabled()) {
            return Result.success()
        }
        val backendUrl = store.backendUrl()
        var cookie = store.sessionCookie()
        if (backendUrl.isBlank() || cookie.isBlank()) {
            return Result.success()
        }

        return try {
            var response = request(
                method = "GET",
                baseUrl = backendUrl,
                path = "/api/widgets?all=true",
                cookie = cookie,
            )
            if (response.code == HttpURLConnection.HTTP_UNAUTHORIZED) {
                cookie = ensureSessionCookie(backendUrl, "") ?: return Result.retry()
                response = request(
                    method = "GET",
                    baseUrl = backendUrl,
                    path = "/api/widgets?all=true",
                    cookie = cookie,
                )
            }
            if (response.code !in 200..299) {
                store.setLastError("Widget sync failed (${response.code}).")
                return if (response.code >= 500) Result.retry() else Result.failure()
            }

            store.saveConfig(
                enabled = true,
                backendUrl = backendUrl,
                sessionCookie = cookie,
            )
            store.saveCachedWidgets(response.body)
            AiHomeWidgetProvider.refreshAll(applicationContext)
            Result.success()
        } catch (err: Exception) {
            store.setLastError(err.message ?: err.javaClass.simpleName)
            Result.retry()
        }
    }

    private fun ensureSessionCookie(
        backendUrl: String,
        currentCookie: String,
    ): String? {
        if (currentCookie.isNotBlank()) {
            return currentCookie
        }
        if (!isHttpsUrl(backendUrl)) {
            Log.e(TAG, "Refusing widget login over non-HTTPS backend URL: $backendUrl")
            return null
        }

        val flutterPrefs = encryptedFlutterPrefs() ?: return null
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
        return response.cookie.substringBefore(";")
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
            }
        }

        return try {
            if (jsonBody != null) {
                connection.outputStream.use { stream ->
                    stream.write(jsonBody.toByteArray(Charsets.UTF_8))
                }
            }
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

    private fun encryptedFlutterPrefs() =
        try {
            val key =
                MasterKey.Builder(applicationContext)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()
            EncryptedSharedPreferences.create(
                applicationContext,
                "FlutterSharedPreferences",
                key,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (err: Exception) {
            Log.e(TAG, "Failed to access encrypted Flutter credentials.", err)
            null
        }

    private fun isHttpsUrl(url: String): Boolean {
        return try {
            URI(url.trim()).scheme.equals("https", ignoreCase = true)
        } catch (_: Exception) {
            false
        }
    }

    private data class HttpResponse(
        val code: Int,
        val body: String,
        val cookie: String? = null,
    )

    companion object {
        private const val TAG = "WidgetSyncWorker"
    }
}
