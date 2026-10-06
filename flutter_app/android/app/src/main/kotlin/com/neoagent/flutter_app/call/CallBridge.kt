package com.neoagent.flutter_app.call

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.WindowManager
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of agent calls: the phone's ringtone and vibration, showing the
 * call screen over the lock screen, bringing the app forward from the
 * background, the permissions that allow it, and the speakerphone.
 */
class CallBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "neoagent/call"
        private val VIBRATION_PATTERN = longArrayOf(0, 800, 600, 800, 1600)

        fun register(messenger: BinaryMessenger, activity: Activity): CallBridge {
            val bridge = CallBridge(activity)
            MethodChannel(messenger, CHANNEL).setMethodCallHandler(bridge)
            return bridge
        }
    }

    private var ringtone: Ringtone? = null
    private var presenting = false

    /**
     * The user sent the app away (home, recents, another app). Locking the
     * phone or a dialog over the app also stops it, but leaves this false:
     * the app is still the user's foreground task then.
     */
    var leftByUser = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissionStatus" -> result.success(
                mapOf(
                    "overlay" to Settings.canDrawOverlays(activity),
                    "fullScreenIntent" to canUseFullScreenIntent(),
                    "unrestrictedBattery" to isIgnoringBatteryOptimizations(),
                ),
            )
            "openOverlaySettings" -> {
                openSettings(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                )
                result.success(null)
            }
            "openFullScreenIntentSettings" -> {
                if (Build.VERSION.SDK_INT >= 34) {
                    openSettings(
                        Intent(
                            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                            Uri.parse("package:${activity.packageName}"),
                        ),
                    )
                }
                result.success(null)
            }
            "requestUnrestrictedBattery" -> {
                // Keeps the background connection that calls arrive on alive.
                openSettings(
                    Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                )
                result.success(null)
            }
            "startRinging" -> {
                startRinging()
                result.success(null)
            }
            "stopRinging" -> {
                stopRinging()
                result.success(null)
            }
            "present" -> result.success(present())
            "setSpeakerphone" -> {
                setSpeakerphone(call.argument<Boolean>("on") == true)
                result.success(null)
            }
            "dismiss" -> {
                dismiss(call.argument<Boolean>("moveToBack") == true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun release() {
        stopRinging()
        setSpeakerphone(false)
    }

    private fun setSpeakerphone(on: Boolean) {
        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!on) {
                audio.clearCommunicationDevice()
                return
            }
            audio.availableCommunicationDevices
                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                ?.let { audio.setCommunicationDevice(it) }
        } else {
            @Suppress("DEPRECATION")
            audio.isSpeakerphoneOn = on
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val manager = activity.getSystemService(NotificationManager::class.java)
        return manager?.canUseFullScreenIntent() ?: false
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(activity.packageName)
    }

    private fun openSettings(intent: Intent) {
        try {
            activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
            activity.startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${activity.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    // Follows the phone's ringer mode, like a real call: ring and vibrate,
    // vibrate only, or stay silent.
    private fun startRinging() {
        stopRinging()
        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val mode = audio.ringerMode
        if (mode == AudioManager.RINGER_MODE_NORMAL) {
            val uri = RingtoneManager.getActualDefaultRingtoneUri(activity, RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(activity, uri)?.apply {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isLooping = true
                play()
            }
        }
        if (mode != AudioManager.RINGER_MODE_SILENT) {
            vibrator()?.vibrate(VibrationEffect.createWaveform(VIBRATION_PATTERN, 0))
        }
    }

    private fun stopRinging() {
        ringtone?.stop()
        ringtone = null
        vibrator()?.cancel()
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (activity.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            activity.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    /**
     * Shows the app over the lock screen and brings it forward. Returns
     * whether it was in the background, so the caller can send it back
     * once the call is declined.
     */
    private fun present(): Boolean {
        val resumed = (activity as LifecycleOwner).lifecycle.currentState
            .isAtLeast(Lifecycle.State.RESUMED)
        presenting = true
        setShowOverLockScreen(true)
        if (!resumed) {
            activity.startActivity(
                Intent(activity, activity.javaClass).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
            )
        }
        return !resumed && leftByUser
    }

    private fun dismiss(moveToBack: Boolean) {
        stopRinging()
        if (!presenting) return
        presenting = false
        setShowOverLockScreen(false)
        if (moveToBack) {
            activity.moveTaskToBack(true)
            leftByUser = true
        }
    }

    private fun setShowOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(show)
            activity.setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) activity.window.addFlags(flags) else activity.window.clearFlags(flags)
        }
    }
}
