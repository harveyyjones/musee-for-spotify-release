-keep class io.grpc.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}