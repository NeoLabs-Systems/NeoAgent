package com.neoagent.aurora.health

import org.json.JSONArray
import org.json.JSONObject

data class HealthSyncRecordPayload(
    val metricType: String,
    val recordId: String,
    val startTime: String?,
    val endTime: String?,
    val recordedAt: String?,
    val numericValue: Double?,
    val textValue: String?,
    val unit: String?,
    val sourceAppId: String?,
    val sourceDevice: String?,
    val lastModifiedTime: String?,
    val payload: JSONObject,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("metricType", metricType)
        put("recordId", recordId)
        put("startTime", startTime)
        put("endTime", endTime)
        put("recordedAt", recordedAt)
        put("numericValue", numericValue)
        put("textValue", textValue)
        put("unit", unit)
        put("sourceAppId", sourceAppId)
        put("sourceDevice", sourceDevice)
        put("lastModifiedTime", lastModifiedTime)
        put("payload", payload)
    }
}

data class HealthSyncBatchPayload(
    val source: String,
    val provider: String,
    val windowStart: String,
    val windowEnd: String,
    val summary: JSONObject,
    val records: List<HealthSyncRecordPayload>,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("source", source)
        put("provider", provider)
        put("windowStart", windowStart)
        put("windowEnd", windowEnd)
        put("summary", summary)
        put(
            "records",
            JSONArray().apply {
                records.forEach { put(it.toJson()) }
            },
        )
    }
}
