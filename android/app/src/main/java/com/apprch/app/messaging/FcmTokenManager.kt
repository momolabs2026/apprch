package com.apprch.app.messaging

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.tasks.await

object FcmTokenManager {
    suspend fun upsertCurrentToken() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val token = FirebaseMessaging.getInstance().token.await()
        upsertToken(uid, token)
    }

    fun upsertToken(uid: String, token: String) {
        FirebaseFirestore.getInstance()
            .collection("users")
            .document(uid)
            .set(mapOf("fcmTokens" to FieldValue.arrayUnion(token)), SetOptions.merge())
    }
}
