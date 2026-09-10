package com.apprch.app.data

import com.apprch.app.ApprchApplication
import com.apprch.app.model.startOfDay
import com.apprch.app.widget.WidgetSnapshotSync
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import java.util.Date

object EventStore {
    suspend fun log(taskId: String, groupId: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val taskRef = db.collection("tasks").document(taskId)
        val snapshot = taskRef.get().await()
        if (!snapshot.exists() || snapshot.getString("groupId") != groupId) {
            throw IllegalStateException("This task isn’t available.")
        }

        val batch = db.batch()
        batch.set(
            db.collection("events").document(),
            mapOf(
                "groupId" to groupId,
                "taskId" to taskId,
                "loggedByUid" to uid,
                "timestamp" to FieldValue.serverTimestamp()
            )
        )
        batch.update(
            taskRef,
            mapOf(
                "lastLoggedAt" to FieldValue.serverTimestamp(),
                "lastLoggedByUid" to uid,
                "eventCount" to FieldValue.increment(1)
            )
        )
        batch.commit().await()
        WidgetSnapshotSync.refreshTask(ApprchApplication.appContext, taskId, groupId)
    }

    suspend fun toggleToday(taskId: String, groupId: String, currentlyComplete: Boolean) {
        if (currentlyComplete) undoToday(taskId, groupId) else log(taskId, groupId)
    }

    suspend fun undoToday(taskId: String, groupId: String) {
        FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val taskRef = db.collection("tasks").document(taskId)
        val snapshot = taskRef.get().await()
        if (!snapshot.exists() || snapshot.getString("groupId") != groupId) {
            throw IllegalStateException("This task isn’t available.")
        }

        val events = db.collection("events")
            .whereEqualTo("groupId", groupId)
            .whereEqualTo("taskId", taskId)
            .get()
            .await()

        val start = startOfDay()
        val today = mutableListOf<com.google.firebase.firestore.DocumentSnapshot>()
        val earlier = mutableListOf<com.google.firebase.firestore.DocumentSnapshot>()
        for (doc in events.documents) {
            val timestamp = doc.getTimestamp("timestamp")
            if (timestamp == null || !timestamp.toDate().before(start)) {
                today += doc
            } else {
                earlier += doc
            }
        }

        val latestEarlier = earlier.maxByOrNull {
            (it.getTimestamp("timestamp")?.toDate() ?: Date(0)).time
        }

        val batch = db.batch()
        today.forEach { batch.delete(it.reference) }

        val currentCount = (snapshot.getLong("eventCount") ?: events.size().toLong()).toInt()
        val update = mutableMapOf<String, Any>(
            "eventCount" to maxOf(0, currentCount - today.size)
        )
        if (latestEarlier != null) {
            latestEarlier.getTimestamp("timestamp")?.let { update["lastLoggedAt"] = it }
            (latestEarlier.getString("loggedByUid") ?: latestEarlier.getString("triggeredByUid"))
                ?.let { update["lastLoggedByUid"] = it }
        } else {
            update["lastLoggedAt"] = FieldValue.delete()
            update["lastLoggedByUid"] = FieldValue.delete()
        }
        batch.update(taskRef, update)
        batch.commit().await()
        WidgetSnapshotSync.refreshTask(ApprchApplication.appContext, taskId, groupId)
    }

    fun userFacingMessage(error: Throwable): String {
        val text = error.localizedMessage.orEmpty()
        if (text.contains("permission", ignoreCase = true) ||
            text.contains("unauthenticated", ignoreCase = true)
        ) {
            return "Couldn’t log this. Check that you’re signed in and try again."
        }
        return text.ifBlank { "Couldn’t log this. Try again." }
    }
}
