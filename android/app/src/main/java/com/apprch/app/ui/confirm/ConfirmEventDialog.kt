package com.apprch.app.ui.confirm

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.apprch.app.data.EventStore
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.delay
import kotlinx.coroutines.tasks.await

@Composable
fun ConfirmEventDialog(taskId: String, onDismiss: () -> Unit) {
    var isSending by remember { mutableStateOf(true) }
    var didSend by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var title by remember { mutableStateOf("Task") }

    LaunchedEffect(taskId) {
        try {
            val doc = FirebaseFirestore.getInstance().collection("tasks").document(taskId).get().await()
            val groupId = doc.getString("groupId") ?: throw IllegalStateException("This task isn’t available.")
            title = listOfNotNull(doc.getString("icon"), doc.getString("name")).joinToString(" ").ifBlank { "Task" }
            EventStore.log(taskId, groupId)
            didSend = true
        } catch (e: Exception) {
            errorMessage = EventStore.userFacingMessage(e)
        }
        isSending = false
    }

    LaunchedEffect(didSend) {
        if (didSend) {
            delay(1200)
            onDismiss()
        }
    }

    AlertDialog(
        onDismissRequest = { if (!isSending) onDismiss() },
        title = { Text(title) },
        text = {
            Column {
                when {
                    isSending -> CircularProgressIndicator()
                    didSend -> Text("Logged", style = MaterialTheme.typography.bodyLarge)
                    else -> errorMessage?.let {
                        Text(it, color = MaterialTheme.colorScheme.error)
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        },
        confirmButton = {
            if (!isSending) {
                TextButton(onClick = onDismiss) { Text("Done") }
            }
        }
    )
}
