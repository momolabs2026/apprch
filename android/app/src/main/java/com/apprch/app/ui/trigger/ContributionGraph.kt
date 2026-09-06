package com.apprch.app.ui.trigger

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.apprch.app.model.TriggerEvent
import com.apprch.app.model.heatmapFill
import com.apprch.app.model.startOfDay
import java.util.Calendar
import java.util.Date

@Composable
fun ContributionGraph(events: List<TriggerEvent>, accent: Color) {
    val calendar = Calendar.getInstance()
    val days = remember { daysInPastYear(calendar) }
    val counts = remember(events) {
        events.groupingBy { startOfDay(it.date) }.eachCount()
    }
    val weeks = remember(days) { days.chunked(7).asReversed() }
    val total = counts.values.sum()
    val today = startOfDay()

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            if (total == 1) "1 time in the last year" else "$total times in the last year",
            style = MaterialTheme.typography.titleSmall
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(7) { index ->
                    Text(
                        weekdayName(index),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(width = 16.dp, height = 16.dp)
                    )
                }
            }
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                weeks.forEach { week ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        week.forEach { day ->
                            val count = counts[startOfDay(day)] ?: 0
                            Box(
                                modifier = Modifier
                                    .size(16.dp)
                                    .clip(RoundedCornerShape(3.dp))
                                    .background(accent.heatmapFill(levelFor(count)))
                                    .then(
                                        if (startOfDay(day) == today) {
                                            Modifier.border(
                                                1.5.dp,
                                                MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                                                RoundedCornerShape(3.dp)
                                            )
                                        } else Modifier
                                    )
                            )
                        }
                    }
                }
            }
        }
        Row(
            modifier = Modifier.align(Alignment.End),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Less", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            (0..4).forEach { level ->
                Box(
                    modifier = Modifier
                        .size(16.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(accent.heatmapFill(level))
                )
            }
            Text("More", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

private fun levelFor(count: Int) = when (count) {
    0 -> 0
    1 -> 1
    2 -> 2
    3 -> 3
    else -> 4
}

private fun weekdayName(index: Int): String {
    val symbols = Calendar.getInstance().getDisplayNames(Calendar.DAY_OF_WEEK, Calendar.NARROW, java.util.Locale.getDefault())
        ?.entries?.sortedBy { it.value }?.map { it.key } ?: listOf("S", "M", "T", "W", "T", "F", "S")
    return symbols.getOrElse(index) { "" }
}

private fun daysInPastYear(calendar: Calendar): List<Date> {
    val today = startOfDay()
    calendar.time = today
    val weekday = calendar.get(Calendar.DAY_OF_WEEK)
    val first = calendar.firstDayOfWeek
    val daysFromWeekStart = (weekday - first + 7) % 7
    calendar.add(Calendar.DAY_OF_YEAR, 6 - daysFromWeekStart)
    val end = calendar.time
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
