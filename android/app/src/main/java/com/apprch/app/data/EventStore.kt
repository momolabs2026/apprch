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
    suspend fun log(triggerId: String, groupId: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val triggerRef = db.collection("triggers").document(triggerId)
        val snapshot = triggerRef.get().await()
        if (!snapshot.exists() || snapshot.getString("groupId") != groupId) {
            throw IllegalStateException("This trigger isn’t available.")
        }

        val batch = db.batch()
        batch.set(
            db.collection("events").document(),
            mapOf(
                "groupId" to groupId,
                "triggerId" to triggerId,
                "triggeredByUid" to uid,
                "timestamp" to FieldValue.serverTimestamp()
            )
        )
        batch.update(
            triggerRef,
            mapOf(
                "lastTriggeredAt" to FieldValue.serverTimestamp(),
                "lastTriggeredByUid" to uid,
                "eventCount" to FieldValue.increment(1)
            )
        )
        batch.commit().await()
        WidgetSnapshotSync.refreshTrigger(ApprchApplication.appContext, triggerId, groupId)
    }

    suspend fun toggleToday(triggerId: String, groupId: String, currentlyComplete: Boolean) {
        if (currentlyComplete) undoToday(triggerId, groupId) else log(triggerId, groupId)
    }

    suspend fun undoToday(triggerId: String, groupId: String) {
        FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val triggerRef = db.collection("triggers").document(triggerId)
        val snapshot = triggerRef.get().await()
        if (!snapshot.exists() || snapshot.getString("groupId") != groupId) {
            throw IllegalStateException("This trigger isn’t available.")
        }

        val events = db.collection("events")
            .whereEqualTo("groupId", groupId)
            .whereEqualTo("triggerId", triggerId)
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
            latestEarlier.getTimestamp("timestamp")?.let { update["lastTriggeredAt"] = it }
            latestEarlier.getString("triggeredByUid")?.let { update["lastTriggeredByUid"] = it }
        } else {
            update["lastTriggeredAt"] = FieldValue.delete()
            update["lastTriggeredByUid"] = FieldValue.delete()
        }
        batch.update(triggerRef, update)
        batch.commit().await()
        WidgetSnapshotSync.refreshTrigger(ApprchApplication.appContext, triggerId, groupId)
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
