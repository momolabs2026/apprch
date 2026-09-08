package com.apprch.app.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModelProvider
import com.apprch.app.ui.AppState
import com.apprch.app.ui.AppViewModel
import com.apprch.app.ui.theme.ApprchTheme

class HeatmapWidgetConfigActivity : ComponentActivity() {

    private val appWidgetId: Int
        get() = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val pending = WidgetSnapshotStore.consumePendingPin(this)
        if (pending != null) {
            finishWith(pending)
            return
        }

        enableEdgeToEdge()
        val viewModel = ViewModelProvider(this)[AppViewModel::class.java]
        setContent {
            ApprchTheme {
                var triggers by remember { mutableStateOf(WidgetSnapshotStore.load(this@HeatmapWidgetConfigActivity)) }
                val state by viewModel.state.collectAsState()

                LaunchedEffect(state) {
                    if (state is AppState.Ready) {
                        WidgetSnapshotSync.refresh(
                            this@HeatmapWidgetConfigActivity,
                            state.spaces.map { it.id }
                        )
                        triggers = WidgetSnapshotStore.load(this@HeatmapWidgetConfigActivity)
                    }
                }

                WidgetPicker(
                    triggers = triggers,
                    onCancel = { finish() },
                    onPick = { finishWith(it) }
                )
            }
        }
    }

    private fun finishWith(triggerId: String) {
        HeatmapWidgetInstaller.bindTrigger(this, appWidgetId, triggerId)
        val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, result)
        finish()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WidgetPicker(
    triggers: List<WidgetTriggerSnapshot>,
    onCancel: () -> Unit,
    onPick: (String) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Choose a Trigger") },
                navigationIcon = {
                    TextButton(onClick = onCancel) { Text("Cancel") }
                }
            )
        }
    ) { padding ->
        if (triggers.isEmpty()) {
            Text(
                "Open Apprch and sign in so your Triggers can show here.",
                modifier = Modifier
                    .padding(padding)
                    .padding(24.dp)
            )
        } else {
            LazyColumn(Modifier.fillMaxSize().padding(padding)) {
                items(triggers, key = { it.id }) { trigger ->
                    ListItem(
                        headlineContent = { Text("${trigger.icon}  ${trigger.name}") },
                        supportingContent = {
                            Text(
                                if (trigger.yearTotal == 1) "1 time in the last year"
                                else "${trigger.yearTotal} times in the last year"
                            )
                        },
                        modifier = Modifier.clickable { onPick(trigger.id) }
                    )
                }
            }
        }
    }
}
