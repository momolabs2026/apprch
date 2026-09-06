package com.apprch.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.apprch.app.messaging.FcmTokenManager
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed class AppState {
    data object Loading : AppState()
    data object Unauthenticated : AppState()
    data object NeedsGroup : AppState()
    data class Ready(val groupId: String) : AppState()
}

class AppViewModel : ViewModel() {

    private val auth = FirebaseAuth.getInstance()
    private val db = FirebaseFirestore.getInstance()

    private val _state = MutableStateFlow<AppState>(AppState.Loading)
    val state: StateFlow<AppState> = _state.asStateFlow()

    private val _pendingEvent = MutableStateFlow<String?>(null)
    val pendingEvent: StateFlow<String?> = _pendingEvent.asStateFlow()

    private var userListener: ListenerRegistration? = null

    init {
        auth.addAuthStateListener { firebaseAuth ->
            val user = firebaseAuth.currentUser
            if (user == null) {
                userListener?.remove()
                _state.value = AppState.Unauthenticated
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

    fun setPendingEvent(type: String) {
        _pendingEvent.value = type
    }

    fun clearPendingEvent() {
        _pendingEvent.value = null
    }

    fun signOut() {
        auth.signOut()
    }

    private fun observeUserDoc(uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { snapshot, _ ->
                val groupId = snapshot?.getString("groupId")
                _state.value = if (groupId != null) {
                    AppState.Ready(groupId)
                } else {
                    AppState.NeedsGroup
                }
            }
    }
}
