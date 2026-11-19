# Regras ProGuard/R8 específicas da aplicação Digital Shelf.
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
