package com.apprch.app.widget

import android.content.Context
import com.apprch.app.model.TaskAccent
import com.apprch.app.model.startOfDay
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

data class WidgetTriggerSnapshot(
    val id: String,
    val name: String,
    val icon: String,
    val accentColorHex: String,
    val countsByDay: Map<String, Int>,
    val yearTotal: Int,
    val todayCount: Int
)

object WidgetSnapshotStore {
    private const val PREFS = "apprch.widget"
    private const val SNAPSHOTS = "snapshots"
    const val PREFERRED_TRIGGER = "preferredTriggerId"
    private const val PENDING_PIN = "pendingPinTriggerId"
    private const val PENDING_PIN_AT = "pendingPinAt"

    val dayKeyFormatter: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = java.util.TimeZone.getDefault()
        }

    fun load(context: Context): List<WidgetTriggerSnapshot> {
        val raw = prefs(context).getString(SNAPSHOTS, null) ?: return emptyList()
        return runCatching { decode(raw) }.getOrDefault(emptyList())
    }

    fun save(context: Context, triggers: List<WidgetTriggerSnapshot>) {
        prefs(context).edit().putString(SNAPSHOTS, encode(triggers)).apply()
    }

    fun upsert(context: Context, snapshot: WidgetTriggerSnapshot) {
        val next = load(context).toMutableList()
        val index = next.indexOfFirst { it.id == snapshot.id }
        if (index >= 0) next[index] = snapshot else next += snapshot
        save(context, next)
    }

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(SNAPSHOTS)
            .remove(PREFERRED_TRIGGER)
            .remove(PENDING_PIN)
            .apply()
    }

    fun snapshot(context: Context, id: String?): WidgetTriggerSnapshot? {
        val triggers = load(context)
        if (id != null) triggers.firstOrNull { it.id == id }?.let { return it }
        preferredTriggerId(context)?.let { preferred ->
            triggers.firstOrNull { it.id == preferred }?.let { return it }
        }
        return triggers.firstOrNull()
    }

    fun preferredTriggerId(context: Context): String? =
        prefs(context).getString(PREFERRED_TRIGGER, null)

    fun setPreferredTriggerId(context: Context, id: String?) {
        prefs(context).edit().putString(PREFERRED_TRIGGER, id).apply()
    }

    fun markPendingPin(context: Context, triggerId: String) {
        setPreferredTriggerId(context, triggerId)
        prefs(context).edit()
            .putString(PENDING_PIN, triggerId)
            .putLong(PENDING_PIN_AT, System.currentTimeMillis())
            .apply()
    }

    fun widgetTrigger(context: Context, appWidgetId: Int): String? {
        if (appWidgetId == 0) return preferredTriggerId(context)
        return prefs(context).getString(widgetKey(appWidgetId), null) ?: preferredTriggerId(context)
    }

    fun setWidgetTrigger(context: Context, appWidgetId: Int, triggerId: String) {
        prefs(context).edit()
            .putString(widgetKey(appWidgetId), triggerId)
            .putString(PREFERRED_TRIGGER, triggerId)
            .apply()
    }

    private fun widgetKey(appWidgetId: Int) = "widget.$appWidgetId"

    fun consumePendingPin(context: Context): String? {
        val stored = prefs(context)
        val id = stored.getString(PENDING_PIN, null) ?: return null
        val at = stored.getLong(PENDING_PIN_AT, 0L)
        stored.edit().remove(PENDING_PIN).remove(PENDING_PIN_AT).apply()
        return id.takeIf { System.currentTimeMillis() - at < 120_000L }
    }

    fun make(
        id: String,
        name: String,
        icon: String,
        accentColorHex: String?,
        dates: List<Date>,
        now: Date = Date()
    ): WidgetTriggerSnapshot {
        val today = startOfDay(now)
        val yearAgo = Calendar.getInstance().apply {
            time = today
            add(Calendar.DAY_OF_YEAR, -370)
        }.time
        val counts = mutableMapOf<String, Int>()
        var yearTotal = 0
        var todayCount = 0
        val formatter = dayKeyFormatter
        for (date in dates) {
            val day = startOfDay(date)
            if (day.time == today.time) todayCount += 1
            if (day.before(yearAgo)) continue
            val key = formatter.format(day)
            counts[key] = (counts[key] ?: 0) + 1
            yearTotal += 1
        }
        return WidgetTriggerSnapshot(
            id = id,
            name = name,
            icon = icon,
            accentColorHex = accentColorHex ?: TaskAccent.fallbackHex,
            countsByDay = counts,
            yearTotal = yearTotal,
            todayCount = todayCount
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun encode(triggers: List<WidgetTriggerSnapshot>): String {
        val array = JSONArray()
        triggers.forEach { trigger ->
            array.put(
                JSONObject().apply {
                    put("id", trigger.id)
                    put("name", trigger.name)
                    put("icon", trigger.icon)
                    put("accentColorHex", trigger.accentColorHex)
                    put("yearTotal", trigger.yearTotal)
                    put("todayCount", trigger.todayCount)
                    put("countsByDay", JSONObject().apply {
                        trigger.countsByDay.forEach { (key, value) -> put(key, value) }
                    })
                }
            )
        }
        return JSONObject().put("tasks", array).toString()
    }

    private fun decode(raw: String): List<WidgetTriggerSnapshot> {
        val json = JSONObject(raw)
        val array = json.optJSONArray("tasks") ?: json.optJSONArray("triggers") ?: return emptyList()
        return buildList {
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val countsObj = obj.optJSONObject("countsByDay") ?: JSONObject()
                val counts = mutableMapOf<String, Int>()
                countsObj.keys().forEach { key -> counts[key] = countsObj.optInt(key) }
                add(
                    WidgetTriggerSnapshot(
                        id = obj.getString("id"),
                        name = obj.getString("name"),
                        icon = obj.optString("icon"),
                        accentColorHex = obj.optString("accentColorHex", TaskAccent.fallbackHex),
                        countsByDay = counts,
                        yearTotal = obj.optInt("yearTotal"),
                        todayCount = obj.optInt("todayCount")
                    )
                )
            }
        }
    }
}
