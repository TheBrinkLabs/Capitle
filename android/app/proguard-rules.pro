# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Unity Ads (rewarded only — see ad_service.dart)
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

# Meta Audience Network (banner/MREC, via our own native bridge in
# android/app/.../meta_ads/ — no Flutter plugin involved)
-keep class com.facebook.ads.** { *; }
-dontwarn com.facebook.ads.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Play Core (deferred components / split install — referenced by Flutter's
# embedding even if not directly used; safe to keep to avoid R8 stripping
# classes Flutter's engine expects to find)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep annotations and generic signatures needed for reflection-based
# libraries (Gson-style serialization, used indirectly by some plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson — flutter_local_notifications uses Gson internally to persist
# scheduled notifications to disk, via TypeToken's generic-type reflection.
# -keepattributes Signature above is necessary but NOT sufficient on
# modern R8 (3.0+) — Gson's own official ProGuard guidance requires these
# additional explicit rules, otherwise TypeToken subclasses crash at
# runtime with reflection failures in release builds specifically
# (this exact crash: com.google.gson.reflect.TypeToken.getSuperclassTypeParameter).
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.stream.** { *; }
-dontwarn com.google.gson.**
