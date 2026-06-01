package com.kazuki.zhulihotwater

import android.content.Context
import android.util.Base64
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class Shower798RuntimeAdapter(
    context: Context
) {
    private val prefs = context.getSharedPreferences("shower_798", Context.MODE_PRIVATE)

    data class CachedSession(
        val phone: String,
        val uid: String,
        val eid: String,
        val token: String
    )

    data class CaptchaResult(
        val imageBytes: ByteArray,
        val doubleRandom: String,
        val timestamp: String
    )

    data class Device(
        val id: String,
        val name: String
    )

    fun loadCachedSession(): CachedSession? {
        val raw = prefs.getString(KEY_TOKEN_JSON, "") ?: ""
        if (raw.isBlank() || !prefs.getBoolean(KEY_IS_LOGIN, false)) return null
        return runCatching {
            val json = JSONObject(raw)
            val phone = prefs.getString(KEY_PHONE, "") ?: ""
            CachedSession(
                phone = phone,
                uid = json.optString("uid"),
                eid = json.optString("eid"),
                token = json.optString("token")
            )
        }.getOrNull()?.takeIf { it.token.isNotBlank() }
    }

    fun getCaptcha(doubleRandom: String, timestamp: String): CaptchaResult {
        val url = URL("$BASE_URL/captcha/?s=${encode(doubleRandom)}&r=${encode(timestamp)}")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 12000
            readTimeout = 12000
        }
        val bytes = conn.inputStream.use { BufferedInputStream(it).readBytes() }
        return CaptchaResult(bytes, doubleRandom, timestamp)
    }

    fun sendSmsCode(doubleRandom: String, captcha: String, phone: String) {
        val result = postJson(
            "$BASE_URL/acc/login/code",
            JSONObject()
                .put("s", doubleRandom)
                .put("authCode", captcha.trim())
                .put("un", phone.trim()),
            null
        )
        ensureSuccess(result, "发送验证码失败")
        prefs.edit().putString(KEY_PHONE, phone.trim()).apply()
    }

    fun login(phone: String, smsCode: String): CachedSession {
        val result = postJson(
            "$BASE_URL/acc/login",
            JSONObject()
                .put("openCode", "")
                .put("authCode", smsCode.trim())
                .put("un", phone.trim())
                .put("cid", "flandre-shuiyi-android"),
            null
        )
        ensureSuccess(result, "登录失败")
        val account = result.optJSONObject("data")
            ?.optJSONObject("al")
            ?: throw IllegalStateException("登录返回缺少账号信息")
        val session = CachedSession(
            phone = phone.trim(),
            uid = account.optString("uid"),
            eid = account.optString("eid"),
            token = account.optString("token")
        )
        prefs.edit()
            .putString(KEY_PHONE, session.phone)
            .putString(
                KEY_TOKEN_JSON,
                JSONObject()
                    .put("uid", session.uid)
                    .put("eid", session.eid)
                    .put("token", session.token)
                    .toString()
            )
            .putBoolean(KEY_IS_LOGIN, true)
            .apply()
        return session
    }

    fun logout() {
        prefs.edit().putBoolean(KEY_IS_LOGIN, false).apply()
    }

    fun loadDevices(): List<Device> {
        val result = getJson("$BASE_URL/ui/app/master", requireToken())
        val account = result.optJSONObject("data")?.optJSONObject("account")
        if (account == null) {
            logout()
            throw IllegalStateException("798 洗浴登录已失效，请重新登录")
        }
        val favos = result.optJSONObject("data")?.optJSONArray("favos") ?: return emptyList()
        val devices = mutableListOf<Device>()
        for (i in 0 until favos.length()) {
            val row = favos.optJSONObject(i) ?: continue
            val id = row.opt("id")?.toString().orEmpty()
            val name = row.opt("name")?.toString().orEmpty()
            if (id.isNotBlank()) {
                devices += Device(id = id, name = name.ifBlank { "洗浴设备 $id" })
            }
        }
        return devices.reversed()
    }

    fun addDevice(deviceId: String) {
        val result = getJson(
            "$BASE_URL/dev/favo?did=${encode(deviceId.trim())}&remove=false",
            requireToken()
        )
        ensureSuccess(result, "添加设备失败")
    }

    fun deleteDevice(deviceId: String) {
        val result = getJson(
            "$BASE_URL/dev/favo?did=${encode(deviceId.trim())}&remove=true",
            requireToken()
        )
        ensureSuccess(result, "删除设备失败")
    }

    fun startShower(deviceId: String) {
        val result = getJson(
            "$BASE_URL/dev/start?did=${encode(deviceId)}&upgrade=true&ptype=21&args=&rcp=false&cnt=1",
            requireToken()
        )
        ensureSuccess(result, "启动洗浴失败")
    }

    fun stopShower(deviceId: String) {
        val result = getJson(
            "$BASE_URL/dev/end?did=${encode(deviceId)}&rcp=false",
            requireToken()
        )
        ensureSuccess(result, "结束洗浴失败")
    }

    fun isDeviceIdle(deviceId: String): Boolean {
        val result = getJson(
            "$BASE_URL/ui/app/dev/status?did=${encode(deviceId)}&more=false",
            requireToken()
        )
        val device = result.optJSONObject("data")?.optJSONObject("device")
        val geneStatus = device?.optJSONObject("gene")?.optInt("status", -1) ?: -1
        val subs = device?.optJSONArray("subs")
        val subStatus = if (subs != null && subs.length() > 0) {
            subs.optJSONObject(0)?.optInt("status", -1) ?: -1
        } else {
            -1
        }
        return geneStatus == 99 || subStatus == 0
    }

    fun captchaBytesToBase64(bytes: ByteArray): String {
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun requireToken(): String {
        val session = loadCachedSession()
        return session?.token?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录 798 洗浴账号")
    }

    private fun getJson(url: String, token: String?): JSONObject {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 12000
            readTimeout = 12000
            setRequestProperty("Accept", "application/json")
            if (!token.isNullOrBlank()) {
                setRequestProperty("Authorization", token)
            }
        }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        if (text.isBlank()) {
            throw IllegalStateException("服务器返回为空")
        }
        return JSONObject(text)
    }

    private fun postJson(url: String, body: JSONObject, token: String?): JSONObject {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 12000
            readTimeout = 12000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            setRequestProperty("Accept", "application/json")
            if (!token.isNullOrBlank()) {
                setRequestProperty("Authorization", token)
            }
        }
        conn.outputStream.use { out ->
            BufferedOutputStream(out).writer(Charsets.UTF_8).use { writer ->
                writer.write(body.toString())
            }
        }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        if (text.isBlank()) {
            throw IllegalStateException("服务器返回为空")
        }
        return JSONObject(text)
    }

    private fun ensureSuccess(json: JSONObject, fallback: String) {
        if (json.optInt("code", -1) == 0) return
        val msg = json.optString("msg")
            .ifBlank { json.optString("message") }
            .ifBlank { fallback }
        throw IllegalStateException(msg)
    }

    private fun encode(value: String): String {
        return URLEncoder.encode(value, "UTF-8")
    }

    companion object {
        private const val BASE_URL = "https://i.ilife798.com/api/v1"
        private const val KEY_TOKEN_JSON = "token_json"
        private const val KEY_IS_LOGIN = "is_login"
        private const val KEY_PHONE = "phone"
    }
}
