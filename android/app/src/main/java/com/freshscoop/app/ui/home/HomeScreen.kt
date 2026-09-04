package com.freshscoop.app.ui.home

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class FamilyEvent(
    val id: String,
    val type: String,
    val triggeredByUid: String,
    val timestamp: Date
) {
    val displayName get() = when (type) {
        "litter_cleaned" -> "Litter box cleaned"
        else -> type.replace("_", " ").replaceFirstChar { it.uppercase() }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    familyId: String,
    onManualLog: () -> Unit,
    onSignOut: () -> Unit
) {
    val db = remember { FirebaseFirestore.getInstance() }
    var events by remember { mutableStateOf<List<FamilyEvent>>(emptyList()) }
    var authorNames by remember { mutableStateOf<Map<String, String>>(emptyMap()) }

    DisposableEffect(familyId) {
        val registration = db.collection("events")
            .whereEqualTo("familyId", familyId)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(50)
            .addSnapshotListener { snapshot, _ ->
                val newEvents = snapshot?.documents?.mapNotNull { doc ->
                    val ts = doc.getTimestamp("timestamp") ?: return@mapNotNull null
                    FamilyEvent(
                        id = doc.id,
                        type = doc.getString("type") ?: return@mapNotNull null,
                        triggeredByUid = doc.getString("triggeredByUid") ?: return@mapNotNull null,
                        timestamp = ts.toDate()
                    )
                } ?: emptyList()
                events = newEvents
            }
        onDispose { registration.remove() }
    }

    // Load display names for new UIDs
    LaunchedEffect(events) {
        val missing = events.map { it.triggeredByUid }.distinct()
            .filter { it !in authorNames }
        for (uid in missing) {
            try {
                val doc = db.collection("users").document(uid).get().await()
                val name = doc.getString("displayName") ?: "Someone"
                authorNames = authorNames + (uid to name)
            } catch (_: Exception) {}
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Fresh Scoop 🐱") },
                actions = {
                    TextButton(onClick = onSignOut) { Text("Sign out") }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onManualLog,
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("Log clean") }
            )
        }
    ) { padding ->
        if (events.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🐱", style = MaterialTheme.typography.displayMedium)
                    Spacer(Modifier.height(16.dp))
                    Text("No events yet", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Tap the NFC tag to log the first clean!",
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
private fun EventRow(event: FamilyEvent, authorName: String?) {
    val formatter = remember { SimpleDateFormat("MMM d 'at' h:mm a", Locale.getDefault()) }
    ListItem(
        headlineContent = { Text(event.displayName) },
        supportingContent = {
            Text("${authorName ?: "Someone"} · ${formatter.format(event.timestamp)}")
        }
    )
}
