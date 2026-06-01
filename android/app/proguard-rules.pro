# Flutter / Dart
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }

# Keep app entry point
-keep class com.bookkeeping.bookkeeping.MainActivity { *; }

# Network / HTTP — Dart uses Java HttpURLConnection on Android
-keep class java.net.** { *; }
-keep class javax.net.** { *; }
-keep class javax.net.ssl.** { *; }
-keep class sun.security.** { *; }
-dontwarn java.net.**
-dontwarn javax.net.**

# JSON
-keep class org.json.** { *; }

# HTTP client internals
-keep class com.android.org.conscrypt.** { *; }
-dontwarn com.android.org.conscrypt.**
