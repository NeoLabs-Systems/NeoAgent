package com.neoagent.flutter_app

import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import com.neoagent.flutter_app.health.HealthConnectGateway
import com.neoagent.flutter_app.health.HealthSyncScheduler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Instant

class MainActivity : FlutterFragmentActivity() {

    private lateinit var healthGateway: HealthConnectGateway
    private lateinit var healthSyncScheduler: HealthSyncScheduler
    private lateinit var permissionLauncher: ActivityResultLauncher<Set<String>>
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        healthGateway = HealthConnectGateway(this)
        healthSyncScheduler = HealthSyncScheduler(this)
        permissionLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) {
            val pending = pendingPermissionResult
            pendingPermissionResult = null
            lifecycleScope.launch {
                pending?.success(buildStatusMap())
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neoagent/health",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> lifecycleScope.launch {
                    result.success(buildStatusMap())
                }

                "requestPermissions" -> lifecycleScope.launch {
                    val client = healthGateway.getClientOrNull()
                    if (client == null) {
                        result.error(
                            "health_unavailable",
                            "Health Connect is unavailable on this device.",
                            null,
                        )
                        return@launch
                    }

                    pendingPermissionResult = result
                    permissionLauncher.launch(healthGateway.getRequestedPermissions(client))
                }

                "collectBatch" -> lifecycleScope.launch {
                    try {
                        val client = healthGateway.getClientOrNull()
                        if (client == null) {
                            result.error(
                                "health_unavailable",
                                "Health Connect is unavailable on this device.",
                                null,
                            )
                            return@launch
                        }

                        val required = healthGateway.getRequestedPermissions(client)
                        val granted = client.permissionController.getGrantedPermissions()
                        if (!granted.containsAll(required)) {
                            result.error(
                                "health_permissions",
                                "Grant Health Connect permissions before syncing.",
                                null,
                            )
                            return@launch
                        }

                        val args = call.arguments as? Map<*, *>
                        val windowStart = Instant.parse(args?.get("windowStart")?.toString())
                        val windowEnd = Instant.parse(args?.get("windowEnd")?.toString())
                        val payload = healthGateway.collectBatch(client, windowStart, windowEnd)
                        result.success(payload.toJson().toString())
                    } catch (err: Exception) {
                        result.error(
                            "health_sync_failed",
                            err.message ?: err.javaClass.simpleName,
                            null,
                        )
                    }
                }

                "configureBackgroundSync" -> {
                    val args = call.arguments as? Map<*, *>
                    val enabled = args?.get("enabled") == true
                    val backendUrl = args?.get("backendUrl")?.toString().orEmpty()
                    val sessionCookie = args?.get("sessionCookie")?.toString().orEmpty()
                    healthSyncScheduler.configure(
                        enabled = enabled,
                        backendUrl = backendUrl,
                        sessionCookie = sessionCookie,
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private suspend fun buildStatusMap(): Map<String, Any?> {
        val available = healthGateway.isAvailable()
        val client = healthGateway.getClientOrNull()
        val required = if (client != null) {
            healthGateway.getRequestedPermissions(client).toList()
        } else {
            emptyList()
        }
        val granted = if (client != null) {
            client.permissionController.getGrantedPermissions().toList()
        } else {
            emptyList()
        }

        val message = when {
            !available -> "Health Connect is unavailable on this device."
            !granted.containsAll(required) -> "Permissions are required for sync."
            else -> "Health sync is ready."
        }

        return mapOf(
            "available" to available,
            "permissionsGranted" to granted.containsAll(required),
            "requiredPermissions" to required,
            "grantedPermissions" to granted,
            "message" to message,
        )
    }
}
