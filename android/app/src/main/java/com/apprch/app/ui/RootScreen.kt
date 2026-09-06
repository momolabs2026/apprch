package com.apprch.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.apprch.app.ui.auth.AuthScreen
import com.apprch.app.ui.confirm.ConfirmEventDialog
import com.apprch.app.ui.group.GroupSetupScreen
import com.apprch.app.ui.home.HomeScreen

@Composable
fun RootScreen(state: AppState, viewModel: AppViewModel) {
    when (state) {
        is AppState.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is AppState.Unauthenticated -> AuthScreen()
        is AppState.NeedsGroup -> GroupSetupScreen(onSignOut = viewModel::signOut)
        is AppState.Ready -> {
            val pendingEvent by viewModel.pendingEvent.collectAsState()
            HomeScreen(
                groupId = state.groupId,
                solo = state.solo,
                onManualLog = { viewModel.setPendingEvent("update") },
                onSignOut = viewModel::signOut
            )
            pendingEvent?.let { eventType ->
                ConfirmEventDialog(
                    eventType = eventType,
                    groupId = state.groupId,
                    solo = state.solo,
                    onDismiss = viewModel::clearPendingEvent
                )
            }
        }
    }
}
