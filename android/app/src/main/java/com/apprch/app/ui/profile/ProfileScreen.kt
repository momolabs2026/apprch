package com.apprch.app.ui.profile

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.apprch.app.data.AppAppearance
import com.apprch.app.data.AppearancePrefs
import com.apprch.app.data.GroupStore
import com.google.firebase.auth.EmailAuthProvider
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.UserProfileChangeRequest
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.io.ByteArrayOutputStream

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(onDismiss: () -> Unit, onSignOut: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val user = FirebaseAuth.getInstance().currentUser
    val appearance by AppearancePrefs.appearance.collectAsState()

    var name by remember { mutableStateOf(user?.displayName.orEmpty()) }
    var photo by remember { mutableStateOf<String?>(null) }
    var currentPassword by remember { mutableStateOf("") }
    var newPassword by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var passwordSaved by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }

    androidx.compose.runtime.LaunchedEffect(user?.uid) {
        val uid = user?.uid ?: return@LaunchedEffect
        val doc = FirebaseFirestore.getInstance().collection("users").document(uid).get().await()
        name = doc.getString("displayName") ?: user.displayName.orEmpty()
        photo = doc.getString("photoBase64")
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            isSaving = true
            error = null
            try {
                val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalStateException("Couldn’t read that photo.")
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: throw IllegalStateException("Couldn’t read that photo.")
                val encoded = encodedAvatar(bitmap)
                FirebaseFirestore.getInstance().collection("users").document(user!!.uid)
                    .set(mapOf("photoBase64" to encoded), SetOptions.merge()).await()
                photo = encoded
            } catch (e: Exception) {
                error = e.localizedMessage
            }
            isSaving = false
        }
    }

    val bitmap = remember(photo) {
        photo?.let {
            runCatching {
                val bytes = Base64.decode(it, Base64.DEFAULT)
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }.getOrNull()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("You") },
                actions = { TextButton(onClick = onDismiss) { Text("Done") } }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center
                ) {
                    if (bitmap != null) {
                        Image(bitmap.asImageBitmap(), contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    } else {
                        Icon(Icons.Filled.Person, contentDescription = null)
                    }
                }
                Column {
                    TextButton(onClick = {
                        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }) { Text(if (photo == null) "Add photo" else "Change photo") }
                    if (photo != null) {
                        TextButton(onClick = {
                            scope.launch {
                                FirebaseFirestore.getInstance().collection("users").document(user!!.uid)
                                    .set(mapOf("photoBase64" to FieldValue.delete()), SetOptions.merge()).await()
                                photo = null
                            }
                        }) { Text("Remove photo") }
                    }
                }
            }

            OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Your name") }, modifier = Modifier.fillMaxWidth())
            Button(
                onClick = {
                    scope.launch {
                        isSaving = true
                        error = null
                        try {
                            val trimmed = name.trim()
                            user?.updateProfile(UserProfileChangeRequest.Builder().setDisplayName(trimmed).build())?.await()
                            FirebaseFirestore.getInstance().collection("users").document(user!!.uid)
                                .set(GroupStore.directoryFields(trimmed, user.email), SetOptions.merge()).await()
                        } catch (e: Exception) {
                            error = e.localizedMessage
                        }
                        isSaving = false
                    }
                },
                enabled = name.isNotBlank() && !isSaving
            ) { Text("Save name") }

            Text("Email", style = MaterialTheme.typography.titleSmall)
            Text(user?.email ?: "No email", color = MaterialTheme.colorScheme.onSurfaceVariant)

            OutlinedTextField(value = currentPassword, onValueChange = { currentPassword = it }, label = { Text("Current password") }, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = newPassword, onValueChange = { newPassword = it }, label = { Text("New password (6+ characters)") }, modifier = Modifier.fillMaxWidth())
            Button(
                onClick = {
                    scope.launch {
                        isSaving = true
                        error = null
                        passwordSaved = false
                        try {
                            val email = user?.email ?: throw IllegalStateException("Please sign in again.")
                            val credential = EmailAuthProvider.credential(email, currentPassword)
                            user.reauthenticate(credential).await()
                            user.updatePassword(newPassword).await()
                            currentPassword = ""
                            newPassword = ""
                            passwordSaved = true
                        } catch (e: Exception) {
                            error = e.localizedMessage
                        }
                        isSaving = false
                    }
                },
                enabled = currentPassword.isNotBlank() && newPassword.length >= 6 && !isSaving
            ) { Text("Update password") }
            if (passwordSaved) Text("Password updated", color = MaterialTheme.colorScheme.primary)

            Text("Appearance", style = MaterialTheme.typography.titleSmall)
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                AppAppearance.entries.forEachIndexed { index, option ->
                    SegmentedButton(
                        selected = appearance == option,
                        onClick = { AppearancePrefs.set(context, option) },
                        shape = SegmentedButtonDefaults.itemShape(index, AppAppearance.entries.size)
                    ) { Text(option.title) }
                }
            }

            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) { Text("Sign out") }
        }
    }
}

private fun encodedAvatar(image: Bitmap): String {
    val size = 256
    val scale = maxOf(size / image.width.toFloat(), size / image.height.toFloat())
    val scaledW = (image.width * scale).toInt()
    val scaledH = (image.height * scale).toInt()
    val scaled = Bitmap.createScaledBitmap(image, scaledW, scaledH, true)
    val x = ((scaledW - size) / 2).coerceAtLeast(0)
    val y = ((scaledH - size) / 2).coerceAtLeast(0)
    val squared = Bitmap.createBitmap(scaled, x, y, size.coerceAtMost(scaled.width), size.coerceAtMost(scaled.height))
    val out = ByteArrayOutputStream()
    squared.compress(Bitmap.CompressFormat.JPEG, 70, out)
    return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
}
