# RazorPay specific rules
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepattributes *Annotation*

# Keep classes with @Keep and @KeepClassMembers annotations
-keep @proguard.annotation.Keep class * { *; }
-keepclassmembers class * {
    @proguard.annotation.Keep *;
}
-keepclassmembers @proguard.annotation.KeepClassMembers class * {
    *;
}

-keep class android.window.BackEvent { *; }
-keepclassmembers class io.flutter.view.FlutterView {
    void startBackGesture(android.window.BackEvent);
    void continueBackGesture(android.window.BackEvent);
}