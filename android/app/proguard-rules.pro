# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Unity Ads, Vungle (Liftoff Monetize), and Meta Audience Network SDKs —
# all mediated through Unity LevelPlay (banner, MREC, streak-repair
# rewarded/interstitial — see ad_service.dart) rather than called
# directly.
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-keep class com.vungle.ads.** { *; }
-keep class com.facebook.ads.** { *; }
-keep class com.unity3d.mediation.** { *; }
-keep class com.ironsource.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**
-dontwarn com.vungle.ads.**
-dontwarn com.facebook.ads.**
-dontwarn com.unity3d.mediation.**
-dontwarn com.ironsource.**

# Mintegral SDK — also mediated through LevelPlay. Account is under
# review, code-only for now, so this keep rule matters once approved,
# not before. (PubMatic and Pangle removed — see build.gradle.kts.)
-keep class com.mbridge.** { *; }
-dontwarn com.mbridge.**

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
