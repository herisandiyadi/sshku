package com.example.sshku

import com.jcraft.jsch.JSch
import com.jcraft.jsch.KeyPair
import java.io.ByteArrayOutputStream

object SshKeyGenerator {
    fun generateEd25519(comment: String): Map<String, String> {
        return generate(KeyPair.ED25519, 0, comment)
    }

    fun generateRsa(bits: Int = 4096, comment: String): Map<String, String> {
        return generate(KeyPair.RSA, bits, comment)
    }

    private fun generate(type: Int, bits: Int, comment: String): Map<String, String> {
        val jsch = JSch()
        val keyPair = if (bits > 0) KeyPair.genKeyPair(jsch, type, bits) else KeyPair.genKeyPair(jsch, type)
        keyPair.setPublicKeyComment(comment)
        val privateOut = ByteArrayOutputStream()
        keyPair.writePrivateKey(privateOut)
        val privateKey = privateOut.toString("UTF-8")
        val publicOut = ByteArrayOutputStream()
        keyPair.writePublicKey(publicOut, comment)
        val publicKey = publicOut.toString("UTF-8")
        keyPair.dispose()
        val encryptedPrivateKey = KeystoreHelper.encrypt(privateKey)
        return mapOf("publicKey" to publicKey, "encryptedPrivateKey" to encryptedPrivateKey)
    }
}
