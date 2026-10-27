package com.local.yearprogress.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import com.local.yearprogress.R
import com.local.yearprogress.core.YearWeeks
import com.local.yearprogress.widget.WidgetUpdater
import com.local.yearprogress.widget.YearProgressMediumWidgetProvider
import com.local.yearprogress.widget.YearProgressSmallWidgetProvider
import com.local.yearprogress.widget.YearProgressWidgetRenderer
import java.time.ZonedDateTime

class MainActivity : Activity() {
    private lateinit var previewImage: ImageView
    private lateinit var widgetStatus: TextView
    private var previewBitmap: Bitmap? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        window.statusBarColor = getColor(R.color.app_background)
        window.navigationBarColor = getColor(R.color.app_background)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR

        previewImage = findViewById(R.id.preview_image)
        widgetStatus = findViewById(R.id.widget_status)
        findViewById<View>(R.id.btn_pin_small).setOnClickListener {
            requestWidgetPin(YearProgressSmallWidgetProvider::class.java, getString(R.string.widget_small_name))
        }
        findViewById<View>(R.id.btn_pin_medium).setOnClickListener {
            requestWidgetPin(YearProgressMediumWidgetProvider::class.java, getString(R.string.widget_medium_name))
        }
        findViewById<View>(R.id.btn_refresh).setOnClickListener {
            WidgetUpdater.updateAll(this)
            Toast.makeText(this, R.string.refresh_done, Toast.LENGTH_SHORT).show()
            renderPreview()
        }
        previewImage.post { renderPreview() }
        window.decorView.post { handleWidgetShortcut(intent) }
    }

    override fun onResume() {
        super.onResume()
        previewImage.post { renderPreview() }
        updateWidgetStatus()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        window.decorView.post { handleWidgetShortcut(intent) }
    }

    override fun onDestroy() {
        previewBitmap?.recycle()
        previewBitmap = null
        super.onDestroy()
    }

    private fun renderPreview() {
        val width = previewImage.width
        val height = previewImage.height
        if (width <= 1 || height <= 1) return

        val now = ZonedDateTime.now()
        val holidayTable = HolidayRepository.load(this, now.year)
        val progress = YearWeeks.progress(now, holidayTable)
        val bitmap = YearProgressWidgetRenderer.render(this, progress, width, height)

        previewImage.setImageBitmap(bitmap)
        previewImage.contentDescription = progress.accessibilitySummary
        previewBitmap?.recycle()
        previewBitmap = bitmap
    }

    private fun requestWidgetPin(
        provider: Class<out AppWidgetProvider>,
        widgetName: String,
    ) {
        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) {
            Toast.makeText(
                this,
                R.string.pin_unsupported,
                Toast.LENGTH_LONG,
            ).show()
            return
        }

        val requested = manager.requestPinAppWidget(
            ComponentName(this, provider),
            null,
            null,
        )
        Toast.makeText(
            this,
            if (requested) {
                getString(R.string.pin_requested, widgetName)
            } else {
                getString(R.string.pin_unsupported)
            },
            Toast.LENGTH_LONG,
        ).show()
    }

    private fun updateWidgetStatus() {
        val manager = AppWidgetManager.getInstance(this)
        val count = manager.installedProviders.count {
            it.provider.packageName == packageName
        }
        widgetStatus.text = if (count > 0) {
            getString(R.string.widget_registered, count)
        } else {
            getString(R.string.widget_not_registered)
        }
    }

    private fun handleWidgetShortcut(intent: Intent?) {
        when (intent?.action) {
            ACTION_PIN_SMALL -> requestWidgetPin(
                YearProgressSmallWidgetProvider::class.java,
                getString(R.string.widget_small_name),
            )
            ACTION_PIN_MEDIUM -> requestWidgetPin(
                YearProgressMediumWidgetProvider::class.java,
                getString(R.string.widget_medium_name),
            )
        }
    }

    private companion object {
        const val ACTION_PIN_SMALL = "com.local.yearprogress.action.PIN_SMALL"
        const val ACTION_PIN_MEDIUM = "com.local.yearprogress.action.PIN_MEDIUM"
    }
}
