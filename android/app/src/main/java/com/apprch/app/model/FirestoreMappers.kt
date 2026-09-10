package com.apprch.app.model

import com.google.firebase.firestore.DocumentSnapshot

fun DocumentSnapshot.toTask(): Task? {
    val name = getString("name") ?: return null
    val groupId = getString("groupId") ?: return null
    return Task(
        id = id,
        groupId = groupId,
        name = name,
        icon = getString("icon") ?: "📌",
        notificationMessage = getString("notificationMessage").orEmpty(),
        visualizationType = getString("visualizationType") ?: "log",
        createdByUid = getString("createdByUid").orEmpty(),
        createdAt = getTimestamp("createdAt")?.toDate(),
        lastLoggedAt = (getTimestamp("lastLoggedAt") ?: getTimestamp("lastTriggeredAt"))?.toDate(),
        lastLoggedByUid = getString("lastLoggedByUid") ?: getString("lastTriggeredByUid"),
        eventCount = getLong("eventCount")?.toInt() ?: 0,
        accentColorHex = getString("accentColorHex")
    )
}

fun DocumentSnapshot.toTaskEvent(): TaskEvent? {
    val timestamp = getTimestamp("timestamp")?.toDate() ?: return null
    val loggedByUid = getString("loggedByUid") ?: getString("triggeredByUid") ?: return null
    return TaskEvent(
        id = id,
        groupId = getString("groupId").orEmpty(),
        taskId = getString("taskId") ?: getString("triggerId").orEmpty(),
        loggedByUid = loggedByUid,
        date = timestamp
    )
}
