# Flutter + plugins keep-rules for the minified release build.

# mobile_scanner delegates to ML Kit; its optional model classes are resolved
# reflectively, so R8 must not strip the missing-class references.
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }

# flutter_secure_storage relies on the AndroidX security library.
-keep class androidx.security.crypto.** { *; }

# Keep Flutter's embedding entry points.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
