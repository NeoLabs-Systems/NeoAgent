package com.neoagent.flutter_app.wearablebg.protocol

import java.util.Locale

class PacketWearableProtocol(
    override val serviceUuid: String,
    override val audioNotifyUuid: String,
    override val controlNotifyUuid: String?,
    override val controlWriteUuid: String?,
) : WearableProtocolHandler {

    override val id: String = "heypocket"

    override fun parseAudioPayload(characteristicUuid: String, payload: ByteArray): ByteArray? {
        if (payload.isEmpty()) {
            return null
        }

        val normalizedCharacteristic = normalizeUuid(characteristicUuid)
        val normalizedAudio = normalizeUuid(audioNotifyUuid)
        if (normalizedCharacteristic == normalizedAudio) {
            return payload
        }

	        if (isAsciiControlMessage(payload)) {
	            return null
	        }

	        // Only audio-notify packets are forwarded as audio payloads.
	        return null
	    }

    override fun startRecordingCommand(): String = "APP&STA"

    override fun stopRecordingCommand(): String = "APP&STO"

    private fun normalizeUuid(value: String): String {
        return value.trim().lowercase(Locale.US).replace("-", "")
    }

    private fun isAsciiControlMessage(payload: ByteArray): Boolean {
        if (payload.size < 5) {
            return false
        }
        return try {
            val text = payload.toString(Charsets.UTF_8)
            val asciiOnly = text.all { c -> c.code in 0x20..0x7E || c == '\r' || c == '\n' || c == '\t' }
            asciiOnly && text.trim().matches(Regex("^(MCU|APP|BLE|SYS)&.*"))
        } catch (_: Exception) {
            false
        }
    }
}
