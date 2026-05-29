package com.kazuki.zhulihotwater;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

public final class HotwaterRuntimeAdapter {
    private static final String PREF = "zhuli_hotwater";
    private final Context appContext;
    private final LegacyHotwaterActivity.Logger logger;

    public HotwaterRuntimeAdapter(Context context) {
        appContext = context.getApplicationContext();
        logger = message -> AppLogStore.append(appContext, "[hotwater-runtime] " + message);
    }

    public void startFromCache() throws Exception {
        HotwaterActionRunner.start(appContext, logger);
    }

    public void start(String phone, String password, String deviceId) throws Exception {
        HotwaterActionRunner.start(appContext, phone, password, deviceId, logger);
    }

    public void login(String phone, String password) throws Exception {
        if (phone == null || phone.trim().isEmpty()) {
            throw new IllegalStateException("请输入住理手机号");
        }
        if (password == null || password.isEmpty()) {
            throw new IllegalStateException("请输入住理密码");
        }
        phone = phone.trim();
        LegacyHotwaterActivity.ZhuliApi api = new LegacyHotwaterActivity.ZhuliApi(logger);
        LegacyHotwaterActivity.ZhuliSession session = api.login(phone, password);
        JSONObject json = new JSONObject();
        json.put("phone", phone);
        json.put("platformToken", session.platformToken);
        json.put("userId", session.userId);
        json.put("identityCode", session.identityCode);
        json.put("projectName", session.projectName);
        json.put("serverAddr", session.serverAddr);
        json.put("serverAppId", session.serverAppId);
        json.put("serverId", session.serverId);
        json.put("secretKey", session.secretKey);
        prefs().edit()
                .putString("phone", phone)
                .putString("session", json.toString())
                .apply();
        logger.log("登录成功并已缓存，用户ID=" + session.userId + "，项目=" + session.projectName);
    }

    public void stopFromCache() throws Exception {
        HotwaterActionRunner.stop(appContext, logger);
    }

    public boolean hasCachedRunningSession() {
        SharedPreferences sp = prefs();
        String deviceId = sp.getString("last_device_id", "");
        String isn = sp.getString("last_isn", "");
        return deviceId != null && !deviceId.isEmpty() && isn != null && !isn.isEmpty();
    }

    public List<HistoryRecord> loadRecentHistory(int days) throws Exception {
        LegacyHotwaterActivity.ZhuliSession session = loadCachedSession();
        if (session == null) {
            throw new IllegalStateException("请先登录住理生活账号");
        }

        SimpleDateFormat fmt = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.CHINA);
        Calendar endCal = Calendar.getInstance();
        String end = fmt.format(endCal.getTime());
        Calendar startCal = Calendar.getInstance();
        startCal.add(Calendar.DAY_OF_MONTH, -Math.max(1, days));
        String start = fmt.format(startCal.getTime());

        try {
            LegacyHotwaterActivity.ZhuliApi api = new LegacyHotwaterActivity.ZhuliApi(logger);
            JSONArray rows = api.listConsumeRecords(session, start, end);
            List<HistoryRecord> result = new ArrayList<>();
            for (int i = 0; i < rows.length(); i++) {
                JSONObject row = rows.getJSONObject(i);
                double money = row.optDouble("consume_money", 0);
                result.add(new HistoryRecord(
                        row.optString("create_at", "-"),
                        row.optString("device_id", "-"),
                        String.format(Locale.CHINA, "%.2f", money),
                        row.optString("status", "-"),
                        row.optString("order_id", "-")
                ));
            }
            return result;
        } catch (Exception e) {
            if (e.getMessage() != null && e.getMessage().contains("api_sign_error")) {
                clearCachedSession();
            }
            throw e;
        }
    }

    private LegacyHotwaterActivity.ZhuliSession loadCachedSession() {
        try {
            String raw = prefs().getString("session", "");
            if (raw == null || raw.isEmpty()) return null;
            JSONObject json = new JSONObject(raw);
            LegacyHotwaterActivity.ZhuliSession s = new LegacyHotwaterActivity.ZhuliSession();
            s.platformToken = json.optString("platformToken");
            s.userId = json.optString("userId");
            s.identityCode = json.optString("identityCode");
            s.projectName = json.optString("projectName");
            s.serverAddr = json.optString("serverAddr");
            s.serverAppId = json.optString("serverAppId");
            s.serverId = json.optString("serverId");
            s.secretKey = json.optString("secretKey");
            if (s.userId.isEmpty() || s.serverAddr.isEmpty() || s.secretKey.isEmpty()) return null;
            return s;
        } catch (Exception ignored) {
            return null;
        }
    }

    private void clearCachedSession() {
        prefs().edit().remove("session").apply();
    }

    private SharedPreferences prefs() {
        return appContext.getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    public static final class HistoryRecord {
        public final String time;
        public final String deviceId;
        public final String amount;
        public final String status;
        public final String orderId;

        HistoryRecord(String time, String deviceId, String amount, String status, String orderId) {
            this.time = time;
            this.deviceId = deviceId;
            this.amount = amount;
            this.status = status;
            this.orderId = orderId;
        }
    }
}
