package com.apprch.app

import android.app.Application
import android.app.NotificationManager
import com.apprch.app.data.AppearancePrefs
import com.apprch.app.messaging.ApprchMessagingService
import com.google.firebase.FirebaseApp

class ApprchApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        appContext = this
        FirebaseApp.initializeApp(this)
        AppearancePrefs.load(this)
        val manager = getSystemService(NotificationManager::class.java)
        ApprchMessagingService.createChannel(manager)
    }

    companion object {
        lateinit var appContext: ApprchApplication
            private set
    }
}
