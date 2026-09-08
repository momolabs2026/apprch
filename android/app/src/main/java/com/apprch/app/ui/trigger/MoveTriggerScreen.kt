package com.apprch.app.ui.trigger

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.apprch.app.data.GroupStore
import com.apprch.app.model.Space
import com.apprch.app.model.Trigger
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoveTriggerScreen(
    trigger: Trigger,
    spaces: List<Space>,
    onDismiss: () -> Unit,
    onMoved: (String) -> Unit
) {
    val scope = rememberCoroutineScope()
    var newGroupName by remember { mutableStateOf("") }
    var isSaving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val destinations = spaces.filter { it.id != trigger.groupId }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Share this Trigger") },
                navigationIcon = { TextButton(onClick = onDismiss, enabled = !isSaving) { Text("Cancel") } }
            )
        }
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).padding(16.dp)) {
            item {
                Text(
                    "This Trigger stays in Solo unless you move it. History moves with it.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 16.dp)
                )
            }
            if (destinations.isNotEmpty()) {
                item { Text("Move to an existing space", style = MaterialTheme.typography.titleMedium) }
                items(destinations, key = { it.id }) { space ->
                    ListItem(
                        headlineContent = { Text(space.title) },
                        modifier = Modifier.clickable(enabled = !isSaving) {
                            scope.launch {
                                isSaving = true
                                error = null
                                try {
                                    GroupStore.moveTrigger(trigger.id, space.id)
                                    onMoved(space.id)
                                } catch (e: Exception) {
                                    error = GroupStore.userFacingMessage(e)
                                }
                                isSaving = false
                            }
                        }
                    )
                }
            }
            item {
                Column(Modifier.padding(top = 16.dp)) {
                    Text("Or create a new group", style = MaterialTheme.typography.titleMedium)
                    OutlinedTextField(
                        value = newGroupName,
                        onValueChange = { newGroupName = it },
                        label = { Text("Group name (e.g. The Delfinos)") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Button(
                        onClick = {
                            scope.launch {
                                isSaving = true
                                error = null
                                try {
                                    val id = GroupStore.createGroup(newGroupName, trigger.id)
                                    onMoved(id)
                                } catch (e: Exception) {
                                    error = GroupStore.userFacingMessage(e)
                                }
                                isSaving = false
                            }
                        },
                        enabled = !isSaving && newGroupName.isNotBlank(),
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                    ) { Text("Create group with this Trigger") }
                    error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 8.dp)) }
                }
            }
        }
    }
}
