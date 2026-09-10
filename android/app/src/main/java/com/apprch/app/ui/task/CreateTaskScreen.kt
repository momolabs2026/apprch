package com.apprch.app.ui.task

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.apprch.app.model.Task
import com.apprch.app.model.TaskAccent
import com.apprch.app.model.colorFromHex
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

private val icons = listOf("📌", "✅", "🏠", "🧹", "💊", "📦", "⭐", "💧", "🍽️", "🔑", "📬", "🗑️", "🚗", "🔔", "🌱", "🧺")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateTaskScreen(
    groupId: String,
    solo: Boolean,
    editing: Task? = null,
    onDismiss: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var name by remember { mutableStateOf(editing?.name.orEmpty()) }
    var icon by remember { mutableStateOf(editing?.icon ?: "📌") }
    var notificationMessage by remember { mutableStateOf(editing?.notificationMessage.orEmpty()) }
    var messageEdited by remember { mutableStateOf(editing != null) }
    var visualization by remember { mutableStateOf(editing?.visualization ?: "log") }
    var accentHex by remember { mutableStateOf(editing?.accentColorHex ?: TaskAccent.fallbackHex) }
    var createdId by remember { mutableStateOf<String?>(null) }
    var isSaving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    fun suggested(forName: String) = if (forName.isBlank()) "" else "$icon ${forName.trim()}"

    if (createdId != null) {
        val url = "apprch://open?id=$createdId"
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Tag link") },
                    actions = { TextButton(onClick = onDismiss) { Text("Done") } }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .padding(padding)
                    .padding(24.dp)
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(icon, style = MaterialTheme.typography.displayMedium)
                Text(name.ifBlank { "Task created" }, style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(12.dp))
                Text(
                    "Copy this as a URI (not a website). Tapping the tag opens Apprch and logs it.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(16.dp))
                Text(url, style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(16.dp))
                Button(onClick = { copyText(context, url) }, modifier = Modifier.fillMaxWidth()) {
                    Text("Copy link")
                }
                Spacer(Modifier.height(12.dp))
                NfcWriteButton(url)
            }
        }
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (editing == null) "Create a Task" else "Edit Task") },
                navigationIcon = { TextButton(onClick = onDismiss) { Text("Cancel") } },
                actions = {
                    TextButton(
                        enabled = name.isNotBlank() && notificationMessage.isNotBlank() && !isSaving,
                        onClick = {
                            scope.launch {
                                isSaving = true
                                error = null
                                try {
                                    val uid = FirebaseAuth.getInstance().currentUser?.uid
                                        ?: throw IllegalStateException("Please sign in again.")
                                    val payload = hashMapOf<String, Any>(
                                        "name" to name.trim(),
                                        "icon" to icon,
                                        "notificationMessage" to notificationMessage.trim(),
                                        "visualizationType" to visualization,
                                        "accentColorHex" to accentHex
                                    )
                                    val db = FirebaseFirestore.getInstance()
                                    if (editing != null) {
                                        db.collection("tasks").document(editing.id).update(payload).await()
                                        onDismiss()
                                    } else {
                                        payload["groupId"] = groupId
                                        payload["createdByUid"] = uid
                                        payload["createdAt"] = FieldValue.serverTimestamp()
                                        payload["eventCount"] = 0
                                        val ref = db.collection("tasks").document()
                                        ref.set(payload).await()
                                        createdId = ref.id
                                    }
                                } catch (e: Exception) {
                                    error = e.localizedMessage
                                }
                                isSaving = false
                            }
                        }
                    ) { Text("Save") }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedTextField(
                value = name,
                onValueChange = {
                    name = it
                    if (!messageEdited) notificationMessage = suggested(it)
                },
                label = { Text("e.g. Took out the trash") },
                modifier = Modifier.fillMaxWidth()
            )
            Text("Icon", style = MaterialTheme.typography.titleSmall)
            LazyVerticalGrid(
                columns = GridCells.Fixed(8),
                modifier = Modifier.height(96.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(icons) { candidate ->
                    Text(
                        candidate,
                        modifier = Modifier
                            .clickable {
                                icon = candidate
                                if (!messageEdited) notificationMessage = suggested(name)
                            }
                            .background(
                                if (icon == candidate) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                                else MaterialTheme.colorScheme.surface
                            )
                            .padding(6.dp),
                        style = MaterialTheme.typography.titleLarge
                    )
                }
            }
            OutlinedTextField(
                value = notificationMessage,
                onValueChange = {
                    notificationMessage = it
                    messageEdited = true
                },
                label = { Text(if (solo) "Reminder note" else "Notification message") },
                modifier = Modifier.fillMaxWidth()
            )
            Text("Visualization", style = MaterialTheme.typography.titleSmall)
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                SegmentedButton(
                    selected = visualization == "log",
                    onClick = { visualization = "log" },
                    shape = SegmentedButtonDefaults.itemShape(0, 2)
                ) { Text("Log") }
                SegmentedButton(
                    selected = visualization == "counter",
                    onClick = { visualization = "counter" },
                    shape = SegmentedButtonDefaults.itemShape(1, 2)
                ) { Text("Counter") }
            }
            if (editing != null) {
                Text("NFC tag", style = MaterialTheme.typography.titleSmall)
                Text(editing.tagUrl, style = MaterialTheme.typography.bodySmall)
                OutlinedButton(onClick = { copyText(context, editing.tagUrl) }, modifier = Modifier.fillMaxWidth()) {
                    Text("Copy link")
                }
                NfcWriteButton(editing.tagUrl)
            }
            Text("Accent color", style = MaterialTheme.typography.titleSmall)
            LazyVerticalGrid(
                columns = GridCells.Fixed(8),
                modifier = Modifier.height(56.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(TaskAccent.presets) { hex ->
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(colorFromHex(hex))
                            .then(
                                if (accentHex.equals(hex, ignoreCase = true)) {
                                    Modifier.border(2.dp, MaterialTheme.colorScheme.onSurface, CircleShape)
                                } else Modifier
                            )
                            .clickable { accentHex = hex }
                    )
                }
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }
}

private fun copyText(context: Context, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Apprch", text))
}
