package com.kazuki.zhulihotwater;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

public class HotwaterWidgetProvider extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] appWidgetIds) {
        for (int id : appWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_hotwater);
            views.setOnClickPendingIntent(R.id.widget_start,
                    serviceIntent(context, LegacyHotwaterActivity.ACTION_WIDGET_START, 10));
            views.setOnClickPendingIntent(R.id.widget_stop,
                    serviceIntent(context, LegacyHotwaterActivity.ACTION_WIDGET_STOP, 11));
            manager.updateAppWidget(id, views);
        }
    }

    private PendingIntent serviceIntent(Context context, String action, int requestCode) {
        Intent intent = new Intent(context, HotwaterActionService.class);
        intent.setAction(action);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (android.os.Build.VERSION.SDK_INT >= 23) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            return PendingIntent.getForegroundService(context, requestCode, intent, flags);
        }
        return PendingIntent.getService(context, requestCode, intent, flags);
    }
}

