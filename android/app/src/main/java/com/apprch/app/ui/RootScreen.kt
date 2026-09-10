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
            val pendingTaskId by viewModel.pendingTaskId.collectAsState()
            HomeScreen(
                active = state.active,
                spaces = state.spaces,
                onSelectSpace = viewModel::selectSpace,
                onSignOut = viewModel::signOut
            )
            pendingTaskId?.let { taskId ->
                ConfirmEventDialog(
                    taskId = taskId,
                    onDismiss = viewModel::clearPendingTask
                )
            }
        }
    }
}
