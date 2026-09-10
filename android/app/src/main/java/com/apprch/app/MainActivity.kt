package com.apprch.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.apprch.app.data.AppearancePrefs
import com.apprch.app.ui.AppViewModel
import com.apprch.app.ui.RootScreen
import com.apprch.app.ui.theme.ApprchTheme

class MainActivity : ComponentActivity() {

    private val appViewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppearancePrefs.load(this)
        enableEdgeToEdge()
        handleIntent(intent)
        setContent {
            ApprchTheme {
                val state by appViewModel.state.collectAsState()
                RootScreen(state = state, viewModel = appViewModel)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val data = intent.data ?: return
        val taskId = when {
            data.scheme == "apprch" -> data.getQueryParameter("id")
            data.scheme == "https" && data.pathSegments.getOrNull(0) in listOf("t", "task", "trigger") ->
                data.pathSegments.getOrNull(1)
            else -> null
        } ?: return
        appViewModel.setPendingTask(taskId)
    }
}
