package com.neoagent.aurora.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.neoagent.aurora.service.AuroraService

/**
 * Starts the [AuroraService] after device boot or after a package update.
 * Declared in AndroidManifest with RECEIVE_BOOT_COMPLETED + MY_PACKAGE_REPLACED.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i("BootReceiver", "Boot / update received — starting Aurora service")
                AuroraService.start(context)
            }
        }
    }
}
