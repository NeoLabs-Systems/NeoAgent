package com.neoagent.flutter_app.wearablebg.protocol

object WearableProtocolRegistry {
    fun resolve(
        protocolId: String,
        serviceUuid: String,
        audioNotifyUuid: String,
        controlNotifyUuid: String?,
        controlWriteUuid: String?,
    ): WearableProtocolHandler {
        val normalized = protocolId.trim().lowercase()
        return when (normalized) {
            "heypocket", "packet" -> PacketWearableProtocol(
                serviceUuid = serviceUuid,
                audioNotifyUuid = audioNotifyUuid,
                controlNotifyUuid = controlNotifyUuid,
                controlWriteUuid = controlWriteUuid,
            )
            else -> PacketWearableProtocol(
                serviceUuid = serviceUuid,
                audioNotifyUuid = audioNotifyUuid,
                controlNotifyUuid = controlNotifyUuid,
                controlWriteUuid = controlWriteUuid,
            )
        }
    }
}
