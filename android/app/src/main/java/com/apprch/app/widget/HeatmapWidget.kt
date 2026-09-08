package com.apprch.app.widget

import android.content.Context
import android.util.TypedValue
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalGlanceId
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.fillMaxSize

class HeatmapGlanceWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(
        setOf(
            DpSize(110.dp, 110.dp),
            DpSize(180.dp, 110.dp),
            DpSize(250.dp, 250.dp)
        )
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            HeatmapWidgetContent()
        }
    }
}

@Composable
private fun HeatmapWidgetContent() {
    val context = LocalContext.current
    val size = LocalSize.current
    val glanceId = LocalGlanceId.current
    val appWidgetId = runCatching {
        GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
    }.getOrDefault(0)
    val triggerId = WidgetSnapshotStore.widgetTrigger(context, appWidgetId)
    val snapshot = WidgetSnapshotStore.snapshot(context, triggerId)
    val weeks = when {
        size.width < 150.dp -> 12
        size.height < 180.dp -> 20
        else -> 26
    }
    val widthPx = dpToPx(context, size.width.value)
    val heightPx = dpToPx(context, size.height.value)
    val bitmap = HeatmapBitmap.render(snapshot, widthPx, heightPx, isNightMode(context), weeks)
    Image(
        provider = ImageProvider(bitmap),
        contentDescription = snapshot?.let { "${it.name} heatmap" } ?: "Trigger heatmap",
        modifier = GlanceModifier.fillMaxSize()
    )
}

class HeatmapWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HeatmapGlanceWidget()
}

private fun dpToPx(context: Context, dp: Float): Int {
    return TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        dp,
        context.resources.displayMetrics
    ).toInt().coerceAtLeast(1)
}

private fun isNightMode(context: Context): Boolean {
    val night = context.resources.configuration.uiMode and
        android.content.res.Configuration.UI_MODE_NIGHT_MASK
    return night == android.content.res.Configuration.UI_MODE_NIGHT_YES
}
