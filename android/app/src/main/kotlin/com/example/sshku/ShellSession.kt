package com.example.sshku

import com.jcraft.jsch.ChannelShell
import com.jcraft.jsch.Session
import java.io.InputStream
import java.io.OutputStream

data class ShellSession(
    val sessionId: String,
    val session: Session,
    val channel: ChannelShell,
    val inputStream: InputStream,
    val outputStream: OutputStream
)
