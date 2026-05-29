package com.kazuki.zhulihotwater;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class HotwaterActionService extends Service {
    private static final String CHANNEL_ID = "hotwater_action";
    private static final int NOTIFICATION_ID = 1006445;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent == null ? "" : intent.getAction();
        boolean start = LegacyHotwaterActivity.ACTION_WIDGET_START.equals(action);
        boolean stop = LegacyHotwaterActivity.ACTION_WIDGET_STOP.equals(action);
        if (!start && !stop) {
            stopSelf(startId);
            return START_NOT_STICKY;
        }

        String label = start ? "正在开热水" : "正在关热水";
        createChannel();
        startForeground(NOTIFICATION_ID, notification(label));

        executor.execute(() -> {
            try {
                log("组件：" + (start ? "开热水" : "关热水"));
                if (start) {
                    HotwaterActionRunner.start(this, this::log);
                } else {
                    HotwaterActionRunner.stop(this, this::log);
                }
                log("组件执行完成");
            } catch (Exception e) {
                log("组件执行失败：" + e.getMessage());
            } finally {
                if (Build.VERSION.SDK_INT >= 24) {
                    stopForeground(STOP_FOREGROUND_REMOVE);
                } else {
                    stopForeground(true);
                }
                stopSelf(startId);
            }
        });
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        executor.shutdownNow();
    }

    private void log(String message) {
        AppLogStore.append(this, message);
    }

    private Notification notification(String text) {
        Intent open = new Intent(this, LogActivity.class);
        PendingIntent pending = PendingIntent.getActivity(
                this,
                20,
                open,
                Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0
        );
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);
        return builder
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle("一键热水")
                .setContentText(text)
                .setContentIntent(pending)
                .setOngoing(true)
                .build();
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        NotificationChannel existing = manager.getNotificationChannel(CHANNEL_ID);
        if (existing != null) return;
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "热水后台操作",
                NotificationManager.IMPORTANCE_LOW
        );
        channel.setDescription("桌面组件后台开关水时显示");
        manager.createNotificationChannel(channel);
    }
}

