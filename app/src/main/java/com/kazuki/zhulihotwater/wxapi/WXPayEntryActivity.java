package com.kazuki.zhulihotwater.wxapi;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;

import com.kazuki.zhulihotwater.AppLogStore;
import com.tencent.mm.opensdk.constants.ConstantsAPI;
import com.tencent.mm.opensdk.modelbase.BaseReq;
import com.tencent.mm.opensdk.modelbase.BaseResp;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler;
import com.tencent.mm.opensdk.openapi.WXAPIFactory;

public class WXPayEntryActivity extends Activity implements IWXAPIEventHandler {
    private static final String PREF = "zhuli_hotwater";
    private IWXAPI api;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        initApi();
        api.handleIntent(getIntent(), this);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        initApi();
        api.handleIntent(intent, this);
    }

    @Override
    public void onReq(BaseReq req) {
        AppLogStore.append(this, "微信回调 onReq type=" + req.getType());
        finish();
    }

    @Override
    public void onResp(BaseResp resp) {
        String message = "微信支付回调 type=" + resp.getType()
                + " errCode=" + resp.errCode
                + " errStr=" + resp.errStr;
        if (resp.getType() == ConstantsAPI.COMMAND_PAY_BY_WX) {
            SharedPreferences sp = getSharedPreferences(PREF, MODE_PRIVATE);
            message += " orderId=" + sp.getString("ujing_last_order_id", "");
        }
        AppLogStore.append(this, message);
        finish();
    }

    private void initApi() {
        SharedPreferences sp = getSharedPreferences(PREF, MODE_PRIVATE);
        String appId = sp.getString("ujing_wechat_appid", "");
        api = WXAPIFactory.createWXAPI(this, appId, true);
        if (!appId.isEmpty()) {
            api.registerApp(appId);
        }
    }
}

