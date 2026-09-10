package com.apprch.app.ui.invite

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.apprch.app.data.GroupStore
import com.apprch.app.model.SpaceMember
import com.apprch.app.ui.components.MemberAvatar
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InviteScreen(groupId: String, onDismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var inviteCode by remember { mutableStateOf<String?>(null) }
    var isSolo by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<SpaceMember>>(emptyList()) }
    var memberIds by remember { mutableStateOf(setOf<String>()) }
    var addedIds by remember { mutableStateOf(setOf<String>()) }
    var isSearching by remember { mutableStateOf(false) }
    var searchError by remember { mutableStateOf<String?>(null) }
    var searchJob by remember { mutableStateOf<Job?>(null) }

    val excluded = memberIds + addedIds + setOfNotNull(FirebaseAuth.getInstance().currentUser?.uid)

    LaunchedEffect(groupId) {
        try {
            val info = GroupStore.inviteCode(groupId)
            isSolo = info.second
            inviteCode = if (info.second) null else info.first ?: GroupStore.enableInvites(groupId)
            if (!info.second) {
                memberIds = GroupStore.members(groupId).map { it.id }.toSet()
            }
        } catch (e: Exception) {
            error = GroupStore.userFacingMessage(e)
        }
        isLoading = false
    }

    LaunchedEffect(query) {
        searchJob?.cancel()
        if (query.trim().length < 2) {
            results = emptyList()
            return@LaunchedEffect
        }
        searchJob = scope.launch {
            delay(250)
            isSearching = true
            searchError = null
            try {
                results = GroupStore.searchUsers(query, excluded)
            } catch (e: Exception) {
                searchError = GroupStore.userFacingMessage(e)
                results = emptyList()
            }
            isSearching = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Invite") },
                actions = { TextButton(onClick = onDismiss) { Text("Done") } }
            )
        }
    ) { padding ->
        when {
            isLoading -> CircularProgressIndicator(Modifier.padding(padding).padding(24.dp))
            isSolo -> Text(
                "Solo stays private. Open a Task and share it into a group.",
                modifier = Modifier.padding(padding).padding(24.dp)
            )
            error != null -> Text(error!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(padding).padding(24.dp))
            else -> LazyColumn(
                modifier = Modifier.padding(padding).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    Text("Find someone", style = MaterialTheme.typography.titleMedium)
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        label = { Text("Search by name or email") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                when {
                    isSearching -> item { CircularProgressIndicator() }
                    query.trim().length < 2 -> item {
                        Text("Type at least 2 characters.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    results.isEmpty() -> item {
                        Text("No one matches that yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    else -> items(results, key = { it.id }) { person ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            MemberAvatar(person, 36.dp)
                            Column(Modifier.weight(1f)) {
                                Text(person.name)
                                person.email?.let {
                                    Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                            if (person.id in addedIds || person.id in memberIds) {
                                Text("Added", color = MaterialTheme.colorScheme.onSurfaceVariant)
                            } else {
                                Button(onClick = {
                                    scope.launch {
                                        try {
                                            GroupStore.addMember(person.id, groupId)
                                            addedIds = addedIds + person.id
                                            memberIds = memberIds + person.id
                                            results = results.filterNot { it.id == person.id }
                                        } catch (e: Exception) {
                                            searchError = GroupStore.userFacingMessage(e)
                                        }
                                    }
                                }) { Text("Add") }
                            }
                        }
                    }
                }
                searchError?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
                item {
                    Text("Or share the invite code", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Anyone with this code can join this group. Your Solo space stays yours.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(inviteCode.orEmpty(), style = MaterialTheme.typography.headlineMedium)
                    Button(
                        onClick = {
                            val code = inviteCode ?: return@Button
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, "Join my Apprch group with invite code $code")
                            }
                            context.startActivity(Intent.createChooser(send, "Share code"))
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Share code") }
                    OutlinedButton(
                        onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("Invite", inviteCode.orEmpty()))
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Copy code") }
                }
            }
        }
    }
}
