package com.kazuki.zhulihotwater;

import android.app.Activity;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;

public class LogActivity extends Activity {
    private TextView logView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        refresh();
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(18), dp(20), dp(22));
        root.setBackgroundColor(color(R.color.zhuli_background));

        TextView title = new TextView(this);
        title.setText("运行日志");
        title.setTextSize(28);
        title.setTextColor(color(R.color.zhuli_on_surface));
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        root.addView(title, new LinearLayout.LayoutParams(-1, -2));

        TextView subtitle = new TextView(this);
        subtitle.setText("主界面已隐藏日志，后台组件的结果也会记录在这里");
        subtitle.setTextSize(14);
        subtitle.setTextColor(color(R.color.zhuli_on_surface_variant));
        subtitle.setPadding(0, dp(3), 0, dp(12));
        root.addView(subtitle, new LinearLayout.LayoutParams(-1, -2));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER);
        Button refresh = button("刷新", true);
        Button clear = button("清空", false);
        LinearLayout.LayoutParams refreshLp = new LinearLayout.LayoutParams(0, dp(48), 1);
        refreshLp.setMargins(0, 0, dp(6), 0);
        actions.addView(refresh, refreshLp);
        LinearLayout.LayoutParams clearLp = new LinearLayout.LayoutParams(0, dp(48), 1);
        clearLp.setMargins(dp(6), 0, 0, 0);
        actions.addView(clear, clearLp);
        root.addView(actions, new LinearLayout.LayoutParams(-1, -2));

        MaterialCardView card = card();
        logView = new TextView(this);
        logView.setTextSize(13);
        logView.setTextColor(color(R.color.zhuli_on_surface));
        logView.setPadding(dp(14), dp(14), dp(14), dp(14));
        ScrollView scroll = new ScrollView(this);
        scroll.addView(logView);
        card.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(-1, 0, 1);
        cardLp.setMargins(0, dp(12), 0, 0);
        root.addView(card, cardLp);

        refresh.setOnClickListener(v -> refresh());
        clear.setOnClickListener(v -> {
            AppLogStore.clear(this);
            refresh();
        });

        setContentView(root);
    }

    private void refresh() {
        String logs = AppLogStore.read(this);
        logView.setText(logs == null || logs.isEmpty() ? "暂无日志" : logs);
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

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }
}

