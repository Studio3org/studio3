# Firebase Messaging — background message handling locates the Dart
# callback/entrypoint via reflection; keep these classes intact.
-keep class com.google.firebase.messaging.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-dontwarn com.google.firebase.**

# photo_manager — Flutter method-channel argument (de)serialization uses
# reflection over these classes.
-keep class com.fluttercandies.photo_manager.** { *; }
-dontwarn com.fluttercandies.photo_manager.**

# Flutter's own embedding/plugin-registration classes — defensive, in case a
# plugin is missing its own consumer proguard rules.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Reflection metadata some plugins rely on (Gson-style (de)serialization,
# generic type resolution).
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Flutter's engine has optional support for Play Store "deferred components"
# (dynamic feature modules) via com.google.android.play:core, which this app
# doesn't depend on or use — these classes are genuinely absent, not a real
# problem, so tell R8 not to warn about them (exact rules R8 itself
# generated into build/app/outputs/mapping/release/missing_rules.txt).
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Stripe (flutter_stripe): the Android SDK's push provisioning classes are optional and
# absent; keep the SDK's own classes for its reflection-based (de)serialization.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**
-keep class com.stripe.android.** { *; }
-keep class com.reactnativestripesdk.** { *; }
