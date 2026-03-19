package com.neoagent.flutter_app.health

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

internal object HealthSyncPrefs {
    const val PREFS_NAME = "neoagent_health_sync"
    const val KEY_ENABLED = "enabled"
    const val KEY_BACKEND_URL = "backend_url"
    const val KEY_SESSION_COOKIE = "session_cookie"
    const val KEY_LAST_SUCCESS_AT = "last_success_at"
    const val KEY_CONSECUTIVE_FAILURES = "consecutive_failures"
    const val KEY_LAST_ERROR = "last_error"

    fun read(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}

class HealthSyncScheduler(private val context: Context) {

    fun configure(
        enabled: Boolean,
        backendUrl: String,
        sessionCookie: String,
    ) {
        HealthSyncNotifications.register(context)
        HealthSyncPrefs.read(context)
            .edit()
            .putBoolean(HealthSyncPrefs.KEY_ENABLED, enabled)
            .putString(HealthSyncPrefs.KEY_BACKEND_URL, backendUrl.trim())
            .putString(HealthSyncPrefs.KEY_SESSION_COOKIE, sessionCookie.trim())
            .apply()

        val workManager = WorkManager.getInstance(context)
        if (!enabled) {
            HealthSyncNotifications.clearFailure(context)
            workManager.cancelUniqueWork(UNIQUE_PERIODIC_WORK)
            workManager.cancelUniqueWork(UNIQUE_IMMEDIATE_WORK)
            return
        }

        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val periodicRequest =
            PeriodicWorkRequestBuilder<HealthSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()

        val immediateRequest = OneTimeWorkRequestBuilder<HealthSyncWorker>()
            .setConstraints(constraints)
            .build()

        workManager.enqueueUniquePeriodicWork(
            UNIQUE_PERIODIC_WORK,
            ExistingPeriodicWorkPolicy.UPDATE,
            periodicRequest,
        )
        workManager.enqueueUniqueWork(
            UNIQUE_IMMEDIATE_WORK,
            ExistingWorkPolicy.REPLACE,
            immediateRequest,
        )
    }

    companion object {
        private const val UNIQUE_PERIODIC_WORK = "neoagent_health_periodic_sync"
        private const val UNIQUE_IMMEDIATE_WORK = "neoagent_health_immediate_sync"
    }
}
