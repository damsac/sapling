# Keep JNA classes used by UniFFI bindings
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }

# Keep UniFFI-generated Kotlin bindings
-keep class dev.damsac.sapling.rust.** { *; }
