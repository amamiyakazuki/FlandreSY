package com.kazuki.zhulihotwater;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.util.Base64;
import android.view.Gravity;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.textfield.TextInputEditText;
import com.google.android.material.textfield.TextInputLayout;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class LegacyHotwaterActivity extends Activity {
    public static final String ACTION_WIDGET_START = "com.kazuki.zhulihotwater.action.START";
    public static final String ACTION_WIDGET_STOP = "com.kazuki.zhulihotwater.action.STOP";
    private static final int REQ_PERMS = 1001;

    private EditText phoneInput;
    private EditText passwordInput;
    private EditText deviceInput;
    private Button startButton;
    private Button endButton;
    private Button historyButton;
    private TextView statusView;

    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private ZhuliSession session;
    private BleDeviceSession bleSession;
    private JSONObject lastOrder;
    private String loginStatus = "未登录";
    private String deviceStatus = "1006445";
    private String bleStatus = "未连接";
    private String orderStatus = "-";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        requestNeededPermissions();
        statusView.postDelayed(() -> handleWidgetIntent(getIntent()), 500);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleWidgetIntent(intent);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (bleSession != null) {
            bleSession.close();
        }
        worker.shutdownNow();
    }

    private void buildUi() {
        SharedPreferences sp = getSharedPreferences("zhuli_hotwater", MODE_PRIVATE);

        ScrollView page = new ScrollView(this);
        page.setFillViewport(true);
        page.setBackgroundColor(color(R.color.zhuli_background));

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(18), dp(20), dp(22));
        page.addView(root, new ScrollView.LayoutParams(-1, -2));

        TextView title = new TextView(this);
        title.setText("一键热水");
        title.setTextSize(28);
        title.setTextColor(color(R.color.zhuli_on_surface));
        title.setGravity(Gravity.START);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        root.addView(title, new LinearLayout.LayoutParams(-1, -2));

        TextView subtitle = new TextView(this);
        subtitle.setText("桌面组件可直接后台开关水");
        subtitle.setTextSize(14);
        subtitle.setTextColor(color(R.color.zhuli_on_surface_variant));
        subtitle.setPadding(0, dp(3), 0, 0);
        root.addView(subtitle, new LinearLayout.LayoutParams(-1, -2));

        MaterialCardView statusCard = card();
        statusView = new TextView(this);
        statusView.setTextSize(15);
        statusView.setTextColor(color(R.color.zhuli_on_surface));
        statusView.setLineSpacing(dp(2), 1f);
        statusView.setPadding(dp(16), dp(14), dp(16), dp(14));
        statusCard.addView(statusView, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams statusLp = new LinearLayout.LayoutParams(-1, -2);
        statusLp.setMargins(0, dp(16), 0, 0);
        root.addView(statusCard, statusLp);

        MaterialCardView formCard = card();
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        form.setPadding(dp(14), dp(14), dp(14), dp(14));

        TextView formTitle = sectionTitle("账号与设备");
        form.addView(formTitle, new LinearLayout.LayoutParams(-1, -2));

        phoneInput = input(form, "手机号", InputType.TYPE_CLASS_PHONE);
        phoneInput.setText(sp.getString("phone", ""));

        passwordInput = input(form, "密码（已有缓存可留空）", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);

        deviceInput = input(form, "设备号", InputType.TYPE_CLASS_NUMBER);
        deviceInput.setText(sp.getString("device_id", "1006445"));
        deviceStatus = deviceInput.getText().toString();
        formCard.addView(form, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams formLp = new LinearLayout.LayoutParams(-1, -2);
        formLp.setMargins(0, dp(12), 0, 0);
        root.addView(formCard, formLp);

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER);
        actions.setPadding(0, dp(14), 0, dp(6));

        startButton = button("开热水", true);
        endButton = button("关热水", false);
        endButton.setEnabled(false);
        LinearLayout.LayoutParams startLp = new LinearLayout.LayoutParams(0, dp(56), 1);
        startLp.setMargins(0, 0, dp(6), 0);
        actions.addView(startButton, startLp);
        LinearLayout.LayoutParams endLp = new LinearLayout.LayoutParams(0, dp(56), 1);
        endLp.setMargins(dp(6), 0, 0, 0);
        actions.addView(endButton, endLp);
        root.addView(actions);

        LinearLayout secondary = new LinearLayout(this);
        secondary.setOrientation(LinearLayout.HORIZONTAL);
        secondary.setGravity(Gravity.CENTER);

        historyButton = button("历史消费", false);
        Button logButton = button("运行日志", false);
        LinearLayout.LayoutParams historyLp = new LinearLayout.LayoutParams(0, dp(48), 1);
        historyLp.setMargins(0, 0, dp(6), 0);
        secondary.addView(historyButton, historyLp);
        LinearLayout.LayoutParams logLp = new LinearLayout.LayoutParams(0, dp(48), 1);
        logLp.setMargins(dp(6), 0, 0, 0);
        secondary.addView(logButton, logLp);
        root.addView(secondary, new LinearLayout.LayoutParams(-1, -2));

        startButton.setOnClickListener(v -> startHotwater());
        endButton.setOnClickListener(v -> endHotwater());
        historyButton.setOnClickListener(v -> startActivity(new Intent(this, HistoryActivity.class)));
        logButton.setOnClickListener(v -> startActivity(new Intent(this, LogActivity.class)));

        setContentView(page);
        updateStatusView();
    }

    private EditText input(LinearLayout parent, String hint, int type) {
        TextInputLayout layout = new TextInputLayout(this);
        layout.setHint(hint);
        layout.setBoxBackgroundMode(TextInputLayout.BOX_BACKGROUND_OUTLINE);
        layout.setBoxBackgroundColor(color(R.color.zhuli_surface));
        layout.setBoxStrokeColor(color(R.color.zhuli_outline));
        layout.setBoxCornerRadii(dp(18), dp(18), dp(18), dp(18));
        TextInputEditText editText = new TextInputEditText(layout.getContext());
        editText.setHint(hint);
        editText.setTextSize(16);
        editText.setSingleLine(true);
        editText.setInputType(type);
        editText.setTextColor(color(R.color.zhuli_on_surface));
        editText.setHintTextColor(color(R.color.zhuli_on_surface_variant));
        editText.setPadding(dp(12), 0, dp(12), 0);
        layout.addView(editText, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(64));
        lp.setMargins(0, dp(10), 0, 0);
        parent.addView(layout, lp);
        return editText;
    }

    private Button button(String text, boolean primary) {
        MaterialButton button = new MaterialButton(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setCornerRadius(dp(18));
        button.setTextSize(15);
        if (primary) {
            button.setBackgroundColor(color(R.color.zhuli_primary));
            button.setTextColor(color(R.color.zhuli_on_primary));
        } else {
            button.setBackgroundColor(color(R.color.zhuli_secondary_container));
            button.setTextColor(color(R.color.zhuli_on_secondary_container));
        }
        return button;
    }

    private TextView sectionTitle(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(16);
        view.setTextColor(color(R.color.zhuli_on_surface));
        view.setTypeface(null, android.graphics.Typeface.BOLD);
        return view;
    }

    private MaterialCardView card() {
        MaterialCardView card = new MaterialCardView(this);
        card.setCardBackgroundColor(color(R.color.zhuli_surface));
        card.setRadius(dp(18));
        card.setStrokeWidth(dp(1));
        card.setStrokeColor(color(R.color.zhuli_outline));
        card.setCardElevation(dp(1));
        return card;
    }

    private int color(int resId) {
        if (Build.VERSION.SDK_INT >= 23) {
            return getColor(resId);
        }
        return getResources().getColor(resId);
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    private void startHotwater() {
        String phone = phoneInput.getText().toString().trim();
        String password = passwordInput.getText().toString();
        String deviceId = deviceInput.getText().toString().trim();
        ZhuliSession cached = loadCachedSession(phone);
        if (phone.isEmpty() || deviceId.isEmpty()) {
            orderStatus = "手机号和设备号都要填";
            updateStatusView();
            log("手机号和设备号都要填");
            return;
        }
        if (password.isEmpty() && cached == null) {
            orderStatus = "首次使用请填写密码";
            updateStatusView();
            log("没有缓存登录状态，首次使用请填写密码");
            return;
        }
        getSharedPreferences("zhuli_hotwater", MODE_PRIVATE)
                .edit()
                .putString("phone", phone)
                .putString("device_id", deviceId)
                .apply();

        startButton.setEnabled(false);
        endButton.setEnabled(false);
        deviceStatus = deviceId;
        bleStatus = "未连接";
        orderStatus = "准备中";
        updateStatusView();
        log("开始：登录并尝试开启设备 " + deviceId);

        worker.execute(() -> {
            try {
                ZhuliApi api = new ZhuliApi(this::log);
                ZhuliSession saved = loadCachedSession(phone);
                if (password.isEmpty() && saved != null) {
                    session = saved;
                    log("使用缓存登录状态，用户ID=" + session.userId + "，项目=" + session.projectName);
                } else {
                    session = api.login(phone, password);
                    saveCachedSession(phone, session);
                    log("登录成功并已缓存，用户ID=" + session.userId + "，项目=" + session.projectName);
                }
                loginStatus = session.projectName + " / " + session.userId;
                updateStatusView();

                JSONObject device = api.getDeviceById(session, deviceId);
                String bleName = device.optString("ble_name");
                String bleMac = device.optString("ble_mac");
                int deviceType = device.optInt("device_type");
                deviceStatus = deviceId + " / " + bleName;
                updateStatusView();
                log("设备信息：type=" + deviceType + " ble_name=" + bleName + " ble_mac=" + bleMac);

                bleSession = new BleDeviceSession(this, this::log);
                bleSession.connect(bleName, bleMac);
                bleStatus = "已连接";
                updateStatusView();
                log("蓝牙已连接");

                String handCmd = api.createHandshake(session, deviceId);
                String handHex = bleSession.writeAndWait(handCmd, "cmd_hand_shark");
                JSONObject hand = api.handshakeResponse(session, deviceId, handHex);
                String isn = hand.optString("isn");
                String rateCmd = hand.optString("ratecmd");
                bleSession.isn = isn;
                saveLastSessionState(deviceId, isn, "");
                log("握手完成，isn=" + isn);

                if (!rateCmd.isEmpty() && deviceType != 3 && deviceType != 5) {
                    bleSession.writeAndWait(rateCmd, "cmd_set_rate");
                    log("费率指令已写入");
                }

                if (deviceType != 3 && deviceType != 5 && hand.optInt("result") != 3) {
                    String historyCmd = api.createHistoryOrderCmd(session, deviceId, isn);
                    if (!historyCmd.isEmpty()) {
                        String historyHex = bleSession.writeAndWait(historyCmd, "cmd_history_order");
                        api.endConsumeResponse(session, deviceId, historyHex);
                        log("历史订单同步完成");
                    }
                }

                JSONObject order = api.createBleOrder(session, deviceId, isn);
                lastOrder = order;
                String appBytes = order.optString("app_bytes");
                String orderId = order.optString("order_id");
                if (appBytes.isEmpty() || orderId.isEmpty()) {
                    throw new IllegalStateException("下单返回缺少 app_bytes/order_id: " + order);
                }
                saveLastSessionState(deviceId, isn, orderId);
                log("订单已创建，order_id=" + orderId);
                orderStatus = "启动中 / " + orderId;
                updateStatusView();

                String startHex = bleSession.writeAndWait(appBytes, "cmd_start_order");
                JSONObject startResult = api.startConsumeResponse(session, deviceId, orderId, startHex);
                orderStatus = "消费中 / " + orderId;
                updateStatusView();
                log("启动确认完成：" + startResult.toString());

                runOnUiThread(() -> {
                    endButton.setEnabled(true);
                    startButton.setEnabled(true);
                });
            } catch (Exception e) {
                if (e.getMessage() != null && e.getMessage().contains("api_sign_error")) {
                    clearCachedSession(phone);
                    loginStatus = "缓存失效，请输入密码重试";
                }
                orderStatus = "失败";
                updateStatusView();
                log("失败：" + e.getMessage());
                runOnUiThread(() -> {
                    startButton.setEnabled(true);
                    endButton.setEnabled(lastOrder != null);
                });
            }
        });
    }

    private void endHotwater() {
        String deviceId = deviceInput.getText().toString().trim();
        String phone = phoneInput.getText().toString().trim();
        endButton.setEnabled(false);
        worker.execute(() -> {
            try {
                ZhuliApi api = new ZhuliApi(this::log);
                if (session == null) {
                    session = loadCachedSession(phone);
                }
                if (session == null) {
                    throw new IllegalStateException("没有缓存登录状态，请先打开 App 登录一次");
                }
                String isn = bleSession != null ? bleSession.isn : getLastIsn(deviceId);
                if (isn == null || isn.isEmpty()) {
                    throw new IllegalStateException("没有可用的 isn，请先用本 App 开水一次再用组件关水");
                }
                if (bleSession != null) {
                    bleSession.close();
                    bleSession = null;
                }
                JSONObject device = api.getDeviceById(session, deviceId);
                String bleName = device.optString("ble_name");
                String bleMac = device.optString("ble_mac");
                bleSession = new BleDeviceSession(this, this::log);
                bleSession.isn = isn;
                bleSession.connect(bleName, bleMac);
                bleStatus = "已连接";
                updateStatusView();
                String endCmd = api.createEndConsumeCmd(session, deviceId, bleSession.isn);
                String endHex = bleSession.writeAndWait(endCmd, "cmd_end_consume");
                JSONObject result = api.endConsumeResponse(session, deviceId, endHex);
                orderStatus = "已结束";
                clearLastSessionState();
                updateStatusView();
                log("结束完成：" + result.toString());
            } catch (Exception e) {
                orderStatus = "结束失败";
                updateStatusView();
                log("结束失败：" + e.getMessage());
                runOnUiThread(() -> endButton.setEnabled(true));
            }
        });
    }

    private void handleWidgetIntent(Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        if (ACTION_WIDGET_START.equals(intent.getAction())) {
            log("来自桌面组件：开热水");
            startHotwater();
        } else if (ACTION_WIDGET_STOP.equals(intent.getAction())) {
            log("来自桌面组件：关热水");
            endHotwater();
        }
    }

    private void updateStatusView() {
        if (statusView == null) return;
        runOnUiThread(() -> statusView.setText(
                "登录：" + loginStatus + "\n"
                        + "设备：" + deviceStatus + "\n"
                        + "蓝牙：" + bleStatus + "\n"
                        + "订单：" + orderStatus
        ));
    }

    private void saveCachedSession(String phone, ZhuliSession s) {
        try {
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
            getSharedPreferences("zhuli_hotwater", MODE_PRIVATE)
                    .edit()
                    .putString("session", json.toString())
                    .apply();
        } catch (Exception e) {
            log("缓存登录状态失败：" + e.getMessage());
        }
    }

    private ZhuliSession loadCachedSession(String phone) {
        if (phone == null || phone.isEmpty()) return null;
        try {
            String raw = getSharedPreferences("zhuli_hotwater", MODE_PRIVATE).getString("session", "");
            if (raw == null || raw.isEmpty()) return null;
            JSONObject json = new JSONObject(raw);
            if (!phone.equals(json.optString("phone"))) return null;
            ZhuliSession s = new ZhuliSession();
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

    private void clearCachedSession(String phone) {
        getSharedPreferences("zhuli_hotwater", MODE_PRIVATE)
                .edit()
                .remove("session")
                .apply();
    }

    private void saveLastSessionState(String deviceId, String isn, String orderId) {
        getSharedPreferences("zhuli_hotwater", MODE_PRIVATE)
                .edit()
                .putString("last_device_id", deviceId)
                .putString("last_isn", isn == null ? "" : isn)
                .putString("last_order_id", orderId == null ? "" : orderId)
                .apply();
    }

    private String getLastIsn(String deviceId) {
        SharedPreferences sp = getSharedPreferences("zhuli_hotwater", MODE_PRIVATE);
        if (!deviceId.equals(sp.getString("last_device_id", ""))) return "";
        return sp.getString("last_isn", "");
    }

    private void clearLastSessionState() {
        getSharedPreferences("zhuli_hotwater", MODE_PRIVATE)
                .edit()
                .remove("last_device_id")
                .remove("last_isn")
                .remove("last_order_id")
                .apply();
    }

    private void log(String message) {
        AppLogStore.append(this, message);
    }

    private void requestNeededPermissions() {
        List<String> permissions = new ArrayList<>();
        if (Build.VERSION.SDK_INT >= 31) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN);
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
        } else {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
        }
        if (Build.VERSION.SDK_INT >= 33) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS);
        }
        if (Build.VERSION.SDK_INT >= 23) {
            List<String> missing = new ArrayList<>();
            for (String p : permissions) {
                if (checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) {
                    missing.add(p);
                }
            }
            if (!missing.isEmpty()) {
                requestPermissions(missing.toArray(new String[0]), REQ_PERMS);
            }
        }
    }

    interface Logger {
        void log(String message);
    }

    static class ZhuliSession {
        String platformToken;
        String userId;
        String identityCode;
        String projectName;
        String serverAddr;
        String serverAppId;
        String serverId;
        String secretKey;
    }

    static class ZhuliApi {
        private static final String PLATFORM_BASE = "https://pm.whxinna.com";
        private static final String PLATFORM_KEY = "6d5dbb85b949447a95ff8fda9a9b759b";
        private final Logger logger;

        ZhuliApi(Logger logger) {
            this.logger = logger;
        }

        ZhuliSession login(String phone, String password) throws Exception {
            Map<String, Object> params = new HashMap<>();
            params.put("appVersion", "3.11.51");
            params.put("systemType", "Android");
            params.put("systemVersion", Build.VERSION.RELEASE == null ? "" : Build.VERSION.RELEASE);
            params.put("deviceModel", Build.MODEL == null ? "" : Build.MODEL);
            params.put("deviceToken", "");
            params.put("pwd", password);
            params.put("phone", phone);
            params.put("code", "");
            params.put("base64_user_extends", base64Url("{\"isAlipayAppExist\":false}"));
            addPlatformSign(params);

            JSONObject resp = getJson(PLATFORM_BASE + "/webapi/users/login", params, null);
            JSONObject data = unwrap(resp);
            ZhuliSession s = new ZhuliSession();
            s.platformToken = data.optString("platform_token");

            JSONObject user = data.getJSONObject("user_info");
            JSONObject server = data.getJSONObject("server_info");
            s.userId = String.valueOf(user.opt("id"));
            s.identityCode = user.optString("identity_code");
            s.projectName = server.optString("projectname");
            s.serverAddr = server.optString("server_addr");
            s.serverAppId = server.optString("server_appid");
            s.serverId = server.optString("server_id");
            s.secretKey = !server.optString("session_secret").isEmpty()
                    ? server.optString("session_secret")
                    : server.optString("appsecret");
            if (s.serverAddr.isEmpty()) {
                s.serverAddr = "https://f5-zhuli.whxinna.com";
            }
            if (s.secretKey.isEmpty()) {
                throw new IllegalStateException("登录成功但没有拿到项目签名密钥");
            }
            return s;
        }

        JSONObject getDeviceById(ZhuliSession s, String deviceId) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("id", deviceId);
            addBusinessSign(s, p);
            return unwrap(getJson(s.serverAddr + "/webapi/v1/device/get_by_id", p, null));
        }

        String createHandshake(ZhuliSession s, String deviceId) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("device_id", deviceId);
            addBusinessSign(s, p);
            return unwrapString(getJson(s.serverAddr + "/webapi/v1/device/ble/create_hand_shake_cmd", p, null));
        }

        JSONObject handshakeResponse(ZhuliSession s, String deviceId, String hex) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("device_id", deviceId);
            p.put("hex", hex);
            addBusinessSign(s, p);
            return unwrap(getJson(s.serverAddr + "/webapi/v1/device/ble/heart_shark_response", p, null));
        }

        String createHistoryOrderCmd(ZhuliSession s, String deviceId, String isn) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("device_id", deviceId);
            p.put("isn", isn);
            addBusinessSign(s, p);
            return unwrapString(getJson(s.serverAddr + "/webapi/v1/device/ble/create_history_order_cmd", p, null));
        }

        JSONObject createBleOrder(ZhuliSession s, String deviceId, String isn) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("isn", isn);
            p.put("device_id", deviceId);
            p.put("net_type", 4);
            p.put("staff_id", s.userId);
            p.put("money", 0);
            p.put("consume_value", 0);
            addBusinessSign(s, p);
            return unwrap(getJson(s.serverAddr + "/webapi/v1/consume/create_order", p, null));
        }

        JSONObject startConsumeResponse(ZhuliSession s, String deviceId, String orderId, String hex) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("device_id", deviceId);
            p.put("order_id", orderId);
            p.put("hex", hex);
            addBusinessSign(s, p);
            return unwrap(getJson(s.serverAddr + "/webapi/v1/consume/ble/start_consume_response", p, null));
        }

        String createEndConsumeCmd(ZhuliSession s, String deviceId, String isn) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("device_id", deviceId);
            p.put("isn", isn == null ? "" : isn);
            addBusinessSign(s, p);
            return unwrapString(getJson(s.serverAddr + "/webapi/v1/consume/ble/create_end_consume_cmd", p, null));
        }

        JSONObject endConsumeResponse(ZhuliSession s, String deviceId, String hex) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("device_id", deviceId);
            p.put("hex", hex);
            addBusinessSign(s, p);
            return unwrap(getJson(s.serverAddr + "/webapi/v1/consume/ble/end_consume_response", p, null));
        }

        JSONArray listConsumeRecords(ZhuliSession s, String start, String end) throws Exception {
            Map<String, Object> p = businessParams(s);
            p.put("staff_id", s.userId);
            p.put("start", start);
            p.put("end", end);
            addBusinessSign(s, p);
            return unwrapArray(getJson(s.serverAddr + "/webapi/v1/consume/list_record_by_staffid", p, null));
        }

        private Map<String, Object> businessParams(ZhuliSession s) throws Exception {
            Map<String, Object> p = new HashMap<>();
            p.put("timestamp", timestamp());
            p.put("noncestr", nonce(32));
            p.put("user_id", s.userId);
            if (s.identityCode != null && !s.identityCode.isEmpty()) {
                p.put("identitycode", s.identityCode);
            }
            if (s.serverAppId != null && !s.serverAppId.isEmpty()) {
                p.put("pid", s.serverAppId);
            }
            if (s.serverId != null && !s.serverId.isEmpty()) {
                p.put("appid", s.serverId);
            }
            return p;
        }

        private void addBusinessSign(ZhuliSession s, Map<String, Object> p) throws Exception {
            p.remove("sign");
            p.put("sign", sign(p, s.secretKey));
        }

        private void addPlatformSign(Map<String, Object> p) throws Exception {
            p.put("timestamp", timestamp());
            p.put("noncestr", nonce(32));
            p.put("sign", sign(p, PLATFORM_KEY));
        }

        private JSONObject getJson(String url, Map<String, Object> params, String authorization) throws Exception {
            String full = url + "?" + query(params);
            logger.log("GET " + url);
            HttpURLConnection conn = (HttpURLConnection) new URL(full).openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(30000);
            conn.setReadTimeout(30000);
            conn.setRequestProperty("Accept", "application/json, text/plain, */*");
            conn.setRequestProperty("Content-Type", "application/json");
            if (authorization != null) {
                conn.setRequestProperty("Authorization", authorization);
            }
            int code = conn.getResponseCode();
            InputStream stream = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
            String body = readAll(stream);
            if (code < 200 || code >= 300) {
                throw new IllegalStateException("HTTP " + code + ": " + body);
            }
            return new JSONObject(body);
        }

        private JSONObject unwrap(JSONObject resp) throws Exception {
            if (!resp.optBoolean("result")) {
                throw new IllegalStateException(resp.optString("msg", resp.optString("err_msg", resp.toString())));
            }
            Object dataObj = resp.opt("data");
            if (dataObj == null || JSONObject.NULL.equals(dataObj)) {
                return new JSONObject();
            }
            if (dataObj instanceof JSONObject) {
                return (JSONObject) dataObj;
            }
            String data = String.valueOf(dataObj);
            String decoded;
            try {
                decoded = decodeBase64Url(data);
            } catch (Exception ignored) {
                decoded = data;
            }
            if (decoded.startsWith("{")) {
                return new JSONObject(decoded);
            }
            JSONObject wrapper = new JSONObject();
            wrapper.put("value", decoded);
            return wrapper;
        }

        private String unwrapString(JSONObject resp) throws Exception {
            if (!resp.optBoolean("result")) {
                throw new IllegalStateException(resp.optString("msg", resp.optString("err_msg", resp.toString())));
            }
            Object dataObj = resp.opt("data");
            if (dataObj == null || JSONObject.NULL.equals(dataObj)) {
                return "";
            }
            if (dataObj instanceof JSONObject) {
                JSONObject obj = (JSONObject) dataObj;
                if (obj.has("value")) {
                    return obj.optString("value");
                }
                return obj.toString();
            }
            String data = String.valueOf(dataObj);
            try {
                return decodeBase64Url(data);
            } catch (Exception ignored) {
                return data;
            }
        }

        private JSONArray unwrapArray(JSONObject resp) throws Exception {
            if (!resp.optBoolean("result")) {
                throw new IllegalStateException(resp.optString("msg", resp.optString("err_msg", resp.toString())));
            }
            Object dataObj = resp.opt("data");
            if (dataObj instanceof JSONArray) {
                return (JSONArray) dataObj;
            }
            if (dataObj instanceof JSONObject) {
                return arrayFromObject((JSONObject) dataObj);
            }
            if (dataObj == null || JSONObject.NULL.equals(dataObj)) {
                return new JSONArray();
            }
            String data = String.valueOf(dataObj);
            String decoded;
            try {
                decoded = decodeBase64Url(data);
            } catch (Exception ignored) {
                decoded = data;
            }
            if (decoded.startsWith("[")) {
                return new JSONArray(decoded);
            }
            if (decoded.startsWith("{")) {
                return arrayFromObject(new JSONObject(decoded));
            }
            return new JSONArray();
        }

        private JSONArray arrayFromObject(JSONObject obj) {
            String[] keys = {"rows", "list", "records", "items", "data"};
            for (String key : keys) {
                Object value = obj.opt(key);
                if (value instanceof JSONArray) {
                    return (JSONArray) value;
                }
            }
            return new JSONArray();
        }

        private static String query(Map<String, Object> params) throws Exception {
            List<String> parts = new ArrayList<>();
            for (Map.Entry<String, Object> e : params.entrySet()) {
                if (e.getValue() == null) continue;
                parts.add(URLEncoder.encode(e.getKey(), "UTF-8") + "="
                        + URLEncoder.encode(String.valueOf(e.getValue()), "UTF-8"));
            }
            return String.join("&", parts);
        }

        private static String sign(Map<String, Object> params, String key) throws Exception {
            List<String> keys = new ArrayList<>(params.keySet());
            Collections.sort(keys);
            List<String> parts = new ArrayList<>();
            for (String k : keys) {
                if ("sign".equals(k)) continue;
                Object v = params.get(k);
                if (v == null || String.valueOf(v).isEmpty()) continue;
                parts.add(k + "=" + String.valueOf(v).replace("\"", "").replace(" ", ""));
            }
            return md5(String.join("&", parts) + "&key=" + key);
        }

        private static String md5(String text) throws Exception {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] bytes = digest.digest(text.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : bytes) {
                sb.append(String.format(Locale.US, "%02X", b));
            }
            return sb.toString();
        }

        private static String timestamp() {
            return String.valueOf(System.currentTimeMillis() / 1000);
        }

        private static String nonce(int len) {
            String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < len; i++) {
                sb.append(chars.charAt((int) (Math.random() * chars.length())));
            }
            return sb.toString();
        }

        private static String base64Url(String text) {
            return Base64.encodeToString(text.getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP)
                    .replace("+", "-")
                    .replace("/", "_");
        }

        private static String decodeBase64Url(String text) {
            String normalized = text.replace("-", "+").replace("_", "/");
            int pad = (4 - normalized.length() % 4) % 4;
            normalized += "====".substring(0, pad);
            byte[] bytes = Base64.decode(normalized, Base64.DEFAULT);
            return new String(bytes, StandardCharsets.UTF_8);
        }

        private static String readAll(InputStream stream) throws Exception {
            BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line);
            }
            return sb.toString();
        }
    }

    static class BleDeviceSession {
        private static final UUID SERVICE_UUID = UUID.fromString("0000ff12-0000-1000-8000-00805f9b34fb");
        private static final UUID WRITE_UUID = UUID.fromString("0000ff01-0000-1000-8000-00805f9b34fb");
        private static final UUID READ_UUID = UUID.fromString("0000ff02-0000-1000-8000-00805f9b34fb");
        private static final UUID CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

        private final Context context;
        private final Logger logger;
        private BluetoothGatt gatt;
        private BluetoothGattCharacteristic writeCharacteristic;
        private CountDownLatch responseLatch;
        private String expectedType;
        private String responseHex;
        String isn;

        BleDeviceSession(Context context, Logger logger) {
            this.context = context;
            this.logger = logger;
        }

        void connect(String bleName, String bleMac) throws Exception {
            BluetoothManager manager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
            BluetoothAdapter adapter = manager.getAdapter();
            if (adapter == null || !adapter.isEnabled()) {
                throw new IllegalStateException("蓝牙未开启");
            }
            BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
            if (scanner == null) {
                throw new IllegalStateException("无法获取 BLE 扫描器");
            }

            CountDownLatch foundLatch = new CountDownLatch(1);
            final BluetoothDevice[] found = new BluetoothDevice[1];
            ScanCallback callback = new ScanCallback() {
                @Override
                public void onScanResult(int callbackType, ScanResult result) {
                    BluetoothDevice dev = result.getDevice();
                    String name = result.getScanRecord() != null ? result.getScanRecord().getDeviceName() : null;
                    if (name == null) {
                        try {
                            name = dev.getName();
                        } catch (SecurityException ignored) {
                        }
                    }
                    String address = dev.getAddress();
                    boolean nameMatch = bleName != null && !bleName.isEmpty() && bleName.equals(name);
                    boolean macMatch = bleMac != null && !bleMac.isEmpty() && bleMac.equalsIgnoreCase(address);
                    boolean fallback = (bleName == null || bleName.isEmpty()) && name != null && name.contains("XN");
                    if (nameMatch || macMatch || fallback) {
                        logger.log("发现设备：" + name + " " + address);
                        found[0] = dev;
                        foundLatch.countDown();
                    }
                }
            };

            try {
                scanner.startScan(callback);
            } catch (SecurityException e) {
                throw new IllegalStateException("缺少蓝牙扫描权限，请在系统设置里允许附近设备权限");
            }
            logger.log("扫描 BLE 设备...");
            boolean ok = foundLatch.await(8, TimeUnit.SECONDS);
            try {
                scanner.stopScan(callback);
            } catch (SecurityException ignored) {
            }
            if (!ok || found[0] == null) {
                throw new IllegalStateException("没扫到目标 BLE 设备，请靠近设备再试");
            }

            try {
                Thread.sleep(700);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }

            Exception lastError = null;
            for (int attempt = 1; attempt <= 3; attempt++) {
                try {
                    logger.log("GATT 连接尝试 " + attempt + "/3");
                    connectGattOnce(found[0]);
                    return;
                } catch (Exception e) {
                    lastError = e;
                    close();
                    if (attempt < 3) {
                        Thread.sleep(1000);
                    }
                }
            }
            throw lastError == null ? new IllegalStateException("BLE 连接失败") : lastError;
        }

        private void connectGattOnce(BluetoothDevice device) throws Exception {
            CountDownLatch connectLatch = new CountDownLatch(1);
            final Exception[] error = new Exception[1];
            try {
                BluetoothGattCallback callback = new BluetoothGattCallback() {
                @Override
                public void onConnectionStateChange(BluetoothGatt g, int status, int newState) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        logger.log("GATT 已连接，发现服务...");
                        g.discoverServices();
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        error[0] = new IllegalStateException("GATT 断开连接，status=" + status);
                        connectLatch.countDown();
                    }
                }

                @Override
                public void onServicesDiscovered(BluetoothGatt g, int status) {
                    BluetoothGattService service = g.getService(SERVICE_UUID);
                    if (service == null) {
                        error[0] = new IllegalStateException("找不到热水 BLE service");
                        connectLatch.countDown();
                        return;
                    }
                    writeCharacteristic = service.getCharacteristic(WRITE_UUID);
                    BluetoothGattCharacteristic read = service.getCharacteristic(READ_UUID);
                    if (writeCharacteristic == null || read == null) {
                        error[0] = new IllegalStateException("找不到读写 characteristic");
                        connectLatch.countDown();
                        return;
                    }
                    g.setCharacteristicNotification(read, true);
                    BluetoothGattDescriptor d = read.getDescriptor(CCCD_UUID);
                    if (d != null) {
                        d.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                        g.writeDescriptor(d);
                    }
                    connectLatch.countDown();
                }

                @Override
                public void onCharacteristicChanged(BluetoothGatt g, BluetoothGattCharacteristic characteristic) {
                    byte[] value = characteristic.getValue();
                    String hex = bytesToHex(value);
                    String type = cmdType(hex);
                    logger.log("BLE 收到：" + type + " " + hex);
                    if (responseLatch != null && type.equals(expectedType)) {
                        responseHex = hex;
                        responseLatch.countDown();
                    }
                }
                };
                if (Build.VERSION.SDK_INT >= 23) {
                    gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE);
                } else {
                    gatt = device.connectGatt(context, false, callback);
                }
            } catch (SecurityException e) {
                throw new IllegalStateException("缺少蓝牙连接权限，请在系统设置里允许附近设备权限");
            }

            if (!connectLatch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("连接 BLE 超时");
            }
            if (error[0] != null) {
                throw error[0];
            }
        }

        String writeAndWait(String hex, String expected) throws Exception {
            if (gatt == null || writeCharacteristic == null) {
                throw new IllegalStateException("BLE 未连接");
            }
            responseLatch = new CountDownLatch(1);
            expectedType = expected;
            responseHex = null;

            byte[] bytes = hexToBytes(hex);
            writeCharacteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
            writeCharacteristic.setValue(bytes);
            boolean ok = gatt.writeCharacteristic(writeCharacteristic);
            if (!ok) {
                throw new IllegalStateException("BLE 写入失败");
            }
            logger.log("BLE 写入：" + expected + " " + hex);
            if (!responseLatch.await(6, TimeUnit.SECONDS)) {
                throw new IllegalStateException("等待设备响应超时：" + expected);
            }
            return responseHex;
        }

        void close() {
            if (gatt != null) {
                gatt.disconnect();
                gatt.close();
                gatt = null;
            }
        }

        private static byte[] hexToBytes(String hex) {
            String clean = hex.replace(" ", "");
            byte[] out = new byte[clean.length() / 2];
            for (int i = 0; i < out.length; i++) {
                out[i] = (byte) Integer.parseInt(clean.substring(i * 2, i * 2 + 2), 16);
            }
            return out;
        }

        private static String bytesToHex(byte[] bytes) {
            StringBuilder sb = new StringBuilder();
            for (byte b : bytes) {
                sb.append(String.format(Locale.US, "%02x", b & 0xff));
            }
            return sb.toString();
        }

        private static String cmdType(String hex) {
            byte[] b = hexToBytes(hex.length() > 40 ? hex.substring(0, 40) : hex);
            if (b.length < 3) return "unknown";
            switch (b[2] & 0xff) {
                case 1:
                    return "cmd_hand_shark";
                case 2:
                case 67:
                    return "cmd_history_order";
                case 3:
                case 64:
                    return "cmd_start_order";
                case 4:
                case 5:
                case 65:
                    return "cmd_end_consume";
                case 16:
                    return "cmd_set_rate";
                case 240:
                    return "error_crc";
                default:
                    return "cmd_" + (b[2] & 0xff);
            }
        }
    }
}

