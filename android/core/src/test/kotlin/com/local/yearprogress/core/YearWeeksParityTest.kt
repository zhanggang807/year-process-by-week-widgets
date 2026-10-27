package com.local.yearprogress.core

import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.WeekFields
import org.json.JSONObject
import kotlin.test.Test
import kotlin.test.assertEquals

class YearWeeksParityTest {
    private val spec = JSONObject(File("spec/year-weeks.json").readText())
    private val utc = ZoneId.of("UTC")

    @Test
    fun `all year boundaries match the shared spec`() {
        val years = spec.getJSONArray("years")
        repeat(years.length()) { i ->
            val expected = years.getJSONObject(i)
            val year = expected.getInt("year")
            val starts = YearWeeks.overlappingWeekStarts(year)

            assertEquals(expected.getInt("weeks"), starts.size, "week count for $year")
            assertEquals(
                LocalDate.parse(expected.getString("firstWeekStart")),
                starts.first(),
                "first week for $year",
            )
            assertEquals(
                LocalDate.parse(expected.getString("lastWeekStart")),
                starts.last(),
                "last week for $year",
            )
            assertEquals(
                LocalDate.parse(expected.getString("lastWeekEnd")),
                starts.last().plusDays(6),
                "last week end for $year",
            )
        }
    }

    @Test
    fun `all probe dates match week and ISO fields`() {
        val probes = spec.getJSONArray("probes")
        repeat(probes.length()) { i ->
            val expected = probes.getJSONObject(i)
            val date = LocalDate.parse(expected.getString("date"))
            val progress = YearWeeks.progress(date.atTime(12, 0).atZone(utc))
            val current = progress.currentWeek

            assertEquals(expected.getInt("year"), progress.year, "year at $date")
            assertEquals(expected.getInt("totalWeeks"), progress.totalWeeks, "total at $date")
            assertEquals(expected.getInt("weekIndex"), current?.index, "week index at $date")
            assertEquals(expected.getString("state"), "current")
            assertEquals(
                expected.getInt("isoWeekIndex"),
                date.get(WeekFields.ISO.weekOfWeekBasedYear()),
                "ISO week at $date",
            )
            assertEquals(
                expected.getInt("isoWeekYear"),
                date.get(WeekFields.ISO.weekBasedYear()),
                "ISO year at $date",
            )
        }
    }

    @Test
    fun `current fraction uses real elapsed duration across DST`() {
        val newYork = ZoneId.of("America/New_York")
        val endOfSpringForwardWeek = ZonedDateTime.of(2026, 3, 8, 23, 0, 0, 0, newYork)
        val progress = YearWeeks.progress(endOfSpringForwardWeek)
        val fraction = progress.weeks.first { it.start == LocalDate.of(2026, 3, 2) }.fraction
        // This week contains 167 real hours. At 23:00 local time on March 8,
        // 166 hours have elapsed even though six days and 23 wall-clock hours passed.
        assertEquals(166.0 / 167.0, fraction, 1e-9)
    }
}
