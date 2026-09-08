package com.apprch.app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

object HeatmapWidgetInstaller {
    fun pin(context: Context, triggerId: String, onUnsupported: () -> Unit) {
        WidgetSnapshotStore.markPendingPin(context, triggerId)
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, HeatmapWidgetReceiver::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) {
            manager.requestPinAppWidget(provider, null, null)
        } else {
            onUnsupported()
        }
    }

    fun bindTrigger(context: Context, appWidgetId: Int, triggerId: String) {
        val appContext = context.applicationContext
        WidgetSnapshotStore.setWidgetTrigger(appContext, appWidgetId, triggerId)
        CoroutineScope(Dispatchers.IO).launch {
            HeatmapGlanceWidget().updateAll(appContext)
        }
    }
}
