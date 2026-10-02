# R8 para GunaYala Ride.
# Con esto Play Store ve el bundle optimizado, ofuscado y reducido (>=25%).
# Sin estas reglas el release rompe en arranque: Flutter, Firebase y los
# plugins de plataforma se registran e invocan por nombre, no por referencia.

# --- Flutter ---
# El embedding y los plugins se resuelven por nombre en el registrant.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# El motor llama a metodos nativos por su nombre de la tabla JNI.
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers class * {
    native <methods>;
}

# --- Firebase ---
# Auth/Storage/Messaging traen sus propias reglas de consumidor, asi que solo
# hace falta preservar lo que el SDK resuelve por reflexion.
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.storage.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.** { *; }
-keepclassmembers class com.google.firebase.auth.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# NO se hace -keep de TODO com.google.android.gms: son cientos de megabytes
# de Play Services que el SDK nunca llama, y mantenerlos deja la reduccion
# en 21%. Firebase ya declara lo que necesita.
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# --- Play Core / App Set ---
# Flutter lo invoca por nombre al dividir el bundle.
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# --- Kotlin / anotaciones ---
# Sin esto R8 borra las anotaciones y Firebase deja de leer los campos.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# --- Modelos de la app ---
# Se serializan a Firestore por nombre de campo.
-keep class com.gunayala.ride.models.** { *; }
-keep class com.gunayala.ride.enums.** { *; }

# --- Cosas que sobran en release ---
# Nunca se usan y solo inflan el DEX.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}
-assumenosideeffects class java.util.logging.Logger {
    public static *** log(...);
}
-dontwarn javax.annotation.**
-dontwarn sun.misc.**

# Codigo muerto que dejan librerias de escritorio.
-dontwarn java.beans.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
