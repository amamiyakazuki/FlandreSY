package com.kazuki.zhulihotwater;

import android.content.Context;
import android.content.SharedPreferences;

public final class AppLogStore {
    private static final String PREF = "zhuli_hotwater";
    private static final String KEY_LOGS = "logs";
    private static final int MAX_CHARS = 16000;

    private AppLogStore() {
    }

    public static synchronized void append(Context context, String message) {
        SharedPreferences sp = context.getApplicationContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
        String line = "[" + System.currentTimeMillis() / 1000 + "] " + message + "\n";
        String merged = sp.getString(KEY_LOGS, "") + line;
        if (merged.length() > MAX_CHARS) {
            merged = merged.substring(merged.length() - MAX_CHARS);
        }
        sp.edit().putString(KEY_LOGS, merged).apply();
    }

    public static String read(Context context) {
        return context.getApplicationContext()
                .getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .getString(KEY_LOGS, "");
    }

    public static void clear(Context context) {
        context.getApplicationContext()
                .getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_LOGS)
                .apply();
    }
}

