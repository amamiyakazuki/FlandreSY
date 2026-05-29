package com.kazuki.zhulihotwater;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

final class UjingApi {
    private static final String PREF = "zhuli_hotwater";
    private static final String BASE = "https://phoenix.ujing.online/api/v1/";
    private static final String APP_VERSION = "2.4.14";
    private static final String MODEL = "HBN-AL00";
    private static final String BRAND = "HUAWEI";

    private final Context context;
    private final LegacyHotwaterActivity.Logger logger;
    private final Map<String, String> cookies = new HashMap<>();

    UjingApi(Context context, LegacyHotwaterActivity.Logger logger) {
        this.context = context.getApplicationContext();
        this.logger = logger;
    }

    void requestCaptcha(String mobile) throws Exception {
        Map<String, Object> query = new HashMap<>();
        query.put("mobile", mobile);
        query.put("type", 1);
        query.put("sessionId", "AFS_SWITCH_OFF");
        query.put("token", "AFS_SWITCH_OFF");
        query.put("sig", "AFS_SWITCH_OFF");
        JSONObject resp = get("captcha", query, "ZA", null, null);
        ensureOk(resp);
    }

    UjingSession login(String mobile, String captcha) throws Exception {
        JSONObject body = new JSONObject();
        body.put("mobile", mobile);
        body.put("captcha", captcha);
        JSONObject resp = post("login", body, "ZA", null, null);
        ensureOk(resp);
        JSONObject data = resp.getJSONObject("data");
        UjingSession session = new UjingSession();
        session.mobile = data.optString("mobile", mobile);
        session.token = data.optString("token");
        session.userId = data.optString("userId");
        session.serviceSubjectId = data.optString("serviceSubjectId");
        if (session.token.isEmpty()) {
            throw new IllegalStateException("U净登录成功但没有返回 token");
        }
        saveSession(session);
        return session;
    }

    UjingSession loadSession() {
        try {
            SharedPreferences sp = context.getSharedPreferences(PREF, Context.MODE_PRIVATE);
            String raw = sp.getString("ujing_session", "");
            if (raw == null || raw.isEmpty()) return null;
            JSONObject json = new JSONObject(raw);
            UjingSession s = new UjingSession();
            s.mobile = json.optString("mobile");
            s.token = json.optString("token");
            s.userId = json.optString("userId");
            s.serviceSubjectId = json.optString("serviceSubjectId");
            if (s.token.isEmpty()) return null;
            return s;
        } catch (Exception ignored) {
            return null;
        }
    }

    void saveSession(UjingSession session) throws Exception {
        JSONObject json = new JSONObject();
        json.put("mobile", session.mobile);
        json.put("token", session.token);
        json.put("userId", session.userId);
        json.put("serviceSubjectId", session.serviceSubjectId);
        context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .edit()
                .putString("ujing_session", json.toString())
                .apply();
    }

    void clearSession() {
        context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .edit()
                .remove("ujing_session")
                .apply();
    }

    WasherDevice scanWasher(UjingSession session, String qrCode) throws Exception {
        JSONObject body = new JSONObject();
        body.put("qrCode", qrCode);
        JSONObject resp = post("devices/scanWasherCode", body, "BA", "1.1.68", session);
        ensureOk(resp);
        JSONObject result = resp.getJSONObject("data").getJSONObject("result");
        WasherDevice device = new WasherDevice();
        device.deviceId = result.optString("deviceId");
        device.deviceTypeId = result.optInt("deviceTypeId");
        device.moduleType = result.optInt("moduleType");
        device.status = result.optInt("status");
        device.reason = result.optString("reason");
        device.createOrderEnabled = result.optBoolean("createOrderEnabled");
        device.needSync = result.optBoolean("needSync");
        device.raw = result;
        return device;
    }

    ProgramInfo getProgramInfo(UjingSession session, WasherDevice device) throws Exception {
        Map<String, Object> query = new HashMap<>();
        query.put("deviceId", device.deviceId);
        JSONObject resp = get("app/washer/devices/program/info", query, "BA", "1.1.68", session);
        ensureOk(resp);
        JSONObject data = resp.getJSONObject("data");
        ProgramInfo info = new ProgramInfo();
        info.deviceId = data.optString("deviceId", device.deviceId);
        info.deviceNo = data.optString("deviceNo");
        info.deviceTypeId = data.optInt("deviceTypeId", device.deviceTypeId);
        info.deviceTypeName = data.optString("deviceTypeName");
        info.storeId = data.optString("storeId");
        info.storeName = data.optString("storeName");
        info.raw = data;
        JSONArray models = data.optJSONArray("deviceWashModel");
        if (models != null) {
            for (int i = 0; i < models.length(); i++) {
                JSONObject item = models.getJSONObject(i);
                WashModel model = new WashModel();
                model.id = item.optInt("workModelId");
                model.name = item.optString("workModelName");
                model.price = item.optInt("basePrice");
                model.time = item.optInt("time");
                info.models.add(model);
                if (model.id == 1) {
                    info.defaultWashModelId = 1;
                }
            }
        }
        if (info.defaultWashModelId == 0 && !info.models.isEmpty()) {
            info.defaultWashModelId = info.models.get(0).id;
        }
        return info;
    }

    WasherOrder createOrder(UjingSession session, ProgramInfo info, int washModelId, int temperatureId) throws Exception {
        if (info.storeId == null || info.storeId.isEmpty()) {
            throw new IllegalStateException("套餐信息没有 storeId，不能创建订单");
        }
        JSONObject body = new JSONObject();
        body.put("type", 1);
        body.put("deviceTypeId", info.deviceTypeId);
        body.put("deviceId", info.deviceId);
        body.put("deviceWashModelId", washModelId);
        body.put("storeId", info.storeId);
        body.put("washTemperatureId", temperatureId);
        JSONObject resp = post("orders/create", body, "BA", "1.1.68", session);
        ensureOk(resp);
        JSONObject data = resp.getJSONObject("data");
        WasherOrder order = new WasherOrder();
        order.orderId = data.optString("orderId");
        order.deviceId = data.optString("deviceId", info.deviceId);
        order.raw = data;
        if (order.orderId.isEmpty()) {
            throw new IllegalStateException("创建订单成功但没有 orderId: " + resp);
        }
        return order;
    }

    JSONObject getOrderDetail(UjingSession session, String orderId) throws Exception {
        JSONObject resp = get("orders/" + orderId + "/detail", null, "BA", "1.1.68", session);
        ensureOk(resp);
        return resp.getJSONObject("data");
    }

    JSONObject getLastRunningOrder(UjingSession session) throws Exception {
        JSONObject resp = get("home/order/lastRunning", null, "QA", "1.0.15", session);
        ensureOk(resp);
        JSONObject data = resp.optJSONObject("data");
        if (data == null) {
            logger.log("Ujing lastRunning unknown response: " + resp);
            return new JSONObject();
        }
        return data;
    }

    JSONArray getRunningOrders(UjingSession session) throws Exception {
        JSONObject resp = get("home/order/running", null, "ZA", null, session);
        ensureOk(resp);
        Object data = resp.opt("data");
        if (data instanceof JSONArray) {
            return (JSONArray) data;
        }
        if (data instanceof JSONObject) {
            JSONObject obj = (JSONObject) data;
            JSONArray list = obj.optJSONArray("list");
            if (list != null) return list;
            JSONArray rows = obj.optJSONArray("rows");
            if (rows != null) return rows;
        }
        if (data != null) {
            logger.log("Ujing running unknown response: " + resp);
        }
        return new JSONArray();
    }

    JSONObject startOrder(UjingSession session, String orderId) throws Exception {
        JSONObject resp = get("orders/" + orderId + "/control/start", null, "BA", "1.1.68", session);
        ensureOk(resp);
        return resp.optJSONObject("data") == null ? new JSONObject() : resp.optJSONObject("data");
    }

    JSONObject stopOrder(UjingSession session, String orderId) throws Exception {
        JSONObject resp = get("orders/" + orderId + "/control/stop", null, "BA", "1.1.68", session);
        ensureOk(resp);
        return resp.optJSONObject("data") == null ? new JSONObject() : resp.optJSONObject("data");
    }

    JSONObject scanCode(UjingSession session, String qrCode) throws Exception {
        JSONObject body = new JSONObject();
        body.put("qrCode", qrCode);
        JSONObject resp = post("home/scanCode", body, "ZA", null, session);
        ensureOk(resp);
        JSONObject data = resp.optJSONObject("data");
        return data == null ? new JSONObject() : data;
    }

    WaterSubject changeWaterServiceSubjectWithScan(UjingSession session, String cd) throws Exception {
        JSONObject body = new JSONObject();
        body.put("cd", cd);
        JSONObject resp = post("water/serviceSubject/changeWithScan", body, "CA", "1.0.102", session);
        ensureOk(resp);
        JSONObject data = resp.getJSONObject("data");
        WaterSubject subject = new WaterSubject();
        subject.cd = cd;
        subject.serviceSubjectId = data.optString("newServiceSubjectId", data.optString("serviceSubjectId"));
        subject.serviceSubjectName = data.optString("newServiceSubjectName", data.optString("serviceSubjectName"));
        subject.storeId = data.optString("storeId");
        subject.balanceFen = data.optInt("balance", 0);
        subject.giftBalanceFen = data.optInt("giftBalance", 0);
        subject.forceRechargeFen = data.optInt("forceRecharge", 0);
        subject.rechargeTipAmountFen = data.optInt("rechargeTipAmount", 0);
        subject.moduleType = data.optInt("moduleType", 6);
        subject.raw = data;
        return subject;
    }

    WaterSubject getCurrentWaterInfo(UjingSession session, WaterSubject previous) throws Exception {
        JSONObject resp = get("app/water/serviceSubject/currentInfo", null, "CA", "1.0.102", session);
        ensureOk(resp);
        JSONObject data = resp.getJSONObject("data");
        WaterSubject subject = previous == null ? new WaterSubject() : previous.copy();
        subject.serviceSubjectId = data.optString("ServiceSubjectId", data.optString("serviceSubjectId", subject.serviceSubjectId));
        subject.serviceSubjectName = data.optString("ServiceSubjectName", data.optString("serviceSubjectName", subject.serviceSubjectName));
        subject.balanceFen = data.optInt("balance", subject.balanceFen);
        subject.giftBalanceFen = data.optInt("giftBalance", subject.giftBalanceFen);
        subject.forceRechargeFen = data.optInt("forceRecharge", subject.forceRechargeFen);
        subject.rechargeTipAmountFen = data.optInt("rechargeTipAmount", subject.rechargeTipAmountFen);
        subject.raw = data;
        return subject;
    }

    WaterOrder createWaterOrder(UjingSession session, String cd) throws Exception {
        JSONObject body = new JSONObject();
        body.put("deviceId", cd);
        JSONObject resp = post("water/createWaterOrder", body, "CA", "1.0.102", session);
        ensureOk(resp);
        JSONObject data = resp.getJSONObject("data");
        WaterOrder order = new WaterOrder();
        order.orderId = data.optString("orderId");
        order.orderNo = data.optString("orderNo");
        order.orderType = data.optInt("orderType", 6);
        order.deviceId = data.optString("deviceId");
        order.raw = data;
        if (order.orderId.isEmpty() || "0".equals(order.orderId)) {
            throw new IllegalStateException("创建饮水订单成功但没有 orderId: " + resp);
        }
        return order;
    }

    JSONObject getWaterOrderDetail(UjingSession session, String orderId) throws Exception {
        JSONObject body = new JSONObject();
        body.put("orderId", Long.parseLong(orderId));
        JSONObject resp = post("water/waterOrderDetail", body, "CA", "1.0.102", session);
        ensureOk(resp);
        return resp.getJSONObject("data");
    }

    JSONObject paymentMethods(UjingSession session, ProgramInfo info, String orderId) throws Exception {
        Map<String, Object> query = new HashMap<>();
        query.put("include", "");
        query.put("serviceSubjectId", session.serviceSubjectId);
        query.put("deviceId", info.deviceId);
        query.put("creativeNumber", "2898011024273709388");
        query.put("orderId", orderId);
        JSONObject resp = get("payment/methods", query, "BA", "1.1.68", session);
        ensureOk(resp);
        return resp;
    }

    JSONObject paymentArguments(UjingSession session, String orderId, String channel) throws Exception {
        Map<String, Object> query = new HashMap<>();
        query.put("channel", channel);
        query.put("orderId", orderId);
        query.put("couponId", "");
        query.put("isUseRedPacket", false);
        query.put("redPacketId", 0);
        query.put("alipayF2FNoAds", false);
        query.put("branchType", 0);
        query.put("jumpToAliMini", false);
        query.put("payVersion", 1);
        JSONObject resp = get("payment/arguments", query, "BA", "1.1.68", session);
        ensureOk(resp);
        return resp;
    }

    void cancelOrder(UjingSession session, String orderId) throws Exception {
        JSONObject body = new JSONObject();
        body.put("orderId", Long.parseLong(orderId));
        JSONObject resp = post("orders/" + orderId + "/cancel", body, "BA", "1.1.68", session);
        ensureOk(resp);
    }

    private JSONObject get(String path, Map<String, Object> query, String appCode, String weex, UjingSession session) throws Exception {
        String url = BASE + path + (query == null || query.isEmpty() ? "" : "?" + query(query));
        return request("GET", url, null, appCode, weex, session);
    }

    private JSONObject post(String path, JSONObject body, String appCode, String weex, UjingSession session) throws Exception {
        return request("POST", BASE + path, body.toString(), appCode, weex, session);
    }

    private JSONObject request(String method, String url, String body, String appCode, String weex, UjingSession session) throws Exception {
        logger.log("U净 " + method + " " + url);
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setRequestMethod(method);
        conn.setConnectTimeout(30000);
        conn.setReadTimeout(30000);
        conn.setRequestProperty("x-mobile-brand", BRAND);
        conn.setRequestProperty("x-mobile-id", "");
        conn.setRequestProperty("x-app-code", appCode);
        conn.setRequestProperty("x-app-version", APP_VERSION);
        conn.setRequestProperty("x-mobile-model", MODEL);
        conn.setRequestProperty("content-type", body == null ? "application/json" : "application/json; charset=utf-8");
        conn.setRequestProperty("accept-encoding", "identity");
        conn.setRequestProperty("user-agent", "okhttp/4.3.1");
        if (weex != null && !weex.isEmpty()) {
            conn.setRequestProperty("weex-version", weex);
        }
        if (session != null && session.token != null && !session.token.isEmpty()) {
            conn.setRequestProperty("authorization", "Bearer " + session.token);
        }
        String cookie = cookieHeader();
        if (!cookie.isEmpty()) {
            conn.setRequestProperty("cookie", cookie);
        }
        if (body != null) {
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            conn.setDoOutput(true);
            conn.setFixedLengthStreamingMode(bytes.length);
            try (OutputStream out = conn.getOutputStream()) {
                out.write(bytes);
            }
        }
        int code = conn.getResponseCode();
        rememberCookies(conn);
        InputStream stream = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
        String text = readAll(stream);
        if (code < 200 || code >= 300) {
            throw new IllegalStateException("HTTP " + code + ": " + text);
        }
        return new JSONObject(text);
    }

    private void ensureOk(JSONObject resp) {
        if (resp.optInt("code", 0) != 0) {
            throw new IllegalStateException(resp.optString("message", resp.toString()));
        }
    }

    private void rememberCookies(HttpURLConnection conn) {
        Map<String, List<String>> headers = conn.getHeaderFields();
        if (headers == null) return;
        List<String> setCookies = headers.get("Set-Cookie");
        if (setCookies == null) return;
        for (String item : setCookies) {
            String[] parts = item.split(";", 2);
            String[] kv = parts[0].split("=", 2);
            if (kv.length == 2) {
                cookies.put(kv[0], kv[1]);
            }
        }
    }

    private String cookieHeader() {
        if (cookies.isEmpty()) return "";
        List<String> parts = new ArrayList<>();
        for (Map.Entry<String, String> e : cookies.entrySet()) {
            parts.add(e.getKey() + "=" + e.getValue());
        }
        return String.join("; ", parts);
    }

    private static String query(Map<String, Object> query) throws Exception {
        List<String> parts = new ArrayList<>();
        for (Map.Entry<String, Object> e : query.entrySet()) {
            Object value = e.getValue();
            if (value == null) continue;
            parts.add(URLEncoder.encode(e.getKey(), "UTF-8") + "="
                    + URLEncoder.encode(String.valueOf(value), "UTF-8"));
        }
        return String.join("&", parts);
    }

    private static String readAll(InputStream stream) throws Exception {
        if (stream == null) return "";
        BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) {
            sb.append(line);
        }
        return sb.toString();
    }

    static final class UjingSession {
        String mobile;
        String token;
        String userId;
        String serviceSubjectId;
    }

    static final class WasherDevice {
        String deviceId;
        int deviceTypeId;
        int moduleType;
        int status;
        String reason;
        boolean createOrderEnabled;
        boolean needSync;
        JSONObject raw;
    }

    static final class ProgramInfo {
        String deviceId;
        String deviceNo;
        int deviceTypeId;
        String deviceTypeName;
        String storeId;
        String storeName;
        int defaultWashModelId;
        final List<WashModel> models = new ArrayList<>();
        JSONObject raw;

        String modelSummary() {
            StringBuilder sb = new StringBuilder();
            for (WashModel model : models) {
                sb.append(String.format(Locale.CHINA, "%s id=%d %.2f元 %d分钟\n",
                        model.name, model.id, model.price / 100.0, model.time));
            }
            return sb.toString();
        }
    }

    static final class WashModel {
        int id;
        String name;
        int price;
        int time;
    }

    static final class WasherOrder {
        String orderId;
        String deviceId;
        JSONObject raw;
    }

    static final class WaterSubject {
        String cd;
        String serviceSubjectId;
        String serviceSubjectName;
        String storeId;
        int balanceFen;
        int giftBalanceFen;
        int forceRechargeFen;
        int rechargeTipAmountFen;
        int moduleType;
        JSONObject raw;

        WaterSubject copy() {
            WaterSubject subject = new WaterSubject();
            subject.cd = cd;
            subject.serviceSubjectId = serviceSubjectId;
            subject.serviceSubjectName = serviceSubjectName;
            subject.storeId = storeId;
            subject.balanceFen = balanceFen;
            subject.giftBalanceFen = giftBalanceFen;
            subject.forceRechargeFen = forceRechargeFen;
            subject.rechargeTipAmountFen = rechargeTipAmountFen;
            subject.moduleType = moduleType;
            subject.raw = raw;
            return subject;
        }
    }

    static final class WaterOrder {
        String orderId;
        String orderNo;
        int orderType;
        String deviceId;
        JSONObject raw;
    }
}

