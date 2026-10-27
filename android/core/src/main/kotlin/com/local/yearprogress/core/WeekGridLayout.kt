package com.local.yearprogress.core

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.ln
import kotlin.math.min

data class WeekGridLayout(
    val columns: Int,
    val rows: Int,
    val cellSize: Double,
    val gap: Double,
    val autoSelectedColumns: Boolean,
) {
    val gridWidth: Double get() = columns * cellSize + (columns - 1) * gap
    val gridHeight: Double get() = rows * cellSize + (rows - 1) * gap

    fun cellsInRow(row: Int, weekCount: Int): Int {
        if (row !in 0 until rows) return 0
        return min(columns, (weekCount - row * columns).coerceAtLeast(0))
    }

    fun rowRange(row: Int, weekCount: Int): IntRange {
        val start = row * columns
        val endExclusive = start + cellsInRow(row, weekCount)
        return start until endExclusive
    }
}

object GridLayoutCalculator {
    const val gapRatio: Double = 0.18

    private val defaultCandidates = listOf(7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 26)

    fun compute(
        weekCount: Int,
        availableWidth: Double,
        availableHeight: Double,
        preferredColumns: Int = 13,
        forcedColumns: Int? = null,
        candidates: List<Int> = defaultCandidates,
    ): WeekGridLayout {
        val count = weekCount.coerceAtLeast(1)
        val targetAspect = if (availableHeight > 0) availableWidth / availableHeight else 1.0

        var columns = (forcedColumns ?: preferredColumns).coerceAtLeast(1)
        var auto = false
        if (forcedColumns == null && count % columns != 0) {
            val selected = bestColumns(count, targetAspect, candidates)
            if (selected != null) {
                columns = selected
                auto = selected != preferredColumns
            }
        }

        val rows = ceil(count.toDouble() / columns).toInt()
        val cell = bestCellSize(
            columns,
            rows,
            availableWidth.coerceAtLeast(1.0),
            availableHeight.coerceAtLeast(1.0),
        )
        return WeekGridLayout(columns, rows, cell, cell * gapRatio, auto)
    }

    fun bestCellSize(
        columns: Int,
        rows: Int,
        availableWidth: Double,
        availableHeight: Double,
    ): Double {
        val byWidth = availableWidth / (columns + gapRatio * (columns - 1))
        val byHeight = availableHeight / (rows + gapRatio * (rows - 1))
        return min(byWidth, byHeight).coerceAtLeast(1.0)
    }

    private fun bestColumns(
        weekCount: Int,
        targetAspect: Double,
        candidates: List<Int>,
    ): Int? {
        var best: Pair<Int, Double>? = null
        for (columns in candidates) {
            if (columns <= 0 || columns > weekCount) continue
            val rows = ceil(weekCount.toDouble() / columns).toInt()
            val waste = (columns * rows - weekCount).toDouble() / (columns * rows)
            val aspect = (columns + gapRatio * (columns - 1)) /
                (rows + gapRatio * (rows - 1))
            val aspectPenalty = abs(ln(aspect / targetAspect.coerceAtLeast(0.01)))
            val lastRow = weekCount - (rows - 1) * columns
            val fill = lastRow.toDouble() / columns
            val sparsePenalty = if (fill < 0.5) 1.2 * (0.5 - fill) / 0.5 else 0.0
            val score = waste + 1.2 * aspectPenalty + sparsePenalty
            if (best == null || score < best.second - 1e-9) {
                best = columns to score
            }
        }
        return best?.first
    }
}
