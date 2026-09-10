package com.apprch.app.ui.task

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Widgets
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.updateAll
import com.apprch.app.model.Space
import com.apprch.app.model.Task
import com.apprch.app.model.TaskEvent
import com.apprch.app.model.isSameDay
import com.apprch.app.model.toTask
import com.apprch.app.model.toTaskEvent
import com.apprch.app.widget.HeatmapGlanceWidget
import com.apprch.app.widget.HeatmapWidgetInstaller
import com.apprch.app.widget.WidgetSnapshotStore
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.launch
import java.util.Date
import java.util.concurrent.TimeUnit

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskDetailScreen(
    initial: Task,
    spaces: List<Space>,
    onBack: () -> Unit,
    onEdit: (Task) -> Unit,
    onMove: (Task) -> Unit
) {
    var trigger by remember(initial.id) { mutableStateOf(initial) }
    var events by remember { mutableStateOf<List<TaskEvent>>(emptyList()) }
    var names by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var historyError by remember { mutableStateOf<String?>(null) }
    var showWidgetHelp by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    DisposableEffect(trigger.id, trigger.groupId) {
        val db = FirebaseFirestore.getInstance()
        val triggerReg = db.collection("tasks").document(trigger.id)
            .addSnapshotListener { snapshot, _ ->
                snapshot?.toTask()?.let { trigger = it }
            }
        val eventsReg = db.collection("events")
            .whereEqualTo("groupId", trigger.groupId)
            .whereEqualTo("taskId", trigger.id)
            .limit(400)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    historyError = error.localizedMessage
                    return@addSnapshotListener
                }
                historyError = null
                events = snapshot?.documents?.mapNotNull { it.toTaskEvent() }
                    ?.sortedByDescending { it.date.time }
                    ?: emptyList()
                WidgetSnapshotStore.upsert(
                    context,
                    WidgetSnapshotStore.make(
                        id = trigger.id,
                        name = trigger.name,
                        icon = trigger.icon,
                        accentColorHex = trigger.accentColorHex,
                        dates = events.map { it.date }
                    )
                )
                scope.launch { HeatmapGlanceWidget().updateAll(context) }
                val missing = events.map { it.loggedByUid }.distinct().filter { it !in names }
                missing.forEach { uid ->
                    db.collection("users").document(uid).get()
                        .addOnSuccessListener { doc ->
                            val name = doc.getString("displayName") ?: return@addOnSuccessListener
                            names = names + (uid to name)
                        }
                }
            }
        onDispose {
            triggerReg.remove()
            eventsReg.remove()
        }
    }

    val todayCount = events.count { isSameDay(it.date, Date()) }
    val todaySummary = when (todayCount) {
        0 -> "Not yet"
        1 -> "Done once"
        else -> "Done $todayCount times"
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("${trigger.icon} ${trigger.name}") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { onMove(trigger) }) {
                        Icon(Icons.Filled.Share, contentDescription = "Move")
                    }
                    IconButton(onClick = { onEdit(trigger) }) {
                        Icon(Icons.Filled.Edit, contentDescription = "Edit")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).padding(16.dp)) {
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Today", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        todaySummary,
                        color = if (todayCount == 0) MaterialTheme.colorScheme.onSurfaceVariant else trigger.accent
                    )
                }
                if (trigger.visualization == "counter") {
                    Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Total", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("${trigger.eventCount}")
                    }
                }
                TextButton(
                    onClick = {
                        HeatmapWidgetInstaller.pin(context, trigger.id) { showWidgetHelp = true }
                    },
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    Icon(Icons.Outlined.Widgets, contentDescription = null)
                    Text("Add Home Screen widget", modifier = Modifier.padding(start = 8.dp))
                }
            }
            item {
                Text("History", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 20.dp, bottom = 12.dp))
                historyError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    ?: ContributionGraph(events = events, accent = trigger.accent)
            }
            if (events.isEmpty()) {
                item {
                    Text(
                        "No activity yet. Check the circle on a day you do this.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 12.dp)
                    )
                }
            } else {
                items(events.take(8), key = { it.id }) { event ->
                    Column(Modifier.padding(vertical = 8.dp)) {
                        Text(names[event.loggedByUid] ?: "Someone")
                        Text(relativeString(event.date), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }

    if (showWidgetHelp) {
        AlertDialog(
            onDismissRequest = { showWidgetHelp = false },
            confirmButton = { TextButton(onClick = { showWidgetHelp = false }) { Text("OK") } },
            title = { Text("Add to Home Screen") },
            text = {
                Text("Touch and hold the Home Screen, choose Widgets, then add Apprch’s Task heatmap and pick this Task.")
            }
        )
    }
}

private fun relativeString(date: Date): String {
    val seconds = TimeUnit.MILLISECONDS.toSeconds(Date().time - date.time)
    return when {
        seconds < 60 -> "Just now"
        seconds < 3600 -> "${seconds / 60} min ago"
        seconds < 86_400 -> "${seconds / 3600} hr ago"
        else -> "${seconds / 86_400} days ago"
    }
}
