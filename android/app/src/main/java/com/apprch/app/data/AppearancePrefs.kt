package com.apprch.app.data

import android.content.Context
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class AppAppearance(val storageValue: String, val title: String) {
    System("system", "System"),
    Light("light", "Light"),
    Dark("dark", "Dark");

    companion object {
        fun fromStorage(value: String?): AppAppearance =
            entries.firstOrNull { it.storageValue == value } ?: System
    }
}

object AppearancePrefs {
    private const val PREFS = "apprch"
    private const val KEY = "appearance"

    private val _appearance = MutableStateFlow(AppAppearance.System)
    val appearance: StateFlow<AppAppearance> = _appearance

    fun load(context: Context) {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, AppAppearance.System.storageValue)
        _appearance.value = AppAppearance.fromStorage(stored)
    }

    fun set(context: Context, value: AppAppearance) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, value.storageValue)
            .apply()
        _appearance.value = value
    }
}

@Composable
fun rememberDarkTheme(): Boolean {
    val appearance by AppearancePrefs.appearance.collectAsState()
    val systemDark = isSystemInDarkTheme()
    return when (appearance) {
        AppAppearance.System -> systemDark
        AppAppearance.Light -> false
        AppAppearance.Dark -> true
    }
}
