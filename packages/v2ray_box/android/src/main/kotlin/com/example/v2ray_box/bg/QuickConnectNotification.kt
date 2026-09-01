package com.example.v2ray_box.bg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.v2ray_box.Settings
import com.example.v2ray_box.V2rayBoxPlugin
import com.example.v2ray_box.constant.Action

/**
 * Persistent disconnected-state notification with a Connect action (Hiddify / v2RayTun style).
 */
object QuickConnectNotification {
    private const val notificationId = 2
    private const val notificationChannel = "v2ray_box_quick_connect"
    private const val launchRequestCode = 11
    private const val connectRequestCode = 12

    private val flags =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    fun show(context: Context, profileName: String, statusText: String) {
        val manager = V2rayBoxPlugin.notificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    notificationChannel,
                    "Quick connect",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Quick VPN connect from notification shade"
                    setShowBadge(false)
                },
            )
        }

        val connectLabel = Settings.quickConnectButtonText.takeIf { it.isNotBlank() } ?: "Connect"
        val title = Settings.notificationTitle.takeIf { it.isNotBlank() }
            ?: profileName.takeIf { it.isNotBlank() }
            ?: "RioNexTunnel"
        val expandedText = buildString {
            append(statusText.ifBlank { "Tap Connect to start VPN" })
            if (profileName.isNotBlank()) {
                append("\n")
                append(profileName)
            }
        }

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(V2rayBoxPlugin.EXTRA_QUICK_CONNECT, true)
            }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(context, launchRequestCode, it, flags)
        }

        val connectIntent = PendingIntent.getBroadcast(
            context,
            connectRequestCode,
            Intent(Action.SERVICE_CONNECT).setPackage(context.packageName),
            flags,
        )

        val iconResId = resolveIcon(context)
        val notification = NotificationCompat.Builder(context, notificationChannel)
            .setShowWhen(false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSmallIcon(iconResId)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentTitle(title)
            .setContentText(statusText.ifBlank { "Disconnected" })
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(expandedText)
                    .setBigContentTitle(title),
            )
            .setContentIntent(contentIntent)
            .addAction(
                NotificationCompat.Action.Builder(0, connectLabel, connectIntent).build(),
            )
            .build()

        manager.notify(notificationId, notification)
    }

    fun dismiss(context: Context) {
        V2rayBoxPlugin.notificationManager?.cancel(notificationId)
    }

    private fun resolveIcon(context: Context): Int {
        val customIconName = Settings.notificationIconName.takeIf { it.isNotBlank() }
        if (customIconName != null) {
            val customIconResId = context.resources.getIdentifier(
                customIconName,
                "drawable",
                context.packageName,
            )
            if (customIconResId != 0) {
                return customIconResId
            }
        }
        val appIconResId = context.applicationInfo.icon
        if (appIconResId != 0) {
            return appIconResId
        }
        return android.R.drawable.ic_dialog_info
    }
}
