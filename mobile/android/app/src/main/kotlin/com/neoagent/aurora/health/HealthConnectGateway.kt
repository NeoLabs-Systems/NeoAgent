package com.neoagent.aurora.health

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import org.json.JSONArray
import org.json.JSONObject
import java.time.Duration
import java.time.Instant

/**
 * Reads Health Connect data and converts it into a transport shape for the NeoAgent backend.
 *
 * We keep the output generic on purpose: the backend stores a deduplicated sample table plus the
 * original payload, so we can expand the supported metrics later without redesigning the pipeline.
 */
class HealthConnectGateway(
    private val context: Context,
) {

    fun getSdkStatus(): Int {
        return HealthConnectClient.getSdkStatus(context, PROVIDER_PACKAGE_NAME)
    }

    fun isAvailable(): Boolean = getSdkStatus() == HealthConnectClient.SDK_AVAILABLE

    fun getClientOrNull(): HealthConnectClient? {
        if (!isAvailable()) return null
        return HealthConnectClient.getOrCreate(context)
    }

    suspend fun getRequestedPermissions(client: HealthConnectClient): Set<String> {
        val permissions = mutableSetOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(WeightRecord::class),
        )

        if (
            client.features.getFeatureStatus(
                HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND,
            ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        ) {
            permissions += HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND
        }

        return permissions
    }

    suspend fun collectBatch(
        client: HealthConnectClient,
        windowStart: Instant,
        windowEnd: Instant,
    ): HealthSyncBatchPayload {
        val timeRange = TimeRangeFilter.between(windowStart, windowEnd)

        val steps = readAllRecords<StepsRecord>(client, timeRange)
        val heartRates = readAllRecords<HeartRateRecord>(client, timeRange)
        val sleepSessions = readAllRecords<SleepSessionRecord>(client, timeRange)
        val exerciseSessions = readAllRecords<ExerciseSessionRecord>(client, timeRange)
        val weights = readAllRecords<WeightRecord>(client, timeRange)

        val records = buildList {
            steps.forEach { add(it.toPayload()) }
            heartRates.forEach { add(it.toPayload()) }
            sleepSessions.forEach { add(it.toPayload()) }
            exerciseSessions.forEach { add(it.toPayload()) }
            weights.forEach { add(it.toPayload()) }
        }

        val totalSteps = steps.sumOf { it.count }
        val allHeartRateSamples = heartRates.flatMap { it.samples }
        val sleepMinutes = sleepSessions.sumOf { Duration.between(it.startTime, it.endTime).toMinutes() }
        val exerciseMinutes = exerciseSessions.sumOf { Duration.between(it.startTime, it.endTime).toMinutes() }
        val latestWeightKg = weights.maxByOrNull { it.time }?.weight?.inKilograms

        val summary = JSONObject().apply {
            put("stepsTotal", totalSteps)
            put("heartRateRecordCount", heartRates.size)
            put("heartRateSampleCount", allHeartRateSamples.size)
            put("heartRateAvgBpm", if (allHeartRateSamples.isEmpty()) JSONObject.NULL else allHeartRateSamples.map { it.beatsPerMinute }.average())
            put("sleepSessionCount", sleepSessions.size)
            put("sleepMinutes", sleepMinutes)
            put("exerciseSessionCount", exerciseSessions.size)
            put("exerciseMinutes", exerciseMinutes)
            put("weightRecordCount", weights.size)
            put("latestWeightKg", latestWeightKg ?: JSONObject.NULL)
        }

        return HealthSyncBatchPayload(
            source = SOURCE_NAME,
            provider = PROVIDER_PACKAGE_NAME,
            windowStart = windowStart.toString(),
            windowEnd = windowEnd.toString(),
            summary = summary,
            records = records,
        )
    }

    private suspend inline fun <reified T : Record> readAllRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
    ): List<T> {
        val records = mutableListOf<T>()
        var pageToken: String? = null

        do {
            val response = client.readRecords(
                ReadRecordsRequest<T>(
                    timeRangeFilter = timeRange,
                    ascendingOrder = true,
                    pageSize = PAGE_SIZE,
                    pageToken = pageToken,
                ),
            )
            records += response.records
            pageToken = response.pageToken
        } while (pageToken != null)

        return records
    }

    private fun StepsRecord.toPayload(): HealthSyncRecordPayload {
        return HealthSyncRecordPayload(
            metricType = "steps",
            recordId = metadata.id,
            startTime = startTime.toString(),
            endTime = endTime.toString(),
            recordedAt = endTime.toString(),
            numericValue = count.toDouble(),
            textValue = null,
            unit = "steps",
            sourceAppId = metadata.dataOrigin.packageName.takeIf { it.isNotBlank() },
            sourceDevice = metadata.device.toLabel(),
            lastModifiedTime = metadata.lastModifiedTime.toString(),
            payload = JSONObject().apply {
                put("count", count)
            },
        )
    }

    private fun HeartRateRecord.toPayload(): HealthSyncRecordPayload {
        val min = samples.minOfOrNull { it.beatsPerMinute }
        val max = samples.maxOfOrNull { it.beatsPerMinute }
        val avg = samples.map { it.beatsPerMinute }.average().takeIf { !it.isNaN() }

        return HealthSyncRecordPayload(
            metricType = "heart_rate",
            recordId = metadata.id,
            startTime = startTime.toString(),
            endTime = endTime.toString(),
            recordedAt = endTime.toString(),
            numericValue = avg,
            textValue = "${samples.size} samples",
            unit = "bpm",
            sourceAppId = metadata.dataOrigin.packageName.takeIf { it.isNotBlank() },
            sourceDevice = metadata.device.toLabel(),
            lastModifiedTime = metadata.lastModifiedTime.toString(),
            payload = JSONObject().apply {
                put("sampleCount", samples.size)
                put("minBpm", min ?: JSONObject.NULL)
                put("maxBpm", max ?: JSONObject.NULL)
                put("avgBpm", avg ?: JSONObject.NULL)
                put(
                    "samples",
                    JSONArray().apply {
                        samples.forEach { sample ->
                            put(
                                JSONObject().apply {
                                    put("time", sample.time.toString())
                                    put("beatsPerMinute", sample.beatsPerMinute)
                                },
                            )
                        }
                    },
                )
            },
        )
    }

    private fun SleepSessionRecord.toPayload(): HealthSyncRecordPayload {
        val durationMinutes = Duration.between(startTime, endTime).toMinutes()
        return HealthSyncRecordPayload(
            metricType = "sleep_session",
            recordId = metadata.id,
            startTime = startTime.toString(),
            endTime = endTime.toString(),
            recordedAt = endTime.toString(),
            numericValue = durationMinutes.toDouble(),
            textValue = title,
            unit = "minutes",
            sourceAppId = metadata.dataOrigin.packageName.takeIf { it.isNotBlank() },
            sourceDevice = metadata.device.toLabel(),
            lastModifiedTime = metadata.lastModifiedTime.toString(),
            payload = JSONObject().apply {
                put("title", title ?: JSONObject.NULL)
                put("notes", notes ?: JSONObject.NULL)
                put("stageCount", stages.size)
                put(
                    "stages",
                    JSONArray().apply {
                        stages.forEach { stage ->
                            put(
                                JSONObject().apply {
                                    put("startTime", stage.startTime.toString())
                                    put("endTime", stage.endTime.toString())
                                    put("stage", stage.stage)
                                },
                            )
                        }
                    },
                )
            },
        )
    }

    private fun ExerciseSessionRecord.toPayload(): HealthSyncRecordPayload {
        val durationMinutes = Duration.between(startTime, endTime).toMinutes()
        return HealthSyncRecordPayload(
            metricType = "exercise_session",
            recordId = metadata.id,
            startTime = startTime.toString(),
            endTime = endTime.toString(),
            recordedAt = endTime.toString(),
            numericValue = durationMinutes.toDouble(),
            textValue = title ?: "exercise:${exerciseType}",
            unit = "minutes",
            sourceAppId = metadata.dataOrigin.packageName.takeIf { it.isNotBlank() },
            sourceDevice = metadata.device.toLabel(),
            lastModifiedTime = metadata.lastModifiedTime.toString(),
            payload = JSONObject().apply {
                put("exerciseType", exerciseType)
                put("title", title ?: JSONObject.NULL)
                put("notes", notes ?: JSONObject.NULL)
            },
        )
    }

    private fun WeightRecord.toPayload(): HealthSyncRecordPayload {
        val kilograms = weight.inKilograms
        return HealthSyncRecordPayload(
            metricType = "weight",
            recordId = metadata.id,
            startTime = time.toString(),
            endTime = null,
            recordedAt = time.toString(),
            numericValue = kilograms,
            textValue = null,
            unit = "kg",
            sourceAppId = metadata.dataOrigin.packageName.takeIf { it.isNotBlank() },
            sourceDevice = metadata.device.toLabel(),
            lastModifiedTime = metadata.lastModifiedTime.toString(),
            payload = JSONObject().apply {
                put("kilograms", kilograms)
            },
        )
    }

    private fun Device?.toLabel(): String? {
        if (this == null) return null
        val parts = listOfNotNull(
            manufacturer?.takeIf { it.isNotBlank() },
            model?.takeIf { it.isNotBlank() },
            type.toTypeName(),
        )
        return parts.joinToString(" / ").takeIf { it.isNotBlank() }
    }

    private fun Int.toTypeName(): String = when (this) {
        Device.TYPE_PHONE -> "phone"
        Device.TYPE_WATCH -> "watch"
        Device.TYPE_SCALE -> "scale"
        Device.TYPE_RING -> "ring"
        Device.TYPE_FITNESS_BAND -> "fitness_band"
        Device.TYPE_CHEST_STRAP -> "chest_strap"
        Device.TYPE_SMART_DISPLAY -> "smart_display"
        Device.TYPE_HEAD_MOUNTED -> "head_mounted"
        else -> "unknown"
    }

    companion object {
        const val SOURCE_NAME = "android-health-connect"
        const val PROVIDER_PACKAGE_NAME = "com.google.android.apps.healthdata"

        private const val PAGE_SIZE = 500
    }
}
