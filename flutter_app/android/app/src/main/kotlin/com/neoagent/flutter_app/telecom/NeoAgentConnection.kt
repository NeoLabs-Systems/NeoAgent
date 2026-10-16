package com.neoagent.flutter_app.telecom

import android.content.Context
import android.net.Uri
import android.os.PowerManager
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.telecom.TelecomManager

class NeoAgentConnection(private val context: Context) : Connection() {
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

    private fun cleanup() {
        proximityLock?.takeIf { it.isHeld }?.release()
        NeoAgentConnectionService.getAndClearCurrentConnection()
    }
}
