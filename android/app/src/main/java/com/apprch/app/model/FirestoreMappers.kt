package com.apprch.app.model

import com.google.firebase.firestore.DocumentSnapshot

fun DocumentSnapshot.toTrigger(): Trigger? {
    val name = getString("name") ?: return null
    val groupId = getString("groupId") ?: return null
    return Trigger(
        id = id,
        groupId = groupId,
        name = name,
        icon = getString("icon") ?: "📌",
        notificationMessage = getString("notificationMessage").orEmpty(),
        visualizationType = getString("visualizationType") ?: "log",
        createdByUid = getString("createdByUid").orEmpty(),
        createdAt = getTimestamp("createdAt")?.toDate(),
        lastTriggeredAt = getTimestamp("lastTriggeredAt")?.toDate(),
        lastTriggeredByUid = getString("lastTriggeredByUid"),
        eventCount = getLong("eventCount")?.toInt() ?: 0,
        accentColorHex = getString("accentColorHex")
    )
}

fun DocumentSnapshot.toTriggerEvent(): TriggerEvent? {
    val timestamp = getTimestamp("timestamp")?.toDate() ?: return null
    return TriggerEvent(
        id = id,
        groupId = getString("groupId").orEmpty(),
        triggerId = getString("triggerId").orEmpty(),
        triggeredByUid = getString("triggeredByUid") ?: return null,
        date = timestamp
    )
}
