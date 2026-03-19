package com.neoagent.flutter_app.recording

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class RecordingBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }
        val store = RecordingStateStore(context)
        val config = store.loadConfig() ?: return
        if (!config.active || config.paused) {
            return
        }
        val serviceIntent = RecordingForegroundService.buildRestoreIntent(context)
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
