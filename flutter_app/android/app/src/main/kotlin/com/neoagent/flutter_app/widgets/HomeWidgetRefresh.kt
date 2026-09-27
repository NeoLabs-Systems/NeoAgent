package com.neoagent.flutter_app.widgets

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.neoagent.flutter_app.R
import com.neoagent.flutter_app.net.BackendHttp
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Keeps the widgets current while the app is closed. Android freezes the app
 * soon after it leaves the screen, so the widgets read the agent's run list
 * from the server: every 15 minutes, and every minute while a run is under
 * way so its end shows up.
 */
internal object HomeWidgetRefresh {
    private const val PREFS_NAME = "neoagent_home_widget_session"
    private const val KEY_BACKEND_URL = "backend_url"
    private const val KEY_SESSION_COOKIE = "session_cookie"
    private const val KEY_AGENT_ID = "agent_id"
    private const val PERIODIC_WORK = "neoagent_widget_refresh"
    private const val FOLLOW_UP_WORK = "neoagent_widget_refresh_soon"

    /** How soon to look again while a run is under way. */
    const val UNDER_WAY_SECONDS = 60L

    internal class Session(val backendUrl: String, val cookie: String, val agentId: String)

    /** The app's sign-in, stored like health sync's; blank when signed out. */
    fun saveSession(context: Context, backendUrl: String, cookie: String, agentId: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_BACKEND_URL, backendUrl.trim())
            .putString(KEY_SESSION_COOKIE, cookie.trim())
            .putString(KEY_AGENT_ID, agentId.trim())
            .apply()
    }

    fun session(context: Context): Session? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val backendUrl = prefs.getString(KEY_BACKEND_URL, null).orEmpty()
        val cookie = prefs.getString(KEY_SESSION_COOKIE, null).orEmpty()
        if (backendUrl.isBlank() || cookie.isBlank()) return null
        return Session(backendUrl, cookie, prefs.getString(KEY_AGENT_ID, null).orEmpty())
    }

    /**
     * Refreshes only while a widget is placed and the app is signed in;
     * [refreshInSeconds] adds a one-off look on top of the periodic one.
     */
    fun sync(context: Context, refreshInSeconds: Long? = null) {
        val workManager = WorkManager.getInstance(context)
        if (!HomeWidgets.hasWidgets(context) || session(context) == null) {
            workManager.cancelUniqueWork(PERIODIC_WORK)
            workManager.cancelUniqueWork(FOLLOW_UP_WORK)
            return
        }
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        workManager.enqueueUniquePeriodicWork(
            PERIODIC_WORK,
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<HomeWidgetRefreshWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build(),
        )
        if (refreshInSeconds != null) {
            workManager.enqueueUniqueWork(
                FOLLOW_UP_WORK,
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<HomeWidgetRefreshWorker>()
                    .setInitialDelay(refreshInSeconds, TimeUnit.SECONDS)
                    .setConstraints(constraints)
                    .build(),
            )
        }
    }

    /**
     * The mood the run list stands for, newest run first: someone waiting on
     * you, then work in progress, then a run that ended in the last minutes.
     */
    fun moodFromRuns(runs: JSONArray?, nowMs: Long): Pair<HomeWidgetMood, String> {
        val list = (0 until (runs?.length() ?: 0)).mapNotNull { runs?.optJSONObject(it) }
        list.firstOrNull { it.optString("status") == "waiting_input" }
            ?.let { return HomeWidgetMood.WAITING to it.title() }
        list.firstOrNull { it.optString("status") == "running" }
            ?.let { return HomeWidgetMood.WORKING to it.title() }
        val latest = list.firstOrNull() ?: return HomeWidgetMood.IDLE to ""
        val endedAt = parseTimestamp(latest.optString("completed_at"))
        if (endedAt == null || nowMs - endedAt > RECENT_END_MS) {
            return HomeWidgetMood.IDLE to ""
        }
        return when (latest.optString("status")) {
            "completed" -> HomeWidgetMood.DONE to latest.title()
            "failed", "error" -> HomeWidgetMood.BLOCKED to latest.title()
            else -> HomeWidgetMood.IDLE to ""
        }
    }

    private const val RECENT_END_MS = 10 * 60 * 1000L

    private fun JSONObject.title() = optString("title").trim()

    /** SQLite writes `YYYY-MM-DD HH:MM:SS` in UTC. */
    private fun parseTimestamp(raw: String): Long? {
        if (raw.isBlank()) return null
        val iso = if (raw.contains('T')) raw else "${raw.replaceFirst(' ', 'T')}Z"
        return runCatching { Instant.parse(iso).toEpochMilli() }.getOrNull()
    }
}

class HomeWidgetRefreshWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val context = applicationContext
        val session = HomeWidgetRefresh.session(context) ?: return Result.success()
        if (HomeWidgetStatus.read(context)?.live == true) return Result.success()

        val agentQuery = if (session.agentId.isBlank()) {
            ""
        } else {
            "&agentId=${URLEncoder.encode(session.agentId, "UTF-8")}"
        }
        val response = try {
            BackendHttp.request("GET", session.backendUrl, "/api/agents?limit=10$agentQuery", session.cookie)
        } catch (err: IOException) {
            return Result.retry()
        }
        if (response.code == HttpURLConnection.HTTP_UNAUTHORIZED) {
            // The sign-in expired; the app stores a fresh one when it next runs.
            HomeWidgetRefresh.saveSession(context, session.backendUrl, "", session.agentId)
            publish(HomeWidgetMood.ASLEEP, context.getString(R.string.neoagent_widget_open_to_connect))
            HomeWidgetRefresh.sync(context)
            return Result.success()
        }
        if (response.code !in 200..299) return Result.retry()

        val runs = runCatching { JSONObject(response.body).optJSONArray("runs") }.getOrNull()
        val (mood, detail) = HomeWidgetRefresh.moodFromRuns(runs, System.currentTimeMillis())
        if (publish(mood, detail)) {
            HomeWidgetRefresh.sync(
                context,
                refreshInSeconds = HomeWidgetRefresh.UNDER_WAY_SECONDS.takeIf { mood.changesSoon },
            )
        }
        return Result.success()
    }

    private fun publish(mood: HomeWidgetMood, detail: String): Boolean {
        if (!HomeWidgetStatus.refresh(applicationContext, mood, detail)) return false
        HomeWidgets.refreshAll(applicationContext)
        return true
    }
}
