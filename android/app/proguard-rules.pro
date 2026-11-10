# WorkManager (Notify me episode checks while the app is closed) builds its
# Room database and our workers by reflection. Release R8 stripped
# WorkDatabase_Impl's constructor and the app crashed at startup on the
# Formuler (+621: NoSuchMethodException WorkDatabase_Impl.<init>).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# smbj (network folder, NetworkFolder.kt): its event bus finds @Handler
# methods by reflection, so R8 must keep them; the rest are optional
# references (Kerberos, JCE, logging back ends) Android never loads.
-keep class com.hierynomus.** { *; }
-keep class net.engio.mbassy.** { *; }
-dontwarn com.hierynomus.**
-dontwarn net.engio.mbassy.**
-dontwarn org.slf4j.**
-dontwarn javax.el.**
-dontwarn org.ietf.jgss.**
-dontwarn javax.security.auth.**
-dontwarn org.bouncycastle.**
