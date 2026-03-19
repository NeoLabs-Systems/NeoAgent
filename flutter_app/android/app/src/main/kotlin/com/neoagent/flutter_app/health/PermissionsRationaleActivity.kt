package com.neoagent.flutter_app.health

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val content = TextView(this).apply {
            setBackgroundColor(Color.parseColor("#081317"))
            setTextColor(Color.parseColor("#F4F0E8"))
            textSize = 16f
            setPadding(40, 48, 40, 48)
            text = """
                NeoAgent Health Sync

                This Flutter app reads only the Health Connect data you explicitly grant and uploads it to your NeoAgent backend.

                Data types:
                - steps
                - heart rate
                - sleep sessions
                - exercise sessions
                - weight

                Purpose:
                - keep your NeoAgent server aware of recent health context
                - let the app sync that context on demand without the old notification workflow

                You can revoke permissions at any time in Android's Health Connect settings.
            """.trimIndent()
        }

        setContentView(
            ScrollView(this).apply {
                setBackgroundColor(Color.parseColor("#081317"))
                addView(content)
            },
        )
    }
}
