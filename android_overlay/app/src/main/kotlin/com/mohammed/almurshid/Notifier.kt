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

    fun schedule(ctx: Context, id: Int, atMs: Long, title: String, body: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmIntent(ctx, id, title, body)
        if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
        else am.set(AlarmManager.RTC_WAKEUP, atMs, pi)
    }

    fun cancel(ctx: Context, id: Int) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(ctx, id, "", ""))
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, i: Intent) {
        Notifier.show(ctx, i.getIntExtra("id", 0), i.getStringExtra("title") ?: "المرشد الدراسي", i.getStringExtra("body") ?: "")
    }
}
