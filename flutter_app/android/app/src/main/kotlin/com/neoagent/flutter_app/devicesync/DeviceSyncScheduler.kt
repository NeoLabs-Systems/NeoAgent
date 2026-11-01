package com.neoagent.flutter_app.devicesync

import android.content.Context
import android.provider.CalendarContract
import android.provider.ContactsContract
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Duration
import java.util.concurrent.TimeUnit

class DeviceSyncWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        withContext(Dispatchers.IO) { DeviceSyncRunner(applicationContext).run() }
        // A content trigger fires once, so the next change needs a new one.
        if (tags.contains(DeviceSyncScheduler.CHANGE_TAG)) DeviceSyncScheduler(applicationContext).watchForChanges()
        return Result.success()
    }
}

/**
 * Syncs every 15 minutes, shortly after the phone's calendars or contacts
 * change, and right away when sharing is turned on.
 */
internal class DeviceSyncScheduler(private val context: Context) {
    data class Config(
        val enabled: Boolean,
        val backendUrl: String = "",
        val sessionCookie: String = "",
        val agentId: String = "",
        val deviceId: String = "",
        val kinds: List<String> = emptyList(),
    ) {
        companion object {
            fun disabled() = Config(enabled = false)
        }
    }

    private val workManager get() = WorkManager.getInstance(context)
    private val online = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

    fun configure(config: Config) {
        val prefs = DeviceSyncPrefs.read(context).edit().putBoolean(DeviceSyncPrefs.KEY_ENABLED, config.enabled)
        if (!config.enabled) {
            prefs.remove(DeviceSyncPrefs.KEY_CALENDAR_HASH).remove(DeviceSyncPrefs.KEY_CONTACTS_HASH).apply()
            listOf(PERIODIC_WORK, CHANGE_WORK, NOW_WORK).forEach(workManager::cancelUniqueWork)
            return
        }
        prefs
            .putString(DeviceSyncPrefs.KEY_BACKEND_URL, config.backendUrl.trim())
            .putString(DeviceSyncPrefs.KEY_SESSION_COOKIE, config.sessionCookie.trim())
            .putString(DeviceSyncPrefs.KEY_AGENT_ID, config.agentId)
            .putString(DeviceSyncPrefs.KEY_DEVICE_ID, config.deviceId)
            .putString(DeviceSyncPrefs.KEY_KINDS, config.kinds.joinToString(","))
            // A changed choice of kinds uploads everything again.
            .remove(DeviceSyncPrefs.KEY_CALENDAR_HASH)
            .remove(DeviceSyncPrefs.KEY_CONTACTS_HASH)
            .apply()
        workManager.enqueueUniquePeriodicWork(
            PERIODIC_WORK,
            ExistingPeriodicWorkPolicy.UPDATE,
            PeriodicWorkRequestBuilder<DeviceSyncWorker>(15, TimeUnit.MINUTES).setConstraints(online).build(),
        )
        workManager.enqueueUniqueWork(
            NOW_WORK,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<DeviceSyncWorker>().setConstraints(online).build(),
        )
        watchForChanges()
    }

    fun watchForChanges() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .addContentUriTrigger(CalendarContract.Events.CONTENT_URI, true)
            .addContentUriTrigger(ContactsContract.Contacts.CONTENT_URI, true)
            .setTriggerContentUpdateDelay(Duration.ofSeconds(20))
            .setTriggerContentMaxDelay(Duration.ofMinutes(2))
            .build()
        workManager.enqueueUniqueWork(
            CHANGE_WORK,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<DeviceSyncWorker>().setConstraints(constraints).addTag(CHANGE_TAG).build(),
        )
    }

    companion object {
        const val CHANGE_TAG = "neoagent_device_sync_change"
        private const val PERIODIC_WORK = "neoagent_device_sync_periodic"
        private const val CHANGE_WORK = "neoagent_device_sync_change"
        private const val NOW_WORK = "neoagent_device_sync_now"
    }
}
