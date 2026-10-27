package com.local.yearprogress.core

import java.time.LocalDate

data class HolidayDay(
    val date: LocalDate,
    val name: String,
)

/**
 * Off-day lookup for one Gregorian year.
 *
 * Only official days off are relevant to the widget. Make-up workdays are
 * intentionally omitted, matching the macOS and iOS rule.
 */
class HolidayTable(
    val year: Int,
    days: List<HolidayDay>,
) {
    private val byDate = days
        .asSequence()
        .filter { it.date.year == year && it.name.isNotBlank() }
        .associateBy { it.date }

    fun holidayName(date: LocalDate): String? = byDate[date]?.name

    val size: Int get() = byDate.size

    companion object {
        /**
         * Fixed-date fallback used when no official JSON is bundled. Lunar
         * festivals are omitted rather than guessed; official data wins as soon
         * as `Support/holidays/<year>.json` is available.
         */
        fun statutory(year: Int): HolidayTable {
            val dates = buildList {
                add(HolidayDay(LocalDate.of(year, 1, 1), "元旦"))
                add(HolidayDay(LocalDate.of(year, 5, 1), "劳动节"))
                add(HolidayDay(LocalDate.of(year, 10, 1), "国庆节"))
                add(HolidayDay(LocalDate.of(year, 10, 2), "国庆节"))
                add(HolidayDay(LocalDate.of(year, 10, 3), "国庆节"))

                // 21st-century approximation used by the existing macOS fallback.
                val yy = year % 100
                val qingmingDay = ((yy * 0.2422 + 4.81).toInt() - yy / 4).coerceIn(4, 6)
                add(HolidayDay(LocalDate.of(year, 4, qingmingDay), "清明节"))
            }
            return HolidayTable(year, dates)
        }
    }
}
