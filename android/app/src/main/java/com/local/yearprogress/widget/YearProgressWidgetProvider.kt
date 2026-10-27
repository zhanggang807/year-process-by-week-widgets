package com.local.yearprogress.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import com.local.yearprogress.app.HolidayRepository
import com.local.yearprogress.core.YearWeeks
import java.time.ZonedDateTime

abstract class BaseYearProgressWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val now = ZonedDateTime.now()
        val progress = YearWeeks.progress(now, HolidayRepository.load(context, now.year))
        WidgetUpdater.updateProvider(context, appWidgetManager, javaClass, progress)
        WidgetSchedule.schedule(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        val now = ZonedDateTime.now()
        val progress = YearWeeks.progress(now, HolidayRepository.load(context, now.year))
        WidgetUpdater.updateProvider(context, appWidgetManager, javaClass, progress)
    }

    override fun onEnabled(context: Context) {
        WidgetSchedule.schedule(context)
    }

    override fun onDisabled(context: Context) {
        if (!WidgetUpdater.hasWidgets(context)) {
            WidgetSchedule.cancel(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in externallyRelevantActions) {
            WidgetUpdater.updateAll(context)
            WidgetSchedule.schedule(context)
        }
    }

    private companion object {
        val externallyRelevantActions = setOf(
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }
}

class YearProgressMediumWidgetProvider : BaseYearProgressWidgetProvider()

class YearProgressSmallWidgetProvider : BaseYearProgressWidgetProvider()
