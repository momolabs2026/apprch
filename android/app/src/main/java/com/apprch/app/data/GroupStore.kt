package com.apprch.app.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

object GroupStore {
    private val inviteChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    suspend fun create(name: String, solo: Boolean) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val groupRef = db.collection("groups").document()
        val inviteCode = if (solo) null else randomInviteCode()
        val group = hashMapOf<String, Any>(
            "name" to name,
            "solo" to solo,
            "memberUids" to listOf(uid),
            "createdAt" to FieldValue.serverTimestamp()
        )
        if (inviteCode != null) {
            group["inviteCode"] = inviteCode
        }

        val batch = db.batch()
        batch.set(groupRef, group)
        batch.set(
            db.collection("users").document(uid),
            mapOf("groupId" to groupRef.id, "solo" to solo),
            com.google.firebase.firestore.SetOptions.merge()
        )
        if (inviteCode != null) {
            batch.set(
                db.collection("inviteCodes").document(inviteCode),
                mapOf("groupId" to groupRef.id, "createdByUid" to uid)
            )
        }
        batch.commit().await()
    }

    suspend fun join(inviteCode: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val code = inviteCode.trim().uppercase()
        val db = FirebaseFirestore.getInstance()
        val invite = db.collection("inviteCodes").document(code).get().await()
        val groupId = invite.getString("groupId")
            ?: throw IllegalStateException("That invite code isn’t valid.")

        val batch = db.batch()
        batch.update(
            db.collection("groups").document(groupId),
            "memberUids",
            FieldValue.arrayUnion(uid)
        )
        batch.set(
            db.collection("users").document(uid),
            mapOf("groupId" to groupId, "solo" to false),
            com.google.firebase.firestore.SetOptions.merge()
        )
        batch.commit().await()
    }

    fun userFacingMessage(error: Throwable): String {
        val text = error.localizedMessage.orEmpty()
        if (text.contains("not found", ignoreCase = true) ||
            text.contains("permission", ignoreCase = true)
        ) {
            return "Couldn’t finish setup. Check your connection and try again."
        }
        return text.ifBlank { "Couldn’t finish setup. Try again." }
    }

    private fun randomInviteCode(): String =
        (1..6).map { inviteChars.random() }.joinToString("")
}
