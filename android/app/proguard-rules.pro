# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Google Sign-In - CRITICAL for Release builds
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keepclassmembers class com.google.android.gms.auth.api.signin.** { *; }

# Google Play Services
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Pigeon (Flutter <-> Android communication) - CRITICAL
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class dev.flutter.pigeon.google_sign_in_android.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Supabase / HTTP
-keep class io.supabase.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep Kotlin Coroutines (used by many plugins)
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Don't warn about missing optional dependencies
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.**
-dontwarn io.flutter.**
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
