package com.neoagent.flutter_app.telecom

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.telecom.TelecomManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class NeoAgentConnection(private val context: Context) : Connection() {
    private var flutterEngine: FlutterEngine? = null
    var isFlutterInitiated: Boolean = false
    private var voiceHeadlessStarted: Boolean = false
    private var speakerRequested = false
    private var initialRouteSettled = false

    // Held while the call plays through the earpiece, so the screen goes dark
    // and ignores touches at the ear, as in the phone's own calls.
    private val proximityLock: PowerManager.WakeLock? =
        (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .takeIf { it.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK) }
            ?.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "neoagent:call-proximity")
            ?.apply { setReferenceCounted(false) }

    init {
        audioModeIsVoip = true
        setAddress(Uri.parse("tel:NeoAgent"), TelecomManager.PRESENTATION_ALLOWED)
        setCallerDisplayName("NeoAgent", TelecomManager.PRESENTATION_ALLOWED)
        connectionProperties = PROPERTY_SELF_MANAGED
        connectionCapabilities = CAPABILITY_MUTE or CAPABILITY_HOLD
    }

    override fun onAnswer() {
        setActive()
        startVoiceAssistantHeadless()
    }

    override fun onAnswer(videoState: Int) {
        onAnswer()
    }

    override fun onReject() {
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
        destroy()
        cleanup()
    }

    override fun onAbort() {
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
        destroy()
        cleanup()
    }

    override fun onDisconnect() {
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
        cleanup()
    }

    override fun onStateChanged(state: Int) {
        super.onStateChanged(state)
        if (state == STATE_ACTIVE) {
            @Suppress("DEPRECATION")
            onCallAudioStateChanged(callAudioState)
            startVoiceAssistantHeadless()
        } else if (state == STATE_DISCONNECTED) {
            cleanup()
        }
    }

    // Deprecated in API 34 for onCallEndpointChanged, but still delivered.
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onCallAudioStateChanged(state: CallAudioState?) {
        if (state == null || this.state != STATE_ACTIVE) return
        settleInitialRoute(state)
        val atEar = state.route == CallAudioState.ROUTE_EARPIECE
        proximityLock?.let { lock ->
            if (atEar && !lock.isHeld) lock.acquire()
            if (!atEar && lock.isHeld) lock.release()
        }
    }

    /** The call screen's speaker button. */
    fun setSpeaker(on: Boolean) {
        speakerRequested = on
        @Suppress("DEPRECATION")
        setAudioRoute(if (on) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_WIRED_OR_EARPIECE)
    }

    // A call starts at the ear, like the phone's own; a headset or car that
    // Telecom routed it to stays.
    private fun settleInitialRoute(state: CallAudioState) {
        if (initialRouteSettled) return
        initialRouteSettled = true
        val earpiece = (state.supportedRouteMask and CallAudioState.ROUTE_EARPIECE) != 0
        if (state.route == CallAudioState.ROUTE_SPEAKER && earpiece && !speakerRequested) {
            @Suppress("DEPRECATION")
            setAudioRoute(CallAudioState.ROUTE_WIRED_OR_EARPIECE)
        }
    }

    private fun startVoiceAssistantHeadless() {
        // Flutter placed this call and is already driving the voice session; pinging it
        // again would restart (and cancel) the turn it is in the middle of.
        if (isFlutterInitiated) return
        if (voiceHeadlessStarted) return
        voiceHeadlessStarted = true

        // Wait a slight moment for audio routing to settle before capturing mic
        Handler(Looper.getMainLooper()).postDelayed({
            // Check if there is already an active engine to avoid duplicating connections
            val existingEngine = FlutterEngineCache.getInstance().get("main_engine")

            if (existingEngine != null) {
                // If engine exists (app is in background), we can just trigger it via method channel
                flutterEngine = existingEngine
            } else {
                // Spawn headless engine
                flutterEngine = FlutterEngine(context.applicationContext)
                flutterEngine?.dartExecutor?.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )
            }

            notifyDart("startVoiceMode")
        }, 500)
    }

    private fun notifyDart(method: String) {
        val messenger = (flutterEngine ?: FlutterEngineCache.getInstance().get("main_engine"))
            ?.dartExecutor
            ?.binaryMessenger
            ?: return
        Handler(Looper.getMainLooper()).post {
            MethodChannel(messenger, "neoagent/car_auto").invokeMethod(method, null)
        }
    }

    private fun cleanup() {
        proximityLock?.takeIf { it.isHeld }?.release()
        // Only calls we started on Dart's behalf need to be torn down from here. When
        // Flutter placed the call it stops capture itself, and a stop signal at this
        // point would discard the turn it is committing.
        if (voiceHeadlessStarted) {
            voiceHeadlessStarted = false
            notifyDart("stopVoiceMode")
        }

        NeoAgentConnectionService.getAndClearCurrentConnection()
        
        // We only destroy the engine if we created it headless and we want to clean up.
        // For simplicity and reusing existing state, we can leave it running 
        // to handle the end-of-call cleanly on the dart side.
    }
}
