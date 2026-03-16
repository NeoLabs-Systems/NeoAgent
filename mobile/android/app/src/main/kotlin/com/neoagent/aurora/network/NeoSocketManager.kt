package com.neoagent.aurora.network

import android.util.Log
import com.neoagent.aurora.settings.SettingsManager
import com.neoagent.aurora.ui.LogBuffer
import io.socket.client.IO
import io.socket.client.Socket
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject

private const val TAG = "NeoSocketManager"

enum class ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, RECONNECTING }

/** Callback interface for the service to receive typed events. */
interface RunEventListener {
    fun onEvent(event: RunEvent)
    fun onConnectionStateChanged(state: ConnectionState, detail: String? = null)
}

/**
 * Manages the Socket.IO connection to the NeoAgent backend.
 *
 * Auth flow:
 *   1. POST /api/auth/login  →  get session cookie
 *   2. Connect Socket.IO with the cookie as an extra header
 *   3. On disconnect, attempt re-authentication + reconnect with exponential backoff
 */
class NeoSocketManager(
    private val listener: RunEventListener,
    private val settings: SettingsManager,
    private val backendSessionClient: BackendSessionClient,
) {

    private var socket: Socket? = null
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private var reconnectJob: Job? = null

    // ── Public API ─────────────────────────────────────────────────────────

    fun connect() {
        reconnectJob?.cancel()
        reconnectJob = scope.launch { connectWithRetry() }
    }

    fun disconnect() {
        reconnectJob?.cancel()
        socket?.apply { off(); disconnect() }
        socket = null
        listener.onConnectionStateChanged(ConnectionState.DISCONNECTED)
    }

    val isConnected: Boolean get() = socket?.connected() == true

    // ── Internal ───────────────────────────────────────────────────────────

    private suspend fun connectWithRetry() {
        var backoffMs = 3_000L
        while (scope.isActive) {
            listener.onConnectionStateChanged(ConnectionState.CONNECTING)
            try {
                val cookie = backendSessionClient.getSessionCookie()
                setupSocket(cookie)
                return // success – event handlers drive the rest
            } catch (e: Exception) {
                Log.e(TAG, "Connection attempt failed: ${e.message}")
                listener.onConnectionStateChanged(ConnectionState.RECONNECTING, e.message)
                delay(backoffMs)
                backoffMs = minOf(backoffMs * 2, 60_000L)
            }
        }
    }

    private fun setupSocket(cookie: String) {
        socket?.apply { off(); disconnect() }

        val opts = IO.Options.builder()
            .setExtraHeaders(mapOf("Cookie" to listOf(cookie)))
            .setReconnection(false) // we manage reconnects ourselves for better auth handling
            .setTransports(arrayOf("websocket"))
            .setTimeout(20_000)
            .build()

        LogBuffer.info("⇄ Connecting to ${settings.backendUrl}")
        socket = IO.socket(settings.backendUrl, opts).apply {
            on(Socket.EVENT_CONNECT) {
                Log.i(TAG, "Socket connected ✓")
                LogBuffer.success("✓ Login OK")
                LogBuffer.success("✓ Socket connected")
                reconnectJob?.cancel()
                reconnectJob = null
                listener.onConnectionStateChanged(ConnectionState.CONNECTED)
            }

            on(Socket.EVENT_CONNECT_ERROR) { args ->
                val msg = args.firstOrNull()?.toString() ?: "unknown"
                Log.w(TAG, "Socket connect error: $msg")
                backendSessionClient.clearSession()
                LogBuffer.error("✗ WS error: $msg")
                listener.onConnectionStateChanged(ConnectionState.RECONNECTING, "WS: $msg")
                scheduleReconnect()
            }

            on(Socket.EVENT_DISCONNECT) { args ->
                val reason = args.firstOrNull()?.toString() ?: "unknown"
                Log.w(TAG, "Socket disconnected: $reason")
                backendSessionClient.clearSession()
                scheduleReconnect()
            }

            registerRunEvents(this)
            connect()
        }
    }

    private fun scheduleReconnect() {
        if (reconnectJob?.isActive == true) return
        listener.onConnectionStateChanged(ConnectionState.RECONNECTING)
        reconnectJob = scope.launch {
            delay(5_000)
            connectWithRetry()
        }
    }

    // ── Event wiring ───────────────────────────────────────────────────────

    private fun registerRunEvents(s: Socket) {
        s.on("run:start") { args ->
            parseJson(args) { j ->
                RunEvent.Start(
                    runId = j.getString("runId"),
                    title = j.optString("title", "Aurora task"),
                    model = j.optString("model", ""),
                    triggerType = j.optString("triggerType").takeIf { it.isNotBlank() },
                    triggerSource = j.optString("triggerSource").takeIf { it.isNotBlank() },
                )
            }
        }

        s.on("run:thinking") { args ->
            parseJson(args) { j ->
                RunEvent.Thinking(
                    runId = j.getString("runId"),
                    iteration = j.optInt("iteration", 1),
                )
            }
        }

        s.on("run:stream") { args ->
            parseJson(args) { j ->
                RunEvent.Stream(
                    runId = j.getString("runId"),
                    content = j.optString("content", ""),
                    iteration = j.optInt("iteration", 1),
                )
            }
        }

        s.on("run:tool_start") { args ->
            parseJson(args) { j ->
                RunEvent.ToolStart(
                    runId = j.getString("runId"),
                    tool = j.optString("tool", "tool"),
                    input = j.optString("input", "{}"),
                    iteration = j.optInt("iteration", 1),
                )
            }
        }

        s.on("run:tool_end") { args ->
            parseJson(args) { j ->
                RunEvent.ToolEnd(
                    runId = j.getString("runId"),
                    tool = j.optString("tool", "tool"),
                    result = j.optString("result").takeIf { it.isNotBlank() },
                    error = j.optString("error").takeIf { it.isNotBlank() },
                    durationMs = j.optLong("durationMs", 0),
                    iteration = j.optInt("iteration", 1),
                )
            }
        }

        s.on("run:interim") { args ->
            parseJson(args) { j ->
                RunEvent.Interim(
                    runId = j.getString("runId"),
                    message = j.optString("message", ""),
                )
            }
        }

        s.on("run:complete") { args ->
            parseJson(args) { j ->
                RunEvent.Complete(
                    runId = j.getString("runId"),
                    content = j.optString("content", ""),
                    totalTokens = j.optInt("totalTokens", 0),
                    iterations = j.optInt("iterations", 1),
                )
            }
        }

        s.on("run:error") { args ->
            parseJson(args) { j ->
                RunEvent.Error(
                    runId = j.getString("runId"),
                    error = j.optString("error", "Unknown error"),
                )
            }
        }
    }

    /**
     * Parses the first arg as a JSONObject, calls [block] to build a RunEvent,
     * then dispatches it. All exceptions are caught and logged.
     */
    private inline fun parseJson(args: Array<Any>, crossinline block: (JSONObject) -> RunEvent) {
        try {
            val json = args.getOrNull(0) as? JSONObject ?: return
            listener.onEvent(block(json))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse event: ${e.message}")
        }
    }
}
