# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# JSch (mwiede fork)
-keep class com.jcraft.jsch.** { *; }
-dontwarn com.jcraft.jsch.**

# SLF4J (JSch dependency)
-dontwarn org.slf4j.**

# Platform Channels
-keep class com.sshku.app.** { *; }
-keep class com.example.sshku.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**

# Play Core (Flutter deferred components)
-dontwarn com.google.android.play.core.**
