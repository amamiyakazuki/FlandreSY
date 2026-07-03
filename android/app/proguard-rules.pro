# R8/ProGuard keep 规则。
# 修复：真机 release 扫码「相机启动失败，请重试 / genericError NullPointerException」。
# 根因：Flutter release 默认跑 R8，把 mobile_scanner 依赖的 CameraX / ML Kit 类混淆或删除，
# 插件运行时靠反射找不到 → 返回 null → 空指针。debug 不混淆故不崩，release 崩。
# 参考：mobile_scanner Android release 崩溃 issue #1507 / #221 / #719。

# --- ML Kit 条码扫描（mobile_scanner 底层）---
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**

# --- CameraX（相机会话 / 生命周期）---
-keep class androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }
-dontwarn androidx.camera.**

# --- mobile_scanner 插件本体 ---
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**
