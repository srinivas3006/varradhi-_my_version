# App-specific R8 rules.
#
# Libraries ship their own keep rules (consumer rules) and the Flutter Gradle
# plugin adds the embedding's, so nothing here keeps a whole library. The old
# blanket rules (-keep io.flutter.**, com.google.firebase.**,
# androidx.media3.** { *; }) stopped R8 from shrinking, optimising or
# obfuscating most of the app: Play Console reported 29 % for each.

# Flutter Secure Storage: Tink/keystore classes reached by reflection.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Geolocator / geocoding: platform callbacks looked up by name.
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }

# Generic signatures and annotations, for libraries that read them at runtime.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Readable crash stack traces in Play Console (with the uploaded mapping).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Optional classes referenced by the Flutter embedding (deferred components)
# and by libraries, not shipped in this app.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.**
