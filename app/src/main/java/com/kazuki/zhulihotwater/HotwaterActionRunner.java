package com.kazuki.zhulihotwater;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

final class HotwaterActionRunner {
    private static final String PREF = "zhuli_hotwater";

    private HotwaterActionRunner() {
    }

    static void start(Context context, LegacyHotwaterActivity.Logger logger) throws Exception {
        SharedPreferences sp = prefs(context);
        String phone = sp.getString("phone", "");
        String deviceId = sp.getString("device_id", "1006445");
        start(context, phone, "", deviceId, logger);
    }

    static void stop(Context context, LegacyHotwaterActivity.Logger logger) throws Exception {
        SharedPreferences sp = prefs(context);
        String phone = sp.getString("phone", "");
        String deviceId = sp.getString("device_id", "1006445");
        stop(context, phone, deviceId, logger);
    }

    static void start(Context context, String phone, String password, String deviceId, LegacyHotwaterActivity.Logger logger) throws Exception {
        if (phone == null || phone.trim().isEmpty()) {
            throw new IllegalStateException("请先打开 App 填手机号并登录一次");
        }
        if (deviceId == null || deviceId.trim().isEmpty()) {
            throw new IllegalStateException("设备号为空");
        }
        phone = phone.trim();
        deviceId = deviceId.trim();
        prefs(context).edit().putString("phone", phone).putString("device_id", deviceId).apply();

        LegacyHotwaterActivity.BleDeviceSession ble = null;
        try {
            LegacyHotwaterActivity.ZhuliApi api = new LegacyHotwaterActivity.ZhuliApi(logger);
            LegacyHotwaterActivity.ZhuliSession session = loadCachedSession(context, phone);
            if (session == null) {
                if (password == null || password.isEmpty()) {
                    throw new IllegalStateException("没有缓存登录状态，请先打开 App 登录一次");
                }
                session = api.login(phone, password);
                saveCachedSession(context, phone, session);
                logger.log("登录成功并已缓存，用户ID=" + session.userId + "，项目=" + session.projectName);
            } else {
                logger.log("使用缓存登录状态，用户ID=" + session.userId + "，项目=" + session.projectName);
            }

            JSONObject device = api.getDeviceById(session, deviceId);
            String bleName = device.optString("ble_name");
            String bleMac = device.optString("ble_mac");
            int deviceType = device.optInt("device_type");
            logger.log("设备信息：type=" + deviceType + " ble_name=" + bleName + " ble_mac=" + bleMac);

            ble = new LegacyHotwaterActivity.BleDeviceSession(context.getApplicationContext(), logger);
            ble.connect(bleName, bleMac);
            logger.log("蓝牙已连接");

            String handCmd = api.createHandshake(session, deviceId);
            String handHex = ble.writeAndWait(handCmd, "cmd_hand_shark");
            JSONObject hand = api.handshakeResponse(session, deviceId, handHex);
            String isn = hand.optString("isn");
            String rateCmd = hand.optString("ratecmd");
            ble.isn = isn;
            saveLastSessionState(context, deviceId, isn, "");
            logger.log("握手完成，isn=" + isn);

            if (!rateCmd.isEmpty() && deviceType != 3 && deviceType != 5) {
                ble.writeAndWait(rateCmd, "cmd_set_rate");
                logger.log("费率指令已写入");
            }

            if (deviceType != 3 && deviceType != 5 && hand.optInt("result") != 3) {
                String historyCmd = api.createHistoryOrderCmd(session, deviceId, isn);
                if (!historyCmd.isEmpty()) {
                    String historyHex = ble.writeAndWait(historyCmd, "cmd_history_order");
                    api.endConsumeResponse(session, deviceId, historyHex);
                    logger.log("历史订单同步完成");
                }
            }

            JSONObject order = api.createBleOrder(session, deviceId, isn);
            String appBytes = order.optString("app_bytes");
            String orderId = order.optString("order_id");
            if (appBytes.isEmpty() || orderId.isEmpty()) {
                throw new IllegalStateException("下单返回缺少 app_bytes/order_id: " + order);
            }
            saveLastSessionState(context, deviceId, isn, orderId);
            logger.log("订单已创建，order_id=" + orderId);

            String startHex = ble.writeAndWait(appBytes, "cmd_start_order");
            JSONObject startResult = api.startConsumeResponse(session, deviceId, orderId, startHex);
            logger.log("启动确认完成：" + startResult.toString());
        } catch (Exception e) {
            if (e.getMessage() != null && e.getMessage().contains("api_sign_error")) {
                clearCachedSession(context);
            }
            throw e;
        } finally {
            if (ble != null) {
                ble.close();
            }
        }
    }

    static void stop(Context context, String phone, String deviceId, LegacyHotwaterActivity.Logger logger) throws Exception {
        if (phone == null || phone.trim().isEmpty()) {
            throw new IllegalStateException("请先打开 App 填手机号并登录一次");
        }
        if (deviceId == null || deviceId.trim().isEmpty()) {
            throw new IllegalStateException("设备号为空");
        }
        phone = phone.trim();
        deviceId = deviceId.trim();

        LegacyHotwaterActivity.BleDeviceSession ble = null;
        try {
            LegacyHotwaterActivity.ZhuliApi api = new LegacyHotwaterActivity.ZhuliApi(logger);
            LegacyHotwaterActivity.ZhuliSession session = loadCachedSession(context, phone);
            if (session == null) {
                throw new IllegalStateException("没有缓存登录状态，请先打开 App 登录一次");
            }
            String isn = getLastIsn(context, deviceId);
            if (isn == null || isn.isEmpty()) {
                throw new IllegalStateException("没有可用的 isn，请先用本 App 开水一次再关水");
            }

            JSONObject device = api.getDeviceById(session, deviceId);
            String bleName = device.optString("ble_name");
            String bleMac = device.optString("ble_mac");
            ble = new LegacyHotwaterActivity.BleDeviceSession(context.getApplicationContext(), logger);
            ble.isn = isn;
            ble.connect(bleName, bleMac);
            logger.log("蓝牙已连接");

            String endCmd = api.createEndConsumeCmd(session, deviceId, ble.isn);
            String endHex = ble.writeAndWait(endCmd, "cmd_end_consume");
            JSONObject result = api.endConsumeResponse(session, deviceId, endHex);
            clearLastSessionState(context);
            logger.log("结束完成：" + result.toString());
        } finally {
            if (ble != null) {
                ble.close();
            }
        }
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    private static void saveCachedSession(Context context, String phone, LegacyHotwaterActivity.ZhuliSession s) throws Exception {
        JSONObject json = new JSONObject();
        json.put("phone", phone);
        json.put("platformToken", s.platformToken);
        json.put("userId", s.userId);
        json.put("identityCode", s.identityCode);
        json.put("projectName", s.projectName);
        json.put("serverAddr", s.serverAddr);
        json.put("serverAppId", s.serverAppId);
        json.put("serverId", s.serverId);
        json.put("secretKey", s.secretKey);
        prefs(context).edit().putString("session", json.toString()).apply();
    }

    private static LegacyHotwaterActivity.ZhuliSession loadCachedSession(Context context, String phone) {
        if (phone == null || phone.isEmpty()) return null;
        try {
            String raw = prefs(context).getString("session", "");
            if (raw == null || raw.isEmpty()) return null;
            JSONObject json = new JSONObject(raw);
            if (!phone.equals(json.optString("phone"))) return null;
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

    private static void clearCachedSession(Context context) {
        prefs(context).edit().remove("session").apply();
    }

    private static void saveLastSessionState(Context context, String deviceId, String isn, String orderId) {
        prefs(context).edit()
                .putString("last_device_id", deviceId)
                .putString("last_isn", isn == null ? "" : isn)
                .putString("last_order_id", orderId == null ? "" : orderId)
                .apply();
    }

    private static String getLastIsn(Context context, String deviceId) {
        SharedPreferences sp = prefs(context);
        if (!deviceId.equals(sp.getString("last_device_id", ""))) return "";
        return sp.getString("last_isn", "");
    }

    private static void clearLastSessionState(Context context) {
        prefs(context).edit()
                .remove("last_device_id")
                .remove("last_isn")
                .remove("last_order_id")
                .apply();
    }
}

