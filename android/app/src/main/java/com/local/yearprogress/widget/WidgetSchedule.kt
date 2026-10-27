package com.local.yearprogress.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.local.yearprogress.core.YearWeeks
import java.time.Instant

object WidgetSchedule {
    private const val REQUEST_CODE = 2042
    private const val ACTION_REFRESH = "com.local.yearprogress.action.MIDNIGHT_REFRESH"

    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val at = YearWeeks.nextMidnight(Instant.now()).toEpochMilli()
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, refreshIntent(context))
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(refreshIntent(context))
    }

    fun refreshIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetRefreshReceiver::class.java).apply {
            action = ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun isMidnightRefresh(intent: Intent?): Boolean = intent?.action == ACTION_REFRESH
}

class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && !WidgetSchedule.isMidnightRefresh(intent)) {
            return
        }
        // Boot and the inexact midnight alarm share this receiver. In both
        // cases a repaint plus the next local-midnight alarm is required.
        WidgetUpdater.updateAll(context)
        WidgetSchedule.schedule(context)
    }
}
