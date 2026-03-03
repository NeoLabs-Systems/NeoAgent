package com.neoagent.aurora

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.SpannableStringBuilder
import android.text.style.ForegroundColorSpan
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.neoagent.aurora.network.ConnectionState
import com.neoagent.aurora.service.AuroraService
import com.neoagent.aurora.settings.SettingsManager
import com.neoagent.aurora.ui.LogBuffer
import com.neoagent.aurora.ui.LogEntry

class MainActivity : Activity() {

    private lateinit var settings: SettingsManager
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Views ────────────────────────────────────────────────────────────
    private lateinit var webView: WebView
    private lateinit var settingsPanel: View
    private lateinit var tabBrowser: TextView
    private lateinit var tabSettings: TextView
    private lateinit var statusDot: View
    private lateinit var statusLabel: TextView
    private lateinit var connStatusText: TextView
    private lateinit var connUrlText: TextView
    private lateinit var btnReconnect: Button
    private lateinit var inputUrl: EditText
    private lateinit var inputUsername: EditText
    private lateinit var inputPassword: EditText
    private lateinit var btnSave: Button
    private lateinit var btnClearLog: TextView
    private lateinit var logScrollView: ScrollView
    private lateinit var logText: TextView

    // ── Listeners (held so we can remove them in onPause) ────────────────
    private val logListener: (LogEntry) -> Unit = { entry ->
        mainHandler.post { appendLog(entry) }
    }
    private val stateListener: (ConnectionState) -> Unit = { state ->
        mainHandler.post { updateState(state) }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        settings = SettingsManager(this)

        webView        = findViewById(R.id.webView)
        settingsPanel  = findViewById(R.id.settingsPanel)
        tabBrowser     = findViewById(R.id.tabBrowser)
        tabSettings    = findViewById(R.id.tabSettings)
        statusDot      = findViewById(R.id.statusDot)
        statusLabel    = findViewById(R.id.statusLabel)
        connStatusText = findViewById(R.id.connStatusText)
        connUrlText    = findViewById(R.id.connUrlText)
        btnReconnect   = findViewById(R.id.btnReconnect)
        inputUrl       = findViewById(R.id.inputUrl)
        inputUsername  = findViewById(R.id.inputUsername)
        inputPassword  = findViewById(R.id.inputPassword)
        btnSave        = findViewById(R.id.btnSave)
        btnClearLog    = findViewById(R.id.btnClearLog)
        logScrollView  = findViewById(R.id.logScrollView)
        logText        = findViewById(R.id.logText)

        // Populate settings fields from persisted values
        inputUrl.setText(settings.backendUrl)
        inputUsername.setText(settings.username)
        inputPassword.setText(settings.password)

        btnReconnect.setOnClickListener { restartService() }
        btnSave.setOnClickListener      { saveAndReconnect() }
        btnClearLog.setOnClickListener  {
            logText.text = ""
            LogBuffer.clear()
        }

        // ── Tab switching ────────────────────────────────────────────
        tabBrowser.setOnClickListener  { showBrowserTab() }
        tabSettings.setOnClickListener { showSettingsTab() }

        // ── WebView setup ────────────────────────────────────────────
        @Suppress("SetJavaScriptEnabled")
        webView.settings.javaScriptEnabled    = true
        webView.settings.domStorageEnabled    = true
        webView.settings.loadWithOverviewMode = true
        webView.settings.useWideViewPort      = true
        webView.webViewClient    = WebViewClient()
        webView.webChromeClient  = WebChromeClient()
        webView.loadUrl(settings.backendUrl)

        // Request notification permission if needed
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 42)
        }

        // Ensure service is running
        AuroraService.start(this)
    }

    override fun onResume() {
        super.onResume()
        AuroraService.addStateListener(stateListener)
        LogBuffer.addListener(logListener)
        updateState(AuroraService.currentState)
        rebuildLog()
    }

    override fun onPause() {
        super.onPause()
        AuroraService.removeStateListener(stateListener)
        LogBuffer.removeListener(logListener)
    }

    // ── UI helpers ───────────────────────────────────────────────────────

    private fun updateState(state: ConnectionState) {
        val (dotColor, label, statusText) = when (state) {
            ConnectionState.CONNECTED    -> Triple(0xFF00E676.toInt(), "Connected",     "Connected")
            ConnectionState.CONNECTING   -> Triple(0xFFFFD740.toInt(), "Connecting…",   "Connecting…")
            ConnectionState.RECONNECTING -> Triple(0xFFFF9800.toInt(), "Reconnecting…", "Reconnecting…")
            ConnectionState.DISCONNECTED -> Triple(0xFF555577.toInt(), "Disconnected",  "Disconnected")
        }
        setDotColor(dotColor)
        statusLabel.text    = label
        connStatusText.text = statusText
        connUrlText.text    = settings.backendUrl
            .removePrefix("https://")
            .removePrefix("http://")
    }

    private fun setDotColor(argb: Int) {
        statusDot.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(argb)
        }
    }

    private fun rebuildLog() {
        val sb = SpannableStringBuilder()
        LogBuffer.entries.forEach { appendEntryToSpan(sb, it) }
        logText.text = sb
        scrollLogToBottom()
    }

    private fun appendLog(entry: LogEntry) {
        val sb = SpannableStringBuilder(logText.text)
        appendEntryToSpan(sb, entry)
        logText.text = sb
        scrollLogToBottom()
    }

    private fun appendEntryToSpan(sb: SpannableStringBuilder, entry: LogEntry) {
        val timeColor = Color.parseColor("#333355")
        val msgColor  = when (entry.level) {
            LogEntry.Level.SUCCESS -> Color.parseColor("#00C853")
            LogEntry.Level.ERROR   -> Color.parseColor("#FF5252")
            LogEntry.Level.WARN    -> Color.parseColor("#FFD740")
            LogEntry.Level.EVENT   -> Color.parseColor("#9575FF")
            LogEntry.Level.INFO    -> Color.parseColor("#AAAACC")
        }
        val t0 = sb.length
        sb.append(entry.timestamp)
        sb.setSpan(ForegroundColorSpan(timeColor), t0, sb.length, 0)
        sb.append("  ")
        val m0 = sb.length
        sb.append(entry.message)
        sb.setSpan(ForegroundColorSpan(msgColor), m0, sb.length, 0)
        sb.append("\n")
    }

    private fun scrollLogToBottom() {
        logScrollView.post { logScrollView.fullScroll(ScrollView.FOCUS_DOWN) }
    }

    // ── Actions ──────────────────────────────────────────────────────────

    private fun saveAndReconnect() {
        val url  = inputUrl.text.toString().trim()
        val user = inputUsername.text.toString().trim()
        val pass = inputPassword.text.toString()

        if (url.isEmpty() || user.isEmpty() || pass.isEmpty()) {
            Toast.makeText(this, "All fields are required", Toast.LENGTH_SHORT).show()
            return
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            Toast.makeText(this, "URL must start with http:// or https://", Toast.LENGTH_SHORT).show()
            return
        }

        settings.backendUrl = url
        settings.username   = user
        settings.password   = pass

        hideKeyboard()
        LogBuffer.info("⚙ Settings saved — reconnecting to $url")
        webView.loadUrl(url)  // also reload the embedded browser
        restartService()
    }

    private fun restartService() {
        AuroraService.stop(this)
        mainHandler.postDelayed({ AuroraService.start(this) }, 700)
    }

    // ── Tab helpers ──────────────────────────────────────────────────────

    private fun showBrowserTab() {
        webView.visibility       = View.VISIBLE
        settingsPanel.visibility = View.GONE
        tabBrowser.setTextColor(Color.parseColor("#7C4DFF"))
        tabBrowser.textStyle(bold = true)
        tabSettings.setTextColor(Color.parseColor("#555577"))
        tabSettings.textStyle(bold = false)
    }

    private fun showSettingsTab() {
        webView.visibility       = View.GONE
        settingsPanel.visibility = View.VISIBLE
        tabSettings.setTextColor(Color.parseColor("#7C4DFF"))
        tabSettings.textStyle(bold = true)
        tabBrowser.setTextColor(Color.parseColor("#555577"))
        tabBrowser.textStyle(bold = false)
    }

    private fun TextView.textStyle(bold: Boolean) {
        typeface = android.graphics.Typeface.create(
            android.graphics.Typeface.DEFAULT,
            if (bold) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL,
        )
    }

    private fun hideKeyboard() {
        val imm = getSystemService(InputMethodManager::class.java)
        currentFocus?.let { imm.hideSoftInputFromWindow(it.windowToken, 0) }
    }
}
