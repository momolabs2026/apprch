# Firebase / Play services
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

-keep class com.apprch.app.widget.** { *; }
-keep class androidx.glance.appwidget.** { *; }
