package com.kazuki.zhulihotwater;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class HistoryActivity extends Activity {
    private TextView summaryView;
    private TextView listView;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        loadHistory();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        worker.shutdownNow();
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(18), dp(20), dp(22));
        root.setBackgroundColor(color(R.color.zhuli_background));

        TextView title = new TextView(this);
        title.setText("历史消费");
        title.setTextSize(28);
        title.setTextColor(color(R.color.zhuli_on_surface));
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        root.addView(title, new LinearLayout.LayoutParams(-1, -2));

        TextView subtitle = new TextView(this);
        subtitle.setText("近 30 天热水消费记录");
        subtitle.setTextSize(14);
        subtitle.setTextColor(color(R.color.zhuli_on_surface_variant));
        subtitle.setPadding(0, dp(3), 0, 0);
        root.addView(subtitle, new LinearLayout.LayoutParams(-1, -2));

        MaterialCardView summaryCard = card();
        summaryView = new TextView(this);
        summaryView.setTextSize(16);
        summaryView.setTextColor(color(R.color.zhuli_on_surface));
        summaryView.setPadding(dp(16), dp(14), dp(16), dp(14));
        summaryCard.addView(summaryView, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams summaryLp = new LinearLayout.LayoutParams(-1, -2);
        summaryLp.setMargins(0, dp(16), 0, dp(10));
        root.addView(summaryCard, summaryLp);

        Button refresh = button("刷新近 30 天", true);
        refresh.setText("刷新近 30 天");
        refresh.setOnClickListener(v -> loadHistory());
        root.addView(refresh, new LinearLayout.LayoutParams(-1, dp(48)));

        MaterialCardView listCard = card();
        listView = new TextView(this);
        listView.setTextSize(14);
        listView.setTextColor(color(R.color.zhuli_on_surface));
        listView.setPadding(dp(14), dp(14), dp(14), dp(14));

        ScrollView scroll = new ScrollView(this);
        scroll.addView(listView);
        listCard.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
        LinearLayout.LayoutParams scrollLp = new LinearLayout.LayoutParams(-1, 0, 1);
        scrollLp.setMargins(0, dp(10), 0, 0);
        root.addView(listCard, scrollLp);

        setContentView(root);
    }

    private void loadHistory() {
        summaryView.setText("正在加载...");
        listView.setText("");
        worker.execute(() -> {
            try {
                LegacyHotwaterActivity.ZhuliSession session = loadCachedSession();
                if (session == null) {
                    show("请先回主页面登录一次", "");
                    return;
                }
                SimpleDateFormat fmt = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.CHINA);
                Calendar endCal = Calendar.getInstance();
                String end = fmt.format(endCal.getTime());
                Calendar startCal = Calendar.getInstance();
                startCal.add(Calendar.DAY_OF_MONTH, -30);
                String start = fmt.format(startCal.getTime());

                LegacyHotwaterActivity.ZhuliApi api = new LegacyHotwaterActivity.ZhuliApi(message -> {});
                JSONArray rows = api.listConsumeRecords(session, start, end);
                double total = 0;
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < rows.length(); i++) {
                    JSONObject row = rows.getJSONObject(i);
                    double money = row.optDouble("consume_money", 0);
                    total += money;
                    sb.append(row.optString("create_at", "-"))
                            .append("\n")
                            .append("设备：").append(row.optString("device_id", "-"))
                            .append("  金额：").append(String.format(Locale.CHINA, "%.2f", money)).append(" 元")
                            .append("\n")
                            .append("状态：").append(row.optString("status", "-"))
                            .append("  订单：").append(row.optString("order_id", "-"))
                            .append("\n\n");
                }
                String summary = "近 30 天共 " + rows.length()
                        + " 笔，合计 "
                        + String.format(Locale.CHINA, "%.2f", total)
                        + " 元";
                show(summary, sb.length() == 0 ? "暂无记录" : sb.toString());
            } catch (Exception e) {
                show("加载失败", e.getMessage());
            }
        });
    }

    private LegacyHotwaterActivity.ZhuliSession loadCachedSession() {
        try {
            SharedPreferences sp = getSharedPreferences("zhuli_hotwater", MODE_PRIVATE);
            String raw = sp.getString("session", "");
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

    private void show(String summary, String list) {
        runOnUiThread(() -> {
            summaryView.setText(summary == null ? "" : summary);
            listView.setText(list == null ? "" : list);
        });
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    private Button button(String text, boolean primary) {
        MaterialButton button = new MaterialButton(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setCornerRadius(dp(18));
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
}

