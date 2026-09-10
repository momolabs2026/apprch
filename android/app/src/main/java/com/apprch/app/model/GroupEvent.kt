package com.apprch.app.model

import java.util.Date

data class GroupEvent(
    val id: String,
    val type: String,
    val loggedByUid: String,
    val timestamp: Date
) {
    val displayName: String
        get() = type.replace("_", " ").replaceFirstChar { it.uppercase() }
}
