package com.apprch.app.ui.task

import android.app.Activity
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.apprch.app.nfc.NfcTagWriter

@Composable
fun NfcWriteButton(url: String) {
    val activity = LocalContext.current as? Activity
    val writer = remember(activity) { activity?.let { NfcTagWriter(it) } }
    var status by remember { mutableStateOf(NfcTagWriter.Status.Idle) }
    var message by remember { mutableStateOf("") }

    DisposableEffect(writer) {
        onDispose { writer?.stop() }
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        Button(
            onClick = {
                if (writer == null) {
                    status = NfcTagWriter.Status.Failed
                    message = "NFC isn’t available here."
                    return@Button
                }
                writer.startWrite(url) { next, text ->
                    status = next
                    message = text
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = status != NfcTagWriter.Status.Waiting
        ) {
            Text(if (status == NfcTagWriter.Status.Waiting) "Waiting for tag…" else "Write to tag")
        }
        if (writer?.isAvailable != true && status == NfcTagWriter.Status.Idle) {
            Spacer(Modifier.height(8.dp))
            Text(
                writer?.unavailableMessage ?: "This device doesn’t have NFC.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (message.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(
                message,
                style = MaterialTheme.typography.bodySmall,
                color = when (status) {
                    NfcTagWriter.Status.Success -> MaterialTheme.colorScheme.primary
                    NfcTagWriter.Status.Failed -> MaterialTheme.colorScheme.error
                    else -> MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
        }
    }
}
