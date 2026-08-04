package com.example.v2ray_box.bg

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Append-only service logs under the app external files dir.
 * Never write session credentials into these files.
 */
object ServiceFileLog {
    private const val TAG = "V2Ray/ServiceFileLog"
    private const val MAX_BYTES = 2 * 1024 * 1024
    private val lock = ReentrantLock()
    private val timeFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    fun logsDir(context: Context): File {
        val base = context.getExternalFilesDir(null) ?: context.filesDir
        return File(base, "logs").also { it.mkdirs() }
    }

    fun append(context: Context, channel: String, message: String) {
        val trimmed = message.trim()
        if (trimmed.isEmpty()) return
        // Defense in depth: never persist lines that look like credential dumps.
        if (looksLikeCredentialLeak(trimmed)) {
            Log.w(TAG, "Skipped log line that may contain credentials")
            return
        }

        lock.withLock {
            try {
                val file = File(logsDir(context), "vpn-$channel.log")
                rotateIfNeeded(file)
                val line = "${timeFormat.format(Date())} [$channel] $trimmed\n"
                file.appendText(line)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to write log: ${e.message}")
            }
        }
    }

    private fun rotateIfNeeded(file: File) {
        if (!file.exists() || file.length() < MAX_BYTES) return
        val backup = File(file.parentFile, "${file.name}.1")
        if (backup.exists()) {
            backup.delete()
        }
        file.renameTo(backup)
    }

    private fun looksLikeCredentialLeak(message: String): Boolean {
        val lower = message.lowercase(Locale.US)
        return lower.contains("\"pass\"") ||
            lower.contains("\"password\"") ||
            lower.contains("socksPassword") ||
            lower.contains("accounts") && lower.contains("user")
    }
}
