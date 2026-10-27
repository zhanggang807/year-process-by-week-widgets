package com.local.yearprogress.app

import android.content.Context
import com.local.yearprogress.core.HolidayDay
import com.local.yearprogress.core.HolidayTable
import java.time.LocalDate
import org.json.JSONObject

object HolidayRepository {
    fun load(context: Context, year: Int): HolidayTable {
        val official = runCatching {
            context.assets.open("holidays/$year.json").bufferedReader().use { it.readText() }
        }.getOrNull()

        return official?.let {
            runCatching { parseHolidayJson(it, year) }.getOrNull()
        } ?: HolidayTable.statutory(year)
    }

    internal fun parseHolidayJson(jsonText: String, expectedYear: Int): HolidayTable {
        val root = JSONObject(jsonText)
        require(root.getInt("year") == expectedYear) {
            "Holiday file year mismatch: expected $expectedYear"
        }
        val rawDays = root.getJSONArray("days")
        val dates = buildList {
            repeat(rawDays.length()) { index ->
                val day = rawDays.getJSONObject(index)
                if (!day.optBoolean("isOffDay", false)) return@repeat
                val name = day.optString("name").trim()
                if (name.isEmpty()) return@repeat
                val date = LocalDate.parse(day.getString("date"))
                if (date.year == expectedYear) {
                    add(HolidayDay(date, name))
                }
            }
        }.distinctBy { it.date }

        require(dates.size >= 5) { "Official holiday file has too few days off" }
        return HolidayTable(expectedYear, dates)
    }
}
