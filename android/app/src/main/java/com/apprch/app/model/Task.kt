package com.apprch.app.model

import androidx.compose.ui.graphics.Color
import com.google.firebase.Timestamp
import java.util.Calendar
import java.util.Date

data class Task(
    val id: String,
    val groupId: String,
    val name: String,
    val icon: String,
    val notificationMessage: String,
    val visualizationType: String,
    val createdByUid: String,
    val createdAt: Date? = null,
    val lastLoggedAt: Date? = null,
    val lastLoggedByUid: String? = null,
    val eventCount: Int = 0,
    val accentColorHex: String? = null
) {
    val visualization: String get() = if (visualizationType == "counter") "counter" else "log"

    val isCompletedToday: Boolean
        get() = lastLoggedAt?.let { isSameDay(it, Date()) } == true

    val accent: Color get() = colorFromHex(accentColorHex ?: TaskAccent.fallbackHex)

    val tagUrl: String get() = "apprch://open?id=$id"
}

data class TaskEvent(
    val id: String,
    val groupId: String,
    val taskId: String,
    val loggedByUid: String,
    val date: Date
)

object TaskAccent {
    const val fallbackHex = "#2ECC71"
    val presets = listOf(
        "#2ECC71", "#3498DB", "#9B59B6", "#E74C3C",
        "#E67E22", "#F1C40F", "#1ABC9C", "#E91E63"
    )
}

fun colorFromHex(hex: String): Color {
    val cleaned = hex.trim().removePrefix("#")
    val value = cleaned.toLongOrNull(16) ?: return Color(0xFF2ECC71)
    return if (cleaned.length == 6) {
        Color(
            red = ((value shr 16) and 0xFF) / 255f,
            green = ((value shr 8) and 0xFF) / 255f,
            blue = (value and 0xFF) / 255f
        )
    } else {
        Color(0xFF2ECC71)
    }
}

fun Color.heatmapFill(level: Int): Color {
    val clamped = level.coerceIn(0, 4)
    return when (clamped) {
        0 -> Color.Gray.copy(alpha = 0.16f)
        1 -> copy(alpha = 0.28f)
        2 -> copy(alpha = 0.50f)
        3 -> copy(alpha = 0.74f)
        else -> copy(alpha = 1f)
    }
}

fun isSameDay(a: Date, b: Date): Boolean {
    val calA = Calendar.getInstance().apply { time = a }
    val calB = Calendar.getInstance().apply { time = b }
    return calA.get(Calendar.YEAR) == calB.get(Calendar.YEAR) &&
        calA.get(Calendar.DAY_OF_YEAR) == calB.get(Calendar.DAY_OF_YEAR)
}

fun startOfDay(date: Date = Date()): Date {
    return Calendar.getInstance().apply {
        time = date
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.time
}

fun Timestamp?.toDateOrNull(): Date? = this?.toDate()
