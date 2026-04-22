package com.neoagent.flutter_app.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.neoagent.flutter_app.R

class WidgetConfigActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val appWidgetId =
            intent?.extras?.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setResult(RESULT_CANCELED)

        val store = AiWidgetStore(this)
        val widgets = store.cachedWidgets().filter { it.id.isNotBlank() }

        val root =
            ScrollView(this).apply {
                setBackgroundColor(Color.parseColor("#0D1118"))
                isFillViewport = true
            }
        val content =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(20), dp(28), dp(20), dp(24))
            }
        root.addView(
            content,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        content.addView(
            textView(
                text = getString(R.string.widget_config_title),
                sizeSp = 28f,
                color = Color.WHITE,
                style = Typeface.BOLD,
            ),
        )
        content.addView(spacer(8))
        content.addView(
            textView(
                text = "Choose the widget you want to place on your home screen.",
                sizeSp = 15f,
                color = Color.parseColor("#A7B2C5"),
            ),
        )
        content.addView(spacer(22))

        if (widgets.isEmpty()) {
            content.addView(
                buildCard(
                    title = "No widgets available yet",
                    subtitle = getString(R.string.widget_config_empty_state),
                    meta = "Open NeoAgent and refresh widgets first",
                ) {},
            )
            setContentView(root)
            return
        }

        widgets.forEachIndexed { index, widget ->
            val cadence =
                if (widget.enabled) formatCadence(widget.refreshCron) else "Paused"
            val subtitle =
                widget.latestSnapshot?.optString("subtitle")
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
                    ?: if (widget.latestSnapshot == null) {
                        "Waiting for first update"
                    } else {
                        "Ready on home screen"
                    }
            val card =
                buildCard(
                    title = displayName(widget.name),
                    subtitle = subtitle,
                    meta = cadence,
                ) {
                    store.bindAppWidget(appWidgetId, widget.id)
                    AiHomeWidgetProvider.refreshAll(this)
                    val resultIntent =
                        Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    setResult(RESULT_OK, resultIntent)
                    finish()
                }
            content.addView(card)
            if (index < widgets.lastIndex) {
                content.addView(spacer(14))
            }
        }

        setContentView(root)
    }

    private fun buildCard(
        title: String,
        subtitle: String,
        meta: String,
        onClick: () -> Unit,
    ): View {
        val card =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(18), dp(18), dp(18), dp(18))
                background =
                    GradientDrawable().apply {
                        cornerRadius = dp(24).toFloat()
                        setColor(Color.parseColor("#171E29"))
                        setStroke(dp(1), Color.parseColor("#22FFFFFF"))
                    }
                isClickable = true
                isFocusable = true
                setOnClickListener { onClick() }
            }
        card.addView(
            textView(
                text = title,
                sizeSp = 20f,
                color = Color.WHITE,
                style = Typeface.BOLD,
            ),
        )
        card.addView(spacer(8))
        card.addView(
            textView(
                text = subtitle,
                sizeSp = 14f,
                color = Color.parseColor("#C7D0E0"),
            ),
        )
        card.addView(spacer(14))
        card.addView(
            textView(
                text = meta,
                sizeSp = 13f,
                color = Color.parseColor("#8FB8FF"),
                style = Typeface.BOLD,
            ),
        )
        return card
    }

    private fun textView(
        text: String,
        sizeSp: Float,
        color: Int,
        style: Int = Typeface.NORMAL,
    ): TextView {
        return TextView(this).apply {
            this.text = text
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
            setTextColor(color)
            setTypeface(typeface, style)
        }
    }

    private fun spacer(heightDp: Int): View =
        View(this).apply {
            layoutParams =
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(heightDp),
                )
        }

    private fun formatCadence(refreshCron: String): String {
        val normalized = refreshCron.trim()
        if (normalized == "0 * * * *") {
            return "Updates hourly"
        }
        val hours = Regex("\\*/(\\d+)").find(normalized)?.groupValues?.getOrNull(1)?.toIntOrNull()
        if (hours != null && hours > 1) {
            return "Every $hours hours"
        }
        return "Refreshes automatically"
    }

    private fun displayName(raw: String): String {
        val normalized =
            raw.trim()
                .replace(Regex("[_-]+"), " ")
                .replace(Regex("\\s+"), " ")
        if (normalized.isBlank()) {
            return "AI Widget"
        }
        return normalized.split(" ")
            .filter { it.isNotBlank() }
            .joinToString(" ") { part ->
                if (part.length <= 2 && part.uppercase() == part) {
                    part
                } else {
                    part.substring(0, 1).uppercase() + part.substring(1)
                }
            }
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics,
        ).toInt()
}
