package com.neoagent.flutter_app.devicesync

import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.provider.CalendarContract
import android.provider.ContactsContract
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.TimeZone

/** A string field, with JSON null and absent both read as blank. */
private fun JSONObject.text(key: String): String = if (isNull(key)) "" else optString(key).trim()

/** Reads and changes the calendars and contacts every account syncs to this phone. */
internal class DeviceDataGateway(private val context: Context) {
    private val resolver get() = context.contentResolver

    fun calendars(): JSONArray {
        val rows = JSONArray()
        resolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                CalendarContract.Calendars.ACCOUNT_NAME,
                CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
                CalendarContract.Calendars.IS_PRIMARY,
            ),
            "${CalendarContract.Calendars.VISIBLE} = 1",
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                rows.put(
                    JSONObject()
                        .put("id", cursor.getLong(0).toString())
                        .put("name", cursor.getString(1).orEmpty())
                        .put("account", cursor.getString(2).orEmpty())
                        .put("writable", cursor.getInt(3) >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR)
                        .put("primary", cursor.getInt(4) == 1),
                )
            }
        }
        return rows
    }

    /** One entry per occurrence, so repeating events need no expanding later. */
    fun events(windowStart: Instant, windowEnd: Instant): JSONArray {
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, windowStart.toEpochMilli())
            ContentUris.appendId(it, windowEnd.toEpochMilli())
        }.build()
        val rows = mutableListOf<JSONObject>()
        resolver.query(
            uri,
            arrayOf(
                CalendarContract.Instances.EVENT_ID,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.EVENT_LOCATION,
                CalendarContract.Instances.DESCRIPTION,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.CALENDAR_ID,
            ),
            "${CalendarContract.Instances.VISIBLE} = 1",
            null,
            "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val eventId = cursor.getLong(0).toString()
                val begin = cursor.getLong(1)
                rows.add(
                    JSONObject()
                        .put("key", "$eventId:$begin")
                        .put("eventId", eventId)
                        .put("start", Instant.ofEpochMilli(begin).toString())
                        .put("end", Instant.ofEpochMilli(cursor.getLong(2)).toString())
                        .put("title", cursor.getString(3).orEmpty())
                        .put("location", cursor.getString(4).orEmpty())
                        .put("notes", cursor.getString(5).orEmpty().take(2000))
                        .put("allDay", cursor.getInt(6) == 1)
                        .put("calendarId", cursor.getLong(7).toString()),
                )
            }
        }
        val attendees = attendeesByEvent(rows.map { it.getString("eventId") }.toSet())
        return JSONArray().also { array ->
            rows.forEach { row -> array.put(row.put("attendees", JSONArray(attendees[row.getString("eventId")].orEmpty()))) }
        }
    }

    private fun attendeesByEvent(eventIds: Set<String>): Map<String, List<String>> {
        val byEvent = mutableMapOf<String, MutableList<String>>()
        eventIds.chunked(500).forEach { chunk ->
            resolver.query(
                CalendarContract.Attendees.CONTENT_URI,
                arrayOf(
                    CalendarContract.Attendees.EVENT_ID,
                    CalendarContract.Attendees.ATTENDEE_NAME,
                    CalendarContract.Attendees.ATTENDEE_EMAIL,
                ),
                "${CalendarContract.Attendees.EVENT_ID} IN (${chunk.joinToString(",") { "?" }})",
                chunk.toTypedArray(),
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val name = cursor.getString(1).orEmpty()
                    val email = cursor.getString(2).orEmpty()
                    val label = if (name.isNotBlank() && email.isNotBlank()) "$name <$email>" else name.ifBlank { email }
                    if (label.isNotBlank()) byEvent.getOrPut(cursor.getLong(0).toString()) { mutableListOf() }.add(label)
                }
            }
        }
        return byEvent
    }

    fun contacts(): JSONArray {
        val byKey = linkedMapOf<String, JSONObject>()
        resolver.query(
            ContactsContract.Data.CONTENT_URI,
            arrayOf(
                ContactsContract.Data.LOOKUP_KEY,
                ContactsContract.Data.DISPLAY_NAME,
                ContactsContract.Data.MIMETYPE,
                ContactsContract.Data.DATA1,
            ),
            "${ContactsContract.Data.MIMETYPE} IN (?, ?, ?)",
            arrayOf(EMAIL_TYPE, PHONE_TYPE, ORGANIZATION_TYPE),
            "${ContactsContract.Data.DISPLAY_NAME} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val key = cursor.getString(0) ?: continue
                val contact = byKey.getOrPut(key) {
                    JSONObject()
                        .put("key", key)
                        .put("name", cursor.getString(1).orEmpty())
                        .put("emails", JSONArray())
                        .put("phones", JSONArray())
                }
                val value = cursor.getString(3)?.trim().orEmpty()
                if (value.isBlank()) continue
                when (cursor.getString(2)) {
                    EMAIL_TYPE -> contact.getJSONArray("emails").put(value)
                    PHONE_TYPE -> contact.getJSONArray("phones").put(value)
                    ORGANIZATION_TYPE -> contact.put("organization", value)
                }
            }
        }
        return JSONArray(byKey.values.filter { it.getString("name").isNotBlank() })
    }

    /** Makes one change the server queued and returns what to report back. */
    fun apply(action: String, payload: JSONObject): JSONObject = when (action) {
        "create_event" -> {
            val calendarId = payload.text("calendarId").ifBlank { defaultCalendarId() }
            val values = eventValues(payload).apply { put(CalendarContract.Events.CALENDAR_ID, calendarId.toLong()) }
            if (!values.containsKey(CalendarContract.Events.DTEND)) {
                values.put(CalendarContract.Events.DTEND, values.getAsLong(CalendarContract.Events.DTSTART))
            }
            val uri = resolver.insert(CalendarContract.Events.CONTENT_URI, values)
                ?: error("The calendar did not accept the event.")
            JSONObject().put("eventId", ContentUris.parseId(uri).toString()).put("calendarId", calendarId)
        }
        "update_event" -> {
            val eventId = payload.getString("eventId")
            val updated = resolver.update(eventUri(eventId), eventValues(payload), null, null)
            if (updated == 0) error("That event is no longer on the phone.")
            JSONObject().put("eventId", eventId)
        }
        "delete_event" -> {
            val eventId = payload.getString("eventId")
            if (resolver.delete(eventUri(eventId), null, null) == 0) error("That event is no longer on the phone.")
            JSONObject().put("eventId", eventId).put("deleted", true)
        }
        "create_contact" -> {
            createContact(payload)
            JSONObject().put("name", payload.getString("name")).put("created", true)
        }
        else -> error("This app version cannot $action.")
    }

    private fun eventUri(eventId: String) =
        ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId.toLong())

    private fun defaultCalendarId(): String {
        val all = calendars()
        val writable = (0 until all.length()).map { all.getJSONObject(it) }.filter { it.getBoolean("writable") }
        val calendar = writable.firstOrNull { it.getBoolean("primary") } ?: writable.firstOrNull()
            ?: error("No calendar on this phone can be written to.")
        return calendar.getString("id")
    }

    private fun eventValues(payload: JSONObject) = ContentValues().apply {
        val allDay = payload.optBoolean("allDay", false)
        if (payload.has("title")) put(CalendarContract.Events.TITLE, payload.text("title"))
        if (payload.has("location")) put(CalendarContract.Events.EVENT_LOCATION, payload.text("location"))
        if (payload.has("notes")) put(CalendarContract.Events.DESCRIPTION, payload.text("notes"))
        if (payload.has("start")) put(CalendarContract.Events.DTSTART, Instant.parse(payload.getString("start")).toEpochMilli())
        if (payload.has("end")) put(CalendarContract.Events.DTEND, Instant.parse(payload.getString("end")).toEpochMilli())
        if (payload.has("allDay")) put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
        if (payload.has("start") || payload.has("allDay")) {
            // Android keeps all-day events at UTC midnight.
            put(CalendarContract.Events.EVENT_TIMEZONE, if (allDay) "UTC" else TimeZone.getDefault().id)
        }
    }

    private fun createContact(payload: JSONObject) {
        val operations = arrayListOf(
            ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                .build(),
            dataRow(ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE, payload.getString("name")),
        )
        mapOf(EMAIL_TYPE to "email", PHONE_TYPE to "phone", ORGANIZATION_TYPE to "organization").forEach { (type, key) ->
            payload.text(key).takeIf { it.isNotBlank() }?.let { operations.add(dataRow(type, it)) }
        }
        resolver.applyBatch(ContactsContract.AUTHORITY, operations)
    }

    private fun dataRow(mimeType: String, value: String): ContentProviderOperation =
        ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
            .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
            .withValue(ContactsContract.Data.MIMETYPE, mimeType)
            .withValue(ContactsContract.Data.DATA1, value)
            .build()

    private companion object {
        const val EMAIL_TYPE = ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE
        const val PHONE_TYPE = ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
        const val ORGANIZATION_TYPE = ContactsContract.CommonDataKinds.Organization.CONTENT_ITEM_TYPE
    }
}
