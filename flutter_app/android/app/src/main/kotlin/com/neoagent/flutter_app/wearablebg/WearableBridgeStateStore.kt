package com.neoagent.flutter_app.wearablebg

import android.content.Context
import org.json.JSONObject

data class WearableBridgeConfig(
    val backendUrl: String,
    val sessionCookie: String,
    val macAddress: String,
    val deviceName: String,
    val protocolId: String,
    val serviceUuid: String,
    val audioNotifyUuid: String,
    val controlNotifyUuid: String?,
    val controlWriteUuid: String?,
    val autoStartRecording: Boolean,
)

class WearableBridgeStateStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(config: WearableBridgeConfig) {
        prefs.edit()
            .putBoolean(KEY_ACTIVE, true)
            .putBoolean(KEY_CONNECTED, false)
            .putString(KEY_CONFIG_JSON, serialize(config).toString())
            .apply()
    }

    fun setConnected(connected: Boolean) {
        prefs.edit()
            .putBoolean(KEY_CONNECTED, connected)
            .apply()
    }

    fun clear() {
        prefs.edit()
            .putBoolean(KEY_ACTIVE, false)
            .putBoolean(KEY_CONNECTED, false)
            .remove(KEY_CONFIG_JSON)
            .apply()
    }

    fun isActive(): Boolean = prefs.getBoolean(KEY_ACTIVE, false)

    fun isConnected(): Boolean = prefs.getBoolean(KEY_CONNECTED, false)

    fun load(): WearableBridgeConfig? {
        val raw = prefs.getString(KEY_CONFIG_JSON, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val backendUrl = json.optString("backendUrl").trim()
            val sessionCookie = json.optString("sessionCookie").trim()
            val macAddress = json.optString("macAddress").trim()
            val deviceName = json.optString("deviceName").trim()
            val protocolId = json.optString("protocolId", "heypocket").trim().ifBlank { "heypocket" }
            val serviceUuid = json.optString("serviceUuid").trim()
            val audioNotifyUuid = json.optString("audioNotifyUuid").trim()
            val controlNotifyUuid = json.optString("controlNotifyUuid").ifBlank { null }
            val controlWriteUuid = json.optString("controlWriteUuid").ifBlank { null }

            if (backendUrl.isBlank() ||
                sessionCookie.isBlank() ||
                macAddress.isBlank() ||
                deviceName.isBlank() ||
                serviceUuid.isBlank() ||
                audioNotifyUuid.isBlank()
            ) {
                return null
            }

            WearableBridgeConfig(
                backendUrl = backendUrl,
                sessionCookie = sessionCookie,
                macAddress = macAddress,
                deviceName = deviceName,
                protocolId = protocolId,
                serviceUuid = serviceUuid,
                audioNotifyUuid = audioNotifyUuid,
                controlNotifyUuid = controlNotifyUuid,
                controlWriteUuid = controlWriteUuid,
                autoStartRecording = json.optBoolean("autoStartRecording", false),
            )
        } catch (_: Exception) {
            null
        }
    }

    fun statusMap(): Map<String, Any?> {
        val config = load()
        return mapOf(
            "active" to isActive(),
            "connected" to isConnected(),
            "macAddress" to config?.macAddress,
            "protocol" to config?.protocolId,
            "backendUrl" to config?.backendUrl,
        )
    }

    private fun serialize(config: WearableBridgeConfig): JSONObject {
        return JSONObject()
            .put("backendUrl", config.backendUrl)
            .put("sessionCookie", config.sessionCookie)
            .put("macAddress", config.macAddress)
            .put("deviceName", config.deviceName)
            .put("protocolId", config.protocolId)
            .put("serviceUuid", config.serviceUuid)
            .put("audioNotifyUuid", config.audioNotifyUuid)
            .put("controlNotifyUuid", config.controlNotifyUuid)
            .put("controlWriteUuid", config.controlWriteUuid)
            .put("autoStartRecording", config.autoStartRecording)
    }

    companion object {
        private const val PREFS_NAME = "wearable_bridge_state"
        private const val KEY_ACTIVE = "active"
        private const val KEY_CONNECTED = "connected"
        private const val KEY_CONFIG_JSON = "config_json"
    }
}
