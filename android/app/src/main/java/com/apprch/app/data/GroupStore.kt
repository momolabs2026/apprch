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
        val userUpdate = hashMapOf<String, Any>(
            "groupId" to groupRef.id,
            "activeGroupId" to groupRef.id,
            "solo" to solo,
            "groupIds" to FieldValue.arrayUnion(groupRef.id)
        )
        if (solo) {
            userUpdate["personalGroupId"] = groupRef.id
        }
        batch.set(
            db.collection("users").document(uid),
            userUpdate,
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
            mapOf(
                "groupId" to groupId,
                "activeGroupId" to groupId,
                "solo" to false,
                "groupIds" to FieldValue.arrayUnion(groupId)
            ),
            com.google.firebase.firestore.SetOptions.merge()
        )
        batch.commit().await()
    }

    suspend fun enableInvites(groupId: String, name: String? = null): String {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val groupRef = db.collection("groups").document(groupId)
        val snapshot = groupRef.get().await()
        val data = snapshot.data ?: throw IllegalStateException("Couldn’t load this group.")
        val members = data["memberUids"] as? List<*> ?: emptyList<Any>()
        if (!members.contains(uid)) {
            throw IllegalStateException("Couldn’t load this group.")
        }

        if (data["solo"] as? Boolean == true) {
            throw IllegalStateException("Invite from a group, or move a Trigger into a new group.")
        }
        val existing = (data["inviteCode"] as? String)?.trim()
        if (!existing.isNullOrEmpty()) {
            return existing
        }

        val code = randomInviteCode()
        val batch = db.batch()
        batch.update(groupRef, mapOf("inviteCode" to code))
        batch.set(
            db.collection("inviteCodes").document(code),
            mapOf("groupId" to groupId, "createdByUid" to uid)
        )
        batch.commit().await()
        return code
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
