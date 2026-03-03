package com.neoagent.aurora.ui

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CopyOnWriteArrayList

data class LogEntry(
    val timestamp: String,
    val level: Level,
    val message: String,
) {
    enum class Level { INFO, SUCCESS, WARN, ERROR, EVENT }
}

/**
 * In-memory circular log buffer shared between [AuroraService] and [MainActivity].
 *
 * Thread-safe: service writes from IO thread, activity reads/listens on main thread.
 */
object LogBuffer {

    private const val MAX = 300

    private val _entries  = ArrayDeque<LogEntry>()
    private val listeners = CopyOnWriteArrayList<(LogEntry) -> Unit>()
    private val fmt       = SimpleDateFormat("HH:mm:ss", Locale.getDefault())

    val entries: List<LogEntry>
        get() = synchronized(_entries) { ArrayList(_entries) }

    // ── Write helpers ────────────────────────────────────────────────────

    fun info(msg: String)    = add(LogEntry.Level.INFO,    msg)
    fun success(msg: String) = add(LogEntry.Level.SUCCESS, msg)
    fun warn(msg: String)    = add(LogEntry.Level.WARN,    msg)
    fun error(msg: String)   = add(LogEntry.Level.ERROR,   msg)
    fun event(msg: String)   = add(LogEntry.Level.EVENT,   msg)

    fun add(level: LogEntry.Level, msg: String) {
        val entry = LogEntry(fmt.format(Date()), level, msg)
        synchronized(_entries) {
            _entries.addLast(entry)
            if (_entries.size > MAX) _entries.removeFirst()
        }
        listeners.forEach { it(entry) }
    }

    fun clear() {
        synchronized(_entries) { _entries.clear() }
        listeners.forEach {
            it(LogEntry(fmt.format(Date()), LogEntry.Level.INFO, "─── log cleared ───"))
        }
    }

    // ── Listener registration (activity uses these) ──────────────────────

    fun addListener(l: (LogEntry) -> Unit)    = listeners.add(l)
    fun removeListener(l: (LogEntry) -> Unit) = listeners.remove(l)
}
