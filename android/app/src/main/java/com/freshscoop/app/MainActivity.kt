package com.freshscoop.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.freshscoop.app.ui.AppViewModel
import com.freshscoop.app.ui.RootScreen
import com.freshscoop.app.ui.theme.FreshScoopTheme

class MainActivity : ComponentActivity() {

    private val appViewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleIntent(intent)
        setContent {
            FreshScoopTheme {
                val state by appViewModel.state.collectAsState()
                RootScreen(state = state, viewModel = appViewModel)
            }
        }
    }

    // App Link received while app is running (singleTop re-deliver)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val data = intent.data ?: return
        if (data.scheme == "https" && data.pathSegments.getOrNull(0) == "trigger") {
            val eventType = data.pathSegments.getOrNull(1) ?: "litter_cleaned"
            appViewModel.setPendingEvent(eventType)
        }
    }
}
