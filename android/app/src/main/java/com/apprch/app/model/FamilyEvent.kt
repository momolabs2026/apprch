package com.apprch.app.model

import java.util.Date

data class FamilyEvent(
    val id: String,
    val type: String,
    val triggeredByUid: String,
    val timestamp: Date
) {
    val displayName: String
        get() = when (type) {
        else -> type.replace("_", " ").replaceFirstChar { it.uppercase() }
        }
}
