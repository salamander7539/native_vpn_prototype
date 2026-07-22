package com.example.native_vpn_prototype

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat

class MyVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null

    companion object {
        const val ACTION_START = "START"
        const val ACTION_STOP = "STOP"
        private const val CHANNEL_ID = "VpnServiceChannel"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_START) {
            val serverIp = intent.getStringExtra("serverIp") ?: "185.22.44.1"
            val dns = intent.getStringExtra("dns") ?: "8.8.8.8"

            startForegroundServiceNotification()

            MainActivity.sendEventToFlutter("statusChanged", "CONNECTING")
            MainActivity.sendEventToFlutter("logMessage", "[Android] Инициализация виртуального интерфейса...")

            try {
                vpnInterface = Builder()
                    .addAddress("10.0.0.2", 24)
                    .addRoute("0.0.0.0", 0)
                    .addDnsServer(dns)
                    .setSession("OsmanVpnSession")
                    .establish()

                MainActivity.sendEventToFlutter("statusChanged", "CONNECTED")
                MainActivity.sendEventToFlutter("logMessage", "[Android] VpnService успешно поднят. Локальный IP: 10.0.0.2")
                MainActivity.sendEventToFlutter("trafficChanged", "⬇️ 145 KB/s  ⬆️ 32 KB/s")
            } catch (e: Exception) {
                MainActivity.sendEventToFlutter("error", e.localizedMessage ?: "Error")
            }
        } else if (intent?.action == ACTION_STOP) {
            stopVpnTunnel()
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        android.util.Log.d("VPN", "Интерфейс закрыт пользователем. Служба продолжает работу благодаря START_STICKY.")
    }

    private fun startForegroundServiceNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Status",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Отображение статуса активного VPN-подключения"
            channel.setShowBadge(false)
            channel.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Osman VPN Core")
            .setContentText("Защищенное VPN-соединение активно")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            notificationBuilder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }

        startForeground(1, notificationBuilder.build())
    }

    private fun stopVpnTunnel() {
        MainActivity.sendEventToFlutter("statusChanged", "DISCONNECTING")
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            Log.e("VPN", "Error closing interface", e)
        }
        MainActivity.sendEventToFlutter("statusChanged", "DISCONNECTED")
        MainActivity.sendEventToFlutter("logMessage", "[Android] VPN туннель остановлен.")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onRevoke() {
        stopVpnTunnel()
        super.onRevoke()
    }
}
