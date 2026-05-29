package com.kazuki.zhulihotwater;

import android.content.Context;
import android.content.SharedPreferences;

import com.alipay.sdk.app.PayTask;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Map;

public final class UjingRuntimeAdapter {
    private static final String PREF = "zhuli_hotwater";
    private final Context appContext;
    private final UjingApi api;
    private UjingApi.WasherDevice currentDevice;
    private UjingApi.ProgramInfo currentProgram;
    private UjingApi.WasherOrder currentOrder;
    private UjingApi.WaterSubject currentWaterSubject;
    private UjingApi.WaterOrder currentWaterOrder;

    public UjingRuntimeAdapter(Context context) {
        appContext = context.getApplicationContext();
        api = new UjingApi(appContext, message -> AppLogStore.append(appContext, "[ujing-runtime] " + message));
    }

    public void requestCaptcha(String mobile) throws Exception {
        String normalized = normalizeMobile(mobile);
        api.requestCaptcha(normalized);
        prefs().edit().putString("ujing_phone", normalized).apply();
    }

    public AccountSession login(String mobile, String captcha) throws Exception {
        String normalized = normalizeMobile(mobile);
        if (captcha == null || captcha.trim().isEmpty()) {
            throw new IllegalStateException("请输入 U净验证码");
        }
        UjingApi.UjingSession session = api.login(normalized, captcha.trim());
        prefs().edit().putString("ujing_phone", normalized).apply();
        return toAccountSession(session);
    }

    public AccountSession loadCachedSession() {
        UjingApi.UjingSession session = api.loadSession();
        if (session == null) return null;
        return toAccountSession(session);
    }

    public void clearCachedSession() {
        api.clearSession();
        currentDevice = null;
        currentProgram = null;
        currentOrder = null;
        currentWaterSubject = null;
        currentWaterOrder = null;
    }

    public WasherProgram scanWasherAndLoadProgram(String qrCode) throws Exception {
        if (qrCode == null || qrCode.trim().isEmpty()) {
            throw new IllegalStateException("请先扫描洗衣机二维码");
        }
        UjingApi.UjingSession session = requireSession();
        String normalized = qrCode.trim();
        prefs().edit().putString("ujing_washer_qr", normalized).apply();
        currentDevice = api.scanWasher(session, normalized);
        if (!currentDevice.createOrderEnabled) {
            currentProgram = null;
            return new WasherProgram(currentDevice, null);
        }
        currentProgram = api.getProgramInfo(session, currentDevice);
        return new WasherProgram(currentDevice, currentProgram);
    }

    public WasherProgram refreshWasherStatus(String qrCode) throws Exception {
        if (qrCode == null || qrCode.trim().isEmpty()) {
            throw new IllegalStateException("洗衣机二维码为空");
        }
        UjingApi.UjingSession session = requireSession();
        UjingApi.WasherDevice device = api.scanWasher(session, qrCode.trim());
        UjingApi.ProgramInfo program = null;
        if (device.createOrderEnabled) {
            program = api.getProgramInfo(session, device);
        }
        return new WasherProgram(device, program);
    }

    public WasherOrderDetail createOrder(int washModelId, int temperatureId, Integer detergentGearId, Integer disinfectantGearId) throws Exception {
        UjingApi.UjingSession session = requireSession();
        if (currentProgram == null) {
            throw new IllegalStateException("请先扫描洗衣机并获取套餐");
        }
        currentOrder = api.createOrder(session, currentProgram, washModelId, temperatureId, detergentGearId, disinfectantGearId);
        saveCurrentOrderId(currentOrder.orderId);
        return loadOrderDetail(currentOrder.orderId);
    }

    public WasherOrderDetail loadCurrentOrderDetail() throws Exception {
        if (currentOrder == null || currentOrder.orderId == null || currentOrder.orderId.isEmpty()) {
            String cachedOrderId = prefs().getString("ujing_current_order_id", "");
            if (cachedOrderId == null || cachedOrderId.isEmpty()) {
                throw new IllegalStateException("当前没有洗衣订单");
            }
            currentOrder = new UjingApi.WasherOrder();
            currentOrder.orderId = cachedOrderId;
        }
        return loadOrderDetail(currentOrder.orderId);
    }

    public WasherOrderDetail loadOrderDetail(String orderId) throws Exception {
        if (orderId == null || orderId.trim().isEmpty()) {
            throw new IllegalStateException("订单号为空");
        }
        String normalizedOrderId = orderId.trim();
        JSONObject detail = api.getOrderDetail(requireSession(), normalizedOrderId);
        WasherOrderDetail orderDetail = new WasherOrderDetail(
                normalizedOrderId,
                detail.optString("deviceNo"),
                detail.optString("statusRemark", detail.optString("status")),
                detail.optString("payPrice"),
                detail.optString("status"),
                detail.optInt("remainTime", 0),
                detail.optInt("countDown", 0),
                detail.toString()
        );
        if (isTerminalWasherStatus(orderDetail.status, orderDetail.statusText)) {
            if (currentOrder != null && normalizedOrderId.equals(currentOrder.orderId)) {
                currentOrder = null;
            }
            String cachedOrderId = prefs().getString("ujing_current_order_id", "");
            if (normalizedOrderId.equals(cachedOrderId)) {
                clearCurrentOrderId();
            }
        }
        return orderDetail;
    }

    public WasherOrderDetail restoreActiveOrder() throws Exception {
        UjingApi.UjingSession session = requireSession();
        String orderId = prefs().getString("ujing_current_order_id", "");
        if (orderId == null || orderId.isEmpty()) {
            orderId = firstRunningOrderId(session);
        }
        if (orderId.isEmpty()) {
            JSONObject lastRunning = api.getLastRunningOrder(session);
            orderId = orderIdFrom(lastRunning);
        }
        if (orderId.isEmpty()) {
            currentOrder = null;
            return null;
        }
        currentOrder = new UjingApi.WasherOrder();
        currentOrder.orderId = orderId;
        WasherOrderDetail detail = loadOrderDetail(orderId);
        if (isTerminalWasherStatus(detail.status, detail.statusText)) {
            currentOrder = null;
            clearCurrentOrderId();
            AppLogStore.append(appContext, "[ujing-runtime] skip terminal washer order orderId=" + orderId
                    + " status=" + detail.statusText);
            return null;
        }
        saveCurrentOrderId(orderId);
        AppLogStore.append(appContext, "[ujing-runtime] restored washer order orderId=" + orderId
                + " status=" + detail.statusText);
        return detail;
    }

    public WasherOrderDetail startCurrentOrder() throws Exception {
        if (currentOrder == null || currentOrder.orderId == null || currentOrder.orderId.isEmpty()) {
            throw new IllegalStateException("当前没有可启动的洗衣订单");
        }
        WasherOrderDetail before = loadOrderDetail(currentOrder.orderId);
        if (!isStartable(before.status, before.statusText)) {
            throw new IllegalStateException("Current washer order cannot start in status " + before.statusText);
        }
        api.startOrder(requireSession(), currentOrder.orderId);
        AppLogStore.append(appContext, "[ujing-runtime] 洗衣启动确认完成，orderId=" + currentOrder.orderId);
        return loadOrderDetail(currentOrder.orderId);
    }

    public WasherOrderDetail stopCurrentOrder() throws Exception {
        if (currentOrder == null || currentOrder.orderId == null || currentOrder.orderId.isEmpty()) {
            throw new IllegalStateException("当前没有可停止的洗衣订单");
        }
        WasherOrderDetail before = loadOrderDetail(currentOrder.orderId);
        if (!isStoppable(before.status, before.statusText)) {
            throw new IllegalStateException("Current washer order cannot stop in status " + before.statusText);
        }
        api.stopOrder(requireSession(), currentOrder.orderId);
        AppLogStore.append(appContext, "[ujing-runtime] 洗衣提前停止完成，orderId=" + currentOrder.orderId);
        return loadOrderDetail(currentOrder.orderId);
    }

    public void cancelCurrentOrder() throws Exception {
        if (currentOrder == null || currentOrder.orderId == null || currentOrder.orderId.isEmpty()) {
            throw new IllegalStateException("当前没有可取消的洗衣订单");
        }
        api.cancelOrder(requireSession(), currentOrder.orderId);
        currentOrder = null;
        clearCurrentOrderId();
    }

    public WaterReady prepareWater(String qrCodeOrCd) throws Exception {
        String cd = extractWaterCd(qrCodeOrCd);
        if (cd.isEmpty()) {
            throw new IllegalStateException("没有识别到饮水设备码");
        }
        UjingApi.UjingSession session = requireSession();
        if (qrCodeOrCd != null && qrCodeOrCd.contains("://")) {
            JSONObject scan = api.scanCode(session, qrCodeOrCd.trim());
            String service = scan.optString("service");
            if (!service.isEmpty() && !"water".equalsIgnoreCase(service)) {
                throw new IllegalStateException("该二维码不是饮水码：" + service);
            }
        }
        currentWaterSubject = api.changeWaterServiceSubjectWithScan(session, cd);
        currentWaterSubject = api.getCurrentWaterInfo(session, currentWaterSubject);
        saveCurrentWaterCd(cd);
        return new WaterReady(currentWaterSubject);
    }

    public WaterOrderDetail createWaterOrder() throws Exception {
        UjingApi.UjingSession session = requireSession();
        String cd = currentWaterSubject == null ? prefs().getString("ujing_current_water_cd", "") : currentWaterSubject.cd;
        if (cd == null || cd.trim().isEmpty()) {
            throw new IllegalStateException("请先扫描饮水机二维码");
        }
        if (currentWaterSubject == null) {
            currentWaterSubject = api.changeWaterServiceSubjectWithScan(session, cd.trim());
            currentWaterSubject = api.getCurrentWaterInfo(session, currentWaterSubject);
        }
        if (currentWaterSubject.balanceFen <= 0) {
            throw new IllegalStateException("余额不足，请先在官方 App 充值");
        }
        currentWaterOrder = api.createWaterOrder(session, cd.trim());
        saveCurrentWaterOrder(currentWaterOrder.orderId, cd.trim());
        return loadWaterOrderDetail(currentWaterOrder.orderId);
    }

    public WaterOrderDetail loadCurrentWaterOrderDetail() throws Exception {
        String orderId = currentWaterOrder == null ? prefs().getString("ujing_current_water_order_id", "") : currentWaterOrder.orderId;
        if (orderId == null || orderId.trim().isEmpty()) {
            throw new IllegalStateException("当前没有饮水订单");
        }
        return loadWaterOrderDetail(orderId.trim());
    }

    public WaterOrderDetail loadWaterOrderDetail(String orderId) throws Exception {
        JSONObject detail = api.getWaterOrderDetail(requireSession(), orderId.trim());
        WaterOrderDetail result = new WaterOrderDetail(
                orderId.trim(),
                detail.optString("orderNo"),
                detail.optString("serviceSubjectName"),
                detail.optString("storeName"),
                detail.optString("deviceNo"),
                detail.optString("orderStatus"),
                detail.optString("orderStatusName", detail.optString("statusRemark")),
                detail.optString("statusRemark", detail.optString("orderStatusName")),
                detail.optInt("warmWaterML", 0),
                detail.optInt("waterSeconds", 0),
                detail.optDouble("payment", 0),
                detail.optDouble("payPrice", 0),
                detail.optInt("payFlag", 0),
                detail.toString()
        );
        if ("50".equals(result.orderStatus) || result.statusRemark.contains("完成")) {
            clearCurrentWaterOrderId();
        }
        return result;
    }

    public PaymentResult payCurrentOrderWithAlipay(android.app.Activity activity) throws Exception {
        if (activity == null) {
            throw new IllegalStateException("支付宝支付需要 Activity 上下文");
        }
        if (currentOrder == null || currentOrder.orderId == null || currentOrder.orderId.isEmpty()) {
            throw new IllegalStateException("请先创建洗衣订单");
        }
        UjingApi.UjingSession session = requireSession();
        String orderId = currentOrder.orderId;
        JSONObject resp = api.paymentArguments(session, orderId, "alipay");
        JSONObject data = resp.optJSONObject("data");
        JSONObject payInfo = data == null ? null : data.optJSONObject("payInfo");
        if (payInfo == null) {
            throw new IllegalStateException("拿到支付响应，但没有 payInfo");
        }
        String orderInfo = payInfo.optString("orderInfo");
        if (orderInfo.isEmpty()) {
            if (payInfo.has("prepayid") || payInfo.has("prepayId")) {
                throw new IllegalStateException("服务端返回了微信支付参数，但当前暂时只支持支付宝");
            }
            if (!payInfo.optString("h5_url").isEmpty()) {
                throw new IllegalStateException("服务端返回了 H5 支付链接，但当前暂时只支持支付宝");
            }
            throw new IllegalStateException("支付宝支付参数缺少 orderInfo");
        }
        AppLogStore.append(appContext, "[ujing-runtime] 启动支付宝支付，orderId=" + orderId);
        Map<String, String> result = new PayTask(activity).payV2(orderInfo, true);
        WasherOrderDetail detail = loadOrderDetail(orderId);
        AppLogStore.append(appContext, "[ujing-runtime] 支付宝返回=" + result + " orderStatus=" + detail.statusText);
        String resultStatus = result == null ? "" : value(result, "resultStatus");
        return new PaymentResult(
                orderId,
                String.valueOf(result),
                resultStatus,
                result == null ? "" : value(result, "memo"),
                "9000".equals(resultStatus),
                detail
        );
    }

    private String normalizeMobile(String mobile) {
        if (mobile == null || mobile.trim().isEmpty()) {
            throw new IllegalStateException("请输入 U净手机号");
        }
        return mobile.trim();
    }

    private UjingApi.UjingSession requireSession() {
        UjingApi.UjingSession session = api.loadSession();
        if (session == null) {
            throw new IllegalStateException("请先登录 U净账号");
        }
        return session;
    }

    private AccountSession toAccountSession(UjingApi.UjingSession session) {
        return new AccountSession(
                session.mobile,
                session.userId,
                session.serviceSubjectId
        );
    }

    private SharedPreferences prefs() {
        return appContext.getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    private void saveCurrentOrderId(String orderId) {
        if (orderId == null || orderId.trim().isEmpty()) return;
        prefs().edit().putString("ujing_current_order_id", orderId.trim()).apply();
    }

    private void clearCurrentOrderId() {
        prefs().edit().remove("ujing_current_order_id").apply();
    }

    private void saveCurrentWaterCd(String cd) {
        if (cd == null || cd.trim().isEmpty()) return;
        prefs().edit().putString("ujing_current_water_cd", cd.trim()).apply();
    }

    private void saveCurrentWaterOrder(String orderId, String cd) {
        if (orderId == null || orderId.trim().isEmpty()) return;
        prefs().edit()
                .putString("ujing_current_water_order_id", orderId.trim())
                .putString("ujing_current_water_cd", cd == null ? "" : cd.trim())
                .apply();
    }

    private void clearCurrentWaterOrderId() {
        prefs().edit().remove("ujing_current_water_order_id").apply();
    }

    private static String extractWaterCd(String qrCodeOrCd) {
        if (qrCodeOrCd == null) return "";
        String raw = qrCodeOrCd.trim();
        if (raw.isEmpty()) return "";
        int index = raw.indexOf("cd=");
        if (index >= 0) {
            String value = raw.substring(index + 3);
            int end = value.indexOf('&');
            return (end >= 0 ? value.substring(0, end) : value).trim();
        }
        return raw;
    }

    private String firstRunningOrderId(UjingApi.UjingSession session) throws Exception {
        JSONArray rows = api.getRunningOrders(session);
        for (int i = 0; i < rows.length(); i++) {
            Object item = rows.opt(i);
            if (item instanceof JSONObject) {
                String orderId = orderIdFrom((JSONObject) item);
                if (!orderId.isEmpty()) return orderId;
            }
        }
        return "";
    }

    private static String orderIdFrom(JSONObject json) {
        if (json == null) return "";
        String direct = normalizeOrderId(json.optString("orderId"));
        if (!direct.isEmpty()) return direct;
        direct = normalizeOrderId(json.optString("id"));
        if (!direct.isEmpty()) return direct;
        JSONObject order = json.optJSONObject("order");
        direct = orderIdFrom(order);
        if (!direct.isEmpty()) return direct;
        JSONObject orderInfo = json.optJSONObject("orderInfo");
        direct = orderIdFrom(orderInfo);
        if (!direct.isEmpty()) return direct;
        JSONObject result = json.optJSONObject("result");
        return orderIdFrom(result);
    }

    private static String normalizeOrderId(String raw) {
        if (raw == null) return "";
        String value = raw.trim();
        if (value.isEmpty() || "0".equals(value) || "null".equalsIgnoreCase(value)) return "";
        return value;
    }

    private static boolean isStartable(String status, String statusText) {
        String normalized = status == null ? "" : status.trim();
        return "20".equals(normalized);
    }

    private static boolean isStoppable(String status, String statusText) {
        String normalized = status == null ? "" : status.trim();
        return "21".equals(normalized) || "40".equals(normalized);
    }

    private static boolean isTerminalWasherStatus(String status, String statusText) {
        String normalized = status == null ? "" : status.trim();
        String text = statusText == null ? "" : statusText;
        return "50".equals(normalized)
                || text.contains("完成")
                || text.contains("取消")
                || text.contains("已取消");
    }

    public static final class AccountSession {
        public final String mobile;
        public final String userId;
        public final String serviceSubjectId;

        AccountSession(String mobile, String userId, String serviceSubjectId) {
            this.mobile = mobile;
            this.userId = userId;
            this.serviceSubjectId = serviceSubjectId;
        }
    }

    public static final class WasherProgram {
        public final String deviceId;
        public final int deviceTypeId;
        public final int moduleType;
        public final int status;
        public final String reason;
        public final boolean createOrderEnabled;
        public final boolean needSync;
        public final String deviceNo;
        public final String deviceTypeName;
        public final String storeId;
        public final String storeName;
        public final int defaultWashModelId;
        public final WashModel[] models;

        WasherProgram(UjingApi.WasherDevice device, UjingApi.ProgramInfo program) {
            deviceId = device.deviceId;
            deviceTypeId = device.deviceTypeId;
            moduleType = device.moduleType;
            status = device.status;
            reason = device.reason;
            createOrderEnabled = device.createOrderEnabled;
            needSync = device.needSync;
            if (program == null) {
                deviceNo = "";
                deviceTypeName = "";
                storeId = "";
                storeName = "";
                defaultWashModelId = 0;
                models = new WashModel[0];
            } else {
                deviceNo = program.deviceNo;
                deviceTypeName = program.deviceTypeName;
                storeId = program.storeId;
                storeName = program.storeName;
                defaultWashModelId = program.defaultWashModelId;
                models = new WashModel[program.models.size()];
                for (int i = 0; i < program.models.size(); i++) {
                    UjingApi.WashModel model = program.models.get(i);
                    models[i] = new WashModel(model.id, model.name, model.price, model.time, model.additions);
                }
            }
        }
    }

    public static final class WashModel {
        public final int id;
        public final String name;
        public final int price;
        public final int time;
        public final AdditionDevice[] additions;

        WashModel(int id, String name, int price, int time, java.util.List<UjingApi.AdditionDevice> sourceAdditions) {
            this.id = id;
            this.name = name;
            this.price = price;
            this.time = time;
            additions = new AdditionDevice[sourceAdditions.size()];
            for (int i = 0; i < sourceAdditions.size(); i++) {
                UjingApi.AdditionDevice addition = sourceAdditions.get(i);
                additions[i] = new AdditionDevice(addition.key, addition.name, addition.options);
            }
        }
    }

    public static final class AdditionDevice {
        public final String key;
        public final String name;
        public final AdditionOption[] options;

        AdditionDevice(String key, String name, java.util.List<UjingApi.AdditionOption> sourceOptions) {
            this.key = key;
            this.name = name;
            options = new AdditionOption[sourceOptions.size()];
            for (int i = 0; i < sourceOptions.size(); i++) {
                UjingApi.AdditionOption option = sourceOptions.get(i);
                options[i] = new AdditionOption(option.id, option.name, option.price);
            }
        }
    }

    public static final class AdditionOption {
        public final int id;
        public final String name;
        public final int price;

        AdditionOption(int id, String name, int price) {
            this.id = id;
            this.name = name;
            this.price = price;
        }
    }

    public static final class WasherOrderDetail {
        public final String orderId;
        public final String deviceNo;
        public final String statusText;
        public final String payPrice;
        public final String status;
        public final int remainTimeSeconds;
        public final int countDownSeconds;
        public final String rawJson;

        WasherOrderDetail(String orderId, String deviceNo, String statusText, String payPrice, String status, int remainTimeSeconds, int countDownSeconds, String rawJson) {
            this.orderId = orderId;
            this.deviceNo = deviceNo;
            this.statusText = statusText;
            this.payPrice = payPrice;
            this.status = status;
            this.remainTimeSeconds = remainTimeSeconds;
            this.countDownSeconds = countDownSeconds;
            this.rawJson = rawJson;
        }
    }

    public static final class WaterReady {
        public final String cd;
        public final String serviceSubjectId;
        public final String serviceSubjectName;
        public final String storeId;
        public final int balanceFen;
        public final int giftBalanceFen;

        WaterReady(UjingApi.WaterSubject subject) {
            cd = subject.cd;
            serviceSubjectId = subject.serviceSubjectId;
            serviceSubjectName = subject.serviceSubjectName;
            storeId = subject.storeId;
            balanceFen = subject.balanceFen;
            giftBalanceFen = subject.giftBalanceFen;
        }
    }

    public static final class WaterOrderDetail {
        public final String orderId;
        public final String orderNo;
        public final String serviceSubjectName;
        public final String storeName;
        public final String deviceNo;
        public final String orderStatus;
        public final String orderStatusName;
        public final String statusRemark;
        public final int warmWaterMl;
        public final int waterSeconds;
        public final double payment;
        public final double payPrice;
        public final int payFlag;
        public final String rawJson;

        WaterOrderDetail(String orderId, String orderNo, String serviceSubjectName, String storeName, String deviceNo, String orderStatus, String orderStatusName, String statusRemark, int warmWaterMl, int waterSeconds, double payment, double payPrice, int payFlag, String rawJson) {
            this.orderId = orderId;
            this.orderNo = orderNo;
            this.serviceSubjectName = serviceSubjectName;
            this.storeName = storeName;
            this.deviceNo = deviceNo;
            this.orderStatus = orderStatus;
            this.orderStatusName = orderStatusName;
            this.statusRemark = statusRemark;
            this.warmWaterMl = warmWaterMl;
            this.waterSeconds = waterSeconds;
            this.payment = payment;
            this.payPrice = payPrice;
            this.payFlag = payFlag;
            this.rawJson = rawJson;
        }
    }

    public static final class PaymentResult {
        public final String orderId;
        public final String sdkResult;
        public final String resultStatus;
        public final String memo;
        public final boolean paymentSucceeded;
        public final WasherOrderDetail refreshedOrder;

        PaymentResult(String orderId, String sdkResult, String resultStatus, String memo, boolean paymentSucceeded, WasherOrderDetail refreshedOrder) {
            this.orderId = orderId;
            this.sdkResult = sdkResult;
            this.resultStatus = resultStatus;
            this.memo = memo;
            this.paymentSucceeded = paymentSucceeded;
            this.refreshedOrder = refreshedOrder;
        }
    }

    private static String value(Map<String, String> map, String key) {
        String value = map.get(key);
        return value == null ? "" : value;
    }
}
