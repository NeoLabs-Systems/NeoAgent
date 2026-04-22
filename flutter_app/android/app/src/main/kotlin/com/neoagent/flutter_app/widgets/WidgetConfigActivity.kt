package com.neoagent.flutter_app.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.LinearLayout
import android.widget.ListView
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

        val container =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(32, 32, 32, 32)
            }
        val title =
            TextView(this).apply {
                text = getString(R.string.widget_config_title)
                textSize = 20f
            }
        container.addView(
            title,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = 20
            },
        )

        if (widgets.isEmpty()) {
            val empty =
                TextView(this).apply {
                    text = getString(R.string.widget_config_empty_state)
                    textSize = 15f
                    setPadding(0, 24, 0, 0)
                }
            container.addView(empty)
            setContentView(container)
            return
        }

        val labels =
            widgets.map { widget ->
                val status = if (widget.enabled) widget.refreshCron else "paused"
                "${widget.name}\n${widget.template} · ${widget.layoutVariant} · $status"
            }
        val listView = ListView(this)
        listView.setPadding(0, 12, 0, 12)
        listView.clipToPadding = false
        listView.dividerHeight = 10
        listView.adapter =
            ArrayAdapter(
                this,
                android.R.layout.simple_list_item_1,
                labels,
            )
        listView.setOnItemClickListener { _, _, position, _ ->
            val widget = widgets[position]
            store.bindAppWidget(appWidgetId, widget.id)
            AiHomeWidgetProvider.refreshAll(this)
            val resultIntent =
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultIntent)
            finish()
        }
        container.addView(
            listView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ),
        )
        setContentView(container)
    }
}
