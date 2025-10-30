package org.totem

import android.content.Intent
import android.provider.CalendarContract
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "org.totem.calendar"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "addToCalendar" -> {
                    try {
                        val args = call.arguments as Map<*, *>

                        val title = args["title"] as String? ?: ""
                        val desc = args["description"] as String? ?: ""
                        val location = args["location"] as String? ?: ""
                        val startMs = (args["start"] as Number).toLong()
                        val endMs = (args["end"] as Number).toLong()
                        val allDay = args["allDay"] as Boolean? ?: false
                        val reminderMinutesBefore = args["reminderMinutesBefore"] as Number?

                        val intent = Intent(Intent.ACTION_INSERT).apply {
                            data = CalendarContract.Events.CONTENT_URI
                            putExtra(CalendarContract.Events.TITLE, title)
                            putExtra(CalendarContract.Events.DESCRIPTION, desc)
                            putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                            putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMs)
                            putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMs)
                            putExtra(CalendarContract.Events.ALL_DAY, allDay)

                            if (reminderMinutesBefore != null) {
                                putExtra(
                                    CalendarContract.Reminders.MINUTES,
                                    reminderMinutesBefore.toInt()
                                )
                                putExtra(
                                    CalendarContract.Reminders.METHOD,
                                    CalendarContract.Reminders.METHOD_ALERT
                                )
                            }
                        }

                        // launch native calendar UI
                        startActivity(intent)

                        // We can't know if user actually saved, but we successfully opened
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("ERR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
