package com.local.yearprogress.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import com.local.yearprogress.core.GridLayoutCalculator
import com.local.yearprogress.core.WeekCell
import com.local.yearprogress.core.WeekState
import com.local.yearprogress.core.YearProgress
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Draws the complete widget into one bitmap. A single RemoteViews ImageView
 * keeps the geometry identical across HyperOS launcher versions and avoids
 * hundreds of RemoteViews actions for nested week rows.
 */
object YearProgressWidgetRenderer {
    // RemoteViews sends the bitmap through Binder. On a 3x-density 4x2 phone,
    // an uncapped ARGB_8888 bitmap is close to 2 MB and can fail the ~1 MB
    // transaction limit. A 180k-pixel budget keeps transport safe while the
    // ImageView scales it back to the exact widget bounds.
    private const val maxBitmapPixels = 180_000.0
    private const val backgroundTop = 0xFF33363B.toInt()
    private const val backgroundBottom = 0xFF202327.toInt()
    private const val pastFill = 0xFF33465C.toInt()
    private const val futureFill = 0xFFAFC8DE.toInt()
    private const val pastLabel = 0xEBFFFFFF.toInt()
    private const val futureLabel = 0xFF1E2B3A.toInt()
    private const val currentRing = 0xFF0033FF.toInt()
    private const val holidayAccent = 0xFFE6513C.toInt()

    fun render(
        context: Context,
        progress: YearProgress,
        widthPx: Int,
        heightPx: Int,
    ): Bitmap {
        val requestedWidth = widthPx.coerceAtLeast(2)
        val requestedHeight = heightPx.coerceAtLeast(2)
        val requestedPixels = requestedWidth.toDouble() * requestedHeight
        val scale = min(1.0, sqrt(maxBitmapPixels / requestedPixels))
        val width = (requestedWidth * scale).roundToInt().coerceAtLeast(2)
        val height = (requestedHeight * scale).roundToInt().coerceAtLeast(2)
        // Keep the same dp geometry after raster-size reduction.
        val density = context.resources.displayMetrics.density * scale.toFloat()
        val widthDp = width / density
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        drawBackground(canvas, width, height, density)

        val padding = (widthDp * 0.05).coerceIn(8.0, 20.0).toFloat() * density
        val compact = widthDp < 250
        val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val initialHeaderSp = if (compact) {
            11.5f
        } else {
            (widthDp * 0.034 + 2.2).coerceIn(10.5, 14.5).toFloat()
        }
        headerPaint.textSize = initialHeaderSp * density
        val header = progress.headerText(compact)
        fitText(headerPaint, header, width - padding * 2, 7.0f * density)

        val headerHeight = headerPaint.textSize * 1.35f
        val headerGap = max(6.0f * density, width * 0.028f)
        val metrics = headerPaint.fontMetrics
        val headerBaseline = padding + headerHeight / 2f - (metrics.ascent + metrics.descent) / 2f
        canvas.drawText(header, width / 2f, headerBaseline, headerPaint)

        val gridTop = padding + headerHeight + headerGap
        val availableWidth = (width - padding * 2).coerceAtLeast(2f)
        val availableHeight = (height - gridTop - padding).coerceAtLeast(2f)
        val layout = GridLayoutCalculator.compute(
            weekCount = progress.totalWeeks,
            availableWidth = availableWidth.toDouble(),
            availableHeight = availableHeight.toDouble(),
        )
        val gridLeft = (width - layout.gridWidth.toFloat()) / 2f
        val gridVerticalSlack = max(0f, availableHeight - layout.gridHeight.toFloat())
        val gridTopCentered = gridTop + gridVerticalSlack * 0.42f

        progress.weeks.forEachIndexed { index, week ->
            val row = index / layout.columns
            val column = index % layout.columns
            val countInRow = layout.cellsInRow(row, progress.totalWeeks)
            val rowWidth = countInRow * layout.cellSize.toFloat() +
                (countInRow - 1).coerceAtLeast(0) * layout.gap.toFloat()
            val rowLeft = (width - rowWidth) / 2f
            val left = rowLeft + column * (layout.cellSize + layout.gap).toFloat()
            val top = gridTopCentered + row * (layout.cellSize + layout.gap).toFloat()
            drawWeek(
                canvas = canvas,
                cell = week,
                left = left,
                top = top,
                side = layout.cellSize.toFloat(),
                density = density,
            )
        }

        return bitmap
    }

    private fun drawBackground(canvas: Canvas, width: Int, height: Int, density: Float) {
        val card = RectF(0f, 0f, width.toFloat(), height.toFloat())
        val radius = min(20f * density, min(width, height) * 0.15f)
        val path = Path().apply { addRoundRect(card, radius, radius, Path.Direction.CW) }
        val background = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                width.toFloat(),
                height.toFloat(),
                intArrayOf(backgroundTop, backgroundBottom),
                null,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawPath(path, background)
        canvas.clipPath(path)
    }

    private fun drawWeek(
        canvas: Canvas,
        cell: WeekCell,
        left: Float,
        top: Float,
        side: Float,
        density: Float,
    ) {
        val radius = side * 0.22f
        val rect = RectF(left, top, left + side, top + side)
        val rounded = Path().apply {
            addRoundRect(rect, radius, radius, Path.Direction.CW)
        }

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = when (cell.state) {
                WeekState.PAST -> pastFill
                WeekState.CURRENT, WeekState.FUTURE -> futureFill
            }
        }
        canvas.drawPath(rounded, fill)

        if (cell.state == WeekState.PAST) {
            val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                color = 0x29FFFFFF
                strokeWidth = max(0.8f, side * 0.03f)
            }
            val inset = stroke.strokeWidth / 2f
            val strokeRect = RectF(
                rect.left + inset,
                rect.top + inset,
                rect.right - inset,
                rect.bottom - inset,
            )
            canvas.drawRoundRect(strokeRect, radius, radius, stroke)
        }

        if (cell.state == WeekState.CURRENT && cell.fraction > 0.0) {
            val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = pastFill }
            canvas.save()
            canvas.clipPath(rounded)
            canvas.clipRect(
                rect.left,
                rect.top,
                rect.right,
                rect.top + side * cell.fraction.toFloat(),
            )
            canvas.drawRect(rect, progressPaint)
            canvas.restore()
        }

        if (cell.holiday != null) {
            val marker = side * 0.48f
            val fold = Path().apply {
                moveTo(rect.right, rect.top)
                lineTo(rect.right - marker, rect.top)
                lineTo(rect.right, rect.top + marker)
                close()
            }
            canvas.save()
            canvas.clipPath(rounded)
            canvas.drawPath(fold, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = holidayAccent })
            canvas.restore()
        }

        drawNumber(canvas, cell, rect, side, density)

        if (cell.state == WeekState.CURRENT) {
            val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                color = currentRing
                strokeWidth = max(1.2f * density, side * 0.065f)
            }
            val inset = ring.strokeWidth / 2f
            canvas.drawRoundRect(
                RectF(
                    rect.left + inset,
                    rect.top + inset,
                    rect.right - inset,
                    rect.bottom - inset,
                ),
                radius,
                radius,
                ring,
            )
        }
    }

    private fun drawNumber(
        canvas: Canvas,
        cell: WeekCell,
        rect: RectF,
        side: Float,
        density: Float,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            textSize = max(5.2f * density, side * 0.48f)
        }
        val text = cell.id.toString()
        fitText(paint, text, side * 0.78f, 4.2f * density)
        val metrics = paint.fontMetrics
        val baseline = rect.centerY() - (metrics.ascent + metrics.descent) / 2f

        canvas.save()
        canvas.clipPath(
            Path().apply {
                addRoundRect(rect, side * 0.22f, side * 0.22f, Path.Direction.CW)
            },
        )
        when (cell.state) {
            WeekState.PAST -> {
                paint.color = pastLabel
                canvas.drawText(text, rect.centerX(), baseline, paint)
            }
            WeekState.FUTURE -> {
                paint.color = futureLabel
                canvas.drawText(text, rect.centerX(), baseline, paint)
            }
            WeekState.CURRENT -> {
                val split = rect.top + side * cell.fraction.toFloat()
                canvas.save()
                canvas.clipRect(rect.left, rect.top, rect.right, split)
                paint.color = pastLabel
                canvas.drawText(text, rect.centerX(), baseline, paint)
                canvas.restore()

                canvas.save()
                canvas.clipRect(rect.left, split, rect.right, rect.bottom)
                paint.color = futureLabel
                canvas.drawText(text, rect.centerX(), baseline, paint)
                canvas.restore()
            }
        }
        canvas.restore()
    }

    private fun fitText(paint: Paint, text: String, maxWidth: Float, minSize: Float) {
        while (paint.textSize > minSize && paint.measureText(text) > maxWidth) {
            paint.textSize -= 0.25f
        }
    }
}
