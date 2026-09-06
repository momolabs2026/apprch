package com.apprch.app.ui.confirm

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

@Composable
fun ConfirmEventDialog(eventType: String, familyId: String, onDismiss: () -> Unit) {
    val functions = remember { FirebaseFunctions.getInstance() }
    val scope = rememberCoroutineScope()

    var isSending by remember { mutableStateOf(false) }
    var didSend by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val displayName = eventType.replace("_", " ").replaceFirstChar { it.uppercase() }

    LaunchedEffect(didSend) {
        if (didSend) {
            delay(1500)
            onDismiss()
        }
    }

    AlertDialog(
        onDismissRequest = { if (!isSending) onDismiss() },
        title = { Text(displayName) },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (didSend) {
                    Text("Notification sent!", style = MaterialTheme.typography.bodyLarge)
                } else {
                    Text("Send a push notification to your family?")
                    errorMessage?.let {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            it,
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        },
        confirmButton = {
            if (!didSend) {
                Button(
                    onClick = {
                        scope.launch {
                            isSending = true
                            errorMessage = null
                            try {
                                functions.getHttpsCallable("logEvent")
                                    .call(mapOf("type" to eventType, "familyId" to familyId))
                                    .await()
                                didSend = true
                            } catch (e: Exception) {
                                errorMessage = e.localizedMessage
                            }
                            isSending = false
                        }
                    },
                    enabled = !isSending
                ) {
                    if (isSending) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                    else Text("Send notification")
                }
            }
        },
        dismissButton = {
            if (!didSend && !isSending) {
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        }
    )
}
