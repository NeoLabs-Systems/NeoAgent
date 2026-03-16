package com.neoagent.aurora.health

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView

/**
 * Minimal privacy-policy/rationale screen required by Health Connect permission flows.
 */
class PermissionsRationaleActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val content = TextView(this).apply {
            setBackgroundColor(Color.parseColor("#0D0D1A"))
            setTextColor(Color.parseColor("#EEEEEE"))
            textSize = 16f
            setPadding(40, 48, 40, 48)
            text = """
                NeoAgent Health Sync

                This feature reads health data that you explicitly grant through Health Connect and
                sends it to your configured NeoAgent backend.

                Data used:
                - steps
                - heart rate
                - sleep sessions
                - exercise sessions
                - weight

                Purpose:
                - keep your NeoAgent backend updated with the latest health context
                - run periodic background sync every 10 minutes while the app's foreground service is active

                NeoAgent only reads the data types you approve. You can revoke permissions at any time
                from Android's Health Connect settings.
            """.trimIndent()
        }

        setContentView(
            ScrollView(this).apply {
                setBackgroundColor(Color.parseColor("#0D0D1A"))
                addView(content)
            },
        )
    }
}
