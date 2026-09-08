package com.apprch.app.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import java.util.Calendar
import java.util.Date
import kotlin.math.min

object HeatmapBitmap {
    fun render(
        snapshot: WidgetTriggerSnapshot?,
        width: Int,
        height: Int,
        isDark: Boolean,
        weeksToShow: Int
    ): Bitmap {
        val w = width.coerceAtLeast(1)
        val h = height.coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val background = if (isDark) Color.parseColor("#141311") else Color.parseColor("#FAF7F2")
        canvas.drawColor(background)

        val onSurface = if (isDark) Color.parseColor("#F3EFE8") else Color.parseColor("#1C1B19")
        val secondary = if (isDark) Color.parseColor("#C8C2B8") else Color.parseColor("#5C574F")
        val accent = parseHex(snapshot?.accentColorHex ?: "#2ECC71")
        val pad = (8f * (w / 180f)).coerceIn(8f, 18f)

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = onSurface
            textSize = (if (weeksToShow <= 13) 28f else 32f) * (w / 360f).coerceIn(0.7f, 1.15f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val captionPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = secondary
            textSize = titlePaint.textSize * 0.58f
        }
        val todayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if ((snapshot?.todayCount ?: 0) == 0) secondary else accent
            textSize = captionPaint.textSize
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }

        val title = if (snapshot != null) "${snapshot.icon}  ${snapshot.name}" else "Trigger heatmap"
        val subtitle = yearLabel(snapshot?.yearTotal ?: 0)
        val today = todayLabel(snapshot?.todayCount ?: 0)

        var y = pad + titlePaint.textSize
        canvas.drawText(title, pad, y, titlePaint)
        if (weeksToShow > 13) {
            y += captionPaint.textSize + 8f
            canvas.drawText(subtitle, pad, y, captionPaint)
        }

        val footerY = h - pad
        canvas.drawText(today, pad, footerY, todayPaint)

        val gridTop = y + 12f
        val gridBottom = footerY - todayPaint.textSize
        if (gridBottom > gridTop + 8f) {
            drawGrid(
                canvas = canvas,
                counts = snapshot?.countsByDay.orEmpty(),
                accent = accent,
                empty = if (isDark) Color.argb(40, 200, 194, 184) else Color.argb(40, 92, 87, 79),
                todayStroke = onSurface,
                left = pad,
                top = gridTop,
                right = w - pad,
                bottom = gridBottom - 8f,
                weeksToShow = weeksToShow
            )
        }
        return bitmap
    }

    private fun drawGrid(
        canvas: Canvas,
        counts: Map<String, Int>,
        accent: Int,
        empty: Int,
        todayStroke: Int,
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
        weeksToShow: Int
    ) {
        val days = daysInPastYear()
        val weeks = days.chunked(7).asReversed().take(weeksToShow)
        if (weeks.isEmpty()) return
        val gap = ((right - left) / 120f).coerceIn(1.5f, 3.5f)
        val cols = weeks.size
        val cell = min(
            (right - left - gap * (cols - 1)) / cols,
            (bottom - top - gap * 6) / 7f
        )
        if (cell <= 1f) return
        val gridWidth = cols * cell + (cols - 1) * gap
        val gridHeight = 7 * cell + 6 * gap
        val originX = left + (right - left - gridWidth) / 2f
        val originY = top + (bottom - top - gridHeight) / 2f
        val formatter = WidgetSnapshotStore.dayKeyFormatter
        val today = startOfDayMillis()
        val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = Color.argb(140, Color.red(todayStroke), Color.green(todayStroke), Color.blue(todayStroke))
            strokeWidth = (cell * 0.08f).coerceAtLeast(1f)
        }
        val corner = (cell * 0.22f).coerceAtLeast(1f)
        weeks.forEachIndexed { col, week ->
            week.forEachIndexed { row, day ->
                val count = counts[formatter.format(day)] ?: 0
                fill.color = heatmapFill(accent, empty, count)
                val rect = RectF(
                    originX + col * (cell + gap),
                    originY + row * (cell + gap),
                    originX + col * (cell + gap) + cell,
                    originY + row * (cell + gap) + cell
                )
                canvas.drawRoundRect(rect, corner, corner, fill)
                if (day.time == today) {
                    canvas.drawRoundRect(rect, corner, corner, stroke)
                }
            }
        }
    }

    private fun heatmapFill(accent: Int, empty: Int, count: Int): Int {
        val level = when (count) {
            0 -> 0
            1 -> 1
            2 -> 2
            3 -> 3
            else -> 4
        }
        if (level == 0) return empty
        val alpha = when (level) {
            1 -> 0.28f
            2 -> 0.50f
            3 -> 0.74f
            else -> 1f
        }
        return Color.argb(
            (alpha * 255).toInt(),
            Color.red(accent),
            Color.green(accent),
            Color.blue(accent)
        )
    }

    private fun parseHex(hex: String): Int {
        val cleaned = hex.trim().removePrefix("#")
        val value = cleaned.toLongOrNull(16) ?: return Color.parseColor("#2ECC71")
        return Color.rgb(
            ((value shr 16) and 0xFF).toInt(),
            ((value shr 8) and 0xFF).toInt(),
            (value and 0xFF).toInt()
        )
    }

    private fun yearLabel(total: Int) =
        if (total == 1) "1 time in the last year" else "$total times in the last year"

    private fun todayLabel(count: Int) = when (count) {
        0 -> "Not yet"
        1 -> "Done once today"
        else -> "Done $count times today"
    }

    private fun startOfDayMillis(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun daysInPastYear(): List<Date> {
        val calendar = Calendar.getInstance()
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val weekday = today.get(Calendar.DAY_OF_WEEK)
        val first = today.firstDayOfWeek
        val daysFromWeekStart = (weekday - first + 7) % 7
        today.add(Calendar.DAY_OF_YEAR, 6 - daysFromWeekStart)
        val end = today.time
        calendar.time = end
        calendar.add(Calendar.DAY_OF_YEAR, -(53 * 7 - 1))
        val start = calendar.time
        return (0 until 53 * 7).map { offset ->
            Calendar.getInstance().apply {
                time = start
                add(Calendar.DAY_OF_YEAR, offset)
            }.time
        }
    }
}
