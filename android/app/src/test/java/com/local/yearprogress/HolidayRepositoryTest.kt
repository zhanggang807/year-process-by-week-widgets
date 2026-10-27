package com.local.yearprogress

import com.local.yearprogress.app.HolidayRepository
import com.local.yearprogress.core.WeekState
import com.local.yearprogress.core.YearWeeks
import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals

class HolidayRepositoryTest {
    @Test
    fun `2026 official file maps to the expected ten holiday weeks`() {
        val table = HolidayRepository.parseHolidayJson(
            File("Support/holidays/2026.json").readText(),
            2026,
        )
        val progress = YearWeeks.progress(
            LocalDate.of(2026, 10, 27),
            ZoneId.of("Asia/Shanghai"),
            table,
        )

        assertEquals(
            listOf(1, 8, 9, 15, 18, 19, 25, 39, 40, 41),
            progress.weeks.filter { it.holiday != null }.map { it.index },
        )
        assertEquals(WeekState.CURRENT, progress.currentWeek?.state)
        assertEquals(53, progress.totalWeeks)
    }
}
