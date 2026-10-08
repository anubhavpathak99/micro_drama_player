# WorkManager comes in with the Google Mobile Ads SDK and builds its Room
# database by reflection at startup. Without this rule R8 strips the generated
# database's constructor, and release builds crash on launch with "Failed to
# create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
