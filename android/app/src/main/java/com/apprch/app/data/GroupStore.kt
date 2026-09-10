package com.apprch.app.data

import com.apprch.app.model.Space
import com.apprch.app.model.SpaceMember
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.tasks.await

object GroupStore {
    private val inviteChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    fun directoryFields(displayName: String, email: String?): Map<String, Any> {
        val name = displayName.trim()
        val searchName = name.lowercase()
        val tokens = searchName.split(Regex("\\s+")).filter { it.isNotEmpty() }.toMutableSet()
        if (searchName.isNotEmpty()) tokens += searchName
        val fields = hashMapOf<String, Any>(
            "displayName" to name,
            "searchName" to searchName,
            "nameTokens" to tokens.toList()
        )
        if (!email.isNullOrBlank()) {
            fields["email"] = email.lowercase()
        }
        return fields
    }

    suspend fun create(name: String, solo: Boolean) {
        if (!solo) ensurePersonal()
        createSpace(name = name, solo = solo, makeActive = true)
    }

    suspend fun ensurePersonal(): String {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val userRef = db.collection("users").document(uid)
        val data = userRef.get().await().data ?: emptyMap()
        val personalId = data["personalGroupId"] as? String
        if (!personalId.isNullOrEmpty()) return personalId

        val groupId = data["groupId"] as? String
        if (groupId != null) {
            val group = db.collection("groups").document(groupId).get().await().data
            if (group?.get("solo") == true) {
                userRef.set(
                    mapOf(
                        "personalGroupId" to groupId,
                        "groupIds" to FieldValue.arrayUnion(groupId),
                        "activeGroupId" to (data["activeGroupId"] ?: groupId),
                        "groupId" to (data["groupId"] ?: groupId),
                        "solo" to (data["solo"] ?: true)
                    ),
                    SetOptions.merge()
                ).await()
                return groupId
            }
        }
        return createSpace(name = "Solo", solo = true, makeActive = data["groupId"] == null)
    }

    suspend fun join(inviteCode: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        ensurePersonal()
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
                "groupIds" to FieldValue.arrayUnion(groupId),
                "groupId" to groupId,
                "activeGroupId" to groupId,
                "solo" to false
            ),
            SetOptions.merge()
        )
        batch.commit().await()
    }

    suspend fun setActiveSpace(groupId: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val snapshot = FirebaseFirestore.getInstance().collection("groups").document(groupId).get().await()
        if (!snapshot.exists()) throw IllegalStateException("Couldn’t load this space.")
        val solo = snapshot.getBoolean("solo") ?: false
        FirebaseFirestore.getInstance().collection("users").document(uid).set(
            mapOf(
                "groupId" to groupId,
                "activeGroupId" to groupId,
                "solo" to solo
            ),
            SetOptions.merge()
        ).await()
    }

    suspend fun spaces(): List<Space> {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val snapshot = FirebaseFirestore.getInstance()
            .collection("groups")
            .whereArrayContains("memberUids", uid)
            .get()
            .await()
        return snapshot.documents.mapNotNull { doc ->
            val name = doc.getString("name") ?: return@mapNotNull null
            Space(id = doc.id, name = name, solo = doc.getBoolean("solo") ?: false)
        }.sortedWith(compareBy<Space> { !it.solo }.thenBy { it.name.lowercase() })
    }

    suspend fun members(groupId: String): List<SpaceMember> {
        val db = FirebaseFirestore.getInstance()
        val snapshot = db.collection("groups").document(groupId).get().await()
        val uids = snapshot.get("memberUids") as? List<*> ?: emptyList<Any>()
        return uids.mapNotNull { it as? String }.map { uid ->
            val data = db.collection("users").document(uid).get().await().data ?: emptyMap()
            SpaceMember(
                id = uid,
                name = (data["displayName"] as? String)?.trim()?.ifEmpty { null } ?: "Someone",
                photoBase64 = data["photoBase64"] as? String,
                email = data["email"] as? String
            )
        }.sortedBy { it.name.lowercase() }
    }

    suspend fun searchUsers(query: String, excluding: Set<String>): List<SpaceMember> {
        val needle = query.trim().lowercase()
        if (needle.length < 2) return emptyList()
        val db = FirebaseFirestore.getInstance()
        val token = needle.split(Regex("\\s+")).first()
        return coroutineScope {
            val prefix = async {
                db.collection("users")
                    .whereGreaterThanOrEqualTo("searchName", needle)
                    .whereLessThan("searchName", needle + "\uf8ff")
                    .limit(12)
                    .get()
                    .await()
            }
            val tokens = async {
                db.collection("users")
                    .whereArrayContains("nameTokens", token)
                    .limit(12)
                    .get()
                    .await()
            }
            val docs = (prefix.await().documents + tokens.await().documents).toMutableList()
            if (needle.contains("@")) {
                docs += db.collection("users")
                    .whereEqualTo("email", needle)
                    .limit(5)
                    .get()
                    .await()
                    .documents
            }
            val seen = mutableSetOf<String>()
            docs.mapNotNull { doc ->
                if (doc.id in excluding || !seen.add(doc.id)) return@mapNotNull null
                val data = doc.data ?: return@mapNotNull null
                SpaceMember(
                    id = doc.id,
                    name = (data["displayName"] as? String)?.trim()?.ifEmpty { null } ?: "Someone",
                    photoBase64 = data["photoBase64"] as? String,
                    email = data["email"] as? String
                )
            }.sortedBy { it.name.lowercase() }
        }
    }

    suspend fun addMember(uid: String, groupId: String) {
        val me = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        if (uid == me) throw IllegalStateException("They’re already in this group.")
        val groupRef = FirebaseFirestore.getInstance().collection("groups").document(groupId)
        val snapshot = groupRef.get().await()
        val data = snapshot.data ?: throw IllegalStateException("Couldn’t load this space.")
        if (data["solo"] == true) {
            throw IllegalStateException("Invite from a group, or move a Task into a new group.")
        }
        val members = data["memberUids"] as? List<*> ?: emptyList<Any>()
        if (!members.contains(me)) throw IllegalStateException("Couldn’t load this space.")
        if (members.contains(uid)) throw IllegalStateException("They’re already in this group.")
        groupRef.update("memberUids", FieldValue.arrayUnion(uid)).await()
    }

    suspend fun enableInvites(groupId: String): String {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val groupRef = db.collection("groups").document(groupId)
        val snapshot = groupRef.get().await()
        val data = snapshot.data ?: throw IllegalStateException("Couldn’t load this group.")
        val members = data["memberUids"] as? List<*> ?: emptyList<Any>()
        if (!members.contains(uid)) throw IllegalStateException("Couldn’t load this group.")
        if (data["solo"] as? Boolean == true) {
            throw IllegalStateException("Invite from a group, or move a Task into a new group.")
        }
        val existing = (data["inviteCode"] as? String)?.trim()
        if (!existing.isNullOrEmpty()) return existing

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

    suspend fun inviteCode(groupId: String): Triple<String?, Boolean, String> {
        val snapshot = FirebaseFirestore.getInstance().collection("groups").document(groupId).get().await()
        val data = snapshot.data ?: throw IllegalStateException("Couldn’t load this space.")
        val code = (data["inviteCode"] as? String)?.trim()?.ifEmpty { null }
        return Triple(code, data["solo"] as? Boolean ?: false, data["name"] as? String ?: "")
    }

    suspend fun moveTask(taskId: String, toGroupId: String) {
        FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Please sign in again.")
        val db = FirebaseFirestore.getInstance()
        val taskRef = db.collection("tasks").document(taskId)
        val task = taskRef.get().await()
        if (!task.exists()) throw IllegalStateException("Couldn’t load this space.")
        val fromGroupId = task.getString("groupId")
            ?: throw IllegalStateException("Couldn’t load this space.")
        if (fromGroupId == toGroupId) return
        taskRef.update("groupId", toGroupId).await()

        val events = db.collection("events")
            .whereEqualTo("groupId", fromGroupId)
            .whereEqualTo("taskId", taskId)
            .get()
            .await()
        if (events.isEmpty) return
        val batch = db.batch()
        events.documents.forEach { batch.update(it.reference, "groupId", toGroupId) }
        batch.commit().await()
    }

    suspend fun createGroup(named: String, movingTaskId: String?): String {
        val trimmed = named.trim()
        if (trimmed.isEmpty()) throw IllegalStateException("Give the group a name first.")
        ensurePersonal()
        val groupId = createSpace(name = trimmed, solo = false, makeActive = true)
        if (movingTaskId != null) {
            moveTask(movingTaskId, groupId)
        }
        return groupId
    }

    fun userFacingMessage(error: Throwable): String {
        val text = error.localizedMessage.orEmpty()
        if (text.contains("not found", ignoreCase = true) ||
            text.contains("permission", ignoreCase = true)
        ) {
            return "Couldn’t finish that. Check your connection and try again."
        }
        return text.ifBlank { "Couldn’t finish that. Try again." }
    }

    private suspend fun createSpace(name: String, solo: Boolean, makeActive: Boolean): String {
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
        if (inviteCode != null) group["inviteCode"] = inviteCode

        val userUpdate = hashMapOf<String, Any>(
            "groupIds" to FieldValue.arrayUnion(groupRef.id)
        )
        if (solo) userUpdate["personalGroupId"] = groupRef.id
        if (makeActive) {
            userUpdate["groupId"] = groupRef.id
            userUpdate["activeGroupId"] = groupRef.id
            userUpdate["solo"] = solo
        }

        val batch = db.batch()
        batch.set(groupRef, group)
        batch.set(db.collection("users").document(uid), userUpdate, SetOptions.merge())
        if (inviteCode != null) {
            batch.set(
                db.collection("inviteCodes").document(inviteCode),
                mapOf("groupId" to groupRef.id, "createdByUid" to uid)
            )
        }
        batch.commit().await()
        return groupRef.id
    }

    private fun randomInviteCode(): String =
        (1..6).map { inviteChars.random() }.joinToString("")
}
