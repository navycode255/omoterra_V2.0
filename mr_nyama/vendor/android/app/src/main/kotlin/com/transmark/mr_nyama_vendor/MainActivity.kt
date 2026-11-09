package com.transmark.mr_nyama_vendor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel pushes arrive on (step 13B); high importance rings and shows a banner.
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                "mr_nyama_alerts",
                "Taarifa za Mr. Nyama",
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }
}
