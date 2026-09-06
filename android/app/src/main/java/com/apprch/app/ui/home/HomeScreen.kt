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
import com.apprch.app.model.FamilyEvent
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    familyId: String,
    onManualLog: () -> Unit,
    onSignOut: () -> Unit
) {
    val db = remember { FirebaseFirestore.getInstance() }
    val context = LocalContext.current
    var events by remember { mutableStateOf<List<FamilyEvent>>(emptyList()) }
    var authorNames by remember { mutableStateOf<Map<String, String>>(emptyMap()) }

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

    DisposableEffect(familyId) {
        val registration = db.collection("events")
            .whereEqualTo("familyId", familyId)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(50)
            .addSnapshotListener { snapshot, _ ->
                events = snapshot?.documents?.mapNotNull { doc ->
                    val ts = doc.getTimestamp("timestamp") ?: return@mapNotNull null
                    FamilyEvent(
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
                        "Create a Trigger on iOS, then tap its NFC tag.",
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
