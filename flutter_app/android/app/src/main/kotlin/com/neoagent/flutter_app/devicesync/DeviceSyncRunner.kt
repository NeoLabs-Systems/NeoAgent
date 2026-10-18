package com.neoagent.flutter_app.devicesync

import android.content.Context
import com.neoagent.flutter_app.net.BackendHttp
import com.neoagent.flutter_app.net.BackendSession
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.security.MessageDigest
import java.time.Duration
import java.time.Instant

internal object DeviceSyncPrefs {
    const val NAME = "neoagent_device_sync"
    const val KEY_ENABLED = "enabled"
    const val KEY_BACKEND_URL = "backend_url"
    const val KEY_SESSION_COOKIE = "session_cookie"
    const val KEY_AGENT_ID = "agent_id"
    const val KEY_DEVICE_ID = "device_id"
    const val KEY_KINDS = "kinds"
    const val KEY_CALENDAR_HASH = "calendar_hash"
    const val KEY_CONTACTS_HASH = "contacts_hash"
    const val KEY_EXECUTED = "executed_commands"
    const val KEY_LAST_SUCCESS_AT = "last_success_at"
    const val KEY_LAST_ERROR = "last_error"

    fun read(context: Context) = context.getSharedPreferences(NAME, Context.MODE_PRIVATE)
}

/**
 * One sync with the server, shared by the background worker and the app:
 * upload what changed, make the changes the server queued for this phone,
 * and report them back.
 */
internal class DeviceSyncRunner(private val context: Context) {
    private val prefs = DeviceSyncPrefs.read(context)
    private val gateway = DeviceDataGateway(context)

    fun run(): Map<String, Any?> = synchronized(LOCK) {
        if (!prefs.getBoolean(DeviceSyncPrefs.KEY_ENABLED, false)) return status()
        try {
            var results = JSONArray()
            for (round in 0 until MAX_ROUNDS) {
                val commands = upload(results) ?: return status()
                if (commands.length() == 0) break
                results = JSONArray((0 until commands.length()).map { execute(commands.getJSONObject(it)) })
            }
            prefs.edit()
                .putString(DeviceSyncPrefs.KEY_LAST_SUCCESS_AT, Instant.now().toString())
                .remove(DeviceSyncPrefs.KEY_LAST_ERROR)
                .apply()
        } catch (err: Exception) {
            prefs.edit().putString(DeviceSyncPrefs.KEY_LAST_ERROR, err.message ?: err.javaClass.simpleName).apply()
        }
        return status()
    }

    fun status(): Map<String, Any?> = mapOf(
        "enabled" to prefs.getBoolean(DeviceSyncPrefs.KEY_ENABLED, false),
        "kinds" to kinds().toList(),
        "lastSuccessAt" to prefs.getString(DeviceSyncPrefs.KEY_LAST_SUCCESS_AT, null),
        "lastError" to prefs.getString(DeviceSyncPrefs.KEY_LAST_ERROR, null),
    )

    /** The shared kinds this app may still read; a permission turned off in Settings drops out. */
    private fun kinds() = prefs.getString(DeviceSyncPrefs.KEY_KINDS, "").orEmpty()
        .split(",").filter { it.isNotBlank() }.toSet()
        .intersect(DevicePermissions.granted(context).toSet())

    /** Sends what changed since the last upload; null once the server forgot this phone. */
    private fun upload(results: JSONArray): JSONArray? {
        val body = JSONObject()
            .put("deviceId", prefs.getString(DeviceSyncPrefs.KEY_DEVICE_ID, ""))
            .put("agentId", prefs.getString(DeviceSyncPrefs.KEY_AGENT_ID, ""))
            .put("results", results)
        val hashes = mutableMapOf<String, String>()
        if ("calendar" in kinds()) {
            val now = Instant.now()
            val calendars = gateway.calendars()
            val events = gateway.events(now.minus(Duration.ofDays(30)), now.plus(Duration.ofDays(90)))
            changed(DeviceSyncPrefs.KEY_CALENDAR_HASH, "$calendars$events", hashes) {
                body.put("calendars", calendars).put("events", events)
            }
        }
        if ("contacts" in kinds()) {
            val contacts = gateway.contacts()
            changed(DeviceSyncPrefs.KEY_CONTACTS_HASH, contacts.toString(), hashes) { body.put("contacts", contacts) }
        }

        val response = JSONObject(post(body).body)
        if (!response.optBoolean("connected", false)) {
            DeviceSyncScheduler(context).configure(DeviceSyncScheduler.Config.disabled())
            return null
        }
        prefs.edit().apply { hashes.forEach { (key, hash) -> putString(key, hash) } }.apply()
        return response.optJSONArray("commands") ?: JSONArray()
    }

    private fun changed(key: String, content: String, hashes: MutableMap<String, String>, include: () -> Unit) {
        val hash = MessageDigest.getInstance("SHA-256").digest(content.toByteArray())
            .joinToString("") { "%02x".format(it) }
        if (hash == prefs.getString(key, null)) return
        hashes[key] = hash
        include()
    }

    /** A change already made is reported again, never made twice. */
    private fun execute(command: JSONObject): JSONObject {
        val id = command.getLong("id").toString()
        val executed = JSONObject(prefs.getString(DeviceSyncPrefs.KEY_EXECUTED, "{}").orEmpty())
        executed.optJSONObject(id)?.let { return it }
        val result = try {
            JSONObject().put("id", id).put("ok", true)
                .put("result", gateway.apply(command.getString("action"), command.getJSONObject("payload")))
        } catch (err: Exception) {
            JSONObject().put("id", id).put("ok", false).put("error", err.message ?: err.javaClass.simpleName)
        }
        executed.put(id, result)
        val kept = executed.keys().asSequence().sortedBy { it.toLong() }.toList().takeLast(KEPT_RESULTS)
        prefs.edit().putString(DeviceSyncPrefs.KEY_EXECUTED, JSONObject().apply {
            kept.forEach { put(it, executed.get(it)) }
        }.toString()).apply()
        return result
    }

    private fun post(body: JSONObject): BackendHttp.Response {
        val backendUrl = prefs.getString(DeviceSyncPrefs.KEY_BACKEND_URL, "").orEmpty()
        val saveCookie: (String) -> Unit = { prefs.edit().putString(DeviceSyncPrefs.KEY_SESSION_COOKIE, it).apply() }
        fun send(cookie: String) = BackendHttp.request("POST", backendUrl, SYNC_PATH, cookie, body.toString())
        val stored = prefs.getString(DeviceSyncPrefs.KEY_SESSION_COOKIE, "").orEmpty()
        var response = send(BackendSession.ensureCookie(context, backendUrl, stored, saveCookie) ?: throw sessionError())
        if (response.code == HttpURLConnection.HTTP_UNAUTHORIZED) {
            response = send(BackendSession.ensureCookie(context, backendUrl, "", saveCookie) ?: throw sessionError())
        }
        if (response.code !in 200..299) throw IOException("NeoAgent rejected the sync (${response.code}).")
        return response
    }

    private fun sessionError() = IOException("NeoAgent could not refresh your session. Open the app and sign in.")

    private companion object {
        const val SYNC_PATH = "/api/mobile/device-sync/sync"
        const val MAX_ROUNDS = 3
        const val KEPT_RESULTS = 50
        val LOCK = Any()
    }
}
