package app.vitasshift

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity statt FlutterActivity — von der `health`-Plugin-
// Doku für korrektes registerForActivityResult() unter Android 14 gefordert
// (Health-Connect-Berechtigungsdialog).
class MainActivity : FlutterFragmentActivity()
