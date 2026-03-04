package com.neoagent.aurora.notification

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.Icon
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.getSystemService
import com.neoagent.aurora.R
import com.neoagent.aurora.network.RunEvent
import kotlin.math.abs

private const val TAG = "LiveUpdateManager"

/** Auto-cancel delay after a task completes or errors (ms). */
private const val COMPLETE_LINGER_MS = 8_000L

/** Auto-dismiss delay for the final result (EVENTS channel) notification (ms). */
private const val RESULT_LINGER_MS = 60_000L

/** Throttle for stream events — don't redraw more often than this (ms). */
private const val STREAM_THROTTLE_MS = 1_200L

/**
 * Creates and manages Android 16 Live Update (promoted ongoing) notifications.
 *
 * One notification per [RunEvent] runId. Uses [Notification.ProgressStyle] with
 * Aurora brand colours, a custom tracker icon, and coloured segments.
 *
 *  • Indeterminate  →  thinking / generating phase
 *  • Determinate    →  tool execution with iteration-based progress
 *  • 100 %          →  complete   (auto-cancelled after [COMPLETE_LINGER_MS])
 *  • Error state    →  error icon (auto-cancelled after [COMPLETE_LINGER_MS])
 */
class LiveUpdateManager(private val context: Context) {

    private val nm = context.getSystemService<NotificationManager>()!!
    private val handler = Handler(Looper.getMainLooper())

    /** runId → notificationId (only present once the first tool call fires) */
    private val activeNotifs = mutableMapOf<String, Int>()

    /** Runs that have started but haven't yet triggered a tool call.
     *  Notification is intentionally deferred until the first ToolStart. */
    private val pendingRuns = mutableSetOf<String>()

    /** runId → start timestamp (for chronometer) */
    private val startTimes = mutableMapOf<String, Long>()

    /** runId → last stream update timestamp */
    private val lastStreamUpdate = mutableMapOf<String, Long>()

    /** runId → last contentText (so we can carry it forward) */
    private val lastStatus = mutableMapOf<String, String>()

    /** runId → iteration count (heuristic for progress) */
    private val iterationCount = mutableMapOf<String, Int>()

    /** runId → display title (set once from [RunEvent.Start]) */
    private val titles = mutableMapOf<String, String>()

    /** runId → trigger source (for subText label) */
    private val triggerSources = mutableMapOf<String, String?>()

    // ── Aurora brand colours ────────────────────────────────────────────────
    private val VIOLET = Color.parseColor("#7C4DFF")
    private val CYAN   = Color.parseColor("#00BCD4")
    private val GREEN  = Color.parseColor("#00E676")
    private val RED    = Color.parseColor("#FF5252")
    private val AMBER  = Color.parseColor("#FFD740")

    // ── Public API ──────────────────────────────────────────────────────────

    fun handleEvent(event: RunEvent) {
        when (event) {
            is RunEvent.Start     -> onStart(event)
            is RunEvent.Thinking  -> onThinking(event)
            is RunEvent.Stream    -> onStream(event)
            is RunEvent.ToolStart -> onToolStart(event)
            is RunEvent.ToolEnd   -> onToolEnd(event)
            is RunEvent.Interim   -> onInterim(event)
            is RunEvent.Complete  -> onComplete(event)
            is RunEvent.Error     -> onError(event)
        }
    }

    fun cancelAll() {
        activeNotifs.keys.toList().forEach { cancel(it) }
    }

    // ── Event handlers ──────────────────────────────────────────────────────

    private fun onStart(e: RunEvent.Start) {
        // Record metadata but DON'T show a notification yet.
        // We wait until the first ToolStart so pure "Thinking…" phases
        // don't clutter the notification shade.
        startTimes[e.runId]     = System.currentTimeMillis()
        iterationCount[e.runId] = 0
        lastStatus[e.runId]     = "Starting…"
        triggerSources[e.runId] = e.triggerSource

        val title = e.title.take(60).ifBlank { "NeoAgent task" }
        titles[e.runId] = title
        pendingRuns.add(e.runId)

        Log.d(TAG, "Run ${e.runId} registered; notification deferred until first tool call")
    }

    private fun onThinking(e: RunEvent.Thinking) {
        // Only update if a notification is already visible (first tool already called)
        val notifId = activeNotifs[e.runId] ?: return
        iterationCount[e.runId] = e.iteration
        val status = if (e.iteration > 1) "Thinking… (step ${e.iteration})" else "Thinking…"
        lastStatus[e.runId] = status

        post(notifId, buildIndeterminate(
            runId  = e.runId,
            title  = titleFor(e.runId),
            status = status,
            chip   = null,
            color  = VIOLET,
        ))
    }

    private fun onStream(e: RunEvent.Stream) {
        // Only update if notification is already showing
        val notifId = activeNotifs[e.runId] ?: return

        // Throttle — streams fire very frequently, don't burn battery
        val now = System.currentTimeMillis()
        if ((now - (lastStreamUpdate[e.runId] ?: 0)) < STREAM_THROTTLE_MS) return
        lastStreamUpdate[e.runId] = now

        // Show a snippet of the streaming content as the status text
        val snippet = e.content.trimEnd().takeLast(120).trim()
        if (snippet.isBlank()) return
        lastStatus[e.runId] = snippet

        post(notifId, buildIndeterminate(
            runId  = e.runId,
            title  = titleFor(e.runId),
            status = snippet,
            chip   = null,
            color  = VIOLET,
        ))
    }

    private fun onToolStart(e: RunEvent.ToolStart) {
        // First tool call for this run? Activate the notification now.
        if (e.runId in pendingRuns) {
            activeNotifs[e.runId] = notifIdFor(e.runId)
            pendingRuns.remove(e.runId)
            Log.d(TAG, "First tool call for ${e.runId} — showing notification now")
        }
        val notifId = activeNotifs[e.runId] ?: return
        iterationCount[e.runId] = e.iteration

        val toolLabel   = friendlyToolName(e.tool)
        val inputSnip   = friendlyInput(e.tool, e.input)
        val status      = if (inputSnip.isNotEmpty()) "$toolLabel: $inputSnip" else "$toolLabel…"
        lastStatus[e.runId] = status

        val progress = coerceProgress(e.iteration, maxEstimate = 10)

        post(notifId, buildDeterminate(
            runId        = e.runId,
            title        = titleFor(e.runId),
            status       = status,
            progress     = progress,
            chip         = toolLabel.take(7),
            color        = CYAN,
            trackerResId = toolIconResId(e.tool),
        ))
    }

    private fun onToolEnd(e: RunEvent.ToolEnd) {
        val notifId = activeNotifs[e.runId] ?: return

        if (e.error != null) {
            // Tool error — pulse amber but don't fail the run yet
            val status = "⚠ ${e.tool} failed · retrying"
            lastStatus[e.runId] = status
            post(notifId, buildIndeterminate(
                runId  = e.runId,
                title  = titleFor(e.runId),
                status = status,
                chip   = "retry",
                color  = AMBER,
            ))
        } else {
            // Back to thinking after tool completes
            val status = lastStatus[e.runId] ?: "Working…"
            post(notifId, buildIndeterminate(
                runId  = e.runId,
                title  = titleFor(e.runId),
                status = status,
                chip   = null,
                color  = VIOLET,
            ))
        }
    }

    private fun onInterim(e: RunEvent.Interim) {
        val notifId = activeNotifs[e.runId] ?: return
        val status = e.message.take(120)
        lastStatus[e.runId] = status
        post(notifId, buildIndeterminate(
            runId  = e.runId,
            title  = titleFor(e.runId),
            status = status,
            chip   = null,
            color  = VIOLET,
        ))
    }

    private fun onComplete(e: RunEvent.Complete) {
        val notifId = activeNotifs[e.runId]

        // Update live update bar to 100% if the notification was ever shown
        val summary = e.content.trim().take(100).ifBlank { "Done" }
        if (notifId != null) {
            post(notifId, buildDeterminate(
                runId        = e.runId,
                title        = titleFor(e.runId),
                status       = summary,
                progress     = 100,
                chip         = "Done",
                color        = GREEN,
                trackerResId = R.drawable.ic_check,
            ))
            scheduleCancel(e.runId, COMPLETE_LINGER_MS)
        } else {
            pendingRuns.remove(e.runId)
            cleanupMetadata(e.runId)
        }

        // Always post a result summary to the EVENTS channel
        postResultNotification(
            title   = titleFor(e.runId),
            content = e.content.trim().ifBlank { "Task completed successfully." },
            success = true,
        )
        Log.d(TAG, "Run ${e.runId} complete")
    }

    private fun onError(e: RunEvent.Error) {
        val notifId = activeNotifs[e.runId]

        if (notifId != null) {
            post(notifId, buildDeterminate(
                runId        = e.runId,
                title        = titleFor(e.runId),
                status       = e.error.take(100),
                progress     = iterationCount[e.runId]?.let { coerceProgress(it, 10) } ?: 50,
                chip         = "Failed",
                color        = RED,
                trackerResId = R.drawable.ic_error,
            ))
            scheduleCancel(e.runId, COMPLETE_LINGER_MS)
        } else {
            pendingRuns.remove(e.runId)
            cleanupMetadata(e.runId)
        }

        // Always post an error summary to the EVENTS channel
        postResultNotification(
            title   = titleFor(e.runId),
            content = e.error.ifBlank { "Task failed." },
            success = false,
        )
        Log.d(TAG, "Run ${e.runId} errored: ${e.error}")
    }

    // ── Notification builders ───────────────────────────────────────────────

    /**
     * Builds an indeterminate Live Update notification (spinning bar).
     * Used during thinking / AI response generation.
     */
    private fun buildIndeterminate(
        runId: String,
        title: String,
        status: String,
        chip: String?,
        subText: String? = null,
        color: Int = VIOLET,
    ): Notification {
        val style = Notification.ProgressStyle()
            .setProgressIndeterminate(true)
            // A single coloured segment sets the hue of the indeterminate bar
            .addProgressSegment(
                Notification.ProgressStyle.Segment(100).setColor(color)
            )

        return baseBuilder(runId, title, status, chip, subText, color, style)
            .build()
    }

    /**
     * Builds a determinate Live Update notification with explicit progress.
     * Used during tool calls and on completion/error.
     */
    private fun buildDeterminate(
        runId: String,
        title: String,
        status: String,
        progress: Int,
        chip: String?,
        subText: String? = null,
        color: Int = VIOLET,
        trackerResId: Int = R.drawable.ic_notification,
    ): Notification {
        val style = Notification.ProgressStyle()
            .setProgress(progress)
            .setStyledByProgress(true)  // system dims the unfilled portion
            .setProgressTrackerIcon(Icon.createWithResource(context, trackerResId))
            .addProgressSegment(
                Notification.ProgressStyle.Segment(100).setColor(color)
            )

        return baseBuilder(runId, title, status, chip, subText, color, style)
            .build()
    }

    /** Common [Notification.Builder] configuration shared by all Live Updates. */
    private fun baseBuilder(
        runId: String,
        title: String,
        status: String,
        chip: String?,
        subText: String?,
        color: Int,
        style: Notification.ProgressStyle,
    ): Notification.Builder {
        val startTime = startTimes[runId] ?: System.currentTimeMillis()
        val sub = subText ?: triggerLabel(runId)

        return Notification.Builder(context, NotificationChannels.LIVE)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(color)
            .setOngoing(true)
            .setRequestPromotedOngoing(true)
            .setContentTitle(title)
            .setContentText(status)
            .apply { if (sub != null) setSubText(sub) }
            .setShortCriticalText(chip)
            .setWhen(startTime)
            .setUsesChronometer(chip == null)
            .setShowWhen(chip == null)
            .setStyle(style)
            .setOnlyAlertOnce(true)
            .setLocalOnly(true)
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Stable numeric notification ID derived from the runId string. */
    private fun notifIdFor(runId: String) = abs(runId.hashCode()) % 90_000 + 10_000

    /** Display title cached from the [RunEvent.Start] event. */
    private fun titleFor(runId: String): String = titles[runId] ?: "NeoAgent task"

    private fun cancel(runId: String) {
        pendingRuns.remove(runId)
        val id = activeNotifs.remove(runId) ?: return
        nm.cancel(id)
        cleanupMetadata(runId)
    }

    private fun cleanupMetadata(runId: String) {
        startTimes.remove(runId)
        lastStatus.remove(runId)
        lastStreamUpdate.remove(runId)
        iterationCount.remove(runId)
        titles.remove(runId)
        triggerSources.remove(runId)
    }

    private fun scheduleCancel(runId: String, delayMs: Long) {
        handler.postDelayed({ cancel(runId) }, delayMs)
    }

    private fun post(notifId: Int, notification: Notification) {
        try {
            nm.notify(notifId, notification)
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing POST_NOTIFICATIONS permission: ${e.message}")
        }
    }

    // ── Results notification (EVENTS channel) ──────────────────────────────

    /** Posts a BigText summary notification once a run completes or errors. */
    private fun postResultNotification(title: String, content: String, success: Boolean) {
        // Use a stable ID per title so results replace each other for the same task
        val id = abs(title.hashCode()) % 80_000 + 110_000
        try {
            nm.notify(id, Notification.Builder(context, NotificationChannels.EVENTS)
                .setSmallIcon(if (success) R.drawable.ic_check else R.drawable.ic_error)
                .setColor(if (success) GREEN else RED)
                .setContentTitle(title)
                .setContentText(content.take(100))
                .setStyle(Notification.BigTextStyle().bigText(content.take(500)))
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
                .setAutoCancel(true)
                .build())
            // Schedule auto-dismiss after ~1 minute
            handler.postDelayed({ try { nm.cancel(id) } catch (_: Exception) {} }, RESULT_LINGER_MS)
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing POST_NOTIFICATIONS permission: ${e.message}")
        }
    }

    /** Returns a human-readable subText label for the notification. */
    private fun triggerLabel(runId: String): String {
        val src = triggerSources[runId] ?: return "NeoAgent"
        return when {
            src.contains("whatsapp", ignoreCase = true) -> "NeoAgent · via WhatsApp"
            src.contains("web",      ignoreCase = true) -> "NeoAgent · via web"
            else                                        -> "NeoAgent"
        }
    }

    /**
     * Extracts a meaningful input snippet from a raw JSON tool-input string
     * without a full JSON parser (lightweight, used in notification status text).
     */
    private fun friendlyInput(tool: String, input: String): String {
        if (input.isBlank() || input == "{}") return ""
        val cleaned = input.removePrefix("{").removeSuffix("}")
            .replace("\\\"", "").replace("\"", "")
            .replace("\\n", " ").trim()
        // CLI: extract command value
        Regex("""(?:command|cmd)\s*:\s*(.+?)(?:,|$)""", RegexOption.IGNORE_CASE)
            .find(cleaned)?.groupValues?.get(1)?.trim()?.take(55)?.let { return it }
        // Browser / navigate: extract url
        Regex("""(?:url|navigate_to)\s*:\s*(\S+)""", RegexOption.IGNORE_CASE)
            .find(cleaned)?.groupValues?.get(1)?.trim()?.take(55)?.let { return it }
        // Files: extract path
        Regex("""(?:path|file(?:_path)?)\s*:\s*(.+?)(?:,|$)""", RegexOption.IGNORE_CASE)
            .find(cleaned)?.groupValues?.get(1)?.trim()?.take(55)?.let { return it }
        // Fallback: first 50 chars of cleaned JSON
        return cleaned.take(50).trim()
    }

    /** Returns an appropriate drawable resource ID for the tool's progress tracker icon. */
    private fun toolIconResId(tool: String): Int = when {
        tool.contains("cli",      ignoreCase = true) -> R.drawable.ic_tool
        tool.contains("bash",     ignoreCase = true) -> R.drawable.ic_tool
        tool.contains("browser",  ignoreCase = true) -> R.drawable.ic_notification
        tool.contains("navigate", ignoreCase = true) -> R.drawable.ic_notification
        tool.contains("check",    ignoreCase = true) -> R.drawable.ic_check
        else                                         -> R.drawable.ic_tool
    }

    /**
     * Maps tool names to short human-friendly labels (≤12 chars, ≤7 for chip).
     */
    private fun friendlyToolName(tool: String): String = when {
        tool.contains("cli", ignoreCase = true)     -> "Terminal"
        tool.contains("bash", ignoreCase = true)    -> "Terminal"
        tool.contains("browser", ignoreCase = true) -> "Browser"
        tool.contains("navigate", ignoreCase = true)-> "Browser"
        tool.contains("memory", ignoreCase = true)  -> "Memory"
        tool.contains("file", ignoreCase = true)    -> "Files"
        tool.contains("read", ignoreCase = true)    -> "Reading"
        tool.contains("write", ignoreCase = true)   -> "Writing"
        tool.contains("message", ignoreCase = true) -> "Message"
        tool.contains("send", ignoreCase = true)    -> "Sending"
        tool.contains("search", ignoreCase = true)  -> "Search"
        tool.contains("web", ignoreCase = true)     -> "Web"
        tool.contains("mcp", ignoreCase = true)     -> "MCP"
        tool.contains("docker", ignoreCase = true)  -> "Docker"
        tool.contains("skill", ignoreCase = true)   -> "Skill"
        else -> tool.replace("_", " ")
                    .split(" ")
                    .joinToString(" ") { it.take(1).uppercase() + it.drop(1) }
                    .take(12)
    }

    /**
     * Estimates 0-95 % progress based on iteration/maxEstimate so that the bar
     * never reaches 100 % until the run truly completes.
     */
    private fun coerceProgress(iteration: Int, maxEstimate: Int): Int =
        ((iteration.toFloat() / maxEstimate) * 95f).toInt().coerceIn(5, 95)
}
