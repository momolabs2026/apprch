package com.apprch.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.glance.appwidget.updateAll
import com.apprch.app.ApprchApplication
import com.apprch.app.data.GroupStore
import com.apprch.app.messaging.FcmTokenManager
import com.apprch.app.model.Space
import com.apprch.app.widget.HeatmapGlanceWidget
import com.apprch.app.widget.WidgetSnapshotStore
import com.apprch.app.widget.WidgetSnapshotSync
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

sealed class AppState {
    data object Loading : AppState()
    data object Unauthenticated : AppState()
    data object NeedsGroup : AppState()
    data class Ready(val active: Space, val spaces: List<Space>) : AppState()
}

class AppViewModel : ViewModel() {

    private val auth = FirebaseAuth.getInstance()
    private val db = FirebaseFirestore.getInstance()

    private val _state = MutableStateFlow<AppState>(AppState.Loading)
    val state: StateFlow<AppState> = _state.asStateFlow()

    private val _pendingTaskId = MutableStateFlow<String?>(null)
    val pendingTaskId: StateFlow<String?> = _pendingTaskId.asStateFlow()

    private var userListener: ListenerRegistration? = null
    private var isMigrating = false

    init {
        auth.addAuthStateListener { firebaseAuth ->
            val user = firebaseAuth.currentUser
            if (user == null) {
                userListener?.remove()
                _state.value = AppState.Unauthenticated
                WidgetSnapshotStore.clear(ApprchApplication.appContext)
                viewModelScope.launch {
                    runCatching { HeatmapGlanceWidget().updateAll(ApprchApplication.appContext) }
                }
            } else {
                observeUserDoc(user.uid)
                viewModelScope.launch {
                    runCatching { FcmTokenManager.upsertCurrentToken() }
                }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        userListener?.remove()
    }

    fun setPendingTask(id: String) {
        _pendingTaskId.value = id
    }

    fun clearPendingTask() {
        _pendingTaskId.value = null
    }

    fun signOut() {
        auth.signOut()
    }

    fun selectSpace(groupId: String) {
        viewModelScope.launch {
            runCatching { GroupStore.setActiveSpace(groupId) }
        }
    }

    private fun observeUserDoc(uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { snapshot, _ ->
                viewModelScope.launch { applyUserSnapshot(uid, snapshot?.data) }
            }
    }

    private suspend fun applyUserSnapshot(uid: String, data: Map<String, Any>?) {
        if (data == null) {
            _state.value = AppState.NeedsGroup
            return
        }

        val displayName = (data["displayName"] as? String)?.trim().orEmpty()
        if (data["searchName"] == null && displayName.isNotEmpty() && !isMigrating) {
            isMigrating = true
            runCatching {
                db.collection("users").document(uid).set(
                    GroupStore.directoryFields(displayName, auth.currentUser?.email),
                    SetOptions.merge()
                ).await()
            }
            isMigrating = false
        }

        val groupId = (data["activeGroupId"] as? String) ?: (data["groupId"] as? String)
        if (groupId == null) {
            _state.value = AppState.NeedsGroup
            return
        }

        val spaces = runCatching { GroupStore.spaces() }.getOrDefault(emptyList())
        val solo = data["solo"] as? Boolean ?: false
        val active = spaces.firstOrNull { it.id == groupId }
            ?: Space(id = groupId, name = if (solo) "Solo" else "Group", solo = solo)
        val all = if (spaces.any { it.id == active.id }) spaces else listOf(active) + spaces
        _state.value = AppState.Ready(active = active, spaces = all)
        viewModelScope.launch {
            runCatching {
                WidgetSnapshotSync.refresh(ApprchApplication.appContext, all.map { it.id })
            }
        }
    }
}
