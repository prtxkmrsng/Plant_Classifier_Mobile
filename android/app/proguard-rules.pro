# Preserve the primary PyTorch Native Bridge wrapper entry points
-keep class org.pytorch.** { *; }
-dontwarn org.pytorch.**

# Preserve the underlying PyTorch Mobile Lite Interpreter layers
-keep class org.pytorch.lite.** { *; }
-dontwarn org.pytorch.lite.**

# Keep class members accessed heavily via JNI Reflection
-keepclasseswithmembernames class * {
    native <methods>;
}

# Ensure runtime class names are preserved for back-end exception analysis
-keepattributes EnclosingMethod,InnerClasses,Signature

# ==============================================================================
# PYTORCH & FACEBOOK JNI RULES
# ==============================================================================

# 1. Existing PyTorch mappings (Keep these)
-keep class org.pytorch.** { *; }
-dontwarn org.pytorch.**
-keep class org.pytorch.lite.** { *; }
-dontwarn org.pytorch.lite.**

# 2. NEW: Preserve the Facebook JNI memory architecture classes completely
-keep class com.facebook.jni.** { *; }
-dontwarn com.facebook.jni.**

# 3. Explicitly shield HybridData and its internal Destructor subclasses
-keep class com.facebook.jni.HybridData {
    *** mDestructor;
}
-keep class com.facebook.jni.HybridData$Destructor { *; }

# 4. Native reflection rule parameters
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepattributes EnclosingMethod,InnerClasses,Signature,Annotation