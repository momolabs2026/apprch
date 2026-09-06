package com.apprch.app.ui.home

import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.apprch.app.data.EventStore
import com.apprch.app.data.GroupStore
import com.apprch.app.model.Space
import com.apprch.app.model.Trigger
import com.apprch.app.model.toTrigger
import com.apprch.app.ui.components.MemberChipsRow
import com.apprch.app.ui.invite.InviteScreen
import com.apprch.app.ui.profile.ProfileScreen
import com.apprch.app.ui.trigger.CreateTriggerScreen
import com.apprch.app.ui.trigger.MoveTriggerScreen
import com.apprch.app.ui.trigger.TriggerDetailScreen
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit
import java.util.Date

private enum class HomeSection { Solo, Groups }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    active: Space,
    spaces: List<Space>,
    onSelectSpace: (String) -> Unit,
    onSignOut: () -> Unit
) {
    val personal = spaces.firstOrNull { it.solo }
    val groups = spaces.filter { !it.solo }
    var section by remember { mutableStateOf(if (active.solo) HomeSection.Solo else HomeSection.Groups) }
    var showingProfile by remember { mutableStateOf(false) }
    var showingAddGroup by remember { mutableStateOf(false) }
    var showingJoin by remember { mutableStateOf(false) }
    var openedGroup by remember { mutableStateOf<Space?>(null) }
    var selectedTrigger by remember { mutableStateOf<Trigger?>(null) }
    var editingTrigger by remember { mutableStateOf<Trigger?>(null) }
    var movingTrigger by remember { mutableStateOf<Trigger?>(null) }
    var creatingIn by remember { mutableStateOf<Space?>(null) }
    var invitingGroupId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(active.id) {
        section = if (active.solo) HomeSection.Solo else HomeSection.Groups
    }

    LaunchedEffect(section, groups.size) {
        val target = when (section) {
            HomeSection.Solo -> personal
            HomeSection.Groups -> if (groups.size == 1) groups.first() else if (active.solo) groups.firstOrNull() else active
        }
        if (target != null && target.id != active.id) onSelectSpace(target.id)
    }

    when {
        showingProfile -> ProfileScreen(onDismiss = { showingProfile = false }, onSignOut = onSignOut)
        invitingGroupId != null -> InviteScreen(groupId = invitingGroupId!!, onDismiss = { invitingGroupId = null })
        creatingIn != null -> CreateTriggerScreen(
            groupId = creatingIn!!.id,
            solo = creatingIn!!.solo,
            onDismiss = { creatingIn = null }
        )
        editingTrigger != null -> CreateTriggerScreen(
            groupId = editingTrigger!!.groupId,
            solo = spaces.firstOrNull { it.id == editingTrigger!!.groupId }?.solo == true,
            editing = editingTrigger,
            onDismiss = { editingTrigger = null }
        )
        movingTrigger != null -> MoveTriggerScreen(
            trigger = movingTrigger!!,
            spaces = spaces,
            onDismiss = { movingTrigger = null },
            onMoved = { groupId ->
                movingTrigger = null
                selectedTrigger = null
                onSelectSpace(groupId)
            }
        )
        selectedTrigger != null -> TriggerDetailScreen(
            initial = selectedTrigger!!,
            spaces = spaces,
            onBack = { selectedTrigger = null },
            onEdit = { editingTrigger = it },
            onMove = { movingTrigger = it }
        )
        else -> Scaffold(
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            when (section) {
                                HomeSection.Solo -> "Solo"
                                HomeSection.Groups -> if (groups.size == 1) groups[0].title else openedGroup?.title ?: "Groups"
                            }
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = { showingProfile = true }) {
                            Icon(Icons.Filled.Person, contentDescription = "You")
                        }
                    },
                    actions = {
                        val spaceForInvite = when {
                            section == HomeSection.Groups && groups.size == 1 -> groups[0]
                            openedGroup != null -> openedGroup
                            else -> null
                        }
                        if (spaceForInvite != null && !spaceForInvite.solo) {
                            IconButton(onClick = { invitingGroupId = spaceForInvite.id }) {
                                Icon(Icons.Outlined.PersonAdd, contentDescription = "Invite")
                            }
                        }
                        val spaceForCreate = when (section) {
                            HomeSection.Solo -> personal
                            HomeSection.Groups -> openedGroup ?: groups.singleOrNull()
                        }
                        if (spaceForCreate != null) {
                            IconButton(onClick = { creatingIn = spaceForCreate }) {
                                Icon(Icons.Filled.Add, contentDescription = "Create a Trigger")
                            }
                        }
                    }
                )
            }
        ) { padding ->
            Column(Modifier.padding(padding)) {
                SingleChoiceSegmentedButtonRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    SegmentedButton(
                        selected = section == HomeSection.Solo,
                        onClick = {
                            section = HomeSection.Solo
                            openedGroup = null
                        },
                        shape = SegmentedButtonDefaults.itemShape(0, 2)
                    ) { Text("Solo") }
                    SegmentedButton(
                        selected = section == HomeSection.Groups,
                        onClick = { section = HomeSection.Groups },
                        shape = SegmentedButtonDefaults.itemShape(1, 2)
                    ) { Text("Groups") }
                }

                when (section) {
                    HomeSection.Solo -> {
                        if (personal != null) {
                            TriggerList(
                                space = personal,
                                onOpen = { selectedTrigger = it },
                                onCreate = { creatingIn = personal }
                            )
                        } else {
                            EmptyState("No Solo space yet", "Pull to refresh, or sign out and back in.")
                        }
                    }
                    HomeSection.Groups -> when {
                        groups.isEmpty() -> EmptyState(
                            title = "No groups yet",
                            body = "Solo stays yours. A group is a separate space you can move Triggers into.",
                            primary = "Create a group" to { showingAddGroup = true },
                            secondary = "Join a group" to { showingJoin = true }
                        )
                        groups.size == 1 -> TriggerList(
                            space = groups[0],
                            onOpen = { selectedTrigger = it },
                            onCreate = { creatingIn = groups[0] }
                        )
                        openedGroup != null -> TriggerList(
                            space = openedGroup!!,
                            onOpen = { selectedTrigger = it },
                            onCreate = { creatingIn = openedGroup }
                        )
                        else -> LazyColumn {
                            items(groups, key = { it.id }) { group ->
                                ListItem(
                                    headlineContent = { Text(group.title) },
                                    modifier = Modifier.clickable {
                                        openedGroup = group
                                        onSelectSpace(group.id)
                                    }
                                )
                            }
                            item {
                                TextButton(onClick = { showingAddGroup = true }) { Text("Create a group") }
                                TextButton(onClick = { showingJoin = true }) { Text("Join a group") }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showingAddGroup) {
        NameDialog(
            title = "Create a group",
            label = "Group name (e.g. The Delfinos)",
            confirm = "Create",
            onDismiss = { showingAddGroup = false },
            onConfirm = { GroupStore.create(it, solo = false) }
        )
    }
    if (showingJoin) {
        NameDialog(
            title = "Join a group",
            label = "Invite code",
            confirm = "Join",
            onDismiss = { showingJoin = false },
            onConfirm = { GroupStore.join(it) }
        )
    }
}

@Composable
private fun TriggerList(
    space: Space,
    onOpen: (Trigger) -> Unit,
    onCreate: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var triggers by remember { mutableStateOf<List<Trigger>>(emptyList()) }
    var names by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var toggleError by remember { mutableStateOf<String?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    DisposableEffect(space.id) {
        val registration = FirebaseFirestore.getInstance()
            .collection("triggers")
            .whereEqualTo("groupId", space.id)
            .addSnapshotListener { snapshot, _ ->
                triggers = snapshot?.documents?.mapNotNull { it.toTrigger() }
                    ?.sortedByDescending { it.lastTriggeredAt?.time ?: it.createdAt?.time ?: 0L }
                    ?: emptyList()
                val missing = triggers.mapNotNull { it.lastTriggeredByUid }.distinct().filter { it !in names }
                missing.forEach { uid ->
                    FirebaseFirestore.getInstance().collection("users").document(uid).get()
                        .addOnSuccessListener { doc ->
                            val name = doc.getString("displayName") ?: return@addOnSuccessListener
                            names = names + (uid to name)
                        }
                }
            }
        onDispose { registration.remove() }
    }

    Column(Modifier.fillMaxSize()) {
        if (!space.solo) {
            MemberChipsRow(groupId = space.id)
        }
        if (triggers.isEmpty()) {
            EmptyState(
                title = "No triggers yet",
                body = if (space.solo) {
                    "Triggers in Solo are only for you. Open one later to move it into a group."
                } else {
                    "Triggers here are shared with this group."
                },
                primary = "Create a Trigger" to onCreate
            )
        } else {
            LazyColumn(Modifier.fillMaxSize()) {
                items(triggers, key = { it.id }) { trigger ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onOpen(trigger) }
                            .padding(horizontal = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        ListItem(
                            headlineContent = { Text("${trigger.icon}  ${trigger.name}") },
                            supportingContent = { Text(activityText(trigger, names[trigger.lastTriggeredByUid])) },
                            modifier = Modifier.weight(1f)
                        )
                        IconButton(onClick = {
                            scope.launch {
                                try {
                                    EventStore.toggleToday(trigger.id, trigger.groupId, trigger.isCompletedToday)
                                } catch (e: Exception) {
                                    toggleError = EventStore.userFacingMessage(e)
                                }
                            }
                        }) {
                            Icon(
                                imageVector = if (trigger.isCompletedToday) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                                contentDescription = if (trigger.isCompletedToday) "Mark not done today" else "Mark done today",
                                tint = if (trigger.isCompletedToday) trigger.accent else Color.Unspecified
                            )
                        }
                    }
                }
            }
        }
    }

    if (toggleError != null) {
        AlertDialog(
            onDismissRequest = { toggleError = null },
            confirmButton = { TextButton(onClick = { toggleError = null }) { Text("OK") } },
            title = { Text("Couldn’t update") },
            text = { Text(toggleError!!) }
        )
    }
}

@Composable
private fun EmptyState(
    title: String,
    body: String,
    primary: Pair<String, () -> Unit>? = null,
    secondary: Pair<String, () -> Unit>? = null
) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(24.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            primary?.let { (label, action) ->
                Button(onClick = action, modifier = Modifier.padding(top = 16.dp)) { Text(label) }
            }
            secondary?.let { (label, action) ->
                OutlinedButton(onClick = action, modifier = Modifier.padding(top = 8.dp)) { Text(label) }
            }
        }
    }
}

@Composable
private fun NameDialog(
    title: String,
    label: String,
    confirm: String,
    onDismiss: () -> Unit,
    onConfirm: suspend (String) -> Unit
) {
    var value by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column {
                OutlinedTextField(value = value, onValueChange = { value = it }, label = { Text(label) })
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = {
            TextButton(
                enabled = value.isNotBlank() && !loading,
                onClick = {
                    scope.launch {
                        loading = true
                        try {
                            onConfirm(value.trim())
                            onDismiss()
                        } catch (e: Exception) {
                            error = GroupStore.userFacingMessage(e)
                        }
                        loading = false
                    }
                }
            ) { Text(confirm) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

private fun activityText(trigger: Trigger, authorName: String?): String {
    val last = trigger.lastTriggeredAt ?: return if (trigger.eventCount > 0) "Logged" else "No activity yet"
    val who = authorName ?: "Someone"
    val minutes = TimeUnit.MILLISECONDS.toMinutes(Date().time - last.time).coerceAtLeast(1)
    val whenText = when {
        minutes < 60 -> "$minutes min ago"
        minutes < 1440 -> "${minutes / 60} hr ago"
        else -> "${minutes / 1440} days ago"
    }
    return "Last logged $whenText by $who"
}
