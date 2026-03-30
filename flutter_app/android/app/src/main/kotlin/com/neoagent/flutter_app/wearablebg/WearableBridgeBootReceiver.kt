package com.neoagent.flutter_app.wearablebg

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class WearableBridgeBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        val store = WearableBridgeStateStore(context)
        if (!store.isActive()) {
            return
        }

        ContextCompat.startForegroundService(
            context,
            WearableBleForegroundService.buildRestoreIntent(context),
        )
    }
}
