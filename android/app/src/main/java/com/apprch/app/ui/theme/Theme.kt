package com.apprch.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.apprch.app.data.rememberDarkTheme

private val ApprchLight = lightColorScheme(
    primary = Color(0xFF2F6F62),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD8EBE6),
    onPrimaryContainer = Color(0xFF0E2F29),
    secondary = Color(0xFF8A6A4F),
    background = Color(0xFFFAF7F2),
    surface = Color(0xFFFAF7F2),
    onBackground = Color(0xFF1C1B19),
    onSurface = Color(0xFF1C1B19),
    surfaceVariant = Color(0xFFF0EBE3),
    onSurfaceVariant = Color(0xFF5C574F)
)

private val ApprchDark = darkColorScheme(
    primary = Color(0xFF8FCBBE),
    onPrimary = Color(0xFF0E2F29),
    primaryContainer = Color(0xFF1E4A41),
    onPrimaryContainer = Color(0xFFD8EBE6),
    secondary = Color(0xFFD2B48C),
    background = Color(0xFF141311),
    surface = Color(0xFF141311),
    onBackground = Color(0xFFF3EFE8),
    onSurface = Color(0xFFF3EFE8),
    surfaceVariant = Color(0xFF2A2824),
    onSurfaceVariant = Color(0xFFC8C2B8)
)

@Composable
fun ApprchTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (rememberDarkTheme()) ApprchDark else ApprchLight,
        content = content
    )
}
