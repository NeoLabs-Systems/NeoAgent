package com.neoagent.flutter_app.devicesync

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal object DevicePermissions {
    private val BY_KIND = mapOf(
        "calendar" to arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
        "contacts" to arrayOf(Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS),
    )

    fun of(kinds: Collection<String>) = kinds.flatMap { BY_KIND[it].orEmpty().toList() }.toTypedArray()

    fun granted(context: Context): List<String> = BY_KIND.filter { (_, permissions) ->
        permissions.all { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }
    }.keys.toList()
}

/** `neoagent/device_sync`: permissions, turning sharing on or off, and syncing now. */
internal object DeviceSyncChannel {
    private var pendingPermissions: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger, activity: FragmentActivity) {
        val context = activity.applicationContext
        val permissionLauncher = activity.registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions(),
        ) {
            pendingPermissions?.success(DevicePermissions.granted(context))
            pendingPermissions = null
        }
        MethodChannel(messenger, "neoagent/device_sync").setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceName" -> result.success(
                    listOf(Build.MANUFACTURER.replaceFirstChar { it.uppercase() }, Build.MODEL)
                        .distinct().joinToString(" "),
                )
                "grantedKinds" -> result.success(DevicePermissions.granted(context))
                "requestPermissions" -> {
                    val kinds = (call.argument<List<String>>("kinds")).orEmpty()
                    pendingPermissions = result
                    permissionLauncher.launch(DevicePermissions.of(kinds))
                }
                "openSettings" -> {
                    activity.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")),
                    )
                    result.success(null)
                }
                "configure" -> {
                    DeviceSyncScheduler(context).configure(
                        DeviceSyncScheduler.Config(
                            enabled = call.argument<Boolean>("enabled") == true,
                            backendUrl = call.argument<String>("backendUrl").orEmpty(),
                            sessionCookie = call.argument<String>("sessionCookie").orEmpty(),
                            agentId = call.argument<String>("agentId").orEmpty(),
                            deviceId = call.argument<String>("deviceId").orEmpty(),
                            kinds = call.argument<List<String>>("kinds").orEmpty(),
                        ),
                    )
                    result.success(null)
                }
                "syncNow" -> activity.lifecycleScope.launch {
                    result.success(withContext(Dispatchers.IO) { DeviceSyncRunner(context).run() })
                }
                "status" -> result.success(DeviceSyncRunner(context).status())
                else -> result.notImplemented()
            }
        }
    }
}
