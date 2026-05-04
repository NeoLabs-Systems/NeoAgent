package com.neoagent.flutter_app.auto

import android.content.Intent
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.content.ComponentName
import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import androidx.car.app.validation.HostValidator
import androidx.core.graphics.drawable.IconCompat
import com.neoagent.flutter_app.MainActivity
import com.neoagent.flutter_app.R
import com.neoagent.flutter_app.widgets.VoiceLaunchWidgetProvider
import com.neoagent.flutter_app.telecom.NeoAgentConnectionService

class NeoAgentCarAppService : CarAppService() {
    override fun onCreateSession(): Session = NeoAgentCarSession()

    override fun createHostValidator(): HostValidator {
        val debuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        return if (debuggable) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(this)
                .addAllowedHosts(R.array.hosts_allowlist)
                .build()
        }
    }
}

private class NeoAgentCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        return NeoAgentCarHomeScreen(carContext)
    }
}

private class NeoAgentCarHomeScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val voiceItem = GridItem.Builder()
            .setTitle("Voice mode")
            .setText("Tap to talk")
            .setImage(
                CarIcon.Builder(
                    IconCompat.createWithResource(carContext, R.mipmap.ic_launcher),
                ).build(),
                GridItem.IMAGE_TYPE_ICON,
            )
            .setOnClickListener { launchVoiceAssistant() }
            .build()

        val grid = ItemList.Builder().addItem(voiceItem).build()
        val template = GridTemplate.Builder()
            .setTitle("NeoAgent")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(grid)

        if (carContext.carAppApiLevel >= 8) {
            template.setItemSize(GridTemplate.ITEM_SIZE_LARGE)
        }

        return template.build()
    }

    private fun launchVoiceAssistant() {
        try {
            val telecomManager = carContext.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            if (telecomManager == null) {
                CarToast.makeText(carContext, "Telecom service unavailable", CarToast.LENGTH_LONG).show()
                return
            }
            val componentName = ComponentName(carContext, NeoAgentConnectionService::class.java)
            val phoneAccountHandle = PhoneAccountHandle(componentName, "NeoAgentVoiceId")
            
            val phoneAccount = PhoneAccount.builder(phoneAccountHandle, "NeoAgent Voice Assistant")
                .setCapabilities(PhoneAccount.CAPABILITY_SELF_MANAGED)
                .build()
            
            telecomManager.registerPhoneAccount(phoneAccount)
            
            val extras = Bundle().apply {
                putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, phoneAccountHandle)
                // For proper routing:
                putInt(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, android.telecom.VideoProfile.STATE_AUDIO_ONLY)
            }
            
            telecomManager.placeCall(Uri.parse("tel:NeoAgent"), extras)
            
            CarToast.makeText(
                carContext,
                "Starting voice mode...",
                CarToast.LENGTH_SHORT,
            ).show()
        } catch (e: SecurityException) {
            CarToast.makeText(carContext, "Missing phone permission", CarToast.LENGTH_LONG).show()
        } catch (e: Exception) {
            CarToast.makeText(carContext, "Could not start call: ${e.message}", CarToast.LENGTH_LONG).show()
        }
    }
}
