package com.freshscoop.app.ui.family

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
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
fun FamilySetupScreen(onSignOut: () -> Unit) {
    val functions = remember { FirebaseFunctions.getInstance() }
    val scope = rememberCoroutineScope()

    var mode by remember { mutableStateOf(Mode.CHOOSE) }
    var familyName by remember { mutableStateOf("") }
    var inviteCode by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Set up your family", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(32.dp))

        when (mode) {
            Mode.CHOOSE -> {
                Button(
                    onClick = { mode = Mode.CREATE },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Create a new family") }
                Spacer(Modifier.height(12.dp))
                OutlinedButton(
                    onClick = { mode = Mode.JOIN },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Join with invite code") }
            }

            Mode.CREATE -> {
                OutlinedTextField(
                    value = familyName,
                    onValueChange = { familyName = it },
                    label = { Text("Family name") },
                    modifier = Modifier.fillMaxWidth()
                )
                ErrorLabel(errorMessage)
                Spacer(Modifier.height(16.dp))
                SubmitButton("Create family", isLoading) {
                    scope.launch {
                        isLoading = true; errorMessage = null
                        try {
                            functions.getHttpsCallable("createFamily")
                                .call(mapOf("name" to familyName)).await()
                        } catch (e: Exception) { errorMessage = e.localizedMessage }
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
                    modifier = Modifier.fillMaxWidth()
                )
                ErrorLabel(errorMessage)
                Spacer(Modifier.height(16.dp))
                SubmitButton("Join family", isLoading) {
                    scope.launch {
                        isLoading = true; errorMessage = null
                        try {
                            functions.getHttpsCallable("joinFamily")
                                .call(mapOf("inviteCode" to inviteCode)).await()
                        } catch (e: Exception) { errorMessage = e.localizedMessage }
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
private fun SubmitButton(label: String, isLoading: Boolean, onClick: () -> Unit) {
    Button(onClick = onClick, enabled = !isLoading, modifier = Modifier.fillMaxWidth()) {
        if (isLoading) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
        else Text(label)
    }
}
