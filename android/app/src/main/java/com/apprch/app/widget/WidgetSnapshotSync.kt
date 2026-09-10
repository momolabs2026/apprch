package com.apprch.app.widget

import android.content.Context
import com.apprch.app.model.Task
import com.apprch.app.model.toTask
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

    suspend fun refreshTask(context: Context, taskId: String, groupId: String) {
        if (FirebaseAuth.getInstance().currentUser == null) return
        val db = FirebaseFirestore.getInstance()
        val task = db.collection("tasks").document(taskId).get().await().toTask()
            ?: return
        if (task.groupId != groupId) return
        snapshotFor(task)?.let {
            WidgetSnapshotStore.upsert(context.applicationContext, it)
            HeatmapGlanceWidget().updateAll(context.applicationContext)
        }
    }

    private suspend fun snapshotsIn(groupId: String): List<WidgetTriggerSnapshot> {
        val db = FirebaseFirestore.getInstance()
        val docs = db.collection("tasks").whereEqualTo("groupId", groupId).get().await()
        return docs.documents.mapNotNull { it.toTask() }.mapNotNull { snapshotFor(it) }
    }

    private suspend fun snapshotFor(task: Task): WidgetTriggerSnapshot? {
        val db = FirebaseFirestore.getInstance()
        val events = db.collection("events")
            .whereEqualTo("groupId", task.groupId)
            .whereEqualTo("taskId", task.id)
            .limit(400)
            .get()
            .await()
        val dates = events.documents.mapNotNull { (it.get("timestamp") as? Timestamp)?.toDate() }
        return WidgetSnapshotStore.make(
            id = task.id,
            name = task.name,
            icon = task.icon,
            accentColorHex = task.accentColorHex,
            dates = dates
        )
    }
}
