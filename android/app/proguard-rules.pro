# WorkManager (Notify me episode checks while the app is closed) builds its
# Room database and our workers by reflection. Release R8 stripped
# WorkDatabase_Impl's constructor and the app crashed at startup on the
# Formuler (+621: NoSuchMethodException WorkDatabase_Impl.<init>).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
