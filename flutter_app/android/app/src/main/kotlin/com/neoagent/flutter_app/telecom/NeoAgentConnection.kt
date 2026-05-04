package com.neoagent.flutter_app.telecom

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
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
            startVoiceAssistantHeadless()
        } else if (state == STATE_DISCONNECTED) {
            cleanup()
        }
    }

    private fun startVoiceAssistantHeadless() {
        if (voiceHeadlessStarted) return
        voiceHeadlessStarted = true
        if (flutterEngine != null) return

        // Wait a slight moment for audio routing to settle before capturing mic
        Handler(Looper.getMainLooper()).postDelayed({
            // Check if there is already an active engine to avoid duplicating connections
            var existingEngine = FlutterEngineCache.getInstance().get("main_engine")
            
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
            
            if (!isFlutterInitiated) {
                // To ensure the flutter side starts the LiveVoiceCapture session automatically
                // we should ideally notify it through a MethodChannel.
                // But since this is a headless connection, if we just initialize the engine,
                // we need to tell it to start voice mode.
                // We will invoke a method call to Dart.
                MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    "neoagent/car_auto"
                ).invokeMethod("startVoiceMode", null)
                isFlutterInitiated = true
            }

        }, 500)
    }

    private fun cleanup() {
        if (!isFlutterInitiated) {
            val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            if (messenger != null) {
                MethodChannel(
                    messenger,
                    "neoagent/car_auto"
                ).invokeMethod("stopVoiceMode", null)
            }
        }
        
        NeoAgentConnectionService.getAndClearCurrentConnection()
        
        // We only destroy the engine if we created it headless and we want to clean up.
        // For simplicity and reusing existing state, we can leave it running 
        // to handle the end-of-call cleanly on the dart side.
    }
}
