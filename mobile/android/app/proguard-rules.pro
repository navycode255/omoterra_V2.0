# Flutter's embedding is reached reflectively from the platform side, so R8
# cannot see those entry points and would otherwise strip them.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter's embedding references the Play Store deferred-components API, which
# this app does not bundle because it ships no deferred components. The code
# paths are unreachable, so the references are safe to ignore.
-dontwarn com.google.android.play.core.**
