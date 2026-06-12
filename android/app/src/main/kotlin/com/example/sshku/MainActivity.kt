package com.example.sshku

import android.os.Handler
import android.os.Looper
import com.jcraft.jsch.ChannelExec
import com.jcraft.jsch.ChannelShell
import com.jcraft.jsch.HostKey
import com.jcraft.jsch.JSch
import com.jcraft.jsch.Session
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.Socket
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.sshku/ssh"
    private val sessions = ConcurrentHashMap<String, Session>()
    private val shellSessions = ConcurrentHashMap<String, ShellSession>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var shellStreamHandler: ShellStreamHandler? = null
    private lateinit var shellEventChannel: EventChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        shellEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.sshku/shell_output")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.sshku/keys").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "encrypt" -> {
                        val data = call.argument<String>("data") ?: return@setMethodCallHandler result.error("INVALID_ARG", "data required", null)
                        result.success(KeystoreHelper.encrypt(data))
                    }
                    "decrypt" -> {
                        val data = call.argument<String>("data") ?: return@setMethodCallHandler result.error("INVALID_ARG", "data required", null)
                        result.success(KeystoreHelper.decrypt(data))
                    }
                    "generateKey" -> {
                        val type = call.argument<String>("type") ?: return@setMethodCallHandler result.error("INVALID_ARG", "type required", null)
                        val comment = call.argument<String>("comment") ?: ""
                        val keyResult = when (type) {
                            "ed25519" -> SshKeyGenerator.generateEd25519(comment)
                            "rsa" -> SshKeyGenerator.generateRsa(call.argument<Int>("bits") ?: 4096, comment)
                            else -> return@setMethodCallHandler result.error("INVALID_ARG", "type must be ed25519 or rsa", null)
                        }
                        result.success(keyResult)
                    }
                    "getPublicKey" -> {
                        val encryptedPrivateKey = call.argument<String>("encryptedPrivateKey") ?: return@setMethodCallHandler result.error("INVALID_ARG", "encryptedPrivateKey required", null)
                        val privateKey = KeystoreHelper.decrypt(encryptedPrivateKey)
                        val jsch = com.jcraft.jsch.JSch()
                        val keyPair = com.jcraft.jsch.KeyPair.load(jsch, privateKey.toByteArray(), null)
                        val out = java.io.ByteArrayOutputStream()
                        keyPair.writePublicKey(out, "")
                        keyPair.dispose()
                        result.success(out.toString("UTF-8"))
                    }
                    "importKey" -> {
                        val keyContent = call.argument<String>("keyContent") ?: return@setMethodCallHandler result.error("INVALID_ARG", "keyContent required", null)
                        val passphrase = call.argument<String>("passphrase")

                        Thread {
                            try {
                                if (keyContent.contains("PuTTY-User-Key-File")) {
                                    mainHandler.post { result.error("PPK_NOT_SUPPORTED", "PPK format not supported. Convert to OpenSSH: puttygen key.ppk -O private-openssh -o key", null) }
                                    return@Thread
                                }

                                val jsch = com.jcraft.jsch.JSch()
                                val keyPair = com.jcraft.jsch.KeyPair.load(jsch, keyContent.toByteArray(), null)

                                if (keyPair.isEncrypted) {
                                    if (passphrase.isNullOrEmpty()) {
                                        mainHandler.post { result.error("PASSPHRASE_REQUIRED", "Key is encrypted, passphrase required", null) }
                                        keyPair.dispose()
                                        return@Thread
                                    }
                                    if (!keyPair.decrypt(passphrase)) {
                                        mainHandler.post { result.error("INVALID_PASSPHRASE", "Invalid passphrase", null) }
                                        keyPair.dispose()
                                        return@Thread
                                    }
                                }

                                val type = when (keyPair.keyType) {
                                    com.jcraft.jsch.KeyPair.RSA -> "RSA"
                                    com.jcraft.jsch.KeyPair.DSA -> "DSA"
                                    com.jcraft.jsch.KeyPair.ECDSA -> "ECDSA"
                                    com.jcraft.jsch.KeyPair.ED25519 -> "ED25519"
                                    else -> "UNKNOWN"
                                }

                                val pubStream = java.io.ByteArrayOutputStream()
                                keyPair.writePublicKey(pubStream, "")
                                val publicKey = pubStream.toString("UTF-8").trim()
                                val encryptedPrivateKey = KeystoreHelper.encrypt(keyContent)
                                keyPair.dispose()

                                mainHandler.post {
                                    result.success(mapOf(
                                        "type" to type,
                                        "publicKey" to publicKey,
                                        "encryptedPrivateKey" to encryptedPrivateKey
                                    ))
                                }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("IMPORT_ERROR", e.message ?: "Failed to parse key", null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("KEYSTORE_ERROR", e.message, null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val host = call.argument<String>("host") ?: return@setMethodCallHandler result.error("INVALID_ARG", "host required", null)
                    val port = call.argument<Int>("port") ?: 22
                    val username = call.argument<String>("username") ?: return@setMethodCallHandler result.error("INVALID_ARG", "username required", null)
                    val password = call.argument<String>("password")
                    val privateKey = call.argument<String>("privateKey")
                    val acceptHostKey = call.argument<Boolean>("acceptHostKey") ?: false

                    Thread {
                        try {
                            val jsch = JSch()
                            if (privateKey != null) {
                                jsch.addIdentity("key", privateKey.toByteArray(), null, null)
                            }
                            val session = jsch.getSession(username, host, port)
                            if (password != null) {
                                session.setPassword(password)
                            }
                            if (acceptHostKey) {
                                session.setConfig("StrictHostKeyChecking", "no")
                            } else {
                                session.setConfig("StrictHostKeyChecking", "yes")
                                // Provide known host via in-memory repository
                                jsch.hostKeyRepository = object : com.jcraft.jsch.HostKeyRepository {
                                    override fun getHostKey() = arrayOf<HostKey>()
                                    override fun getHostKey(h: String?, t: String?) = arrayOf<HostKey>()
                                    override fun check(h: String?, k: ByteArray?) = com.jcraft.jsch.HostKeyRepository.OK
                                    override fun add(hostkey: HostKey?, ui: com.jcraft.jsch.UserInfo?) {}
                                    override fun remove(h: String?, t: String?) {}
                                    override fun remove(h: String?, t: String?, k: ByteArray?) {}
                                    override fun getKnownHostsRepositoryID() = "sshku"
                                }
                            }
                            session.connect(10000)
                            val sessionId = UUID.randomUUID().toString()
                            sessions[sessionId] = session
                            mainHandler.post { result.success(sessionId) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("SSH_CONNECT_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "getHostFingerprint" -> {
                    val host = call.argument<String>("host") ?: return@setMethodCallHandler result.error("INVALID_ARG", "host required", null)
                    val port = call.argument<Int>("port") ?: 22

                    Thread {
                        try {
                            val jsch = JSch()
                            val session = jsch.getSession("probe", host, port)
                            session.setConfig("StrictHostKeyChecking", "no")
                            // Use a short timeout just to get the host key
                            session.setConfig("PreferredAuthentications", "none")
                            try {
                                session.connect(10000)
                            } catch (_: Exception) {
                                // Auth will fail but host key is captured
                            }
                            val hostKey = session.hostKey
                            if (hostKey != null) {
                                val md = MessageDigest.getInstance("SHA-256")
                                val digest = md.digest(hostKey.key.let { 
                                    android.util.Base64.decode(it, android.util.Base64.DEFAULT) 
                                })
                                val fingerprint = "SHA256:" + android.util.Base64.encodeToString(digest, android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
                                val keyType = hostKey.type
                                session.disconnect()
                                mainHandler.post {
                                    result.success(mapOf(
                                        "fingerprint" to fingerprint,
                                        "keyType" to keyType
                                    ))
                                }
                            } else {
                                session.disconnect()
                                mainHandler.post { result.error("HOST_KEY_ERROR", "Could not retrieve host key", null) }
                            }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("HOST_KEY_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "disconnect" -> {
                    val sessionId = call.argument<String>("sessionId") ?: return@setMethodCallHandler result.error("INVALID_ARG", "sessionId required", null)
                    Thread {
                        try {
                            val session = sessions.remove(sessionId)
                            session?.disconnect()
                            mainHandler.post { result.success(true) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("SSH_DISCONNECT_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "execute" -> {
                    val sessionId = call.argument<String>("sessionId") ?: return@setMethodCallHandler result.error("INVALID_ARG", "sessionId required", null)
                    val command = call.argument<String>("command") ?: return@setMethodCallHandler result.error("INVALID_ARG", "command required", null)
                    val session = sessions[sessionId] ?: return@setMethodCallHandler result.error("SESSION_NOT_FOUND", "No session for id: $sessionId", null)

                    Thread {
                        try {
                            val channel = session.openChannel("exec") as ChannelExec
                            channel.setCommand(command)
                            channel.inputStream = null
                            val input = channel.inputStream
                            channel.connect(10000)
                            try {
                                val output = BufferedReader(InputStreamReader(input)).readText()
                                mainHandler.post { result.success(output) }
                            } finally {
                                channel.disconnect()
                            }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("SSH_EXEC_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "startKeepAlive" -> {
                    val duration = call.argument<Int>("duration") ?: 15
                    SshKeepAliveService.sessions = sessions
                    SshKeepAliveService.durationMinutes = duration
                    SshKeepAliveService.onExpired = {
                        mainHandler.post {
                            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                                .invokeMethod("keepAliveExpired", null)
                        }
                    }
                    val intent = android.content.Intent(this, SshKeepAliveService::class.java)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopKeepAlive" -> {
                    stopService(android.content.Intent(this, SshKeepAliveService::class.java))
                    result.success(true)
                }
                "openShell" -> {
                    val sessionId = call.argument<String>("sessionId") ?: return@setMethodCallHandler result.error("INVALID_ARG", "sessionId required", null)
                    val session = sessions[sessionId] ?: return@setMethodCallHandler result.error("SESSION_NOT_FOUND", "No session for id: $sessionId", null)
                    Thread {
                        try {
                            val channel = session.openChannel("shell") as ChannelShell
                            channel.setPtyType("vt100", 80, 24, 0, 0)
                            val inputStream = channel.inputStream
                            val outputStream = channel.outputStream
                            channel.connect(10000)
                            shellSessions[sessionId] = ShellSession(sessionId, session, channel, inputStream, outputStream)
                            mainHandler.post {
                                shellStreamHandler = ShellStreamHandler(inputStream)
                                shellEventChannel.setStreamHandler(shellStreamHandler)
                                result.success(sessionId)
                            }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("SHELL_OPEN_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "sendInput" -> {
                    val sessionId = call.argument<String>("sessionId") ?: return@setMethodCallHandler result.error("INVALID_ARG", "sessionId required", null)
                    val input = call.argument<String>("input") ?: return@setMethodCallHandler result.error("INVALID_ARG", "input required", null)
                    val shell = shellSessions[sessionId] ?: return@setMethodCallHandler result.error("SHELL_NOT_FOUND", "No shell for id: $sessionId", null)
                    Thread {
                        try {
                            shell.outputStream.write(input.toByteArray())
                            shell.outputStream.flush()
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("SHELL_INPUT_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "resizeShell" -> {
                    val sessionId = call.argument<String>("sessionId") ?: return@setMethodCallHandler result.error("INVALID_ARG", "sessionId required", null)
                    val cols = call.argument<Int>("cols") ?: return@setMethodCallHandler result.error("INVALID_ARG", "cols required", null)
                    val rows = call.argument<Int>("rows") ?: return@setMethodCallHandler result.error("INVALID_ARG", "rows required", null)
                    val shell = shellSessions[sessionId] ?: return@setMethodCallHandler result.error("SHELL_NOT_FOUND", "No shell for id: $sessionId", null)
                    shell.channel.setPtySize(cols, rows, 0, 0)
                    result.success(null)
                }
                "closeShell" -> {
                    val sessionId = call.argument<String>("sessionId") ?: return@setMethodCallHandler result.error("INVALID_ARG", "sessionId required", null)
                    val shell = shellSessions.remove(sessionId)
                    shellStreamHandler?.onCancel(null)
                    shellStreamHandler = null
                    shellEventChannel.setStreamHandler(null)
                    shell?.channel?.disconnect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        shellSessions.values.forEach { it.channel.disconnect() }
        shellSessions.clear()
        sessions.values.forEach { it.disconnect() }
        sessions.clear()
        super.onDestroy()
    }
}
