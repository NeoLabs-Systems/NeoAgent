package com.neoagent.flutter_app.net

import android.content.Context
import org.json.JSONObject

/** Session cookies for native background work. */
internal object BackendSession {
    /**
     * [currentCookie] when there is one; otherwise signs in again with the
     * credentials the app saved and hands the new cookie to [save].
     */
    fun ensureCookie(
        context: Context,
        backendUrl: String,
        currentCookie: String,
        save: (String) -> Unit,
    ): String? {
        if (currentCookie.isNotBlank()) {
            return currentCookie
        }

        val flutterPrefs =
            context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
        val username = flutterPrefs.getString("flutter.username", "")?.trim().orEmpty()
        val password = flutterPrefs.getString("flutter.password", "")?.trim().orEmpty()
        if (username.isBlank() || password.isBlank()) {
            return null
        }

        val response = BackendHttp.request(
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
        save(cookie)
        return cookie
    }
}
