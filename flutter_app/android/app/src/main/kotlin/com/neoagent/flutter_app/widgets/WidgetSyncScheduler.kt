package com.neoagent.flutter_app.widgets

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class WidgetSyncScheduler(private val context: Context) {

    fun configure(
        enabled: Boolean,
        backendUrl: String,
        sessionCookie: String,
    ) {
        val store = AiWidgetStore(context)
        store.saveConfig(
            enabled = enabled,
            backendUrl = backendUrl,
            sessionCookie = sessionCookie,
        )

        val workManager = WorkManager.getInstance(context)
        if (!enabled) {
            workManager.cancelUniqueWork(UNIQUE_PERIODIC_WORK)
            workManager.cancelUniqueWork(UNIQUE_IMMEDIATE_WORK)
            return
        }

        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val periodicRequest =
            PeriodicWorkRequestBuilder<WidgetSyncWorker>(1, TimeUnit.HOURS)
                .setConstraints(constraints)
                .build()

        val immediateRequest =
            OneTimeWorkRequestBuilder<WidgetSyncWorker>()
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

    fun syncNow() {
        if (!AiWidgetStore(context).isEnabled()) {
            return
        }
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request =
            OneTimeWorkRequestBuilder<WidgetSyncWorker>()
                .setConstraints(constraints)
                .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_IMMEDIATE_WORK,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    companion object {
        private const val UNIQUE_PERIODIC_WORK = "neoagent_widgets_periodic_sync"
        private const val UNIQUE_IMMEDIATE_WORK = "neoagent_widgets_immediate_sync"
    }
}
