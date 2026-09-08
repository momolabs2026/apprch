package com.apprch.app.widget

import android.content.Context
import com.apprch.app.model.toTrigger
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import androidx.glance.appwidget.updateAll

object WidgetSnapshotSync {
    suspend fun refresh(context: Context, groupIds: List<String>) {
        val appContext = context.applicationContext
        if (FirebaseAuth.getInstance().currentUser == null) {
            WidgetSnapshotStore.clear(appContext)
            HeatmapGlanceWidget().updateAll(appContext)
            return
        }
        val unique = groupIds.filter { it.isNotBlank() }.distinct()
        if (unique.isEmpty()) return
        val snapshots = unique.flatMap { snapshotsIn(it) }
            .sortedBy { it.name.lowercase() }
        WidgetSnapshotStore.save(appContext, snapshots)
        HeatmapGlanceWidget().updateAll(appContext)
    }

    suspend fun refreshTrigger(context: Context, triggerId: String, groupId: String) {
        if (FirebaseAuth.getInstance().currentUser == null) return
        val db = FirebaseFirestore.getInstance()
        val trigger = db.collection("triggers").document(triggerId).get().await().toTrigger()
            ?: return
        if (trigger.groupId != groupId) return
        snapshotFor(trigger)?.let {
            WidgetSnapshotStore.upsert(context.applicationContext, it)
            HeatmapGlanceWidget().updateAll(context.applicationContext)
        }
    }

    private suspend fun snapshotsIn(groupId: String): List<WidgetTriggerSnapshot> {
        val db = FirebaseFirestore.getInstance()
        val docs = db.collection("triggers").whereEqualTo("groupId", groupId).get().await()
        return docs.documents.mapNotNull { it.toTrigger() }.mapNotNull { snapshotFor(it) }
    }

    private suspend fun snapshotFor(trigger: com.apprch.app.model.Trigger): WidgetTriggerSnapshot? {
        val db = FirebaseFirestore.getInstance()
        val events = db.collection("events")
            .whereEqualTo("groupId", trigger.groupId)
            .whereEqualTo("triggerId", trigger.id)
            .limit(400)
            .get()
            .await()
        val dates = events.documents.mapNotNull { (it.get("timestamp") as? Timestamp)?.toDate() }
        return WidgetSnapshotStore.make(
            id = trigger.id,
            name = trigger.name,
            icon = trigger.icon,
            accentColorHex = trigger.accentColorHex,
            dates = dates
        )
    }
}
