package com.example.v2ray_box.xray

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import go.Seq
import libXray.LibXray
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

interface XrayCallbackHandler {
    fun startup(): Long
    fun shutdown(): Long
    fun onEmitStatus(status: Long, message: String?): Long
}

object XrayBridge {
    private const val TAG = "V2Ray/XrayBridge"
    private const val API_VERSION = 1
    private val gson = Gson()
    private val protectLogCount = AtomicLong(0L)
    @Volatile
    private var dialerControllerRef: libXray.DialerController? = null

    @Volatile
    private var workDirPath: String = ""

    fun initCoreEnv(context: Context, workDir: String) {
        workDirPath = workDir
        runCatching { File(workDirPath).mkdirs() }
        // Required by gomobile bindings on Android for proper runtime initialization.
        runCatching { Seq.setContext(context.applicationContext) }
            .onFailure { Log.w(TAG, "Seq.setContext failed: ${it.message}") }
        runCatching { LibXray.touch() }
    }

    fun newCoreController(callback: XrayCallbackHandler): XrayCoreController {
        if (workDirPath.isBlank()) {
            throw IllegalStateException("Core env not initialized. Call initCoreEnv first.")
        }
        return XrayCoreController(callback, workDirPath)
    }

    fun checkVersion(): String {
        val response = invokeMethod("xrayVersion")
        return if (response.success) response.dataFieldAsString("version") else ""
    }

    fun configureSocketProtection(
        protectFd: ((Int) -> Boolean)?,
        dnsServer: String? = null
    ) {
        if (protectFd == null) {
            dialerControllerRef = null
            runCatching { LibXray.resetDNS() }
            return
        }
        val controller = object : libXray.DialerController {
            override fun protectFd(fd: Long): Boolean {
                val result = runCatching { protectFd(fd.toInt()) }.getOrDefault(false)
                if (protectLogCount.getAndIncrement() < 20) {
                    Log.d(TAG, "protectFd(fd=$fd) -> $result")
                }
                return result
            }
        }
        dialerControllerRef = controller
        runCatching { LibXray.registerDialerController(controller) }
            .onFailure { Log.w(TAG, "registerDialerController failed: ${it.message}") }
        runCatching { LibXray.registerListenerController(controller) }
            .onFailure { Log.w(TAG, "registerListenerController failed: ${it.message}") }
        if (!dnsServer.isNullOrBlank()) {
            runCatching { LibXray.setDNS(controller, dnsServer) }
                .onFailure { Log.w(TAG, "setDNS failed: ${it.message}") }
        }
    }

    fun parseFirstOutboundFromShareLink(link: String): Map<String, Any>? {
        return runCatching {
            val response = invokeMethod(
                "convertShareLinksToXrayJson",
                JsonObject().apply { addProperty("text", link) }
            )
            if (!response.success) {
                Log.w(TAG, "parseFirstOutboundFromShareLink failed: ${response.error}")
                return null
            }
            val root = response.dataAsJsonObject() ?: return null
            val outbounds = root.getAsJsonArray("outbounds") ?: return null
            if (outbounds.size() == 0 || !outbounds[0].isJsonObject) return null
            val normalizedAny = normalizeNumericTypes(
                gson.fromJson<Any>(outbounds[0], Any::class.java)
            )
            @Suppress("UNCHECKED_CAST")
            val outbound = (normalizedAny as? Map<String, Any>) ?: return null
            // libXray share parser stores remarks in sendThrough.
            // Keep ping/runtime outbound clean and deterministic.
            outbound.toMutableMap().apply {
                remove("sendThrough")
                if (this["tag"] == null) {
                    this["tag"] = "proxy"
                }
            }
        }.getOrElse { e ->
            Log.w(TAG, "parseFirstOutboundFromShareLink exception: ${e.message}")
            null
        }
    }

    fun measureOutboundDelay(
        configJson: String,
        testUrl: String,
        timeoutMs: Int,
        proxyUrl: String
    ): Long {
        if (workDirPath.isBlank()) return -1L

        val timeoutSec = (timeoutMs.coerceAtLeast(1000) + 999) / 1000
        val workDir = File(workDirPath).apply { mkdirs() }
        val configFile = runCatching {
            File.createTempFile("ping_", ".json", workDir)
        }.getOrElse {
            File(workDir, "ping_${System.nanoTime()}.json")
        }
        return try {
            configFile.writeText(configJson)
            val payload = JsonObject().apply {
                addProperty("configPath", configFile.absolutePath)
                addProperty("timeout", timeoutSec)
                addProperty("url", testUrl)
                // Ensure delay is measured through the tested outbound, not direct network.
                addProperty("proxy", proxyUrl)
            }
            val response = invokeMethod("ping", payload)
            if (!response.success) return -1L
            response.dataFieldAsLong("delay")
        } catch (e: Exception) {
            Log.w(TAG, "measureOutboundDelay failed: ${e.message}")
            -1L
        } finally {
            runCatching { configFile.delete() }
        }
    }

    internal fun invokeMethod(method: String, payload: JsonObject? = null): CallResponse {
        val request = JsonObject().apply {
            addProperty("apiVersion", API_VERSION)
            addProperty("method", method)
            if (payload != null) {
                add("payload", payload)
            }
        }
        val raw = runCatching { LibXray.invoke(request.toString()) }.getOrElse { e ->
            return CallResponse(success = false, data = null, error = e.message ?: "invoke failed")
        }
        return decodeInvokeResponse(raw)
    }

    internal fun getXrayRunning(): Boolean {
        val response = invokeMethod("getXrayState")
        return response.success && response.dataFieldAsBoolean("running")
    }
}

class XrayCoreController(
    private val callback: XrayCallbackHandler,
    private val workDirPath: String
) {
    companion object {
        private const val TAG = "V2Ray/XrayCoreController"
        private const val TUN_FD_ENV = "xray.tun.fd"
        private const val TUN_FD_ENV_ALT = "XRAY_TUN_FD"
        private val coreLifecycleLock = Any()
    }

    @Volatile
    private var running = false

    @Volatile
    private var metricsListen = ""

    private val lastStats = ConcurrentHashMap<String, AtomicLong>()

    val isRunning: Boolean
        get() = running && XrayBridge.getXrayRunning()

    fun startLoop(configContent: String, _tunFd: Int) {
        callback.startup()
        try {
            synchronized(coreLifecycleLock) {
                if (XrayBridge.getXrayRunning()) {
                    runCatching { XrayBridge.invokeMethod("stopXray") }
                }
                val tunFd = _tunFd.takeIf { it > 0 }
                // New libXray: SetTunFd is gone — inject into config root env.
                setTunFdEnv(tunFd)

                val sanitizedConfig = sanitizeConfig(configContent, tunFd)
                val payload = JsonObject().apply {
                    addProperty("configJSON", sanitizedConfig)
                }
                val response = XrayBridge.invokeMethod("runXrayFromJson", payload)
                if (!response.success) {
                    val message = response.error ?: "runXrayFromJson failed"
                    callback.onEmitStatus(1, message)
                    throw IllegalStateException(message)
                }
                // If state probe fails after a successful start, keep local running=true.
                val state = XrayBridge.invokeMethod("getXrayState")
                running = if (state.success) state.dataFieldAsBoolean("running") else true
            }
            callback.onEmitStatus(0, "core started")
        } catch (e: Exception) {
            running = false
            setTunFdEnv(null)
            callback.onEmitStatus(1, e.message)
            throw e
        }
    }

    fun stopLoop() {
        try {
            synchronized(coreLifecycleLock) {
                val response = XrayBridge.invokeMethod("stopXray")
                if (!response.success) {
                    Log.w(TAG, "stopXray returned error: ${response.error}")
                }
            }
        } finally {
            setTunFdEnv(null)
            running = false
            lastStats.clear()
            callback.shutdown()
        }
    }

    fun queryStats(tag: String, direction: String): Long {
        if (!isRunning) return 0L
        if (metricsListen.isBlank()) return 0L
        return try {
            val metricsUrl = if (metricsListen.startsWith("http://") || metricsListen.startsWith("https://")) {
                "${metricsListen.trimEnd('/')}/debug/vars"
            } else {
                "http://$metricsListen/debug/vars"
            }

            // libXray no longer exposes queryStats — fetch metrics HTTP endpoint directly.
            val body = fetchHttpBody(metricsUrl) ?: return 0L
            if (body.isBlank()) return 0L
            val total = extractTrafficTotal(body, tag, direction)
            val key = "$tag:$direction"
            val previous = lastStats.getOrPut(key) { AtomicLong(0L) }.getAndSet(total)
            (total - previous).coerceAtLeast(0L)
        } catch (e: Exception) {
            Log.w(TAG, "queryStats failed: ${e.message}")
            0L
        }
    }

    private fun sanitizeConfig(rawConfig: String, tunFd: Int?): String {
        return try {
            val root = JsonParser.parseString(rawConfig).asJsonObject
            metricsListen = extractMetricsListen(root)
            injectTunFdEnv(root, tunFd)
            // Avoid injecting metrics/stats blocks automatically.
            // Some libXray builds panic on repeated core starts when stats are re-registered.
            root.toString()
        } catch (e: Exception) {
            metricsListen = ""
            Log.w(TAG, "sanitizeConfig failed, using original config: ${e.message}")
            rawConfig
        }
    }

    private fun injectTunFdEnv(root: JsonObject, tunFd: Int?) {
        val value = (tunFd ?: 0).coerceAtLeast(0).toString()
        val env = if (root.has("env") && root.get("env").isJsonObject) {
            root.getAsJsonObject("env")
        } else {
            JsonObject().also { root.add("env", it) }
        }
        env.addProperty(TUN_FD_ENV, value)
        env.addProperty(TUN_FD_ENV_ALT, value)
        Log.d(TAG, "Injected tun fd into config env value=$value")
    }

    private fun extractMetricsListen(root: JsonObject): String {
        if (!root.has("metrics") || !root.get("metrics").isJsonObject) return ""
        val metricsObj = root.getAsJsonObject("metrics")
        if (!metricsObj.has("listen")) return ""
        return runCatching { metricsObj.get("listen").asString.trim() }
            .getOrDefault("")
    }

    private fun extractTrafficTotal(metricsBody: String, tag: String, direction: String): Long {
        val root = JsonParser.parseString(metricsBody).asJsonObject
        if (root.has("stats") && root.get("stats").isJsonObject) {
            val stats = root.getAsJsonObject("stats")
            if (stats.has("outbound") && stats.get("outbound").isJsonObject) {
                val outbound = stats.getAsJsonObject("outbound")
                if (outbound.has(tag) && outbound.get(tag).isJsonObject) {
                    val tagStats = outbound.getAsJsonObject(tag)
                    val nestedValue = tagStats.get(direction)?.safeAsLong()
                    if (nestedValue != null) return nestedValue
                }
            }
        }

        val statsObject = if (root.has("stats") && root.get("stats").isJsonObject) {
            root.getAsJsonObject("stats")
        } else root

        val key = "outbound>>>$tag>>>traffic>>>$direction"
        val direct = statsObject.get(key)?.safeAsLong()
        if (direct != null) return direct

        var fallback = 0L
        for ((name, value) in statsObject.entrySet()) {
            if (
                name.contains("outbound>>>$tag>>>traffic>>>", ignoreCase = true) &&
                name.endsWith(direction, ignoreCase = true)
            ) {
                fallback = value.safeAsLong() ?: fallback
            }
        }
        return fallback
    }

    private fun setTunFdEnv(tunFd: Int?) {
        val value = (tunFd ?: 0).coerceAtLeast(0).toString()
        val appliedPrimary = applyProcessEnv(TUN_FD_ENV, value)
        val appliedAlt = applyProcessEnv(TUN_FD_ENV_ALT, value)
        if (!appliedPrimary && !appliedAlt) {
            runCatching {
                System.setProperty(TUN_FD_ENV, value)
                System.setProperty(TUN_FD_ENV_ALT, value)
            }.onFailure {
                Log.w(TAG, "Failed to set tun fd fallback property: ${it.message}")
            }
        }
        Log.d(TAG, "Configured tun fd env value=$value")
    }

    private fun applyProcessEnv(name: String, value: String): Boolean {
        return runCatching {
            val osClass = Class.forName("android.system.Os")
            val setenv = osClass.getMethod(
                "setenv",
                String::class.java,
                String::class.java,
                java.lang.Boolean.TYPE
            )
            setenv.invoke(null, name, value, true)
            true
        }.getOrElse {
            Log.w(TAG, "applyProcessEnv failed for $name: ${it.message}")
            false
        }
    }

    private fun fetchHttpBody(url: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 1500
                readTimeout = 1500
                requestMethod = "GET"
                useCaches = false
            }
            val code = connection.responseCode
            if (code !in 200..299) return null
            BufferedReader(InputStreamReader(connection.inputStream, Charsets.UTF_8)).use { reader ->
                reader.readText()
            }
        } catch (e: Exception) {
            Log.w(TAG, "fetchHttpBody failed: ${e.message}")
            null
        } finally {
            connection?.disconnect()
        }
    }
}

private fun normalizeNumericTypes(value: Any?): Any? {
    return when (value) {
        is Map<*, *> -> {
            val out = LinkedHashMap<String, Any>()
            value.forEach { (k, v) ->
                val key = k?.toString() ?: return@forEach
                val normalized = normalizeNumericTypes(v) ?: return@forEach
                out[key] = normalized
            }
            out
        }
        is List<*> -> {
            value.mapNotNull { normalizeNumericTypes(it) }
        }
        is Double -> {
            if (!value.isFinite()) return value
            val longValue = value.toLong()
            if (value == longValue.toDouble()) {
                if (longValue in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()) {
                    longValue.toInt()
                } else {
                    longValue
                }
            } else {
                value
            }
        }
        else -> value
    }
}

internal data class CallResponse(
    val success: Boolean,
    val data: JsonElement?,
    val error: String?
) {
    fun dataAsJsonObject(): JsonObject? {
        val element = data ?: return null
        return when {
            element.isJsonObject -> element.asJsonObject
            element.isJsonPrimitive && element.asJsonPrimitive.isString -> {
                runCatching { JsonParser.parseString(element.asString).asJsonObject }.getOrNull()
            }
            else -> null
        }
    }

    fun dataFieldAsString(name: String): String {
        val obj = dataAsJsonObject() ?: return ""
        return runCatching { obj.get(name)?.asString }.getOrDefault("") ?: ""
    }

    fun dataFieldAsBoolean(name: String): Boolean {
        val obj = dataAsJsonObject() ?: return false
        return runCatching { obj.get(name)?.asBoolean }.getOrDefault(false) ?: false
    }

    fun dataFieldAsLong(name: String): Long {
        val obj = dataAsJsonObject() ?: return -1L
        return runCatching { obj.get(name)?.asLong }.getOrDefault(-1L) ?: -1L
    }
}

private fun decodeInvokeResponse(raw: String): CallResponse {
    if (raw.isBlank()) {
        return CallResponse(success = false, data = null, error = "empty response")
    }
    return try {
        val obj = JsonParser.parseString(raw).asJsonObject
        CallResponse(
            success = obj.get("success")?.asBoolean ?: false,
            data = obj.get("data"),
            error = obj.get("error")?.takeIf { !it.isJsonNull }?.asString
        )
    } catch (e: Exception) {
        CallResponse(success = false, data = null, error = e.message ?: "decode failed")
    }
}

private fun JsonElement.safeAsLong(): Long? {
    return runCatching {
        if (!isJsonPrimitive) return null
        asJsonPrimitive.asLong
    }.getOrNull()
}
