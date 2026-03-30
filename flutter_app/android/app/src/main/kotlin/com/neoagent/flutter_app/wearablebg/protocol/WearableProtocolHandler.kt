package com.neoagent.flutter_app.wearablebg.protocol

interface WearableProtocolHandler {
    val id: String
    val serviceUuid: String
    val audioNotifyUuid: String
    val controlNotifyUuid: String?
    val controlWriteUuid: String?

    fun parseAudioPayload(characteristicUuid: String, payload: ByteArray): ByteArray?

    fun startRecordingCommand(): String?

    fun stopRecordingCommand(): String?
}
