package com.local.yearprogress.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.local.yearprogress.R
import com.local.yearprogress.app.HolidayRepository
import com.local.yearprogress.app.MainActivity
import com.local.yearprogress.core.YearProgress
import com.local.yearprogress.core.YearWeeks
import java.time.ZonedDateTime
import kotlin.math.roundToInt

object WidgetUpdater {
    private const val TAG = "YearProgressWidget"
    private val providers = listOf(
        YearProgressMediumWidgetProvider::class.java,
        YearProgressSmallWidgetProvider::class.java,
    )

    fun updateAll(context: Context) {
        val now = ZonedDateTime.now()
        val progress = YearWeeks.progress(now, HolidayRepository.load(context, now.year))
        val manager = AppWidgetManager.getInstance(context)
        providers.forEach { provider ->
            updateProvider(context, manager, provider, progress)
        }
    }

    fun updateProvider(
        context: Context,
        manager: AppWidgetManager,
        provider: Class<out AppWidgetProvider>,
        progress: YearProgress,
    ) {
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        ids.forEach { id ->
            updateWidget(context, manager, id, progress)
        }
    }

    fun hasWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return providers.any { manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        progress: YearProgress,
    ) {
        val options: Bundle = manager.getAppWidgetOptions(appWidgetId)
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            .takeIf { it > 0 } ?: 158
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            .takeIf { it > 0 } ?: 158
        val density = context.resources.displayMetrics.density
        val widthPx = (minWidthDp * density).roundToInt().coerceIn(2, 4096)
        val heightPx = (minHeightDp * density).roundToInt().coerceIn(2, 4096)

        val views = android.widget.RemoteViews(context.packageName, R.layout.widget_root)
        runCatching {
            YearProgressWidgetRenderer.render(context, progress, widthPx, heightPx)
        }.onSuccess { bitmap ->
            views.setImageViewBitmap(R.id.widget_image, bitmap)
            views.setContentDescription(R.id.widget_image, progress.accessibilitySummary)
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
            manager.updateAppWidget(appWidgetId, views)
        }.onFailure {
            Log.e(TAG, "Unable to render widget $appWidgetId", it)
        }
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
