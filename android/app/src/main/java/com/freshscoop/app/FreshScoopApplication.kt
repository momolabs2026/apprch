package com.freshscoop.app

import android.app.Application
import com.google.firebase.FirebaseApp

class FreshScoopApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)
    }
}
