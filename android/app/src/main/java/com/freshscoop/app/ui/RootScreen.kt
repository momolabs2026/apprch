package com.freshscoop.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.freshscoop.app.ui.auth.AuthScreen
import com.freshscoop.app.ui.confirm.ConfirmEventDialog
import com.freshscoop.app.ui.family.FamilySetupScreen
import com.freshscoop.app.ui.home.HomeScreen

@Composable
fun RootScreen(state: AppState, viewModel: AppViewModel) {
    when (state) {
        is AppState.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is AppState.Unauthenticated -> AuthScreen()
        is AppState.NeedsFamily -> FamilySetupScreen(onSignOut = viewModel::signOut)
        is AppState.Ready -> {
            val pendingEvent by viewModel.pendingEvent.collectAsState()
            HomeScreen(
                familyId = state.familyId,
                onManualLog = { viewModel.setPendingEvent("litter_cleaned") },
                onSignOut = viewModel::signOut
            )
            pendingEvent?.let { eventType ->
                ConfirmEventDialog(
                    eventType = eventType,
                    familyId = state.familyId,
                    onDismiss = viewModel::clearPendingEvent
                )
            }
        }
    }
}
