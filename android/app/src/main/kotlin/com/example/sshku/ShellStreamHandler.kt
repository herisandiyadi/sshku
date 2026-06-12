package com.example.sshku

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.InputStream

class ShellStreamHandler(private val inputStream: InputStream) : EventChannel.StreamHandler {
    @Volatile
    private var running = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        running = true
        Thread {
            val buffer = ByteArray(4096)
            try {
                while (running) {
                    val len = inputStream.read(buffer)
                    if (len == -1) break
                    val data = String(buffer, 0, len, Charsets.UTF_8)
                    mainHandler.post { events?.success(data) }
                }
            } catch (e: Exception) {
                if (running) {
                    mainHandler.post { events?.error("STREAM_ERROR", e.message, null) }
                }
            }
            mainHandler.post { events?.endOfStream() }
        }.start()
    }

    override fun onCancel(arguments: Any?) {
        running = false
    }
}
