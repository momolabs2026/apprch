package com.apprch.app.ui.group

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.intl.Locale
import androidx.compose.ui.text.toUpperCase
import androidx.compose.ui.unit.dp
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

private enum class Mode { CHOOSE, CREATE, JOIN }

@Composable
fun GroupSetupScreen(onSignOut: () -> Unit) {
    val functions = remember { FirebaseFunctions.getInstance() }
    val scope = rememberCoroutineScope()

    var mode by remember { mutableStateOf(Mode.CHOOSE) }
    var groupName by remember { mutableStateOf("") }
    var inviteCode by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .systemBarsPadding()
            .imePadding()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Set up your group", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(32.dp))

        when (mode) {
            Mode.CHOOSE -> {
                Button(
                    onClick = { mode = Mode.CREATE },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Create a new group") }
                Spacer(Modifier.height(12.dp))
                OutlinedButton(
                    onClick = { mode = Mode.JOIN },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Join with invite code") }
            }

            Mode.CREATE -> {
                OutlinedTextField(
                    value = groupName,
                    onValueChange = { groupName = it },
                    label = { Text("Group name (e.g. The Delfinos)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                ErrorLabel(errorMessage)
                Spacer(Modifier.height(16.dp))
                SubmitButton("Create group", isLoading, enabled = groupName.isNotBlank()) {
                    scope.launch {
                        isLoading = true
                        errorMessage = null
                        try {
                            functions.getHttpsCallable("createGroup")
                                .call(mapOf("name" to groupName.trim()))
                                .await()
                        } catch (e: Exception) {
                            errorMessage = e.localizedMessage
                        }
                        isLoading = false
                    }
                }
                TextButton(onClick = { mode = Mode.CHOOSE }) { Text("Back") }
            }

            Mode.JOIN -> {
                OutlinedTextField(
                    value = inviteCode,
                    onValueChange = { inviteCode = it.toUpperCase(Locale.current) },
                    label = { Text("Invite code") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                ErrorLabel(errorMessage)
                Spacer(Modifier.height(16.dp))
                SubmitButton("Join group", isLoading, enabled = inviteCode.isNotBlank()) {
                    scope.launch {
                        isLoading = true
                        errorMessage = null
                        try {
                            functions.getHttpsCallable("joinGroup")
                                .call(mapOf("inviteCode" to inviteCode.trim()))
                                .await()
                        } catch (e: Exception) {
                            errorMessage = e.localizedMessage
                        }
                        isLoading = false
                    }
                }
                TextButton(onClick = { mode = Mode.CHOOSE }) { Text("Back") }
            }
        }

        Spacer(Modifier.height(32.dp))
        TextButton(onClick = onSignOut) { Text("Sign out") }
    }
}

@Composable
private fun ErrorLabel(message: String?) {
    message?.let {
        Spacer(Modifier.height(8.dp))
        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun SubmitButton(
    label: String,
    isLoading: Boolean,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled && !isLoading,
        modifier = Modifier.fillMaxWidth()
    ) {
        if (isLoading) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
        else Text(label)
    }
}
