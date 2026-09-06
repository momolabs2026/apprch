package com.apprch.app.ui.home

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import com.apprch.app.data.GroupStore
import com.apprch.app.model.GroupEvent
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    groupId: String,
    solo: Boolean = false,
    onManualLog: () -> Unit,
    onSignOut: () -> Unit
) {
    val db = remember { FirebaseFirestore.getInstance() }
    val context = LocalContext.current
    var events by remember { mutableStateOf<List<GroupEvent>>(emptyList()) }
    var authorNames by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var showingInvite by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    DisposableEffect(groupId) {
        val registration = db.collection("events")
            .whereEqualTo("groupId", groupId)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(50)
            .addSnapshotListener { snapshot, _ ->
                events = snapshot?.documents?.mapNotNull { doc ->
                    val ts = doc.getTimestamp("timestamp") ?: return@mapNotNull null
                    GroupEvent(
                        id = doc.id,
                        type = doc.getString("type") ?: return@mapNotNull null,
                        triggeredByUid = doc.getString("triggeredByUid") ?: return@mapNotNull null,
                        timestamp = ts.toDate()
                    )
                } ?: emptyList()
            }
        onDispose { registration.remove() }
    }

    LaunchedEffect(events) {
        val missing = events.map { it.triggeredByUid }.distinct()
            .filter { it !in authorNames }
        for (uid in missing) {
            try {
                val doc = db.collection("users").document(uid).get().await()
                val name = doc.getString("displayName") ?: "Someone"
                authorNames = authorNames + (uid to name)
            } catch (_: Exception) {
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Apprch") },
                actions = {
                    TextButton(onClick = { showingInvite = true }) {
                        Text(if (solo) "Invite people" else "Invite")
                    }
                    TextButton(onClick = onSignOut) { Text("Sign out") }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onManualLog,
                icon = { Icon(Icons.Filled.CheckCircle, contentDescription = null) },
                text = { Text("Log") }
            )
        }
    ) { padding ->
        if (showingInvite) {
            InviteDialog(groupId = groupId, solo = solo, onDismiss = { showingInvite = false })
        }
        if (events.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("No events yet", style = MaterialTheme.typography.titleMedium)
                    Text(
                        if (solo) "Create a Trigger on iOS, then tap its tag to log it for yourself."
                        else "Create a Trigger on iOS, then tap its NFC tag.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            LazyColumn(modifier = Modifier.padding(padding)) {
                items(events, key = { it.id }) { event ->
                    EventRow(event = event, authorName = authorNames[event.triggeredByUid])
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun InviteDialog(groupId: String, solo: Boolean, onDismiss: () -> Unit) {
    var code by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(!solo) }

    LaunchedEffect(groupId, solo) {
        if (!solo) {
            try {
                code = GroupStore.enableInvites(groupId)
            } catch (e: Exception) {
                error = GroupStore.userFacingMessage(e)
            }
            loading = false
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Invite") },
        text = {
            Column {
                when {
                    loading -> CircularProgressIndicator()
                    code != null -> Text(
                        code!!,
                        style = MaterialTheme.typography.headlineMedium
                    )
                    else -> {
                        Text("Solo stays private. On iOS, open a Trigger and share that one into a group.")
                    }
                }
                error?.let {
                    Spacer(Modifier.height(8.dp))
                    Text(it, color = MaterialTheme.colorScheme.error)
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Done") }
        },
        dismissButton = {
            if (code == null) {
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        }
    )
}

@Composable
private fun EventRow(event: GroupEvent, authorName: String?) {
    val formatter = remember { SimpleDateFormat("MMM d 'at' h:mm a", Locale.getDefault()) }
    ListItem(
        headlineContent = { Text(event.displayName) },
        supportingContent = {
            Text("${authorName ?: "Someone"} · ${formatter.format(event.timestamp)}")
        }
    )
}
