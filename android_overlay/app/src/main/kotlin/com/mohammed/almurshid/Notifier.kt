package com.mohammed.almurshid

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

// Local notifications: shown immediately (new lectures after a sync) or scheduled with AlarmManager
// (deadline / exam / daily study reminders). Dart re-schedules everything every time the app opens.
object Notifier {
    private const val CH = "almurshid_updates"
    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun show(ctx: Context, id: Int, title: String, body: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CH, "تنبيهات المرشد", NotificationManager.IMPORTANCE_HIGH))
        }
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()
        val pi = PendingIntent.getActivity(ctx, id, open, FLAGS)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CH) else Notification.Builder(ctx)
        b.setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pi)
            .setAutoCancel(true)
        nm.notify(id, b.build())
    }

    private fun alarmIntent(ctx: Context, id: Int, title: String, body: String): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java)
            .putExtra("id", id).putExtra("title", title).putExtra("body", body)
        return PendingIntent.getBroadcast(ctx, id, i, FLAGS)
    }

    // AlarmManager forgets every alarm when the phone restarts, so each scheduled reminder is also saved
    // here; BootReceiver re-arms the ones still in the future after a restart / clock / time-zone change.
    private const val STORE = "reminders"
    private fun store(ctx: Context) = ctx.getSharedPreferences(STORE, Context.MODE_PRIVATE)

    // Inexact alarms (setAndAllowWhileIdle) need no special permission and are fine for study reminders.
    private fun arm(ctx: Context, id: Int, atMs: Long, title: String, body: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmIntent(ctx, id, title, body)
        if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
        else am.set(AlarmManager.RTC_WAKEUP, atMs, pi)
    }

    fun schedule(ctx: Context, id: Int, atMs: Long, title: String, body: String) {
        val o = org.json.JSONObject().put("at", atMs).put("title", title).put("body", body)
        store(ctx).edit().putString(id.toString(), o.toString()).apply()
        arm(ctx, id, atMs, title, body)
    }

    fun cancel(ctx: Context, id: Int) {
        store(ctx).edit().remove(id.toString()).apply()
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(ctx, id, "", ""))
    }

    // Called when a reminder fired: it no longer needs to be re-armed after a restart.
    fun fired(ctx: Context, id: Int) {
        store(ctx).edit().remove(id.toString()).apply()
    }

    // Re-arms every saved reminder that is still in the future; drops the old or broken ones.
    fun rearmAll(ctx: Context) {
        val p = store(ctx)
        val now = System.currentTimeMillis()
        val edit = p.edit()
        for ((k, v) in p.all) {
            try {
                val o = org.json.JSONObject(v as String)
                val at = o.getLong("at")
                if (at <= now) { edit.remove(k); continue }
                arm(ctx, k.toInt(), at, o.optString("title"), o.optString("body"))
            } catch (e: Exception) {
                edit.remove(k)
            }
        }
        edit.apply()
    }
}

// Phone restarted / clock changed / time zone changed / app updated: put the reminders back.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, i: Intent) {
        when (i.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> Notifier.rearmAll(ctx)
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, i: Intent) {
        val id = i.getIntExtra("id", 0)
        Notifier.fired(ctx, id)
        Notifier.show(ctx, id, i.getStringExtra("title") ?: "المرشد الدراسي", i.getStringExtra("body") ?: "")
    }
}
