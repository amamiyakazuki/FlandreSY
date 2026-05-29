package com.kazuki.zhulihotwater;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
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
import com.alipay.sdk.app.PayTask;
import com.tencent.mm.opensdk.modelpay.PayReq;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import com.tencent.mm.opensdk.openapi.WXAPIFactory;

import org.json.JSONObject;

import java.net.URLEncoder;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class UjingWasherTestActivity extends Activity {
    private static final String PREF = "zhuli_hotwater";
    private static final String DEFAULT_QR = "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140003074";

    private EditText phoneInput;
    private EditText captchaInput;
    private EditText qrInput;
    private EditText washModelInput;
    private EditText temperatureInput;
    private EditText channelInput;
    private TextView statusView;

    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private UjingApi api;
    private UjingApi.UjingSession session;
    private UjingApi.WasherDevice device;
    private UjingApi.ProgramInfo programInfo;
    private UjingApi.WasherOrder order;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        api = new UjingApi(this, this::log);
        session = api.loadSession();
        buildUi();
        show("准备就绪" + (session == null ? "" : "\n已缓存 U净登录：" + session.mobile));
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        worker.shutdownNow();
    }

    private void buildUi() {
        SharedPreferences sp = getSharedPreferences(PREF, MODE_PRIVATE);
        ScrollView page = new ScrollView(this);
        page.setFillViewport(true);
        page.setBackgroundColor(color(R.color.zhuli_background));

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(18), dp(20), dp(22));
        page.addView(root, new ScrollView.LayoutParams(-1, -2));

        TextView title = new TextView(this);
        title.setText("U净洗衣测试");
        title.setTextSize(26);
        title.setTextColor(color(R.color.zhuli_on_surface));
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        root.addView(title, new LinearLayout.LayoutParams(-1, -2));

        TextView subtitle = new TextView(this);
        subtitle.setText("最小流程：登录、扫码、下单、尝试支付");
        subtitle.setTextSize(14);
        subtitle.setTextColor(color(R.color.zhuli_on_surface_variant));
        subtitle.setPadding(0, dp(4), 0, 0);
        root.addView(subtitle, new LinearLayout.LayoutParams(-1, -2));

        MaterialCardView inputCard = card();
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        form.setPadding(dp(14), dp(14), dp(14), dp(14));

        phoneInput = input(form, "U净手机号", InputType.TYPE_CLASS_PHONE);
        phoneInput.setText(sp.getString("ujing_phone", session == null ? "" : session.mobile));
        captchaInput = input(form, "验证码", InputType.TYPE_CLASS_NUMBER);
        qrInput = input(form, "洗衣二维码 URL", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        qrInput.setText(sp.getString("ujing_washer_qr", DEFAULT_QR));
        washModelInput = input(form, "套餐ID deviceWashModelId", InputType.TYPE_CLASS_NUMBER);
        washModelInput.setText("1");
        temperatureInput = input(form, "温度ID washTemperatureId", InputType.TYPE_CLASS_NUMBER);
        temperatureInput.setText("1");
        channelInput = input(form, "支付 channel", InputType.TYPE_CLASS_TEXT);
        channelInput.setText("alipay");

        inputCard.addView(form, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams inputLp = new LinearLayout.LayoutParams(-1, -2);
        inputLp.setMargins(0, dp(16), 0, 0);
        root.addView(inputCard, inputLp);

        addButton(root, "获取验证码", true, v -> requestCaptcha());
        addButton(root, "登录 U净", false, v -> login());
        addButton(root, "扫码识别洗衣机", false, v -> scanWasher());
        addButton(root, "创建待支付订单", true, v -> createOrder());
        addButton(root, "获取支付方式", false, v -> getPaymentMethods());
        addButton(root, "尝试支付", true, v -> tryPayment());
        addButton(root, "探测微信H5通道", false, v -> probeWechatH5());
        addButton(root, "取消当前订单", false, v -> cancelOrder());

        MaterialCardView statusCard = card();
        statusView = new TextView(this);
        statusView.setTextSize(14);
        statusView.setTextColor(color(R.color.zhuli_on_surface));
        statusView.setPadding(dp(14), dp(14), dp(14), dp(14));
        statusView.setLineSpacing(dp(2), 1f);
        statusCard.addView(statusView, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams statusLp = new LinearLayout.LayoutParams(-1, -2);
        statusLp.setMargins(0, dp(12), 0, 0);
        root.addView(statusCard, statusLp);

        setContentView(page);
    }

    private void requestCaptcha() {
        String phone = phoneInput.getText().toString().trim();
        if (phone.isEmpty()) {
            show("请先填写手机号");
            return;
        }
        run("获取验证码", () -> {
            api.requestCaptcha(phone);
            getSharedPreferences(PREF, MODE_PRIVATE).edit().putString("ujing_phone", phone).apply();
            return "验证码已发送";
        });
    }

    private void login() {
        String phone = phoneInput.getText().toString().trim();
        String captcha = captchaInput.getText().toString().trim();
        if (phone.isEmpty() || captcha.isEmpty()) {
            show("手机号和验证码都要填");
            return;
        }
        run("登录 U净", () -> {
            session = api.login(phone, captcha);
            getSharedPreferences(PREF, MODE_PRIVATE).edit().putString("ujing_phone", phone).apply();
            return "登录成功\n手机号：" + session.mobile + "\nuserId：" + session.userId
                    + "\nserviceSubjectId：" + session.serviceSubjectId;
        });
    }

    private void scanWasher() {
        String qr = qrInput.getText().toString().trim();
        if (qr.isEmpty()) {
            show("请填写洗衣二维码 URL");
            return;
        }
        run("扫码识别洗衣机", () -> {
            ensureSession();
            getSharedPreferences(PREF, MODE_PRIVATE).edit().putString("ujing_washer_qr", qr).apply();
            device = api.scanWasher(session, qr);
            StringBuilder sb = new StringBuilder();
            sb.append("扫码成功\n")
                    .append("deviceId：").append(device.deviceId).append("\n")
                    .append("deviceTypeId：").append(device.deviceTypeId).append("\n")
                    .append("status：").append(device.status).append("\n")
                    .append("createOrderEnabled：").append(device.createOrderEnabled).append("\n");
            if (device.reason != null && !device.reason.isEmpty()) {
                sb.append("reason：").append(device.reason).append("\n");
            }
            if (!device.createOrderEnabled) {
                return sb.toString();
            }
            programInfo = api.getProgramInfo(session, device);
            if (programInfo.defaultWashModelId != 0) {
                washModelInput.post(() -> washModelInput.setText(String.valueOf(programInfo.defaultWashModelId)));
            }
            sb.append("\n套餐信息\n")
                    .append("设备号：").append(programInfo.deviceNo).append("\n")
                    .append("类型：").append(programInfo.deviceTypeName).append("\n")
                    .append("storeId：").append(programInfo.storeId).append("\n")
                    .append(programInfo.modelSummary());
            return sb.toString();
        });
    }

    private void createOrder() {
        run("创建洗衣订单", () -> {
            ensureSession();
            if (programInfo == null) {
                if (device == null) {
                    String qr = qrInput.getText().toString().trim();
                    device = api.scanWasher(session, qr);
                }
                programInfo = api.getProgramInfo(session, device);
            }
            int modelId = Integer.parseInt(washModelInput.getText().toString().trim());
            int temperatureId = Integer.parseInt(temperatureInput.getText().toString().trim());
            order = api.createOrder(session, programInfo, modelId, temperatureId);
            JSONObject detail = api.getOrderDetail(session, order.orderId);
            return "订单已创建\norderId：" + order.orderId
                    + "\n设备号：" + detail.optString("deviceNo")
                    + "\n状态：" + detail.optString("statusRemark")
                    + "\n金额：" + detail.optDouble("payPrice") + " 元";
        });
    }

    private void getPaymentMethods() {
        run("获取支付方式", () -> {
            ensureSession();
            ensureOrder();
            JSONObject resp = api.paymentMethods(session, programInfo, order.orderId);
            return "支付方式：\n" + resp.getJSONObject("data").optJSONArray("channels");
        });
    }

    private void tryPayment() {
        String channel = channelInput.getText().toString().trim();
        if (channel.isEmpty()) channel = "alipay";
        String finalChannel = channel;
        run("尝试支付 " + finalChannel, () -> {
            ensureSession();
            ensureOrder();
            JSONObject resp = api.paymentArguments(session, order.orderId, finalChannel);
            JSONObject data = resp.optJSONObject("data");
            JSONObject payInfo = data == null ? null : data.optJSONObject("payInfo");
            if (payInfo == null) {
                return "拿到支付响应，但没有 payInfo：\n" + resp;
            }
            String h5 = payInfo.optString("h5_url");
            if (!h5.isEmpty()) {
                openUri(h5);
                return "已尝试打开 H5 支付：\n" + h5;
            }
            String orderInfo = payInfo.optString("orderInfo");
            if (!orderInfo.isEmpty()) {
                PayTask payTask = new PayTask(this);
                Map<String, String> result = payTask.payV2(orderInfo, true);
                JSONObject detail = api.getOrderDetail(session, order.orderId);
                return "支付宝 SDK 返回：\n" + result
                        + "\n\n订单状态："
                        + detail.optString("statusRemark", detail.optString("status"))
                        + "\n金额：" + detail.optDouble("payPrice") + " 元";
            }
            if (payInfo.has("prepayid") || payInfo.has("prepayId")) {
                String appId = payInfo.optString("appid", payInfo.optString("appId"));
                IWXAPI wxApi = WXAPIFactory.createWXAPI(this, appId, true);
                wxApi.registerApp(appId);
                if (!wxApi.isWXAppInstalled()) {
                    return "已拿到微信支付参数，但本机没有安装微信";
                }
                PayReq req = new PayReq();
                req.appId = appId;
                req.partnerId = payInfo.optString("partnerid", payInfo.optString("partnerId"));
                req.prepayId = payInfo.optString("prepayid", payInfo.optString("prepayId"));
                req.packageValue = payInfo.optString("package", payInfo.optString("packageValue", "Sign=WXPay"));
                req.nonceStr = payInfo.optString("noncestr", payInfo.optString("nonceStr"));
                req.timeStamp = payInfo.optString("timestamp", payInfo.optString("timeStamp"));
                req.sign = payInfo.optString("sign");
                getSharedPreferences(PREF, MODE_PRIVATE).edit()
                        .putString("ujing_wechat_appid", appId)
                        .putString("ujing_last_order_id", order.orderId)
                        .apply();
                boolean sent = wxApi.sendReq(req);
                return "已调用微信 SDK sendReq=" + sent
                        + "\n如果微信拒绝或无支付界面，大概率是包名/签名绑定限制。"
                        + "\nprepayId：" + req.prepayId;
            }
            return "未知支付参数：\n" + payInfo;
        });
    }

    private void probeWechatH5() {
        run("探测微信H5通道", () -> {
            ensureSession();
            ensureOrder();
            String[] candidates = {
                    "wechatPayH5",
                    "wechatH5",
                    "wxH5",
                    "wxPayH5",
                    "mweb",
                    "wechatMweb",
                    "wechatPayMWeb",
                    "wechatPayWeb",
                    "weixinH5",
                    "weixinPayH5"
            };
            StringBuilder report = new StringBuilder("微信H5通道探测：\n");
            for (String candidate : candidates) {
                try {
                    JSONObject resp = api.paymentArguments(session, order.orderId, candidate);
                    JSONObject data = resp.optJSONObject("data");
                    JSONObject payInfo = data == null ? null : data.optJSONObject("payInfo");
                    String url = findPayUrl(payInfo);
                    if (!url.isEmpty()) {
                        openUri(url);
                        return report.append(candidate)
                                .append("：找到可打开链接\n")
                                .append(url)
                                .toString();
                    }
                    report.append(candidate).append("：成功但没有 H5 链接\n");
                    if (payInfo != null) {
                        report.append(payInfo.toString().substring(0, Math.min(180, payInfo.toString().length()))).append("\n");
                    }
                } catch (Exception e) {
                    report.append(candidate).append("：").append(e.getMessage()).append("\n");
                }
            }
            return report.append("\n没有发现可用微信 H5 通道。").toString();
        });
    }

    private void cancelOrder() {
        run("取消订单", () -> {
            ensureSession();
            ensureOrder();
            api.cancelOrder(session, order.orderId);
            String canceled = order.orderId;
            order = null;
            return "订单已取消：" + canceled;
        });
    }

    private void ensureSession() {
        if (session == null) {
            session = api.loadSession();
        }
        if (session == null) {
            throw new IllegalStateException("请先登录 U净");
        }
    }

    private void ensureOrder() {
        if (order == null || order.orderId == null || order.orderId.isEmpty()) {
            throw new IllegalStateException("请先创建订单");
        }
    }

    private void openUri(String uri) {
        runOnUiThread(() -> {
            try {
                Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(uri));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
            } catch (ActivityNotFoundException e) {
                show("没有可处理该支付链接的 App：\n" + e.getMessage());
            } catch (Exception e) {
                show("拉起支付失败：\n" + e.getMessage());
            }
        });
    }

    private String findPayUrl(JSONObject payInfo) {
        if (payInfo == null) return "";
        String[] keys = {"h5_url", "mweb_url", "mwebUrl", "payUrl", "pay_url", "url", "jumpURL", "jumpUrl"};
        for (String key : keys) {
            String value = payInfo.optString(key);
            if (value != null && (value.startsWith("http://") || value.startsWith("https://") || value.startsWith("weixin://"))) {
                return value;
            }
        }
        return "";
    }

    private void run(String title, Task task) {
        show(title + "...");
        log(title);
        worker.execute(() -> {
            try {
                String result = task.call();
                show(result);
                log(title + " 成功");
            } catch (Exception e) {
                show(title + "失败：\n" + e.getMessage());
                log(title + "失败：" + e.getMessage());
            }
        });
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
        editText.setTextSize(15);
        editText.setSingleLine(true);
        editText.setInputType(type);
        editText.setTextColor(color(R.color.zhuli_on_surface));
        editText.setHintTextColor(color(R.color.zhuli_on_surface_variant));
        layout.addView(editText, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(64));
        lp.setMargins(0, dp(10), 0, 0);
        parent.addView(layout, lp);
        return editText;
    }

    private void addButton(LinearLayout root, String text, boolean primary, android.view.View.OnClickListener listener) {
        Button button = button(text, primary);
        button.setOnClickListener(listener);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(48));
        lp.setMargins(0, dp(10), 0, 0);
        root.addView(button, lp);
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

    private void show(String text) {
        runOnUiThread(() -> statusView.setText(text == null ? "" : text));
    }

    private void log(String message) {
        AppLogStore.append(this, "U净：" + message);
    }

    interface Task {
        String call() throws Exception;
    }
}

