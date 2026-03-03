# Socket.IO client
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# OkHttp
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson / JSON
-keep class org.json.** { *; }
-keepattributes *Annotation*
-keepattributes Signature

# Keep BuildConfig so log messages include the URL
-keep class com.neoagent.aurora.BuildConfig { *; }
