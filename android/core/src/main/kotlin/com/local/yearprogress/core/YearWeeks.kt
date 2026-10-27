package com.local.yearprogress.core

import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.TemporalAdjusters
import java.time.temporal.WeekFields
import kotlin.math.roundToInt

enum class WeekState {
    PAST,
    CURRENT,
    FUTURE,
}

data class WeekCell(
    val index: Int,
    val start: LocalDate,
    val endExclusive: LocalDate,
    val state: WeekState,
    val fraction: Double,
    val holiday: String?,
    val rangeText: String,
) {
    val id: Int get() = index
}

data class YearProgress(
    val year: Int,
    val ganzhi: Ganzhi,
    val weeks: List<WeekCell>,
    val now: ZonedDateTime,
) {
    val totalWeeks: Int get() = weeks.size
    val pastCount: Int get() = weeks.count { it.state == WeekState.PAST }
    val currentWeek: WeekCell? get() = weeks.firstOrNull { it.state == WeekState.CURRENT }
    val remainingWeeks: Int get() = weeks.count { it.state == WeekState.FUTURE }

    val percent: Double
        get() {
            if (weeks.isEmpty()) return 0.0
            val done = pastCount + (currentWeek?.fraction ?: 0.0)
            return (done / totalWeeks * 100.0).coerceIn(0.0, 100.0)
        }

    val yearTitle: String get() = "${year}年"

    val subtitle: String
        get() {
            val current = currentWeek
            return if (current == null) {
                "${ganzhi.yearName} · 共 $totalWeeks 周"
            } else {
                "${ganzhi.yearName} · 第 ${current.index} 周 · 剩 $remainingWeeks 周"
            }
        }

    fun headerText(compact: Boolean = false): String {
        val p = percent.roundToInt()
        if (compact) {
            return "$year · ${ganzhi.name} · ${currentWeek?.index ?: totalWeeks} 周 · 剩 $remainingWeeks · $p%"
        }
        return "$yearTitle · ${ganzhi.yearName} · 第 ${currentWeek?.index ?: totalWeeks} 周 · 剩 $remainingWeeks 周 · 已过 $p%"
    }

    val accessibilitySummary: String
        get() = "$yearTitle，${ganzhi.yearName}，第 ${currentWeek?.index ?: totalWeeks} 周，" +
            "剩余 $remainingWeeks 周，已过 ${percent.roundToInt()}%"
}

object YearWeeks {
    fun overlappingWeekStarts(year: Int): List<LocalDate> {
        val yearStart = LocalDate.of(year, 1, 1)
        val nextYearStart = yearStart.plusYears(1)
        var start = yearStart.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        return buildList {
            while (start.isBefore(nextYearStart)) {
                add(start)
                start = start.plusWeeks(1)
            }
        }
    }

    fun weeksOverlapping(year: Int): Int = overlappingWeekStarts(year).size

    fun isoWeeksInYear(year: Int): Int {
        return LocalDate.of(year, 12, 28).get(WeekFields.ISO.weekOfWeekBasedYear())
    }

    fun progress(
        now: ZonedDateTime,
        holidayTable: HolidayTable? = null,
    ): YearProgress {
        val zone = now.zone
        val year = now.year
        val yearStart = LocalDate.of(year, 1, 1)
        val nextYearStart = yearStart.plusYears(1)
        val starts = overlappingWeekStarts(year)
        val startsInstant = now.toInstant()

        val cells = starts.mapIndexed { offset, weekStart ->
            val endExclusive = weekStart.plusWeeks(1)
            val startInstant = weekStart.atStartOfDay(zone).toInstant()
            val endInstant = endExclusive.atStartOfDay(zone).toInstant()

            val state = when {
                !startsInstant.isBefore(endInstant) -> WeekState.PAST
                startsInstant.isBefore(startInstant) -> WeekState.FUTURE
                else -> WeekState.CURRENT
            }

            val fraction = if (state != WeekState.CURRENT) {
                if (state == WeekState.PAST) 1.0 else 0.0
            } else {
                // A week touching a year boundary only counts the part that
                // belongs to the displayed Gregorian year.
                val portionStart = maxOf(weekStart, yearStart).atStartOfDay(zone).toInstant()
                val portionEnd = minOf(endExclusive, nextYearStart).atStartOfDay(zone).toInstant()
                val span = Duration.between(portionStart, portionEnd).toNanos()
                if (span <= 0L) 0.0 else {
                    (Duration.between(portionStart, startsInstant).toNanos().toDouble() /
                        span.toDouble()).coerceIn(0.0, 1.0)
                }
            }

            var holidayName: String? = null
            if (holidayTable != null) {
                var day = maxOf(weekStart, yearStart)
                val scanEnd = minOf(endExclusive, nextYearStart)
                while (day.isBefore(scanEnd)) {
                    if (day.dayOfWeek != DayOfWeek.SATURDAY &&
                        day.dayOfWeek != DayOfWeek.SUNDAY
                    ) {
                        holidayName = holidayTable.holidayName(day)
                        if (holidayName != null) break
                    }
                    day = day.plusDays(1)
                }
            }

            WeekCell(
                index = offset + 1,
                start = weekStart,
                endExclusive = endExclusive,
                state = state,
                fraction = fraction,
                holiday = holidayName,
                rangeText = "${weekStart.monthValue}/${weekStart.dayOfMonth}" +
                    "–${endExclusive.minusDays(1).monthValue}/${endExclusive.minusDays(1).dayOfMonth}",
            )
        }

        return YearProgress(
            year = year,
            ganzhi = Ganzhi.fromYear(year),
            weeks = cells,
            now = now,
        )
    }

    fun progress(
        date: LocalDate,
        zoneId: ZoneId = ZoneId.systemDefault(),
        holidayTable: HolidayTable? = null,
    ): YearProgress = progress(date.atTime(12, 0).atZone(zoneId), holidayTable)

    fun nextMidnight(after: Instant, zoneId: ZoneId = ZoneId.systemDefault()): Instant {
        return after.atZone(zoneId)
            .toLocalDate()
            .plusDays(1)
            .atStartOfDay(zoneId)
            .toInstant()
    }
}
