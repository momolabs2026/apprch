package com.apprch.app.model

data class Space(
    val id: String,
    val name: String,
    val solo: Boolean
) {
    val title: String get() = if (solo) "Solo" else name
}

data class SpaceMember(
    val id: String,
    val name: String,
    val photoBase64: String? = null,
    val email: String? = null
) {
    val initial: String get() = name.firstOrNull()?.uppercase() ?: "?"
}
