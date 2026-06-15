package com.example.sshku

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.sshku/keys").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "encrypt" -> {
                        val data = call.argument<String>("data") ?: return@setMethodCallHandler result.error("INVALID_ARG", "data required", null)
                        Thread {
                            try {
                                val encrypted = KeystoreHelper.encrypt(data)
                                mainHandler.post { result.success(encrypted) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("KEYSTORE_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "decrypt" -> {
                        val data = call.argument<String>("data") ?: return@setMethodCallHandler result.error("INVALID_ARG", "data required", null)
                        Thread {
                            try {
                                val decrypted = KeystoreHelper.decrypt(data)
                                mainHandler.post { result.success(decrypted) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("KEYSTORE_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "generateKey" -> {
                        val type = call.argument<String>("type") ?: return@setMethodCallHandler result.error("INVALID_ARG", "type required", null)
                        val comment = call.argument<String>("comment") ?: ""
                        Thread {
                            try {
                                val keyResult = when (type) {
                                    "ed25519" -> SshKeyGenerator.generateEd25519(comment)
                                    "rsa" -> SshKeyGenerator.generateRsa(call.argument<Int>("bits") ?: 4096, comment)
                                    else -> {
                                        mainHandler.post { result.error("INVALID_ARG", "type must be ed25519 or rsa", null) }
                                        return@Thread
                                    }
                                }
                                mainHandler.post { result.success(keyResult) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("KEYSTORE_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "getPublicKey" -> {
                        val encryptedPrivateKey = call.argument<String>("encryptedPrivateKey") ?: return@setMethodCallHandler result.error("INVALID_ARG", "encryptedPrivateKey required", null)
                        Thread {
                            try {
                                val privateKey = KeystoreHelper.decrypt(encryptedPrivateKey)
                                val jsch = com.jcraft.jsch.JSch()
                                val keyPair = com.jcraft.jsch.KeyPair.load(jsch, privateKey.toByteArray(), null)
                                val out = java.io.ByteArrayOutputStream()
                                keyPair.writePublicKey(out, "")
                                keyPair.dispose()
                                mainHandler.post { result.success(out.toString("UTF-8")) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("KEYSTORE_ERROR", e.message, null) }
                            }
                        }.start()
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
    }
}
