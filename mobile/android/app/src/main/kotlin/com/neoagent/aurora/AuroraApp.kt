package com.neoagent.aurora

import android.app.Application
import android.util.Log
import com.neoagent.aurora.notification.NotificationChannels

/**
 * Application entry point.
 * Registers notification channels (idempotent — safe to call on every launch).
 */
class AuroraApp : Application() {

    override fun onCreate() {
        super.onCreate()
        NotificationChannels.register(this)
        Log.i("AuroraApp", "Aurora initialised — backend: ${BuildConfig.BACKEND_URL}")
    }
}
