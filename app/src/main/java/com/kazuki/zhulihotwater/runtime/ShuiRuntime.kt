package com.kazuki.zhulihotwater.runtime

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.Context
import android.app.Activity
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.kazuki.zhulihotwater.AppLogStore
import com.kazuki.zhulihotwater.HotwaterRuntimeAdapter
import com.kazuki.zhulihotwater.UjingRuntimeAdapter
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

enum class RuntimeTaskState {
    Idle,
    Loading,
    Success,
    Failure,
    LoginRequired,
    PermissionRequired,
    PaymentInProgress,
    Unavailable
}

enum class LocalDeviceType {
    Washer,
    DrinkingWater,
    Unknown
}

enum class PaymentMode {
    AlipayOnly
}

enum class OrderDisplayMode {
    SplitHotwaterHistoryAndCurrentWasherOrder
}

data class RuntimeActionStatus(
    val state: RuntimeTaskState = RuntimeTaskState.Idle,
    val message: String? = null
)

data class LocalDeviceShortcut(
    val id: String,
    val customName: String,
    val deviceType: LocalDeviceType,
    val qrUrl: String? = null,
    val cd: String? = null,
    val lastStatus: String? = null,
    val sortOrder: Int = 0
)

data class HotwaterHistoryUi(
    val time: String,
    val deviceId: String,
    val amount: String,
    val status: String,
    val orderId: String
)

data class UjingAccountUi(
    val mobile: String,
    val userId: String,
    val serviceSubjectId: String
)

data class WasherProgramUi(
    val deviceId: String,
    val deviceNo: String,
    val deviceTypeName: String,
    val storeId: String,
    val storeName: String,
    val status: String,
    val reason: String,
    val createOrderEnabled: Boolean,
    val defaultWashModelId: Int,
    val models: List<WasherModelUi>
)

data class WasherModelUi(
    val id: Int,
    val name: String,
    val priceFen: Int,
    val timeMinutes: Int
)

data class WasherOrderUi(
    val orderId: String,
    val deviceNo: String,
    val statusText: String,
    val payPrice: String,
    val status: String,
    val remainTimeSeconds: Int = 0,
    val countDownSeconds: Int = 0
)

data class WasherPaymentUi(
    val orderId: String,
    val resultStatus: String,
    val memo: String,
    val sdkResult: String,
    val paymentSucceeded: Boolean = false
)

data class WaterReadyUi(
    val cd: String,
    val serviceSubjectId: String,
    val serviceSubjectName: String,
    val storeId: String,
    val balanceFen: Int,
    val giftBalanceFen: Int
)

data class WaterOrderUi(
    val orderId: String,
    val orderNo: String,
    val serviceSubjectName: String,
    val storeName: String,
    val deviceNo: String,
    val orderStatus: String,
    val orderStatusName: String,
    val statusRemark: String,
    val warmWaterMl: Int,
    val waterSeconds: Int,
    val payment: Double,
    val payPrice: Double,
    val payFlag: Int
)

data class ShuiRuntimeState(
    val hotwaterLogin: RuntimeActionStatus = RuntimeActionStatus(RuntimeTaskState.LoginRequired),
    val hotwaterStart: RuntimeActionStatus = RuntimeActionStatus(),
    val hotwaterStop: RuntimeActionStatus = RuntimeActionStatus(),
    val hotwaterHistory: RuntimeActionStatus = RuntimeActionStatus(),
    val hotwaterHistoryRecords: List<HotwaterHistoryUi> = emptyList(),
    val hotwaterPhone: String = "",
    val hotwaterDeviceCode: String = "",
    val ujingAccount: UjingAccountUi? = null,
    val ujingCaptcha: RuntimeActionStatus = RuntimeActionStatus(),
    val washerLogin: RuntimeActionStatus = RuntimeActionStatus(RuntimeTaskState.LoginRequired),
    val washerScan: RuntimeActionStatus = RuntimeActionStatus(),
    val washerProgram: WasherProgramUi? = null,
    val washerOrder: RuntimeActionStatus = RuntimeActionStatus(),
    val currentWasherOrder: WasherOrderUi? = null,
    val washerPayment: RuntimeActionStatus = RuntimeActionStatus(),
    val currentWasherPayment: WasherPaymentUi? = null,
    val waterScan: RuntimeActionStatus = RuntimeActionStatus(),
    val currentWaterReady: WaterReadyUi? = null,
    val waterOrder: RuntimeActionStatus = RuntimeActionStatus(),
    val currentWaterOrder: WaterOrderUi? = null,
    val localDevices: List<LocalDeviceShortcut> = emptyList(),
    val localDevicesLastRefreshed: String = "",
    val paymentMode: PaymentMode = PaymentMode.AlipayOnly,
    val orderDisplayMode: OrderDisplayMode = OrderDisplayMode.SplitHotwaterHistoryAndCurrentWasherOrder,
    val userNotice: String? = "暂时只支持支付宝支付"
)

interface ShuiRuntimeActions {
    fun loginHotwater(phone: String, password: String)
    fun checkHotwaterStatus()
    fun bindHotwaterDeviceCode(deviceId: String)
    fun startHotwater(phone: String, password: String, deviceId: String)
    fun startHotwater()
    fun stopHotwater()
    fun loadHotwaterHistory()
    fun loginUjing(phone: String, captcha: String)
    fun requestUjingCaptcha(phone: String)
    fun checkUjingStatus()
    fun scanWasherWithCamera()
    fun scanWasher(qrCode: String)
    fun createWasherOrder(washModelId: Int, temperatureId: Int)
    fun refreshCurrentWasherOrder()
    fun createWasherOrder()
    fun payCurrentWasherOrderWithAlipay()
    fun startCurrentWasherOrder()
    fun cancelCurrentWasherOrder()
    fun stopCurrentWasherOrder()
    fun prepareDrinkingWater(qrCodeOrCd: String)
    fun createDrinkingWaterOrder()
    fun refreshCurrentDrinkingWaterOrder()
    fun refreshLocalDevices()
    fun renameLocalDevice(deviceId: String, name: String)
    fun deleteLocalDevice(deviceId: String)
}

interface ShuiRuntimeProvider {
    val state: ShuiRuntimeState
    val actions: ShuiRuntimeActions
}

@Stable
class ShuiRuntimeController private constructor(
    context: Context
) : ShuiRuntimeProvider, ShuiRuntimeActions {
    private val activity = context as? Activity
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val hotwater = HotwaterRuntimeAdapter(appContext)
    private val ujing = UjingRuntimeAdapter(appContext)
    private val prefs = appContext.getSharedPreferences("zhuli_hotwater", Context.MODE_PRIVATE)

    override var state by mutableStateOf(initialState())
        private set

    override val actions: ShuiRuntimeActions = this

    init {
        restoreCurrentWasherOrderOnStartup()
        restoreCurrentWaterOrderOnStartup()
    }

    override fun loginHotwater(phone: String, password: String) {
        if (state.hotwaterLogin.state == RuntimeTaskState.Loading) return
        val normalizedPhone = phone.trim()
        runHotwaterAction(
            loading = { copy(hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Loading, "正在登录住理生活")) },
            success = {
                copy(
                    hotwaterPhone = prefs.getString("phone", "") ?: "",
                    hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Success, "住理生活已登录：$normalizedPhone")
                )
            },
            failure = { message -> copy(hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Failure, message)) }
        ) {
            hotwater.login(normalizedPhone, password)
        }
    }

    override fun checkHotwaterStatus() {
        val phone = prefs.getString("phone", "") ?: ""
        val device = prefs.getString("device_id", "") ?: ""
        state = state.copy(
            hotwaterPhone = phone,
            hotwaterDeviceCode = device,
            hotwaterLogin = if (phone.isBlank()) {
                RuntimeActionStatus(RuntimeTaskState.LoginRequired, "住理生活未登录")
            } else {
                RuntimeActionStatus(RuntimeTaskState.Success, "住理生活账号：$phone；热水设备码：${device.ifBlank { "未绑定" }}")
            }
        )
    }

    override fun bindHotwaterDeviceCode(deviceId: String) {
        val normalized = deviceId.trim()
        if (normalized.isBlank()) {
            state = state.copy(hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Failure, "请输入热水设备码"))
            return
        }
        prefs.edit().putString("device_id", normalized).apply()
        state = state.copy(
            hotwaterDeviceCode = normalized,
            hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Success, "已绑定热水设备码：$normalized")
        )
    }

    override fun startHotwater(phone: String, password: String, deviceId: String) {
        if (state.hotwaterStart.state == RuntimeTaskState.Loading) return

        val normalizedPhone = phone.trim()
        val normalizedDeviceId = deviceId.trim()
        if (normalizedPhone.isEmpty()) {
            state = state.copy(
                hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.LoginRequired, "请输入住理手机号"),
                hotwaterStart = RuntimeActionStatus(RuntimeTaskState.LoginRequired, "请输入住理手机号")
            )
            return
        }
        if (normalizedDeviceId.isEmpty()) {
            state = state.copy(
                hotwaterStart = RuntimeActionStatus(RuntimeTaskState.Failure, "请输入热水设备号")
            )
            return
        }

        val missingPermission = missingHotwaterBlePermission()
        if (missingPermission != null) {
            state = state.copy(
                hotwaterStart = RuntimeActionStatus(RuntimeTaskState.PermissionRequired, missingPermission)
            )
            return
        }

        runHotwaterAction(
            loading = {
                copy(
                    hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Loading, "正在检查住理登录"),
                    hotwaterStart = RuntimeActionStatus(RuntimeTaskState.Loading, "正在启动热水")
                )
            },
            success = {
                copy(
                    hotwaterPhone = normalizedPhone,
                    hotwaterDeviceCode = normalizedDeviceId,
                    hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Success, "住理账号可用"),
                    hotwaterStart = RuntimeActionStatus(RuntimeTaskState.Success, "热水启动完成")
                )
            },
            failure = { message ->
                val loginRequired = message.contains("登录") || message.contains("手机号")
                copy(
                    hotwaterLogin = if (loginRequired) {
                        RuntimeActionStatus(RuntimeTaskState.LoginRequired, message)
                    } else {
                        hotwaterLogin
                    },
                    hotwaterStart = RuntimeActionStatus(
                        if (loginRequired) RuntimeTaskState.LoginRequired else RuntimeTaskState.Failure,
                        message
                    )
                )
            }
        ) {
            hotwater.start(normalizedPhone, password, normalizedDeviceId)
        }
    }

    override fun startHotwater() {
        runHotwaterAction(
            loading = { copy(hotwaterStart = RuntimeActionStatus(RuntimeTaskState.Loading, "正在启动热水")) },
            success = { copy(hotwaterStart = RuntimeActionStatus(RuntimeTaskState.Success, "热水启动完成")) },
            failure = { message -> copy(hotwaterStart = RuntimeActionStatus(RuntimeTaskState.Failure, message)) }
        ) {
            hotwater.startFromCache()
        }
    }

    override fun stopHotwater() {
        if (state.hotwaterStop.state == RuntimeTaskState.Loading) return

        if (!hotwater.hasCachedRunningSession()) {
            state = state.copy(
                hotwaterStop = RuntimeActionStatus(
                    RuntimeTaskState.Unavailable,
                    "没有可关闭的热水会话；只能关闭本 App 当前开启的热水"
                )
            )
            return
        }

        val missingPermission = missingHotwaterBlePermission()
        if (missingPermission != null) {
            state = state.copy(
                hotwaterStop = RuntimeActionStatus(RuntimeTaskState.PermissionRequired, missingPermission)
            )
            return
        }

        runHotwaterAction(
            loading = { copy(hotwaterStop = RuntimeActionStatus(RuntimeTaskState.Loading, "正在关闭热水")) },
            success = {
                copy(
                    hotwaterStop = RuntimeActionStatus(RuntimeTaskState.Success, "热水已关闭"),
                    hotwaterStart = RuntimeActionStatus(RuntimeTaskState.Idle, "热水已关闭")
                )
            },
            failure = { message -> copy(hotwaterStop = RuntimeActionStatus(RuntimeTaskState.Failure, message)) }
        ) {
            hotwater.stopFromCache()
        }
    }

    override fun loadHotwaterHistory() {
        runHotwaterAction(
            loading = { copy(hotwaterHistory = RuntimeActionStatus(RuntimeTaskState.Loading, "正在加载热水历史")) },
            success = { copy(hotwaterHistory = RuntimeActionStatus(RuntimeTaskState.Success, "热水历史已刷新")) },
            failure = { message -> copy(hotwaterHistory = RuntimeActionStatus(RuntimeTaskState.Failure, message)) }
        ) {
            val records = hotwater.loadRecentHistory(30).map { record ->
                HotwaterHistoryUi(
                    time = record.time,
                    deviceId = record.deviceId,
                    amount = record.amount,
                    status = record.status,
                    orderId = record.orderId
                )
            }
            postState {
                state = state.copy(hotwaterHistoryRecords = records)
            }
        }
    }

    override fun loginUjing(phone: String, captcha: String) {
        if (state.washerLogin.state == RuntimeTaskState.Loading) return

        runUjingAction(
            loading = { copy(washerLogin = RuntimeActionStatus(RuntimeTaskState.Loading, "正在登录 U净")) },
            success = { copy(washerLogin = RuntimeActionStatus(RuntimeTaskState.Success, "U净登录成功")) },
            failure = { message -> copy(washerLogin = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val session = ujing.login(phone, captcha)
            postState {
                state = state.copy(
                    ujingAccount = session.toUi(),
                    washerLogin = RuntimeActionStatus(RuntimeTaskState.Success, "U净登录成功")
                )
            }
        }
    }

    override fun requestUjingCaptcha(phone: String) {
        if (state.ujingCaptcha.state == RuntimeTaskState.Loading) return

        runUjingAction(
            loading = { copy(ujingCaptcha = RuntimeActionStatus(RuntimeTaskState.Loading, "正在获取 U净验证码")) },
            success = { copy(ujingCaptcha = RuntimeActionStatus(RuntimeTaskState.Success, "验证码已发送")) },
            failure = { message -> copy(ujingCaptcha = RuntimeActionStatus(RuntimeTaskState.Failure, message)) }
        ) {
            ujing.requestCaptcha(phone)
        }
    }

    override fun checkUjingStatus() {
        val account = state.ujingAccount ?: ujing.loadCachedSession()?.toUi()
        state = state.copy(
            ujingAccount = account,
            washerLogin = if (account == null) {
                RuntimeActionStatus(RuntimeTaskState.LoginRequired, "U净未登录")
            } else {
                RuntimeActionStatus(RuntimeTaskState.Success, "U净账号：${account.mobile}；服务：${account.serviceSubjectId}")
            }
        )
    }

    override fun scanWasherWithCamera() {
        markUnavailable("相机扫码将在权限与扫码任务中接入")
    }

    override fun scanWasher(qrCode: String) {
        if (state.washerScan.state == RuntimeTaskState.Loading) return

        val drinkingCd = drinkingWaterCd(qrCode)
        if (drinkingCd != null) {
            val devices = upsertDrinkingWaterShortcut(drinkingCd, qrCode.trim())
            saveLocalDevices(devices)
            state = state.copy(
                localDevices = devices,
                washerScan = RuntimeActionStatus(
                    RuntimeTaskState.Success,
                    "已保存饮水机快捷入口"
                )
            )
            return
        }

        runUjingAction(
            loading = { copy(washerScan = RuntimeActionStatus(RuntimeTaskState.Loading, "正在识别洗衣机")) },
            success = { copy(washerScan = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣机识别完成")) },
            failure = { message -> copy(washerScan = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val normalizedQr = qrCode.trim()
            val program = ujing.scanWasherAndLoadProgram(normalizedQr).toUi()
            postState {
                val devices = upsertWasherShortcut(program, normalizedQr)
                saveLocalDevices(devices)
                state = state.copy(
                    washerProgram = program,
                    localDevices = devices,
                    washerScan = RuntimeActionStatus(
                        if (program.createOrderEnabled) RuntimeTaskState.Success else RuntimeTaskState.Unavailable,
                        if (program.createOrderEnabled) "洗衣机识别完成" else program.reason.ifBlank { "该设备暂不可下单" }
                    )
                )
            }
        }
    }

    override fun createWasherOrder(washModelId: Int, temperatureId: Int) {
        if (state.washerOrder.state == RuntimeTaskState.Loading) return

        runUjingAction(
            loading = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在创建洗衣订单")) },
            success = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣订单已创建")) },
            failure = { message -> copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val detail = ujing.createOrder(washModelId, temperatureId).toUi()
            postState {
                state = state.copy(
                    currentWasherOrder = detail,
                    washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣订单已创建")
                )
            }
        }
    }

    override fun refreshCurrentWasherOrder() {
        runUjingAction(
            loading = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在刷新洗衣订单")) },
            success = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣订单已刷新")) },
            failure = { message -> copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val detail = ujing.loadCurrentOrderDetail().toUi()
            postState {
                state = state.copy(
                    currentWasherOrder = detail,
                    washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣订单已刷新")
                )
            }
        }
    }

    override fun createWasherOrder() {
        val modelId = state.washerProgram?.defaultWashModelId ?: 0
        if (modelId == 0) {
            state = state.copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, "请先扫描洗衣机并选择套餐"))
            return
        }
        createWasherOrder(modelId, 1)
    }

    override fun payCurrentWasherOrderWithAlipay() {
        if (state.washerPayment.state == RuntimeTaskState.PaymentInProgress) return
        if (state.washerOrder.state == RuntimeTaskState.Loading) return

        runUjingAction(
            loading = { copy(washerPayment = RuntimeActionStatus(RuntimeTaskState.PaymentInProgress, "正在启动支付宝支付")) },
            success = { copy(washerPayment = RuntimeActionStatus(RuntimeTaskState.Success, "支付宝支付已返回，订单状态已刷新")) },
            failure = { message -> copy(washerPayment = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val result = ujing.payCurrentOrderWithAlipay(activity)
            val refreshedOrder = result.refreshedOrder.toUi()
            val paymentState = if (result.paymentSucceeded) RuntimeTaskState.Success else RuntimeTaskState.Failure
            val paymentMessage = if (result.paymentSucceeded) {
                "支付宝支付已返回成功，订单状态：${refreshedOrder.statusText}"
            } else {
                "支付宝未确认成功(${result.resultStatus.ifBlank { "unknown" }})，订单状态：${refreshedOrder.statusText}"
            }
            postState {
                state = state.copy(
                    currentWasherPayment = result.toUi(),
                    currentWasherOrder = refreshedOrder,
                    washerPayment = RuntimeActionStatus(paymentState, paymentMessage)
                )
            }
        }
    }

    override fun startCurrentWasherOrder() {
        if (state.washerOrder.state == RuntimeTaskState.Loading) return
        if (state.washerPayment.state == RuntimeTaskState.PaymentInProgress) return

        runUjingAction(
            loading = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在启动洗衣机")) },
            success = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣机启动请求已发送")) },
            failure = { message -> copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val detail = ujing.startCurrentOrder().toUi()
            postState {
                state = state.copy(
                    currentWasherOrder = detail,
                    washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣机启动请求已发送")
                )
            }
        }
    }

    override fun stopCurrentWasherOrder() {
        if (state.washerOrder.state == RuntimeTaskState.Loading) return
        if (state.washerPayment.state == RuntimeTaskState.PaymentInProgress) return

        runUjingAction(
            loading = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在提前停止洗衣机")) },
            success = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣机已提前停止")) },
            failure = { message -> copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val detail = ujing.stopCurrentOrder().toUi()
            postState {
                state = state.copy(
                    currentWasherOrder = detail,
                    washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣机已提前停止")
                )
            }
        }
    }

    override fun cancelCurrentWasherOrder() {
        if (state.washerOrder.state == RuntimeTaskState.Loading) return
        if (state.washerPayment.state == RuntimeTaskState.PaymentInProgress) return

        runUjingAction(
            loading = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在取消洗衣订单")) },
            success = { copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "洗衣订单已取消")) },
            failure = { message -> copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)) }
        ) {
            ujing.cancelCurrentOrder()
            postState {
                state = state.copy(currentWasherOrder = null)
            }
        }
    }

    override fun prepareDrinkingWater(qrCodeOrCd: String) {
        if (state.waterScan.state == RuntimeTaskState.Loading) return
        val cd = drinkingWaterCd(qrCodeOrCd) ?: qrCodeOrCd.trim()
        if (cd.isBlank()) {
            state = state.copy(waterScan = RuntimeActionStatus(RuntimeTaskState.Failure, "没有识别到饮水设备码"))
            return
        }
        val qrOrCd = qrCodeOrCd.trim().ifBlank { cd }
        runUjingAction(
            loading = { copy(waterScan = RuntimeActionStatus(RuntimeTaskState.Loading, "正在确认饮水机")) },
            success = { copy(waterScan = RuntimeActionStatus(RuntimeTaskState.Success, "饮水机已确认")) },
            failure = { message -> copy(waterScan = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val ready = ujing.prepareWater(qrOrCd).toUi()
            postState {
                val devices = upsertDrinkingWaterShortcut(ready.cd, qrOrCd)
                saveLocalDevices(devices)
                state = state.copy(
                    currentWaterReady = ready,
                    localDevices = devices,
                    waterScan = RuntimeActionStatus(
                        RuntimeTaskState.Success,
                        "饮水机已确认：${ready.serviceSubjectName.ifBlank { ready.cd }}"
                    )
                )
            }
        }
    }

    override fun createDrinkingWaterOrder() {
        if (state.waterOrder.state == RuntimeTaskState.Loading) return
        if ((state.currentWaterReady?.balanceFen ?: 0) <= 0) {
            state = state.copy(waterOrder = RuntimeActionStatus(RuntimeTaskState.Unavailable, "余额不足，请先在官方 App 充值"))
            return
        }
        runUjingAction(
            loading = { copy(waterOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在创建接水订单")) },
            success = { copy(waterOrder = RuntimeActionStatus(RuntimeTaskState.Success, "接水订单已创建")) },
            failure = { message -> copy(waterOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val detail = ujing.createWaterOrder().toUi()
            postState {
                state = state.copy(
                    currentWaterOrder = detail,
                    waterOrder = RuntimeActionStatus(RuntimeTaskState.Success, "接水订单已创建，请在饮水机上按按钮开始/停止接水")
                )
            }
        }
    }

    override fun refreshCurrentDrinkingWaterOrder() {
        if (state.waterOrder.state == RuntimeTaskState.Loading) return
        runUjingAction(
            loading = { copy(waterOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在刷新接水订单")) },
            success = { copy(waterOrder = RuntimeActionStatus(RuntimeTaskState.Success, "接水订单已刷新")) },
            failure = { message -> copy(waterOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)) },
            autoSuccess = false
        ) {
            val detail = ujing.loadCurrentWaterOrderDetail().toUi()
            postState {
                state = state.copy(
                    currentWaterOrder = detail,
                    waterOrder = RuntimeActionStatus(RuntimeTaskState.Success, "接水订单已刷新：${detail.statusRemark.ifBlank { detail.orderStatusName }}")
                )
            }
        }
    }

    override fun refreshLocalDevices() {
        val devices = loadLocalDevices()
        val now = formatRefreshTime(System.currentTimeMillis())
        prefs.edit().putString("local_devices_last_refreshed", now).apply()
        state = state.copy(
            localDevices = devices,
            localDevicesLastRefreshed = now
        )
    }

    override fun renameLocalDevice(deviceId: String, name: String) {
        val normalized = name.trim()
        if (normalized.isEmpty()) return
        val devices = state.localDevices.map { device ->
            if (device.id == deviceId) device.copy(customName = normalized) else device
        }
        saveLocalDevices(devices)
        state = state.copy(localDevices = devices)
    }

    override fun deleteLocalDevice(deviceId: String) {
        val devices = state.localDevices.filterNot { it.id == deviceId }
        saveLocalDevices(devices)
        state = state.copy(localDevices = devices)
    }

    private fun markUnavailable(message: String) {
        state = state.copy(userNotice = message)
    }

    private fun upsertWasherShortcut(program: WasherProgramUi, qrCode: String): List<LocalDeviceShortcut> {
        val existing = state.localDevices.firstOrNull { it.id == program.deviceId }
        val shortcut = LocalDeviceShortcut(
            id = program.deviceId,
            customName = existing?.customName?.takeIf { it.isNotBlank() }
                ?: program.deviceNo.ifBlank { "洗衣机 ${program.deviceId}" },
            deviceType = LocalDeviceType.Washer,
            qrUrl = qrCode,
            lastStatus = if (program.createOrderEnabled) "可下单" else program.reason.ifBlank { "不可下单" },
            sortOrder = existing?.sortOrder ?: state.localDevices.size
        )
        return state.localDevices
            .filterNot { it.id == program.deviceId }
            .plus(shortcut)
            .sortedBy { it.sortOrder }
    }

    private fun upsertDrinkingWaterShortcut(cd: String, qrCode: String): List<LocalDeviceShortcut> {
        val id = "drinking-$cd"
        val existing = state.localDevices.firstOrNull { it.id == id }
        val shortcut = LocalDeviceShortcut(
            id = id,
            customName = existing?.customName?.takeIf { it.isNotBlank() } ?: "饮水机 $cd",
            deviceType = LocalDeviceType.DrinkingWater,
            qrUrl = qrCode,
            cd = cd,
            lastStatus = "可接水",
            sortOrder = existing?.sortOrder ?: state.localDevices.size
        )
        return state.localDevices
            .filterNot { it.id == id }
            .plus(shortcut)
            .sortedBy { it.sortOrder }
    }

    private fun drinkingWaterCd(qrCode: String): String? {
        val raw = qrCode.trim()
        if (raw.isBlank()) return null
        return try {
            val uri = Uri.parse(raw)
            val cd = uri.getQueryParameter("cd")
            if (!cd.isNullOrBlank() && raw.contains("q.ujing.com.cn/ed")) cd else null
        } catch (e: Exception) {
            null
        }
    }

    private fun loadLocalDevices(): List<LocalDeviceShortcut> {
        val raw = prefs.getString("local_devices", "") ?: ""
        if (raw.isBlank()) return emptyList()
        return try {
            val rows = JSONArray(raw)
            buildList {
                for (i in 0 until rows.length()) {
                    val row = rows.getJSONObject(i)
                    add(
                        LocalDeviceShortcut(
                            id = row.optString("id"),
                            customName = row.optString("customName"),
                            deviceType = runCatching { LocalDeviceType.valueOf(row.optString("deviceType")) }
                                .getOrDefault(LocalDeviceType.Unknown),
                            qrUrl = row.optString("qrUrl").ifBlank { null },
                            cd = row.optString("cd").ifBlank { null },
                            lastStatus = row.optString("lastStatus").ifBlank { null },
                            sortOrder = row.optInt("sortOrder", i)
                        )
                    )
                }
            }.filter { it.id.isNotBlank() }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun saveLocalDevices(devices: List<LocalDeviceShortcut>) {
        val rows = JSONArray()
        devices.forEach { device ->
            rows.put(
                JSONObject()
                    .put("id", device.id)
                    .put("customName", device.customName)
                    .put("deviceType", device.deviceType.name)
                    .put("qrUrl", device.qrUrl ?: "")
                    .put("cd", device.cd ?: "")
                    .put("lastStatus", device.lastStatus ?: "")
                    .put("sortOrder", device.sortOrder)
            )
        }
        prefs.edit().putString("local_devices", rows.toString()).apply()
    }

    private fun formatRefreshTime(timestamp: Long): String {
        return SimpleDateFormat("MM-dd HH:mm", Locale.CHINA).format(Date(timestamp))
    }

    private fun restoreCurrentWasherOrderOnStartup() {
        if (state.ujingAccount == null) return
        state = state.copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Loading, "正在恢复洗衣订单"))
        worker.execute {
            try {
                val restored = ujing.restoreActiveOrder()?.toUi()
                postState {
                    state = if (restored == null) {
                        state.copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Idle, "暂无进行中的洗衣订单"))
                    } else {
                        state.copy(
                            currentWasherOrder = restored,
                            washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "已恢复洗衣订单")
                        )
                    }
                }
            } catch (e: Exception) {
                val message = e.message ?: "恢复洗衣订单失败"
                AppLogStore.append(appContext, "[runtime-ujing-restore-error] ${e.javaClass.simpleName}: $message")
                postState {
                    if (isSessionError(message)) {
                        ujing.clearCachedSession()
                        state = state.copy(
                            ujingAccount = null,
                            currentWasherOrder = null,
                            washerLogin = RuntimeActionStatus(RuntimeTaskState.LoginRequired, "U净登录已失效，请重新登录"),
                            washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message)
                        )
                    } else {
                        state = state.copy(washerOrder = RuntimeActionStatus(RuntimeTaskState.Failure, message))
                    }
                }
            }
        }
    }

    private fun restoreCurrentWaterOrderOnStartup() {
        if (state.ujingAccount == null) return
        worker.execute {
            try {
                val restored = ujing.loadCurrentWaterOrderDetail().toUi()
                postState {
                    state = state.copy(
                        currentWaterOrder = restored,
                        waterOrder = RuntimeActionStatus(RuntimeTaskState.Success, "已恢复接水订单")
                    )
                }
            } catch (e: Exception) {
                val message = e.message ?: ""
                if (!message.contains("当前没有饮水订单")) {
                    AppLogStore.append(appContext, "[runtime-water-restore-error] ${e.javaClass.simpleName}: $message")
                }
            }
        }
    }

    private fun missingHotwaterBlePermission(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null

        val missing = mutableListOf<String>()
        val bluetoothManager = appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        if (bluetoothManager?.adapter?.isEnabled != true) {
            missing += "请先开启蓝牙"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (appContext.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                missing += "附近设备扫描权限"
            }
            if (appContext.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                missing += "蓝牙连接权限"
            }
        } else if (appContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            missing += "定位权限"
        }

        return if (missing.isEmpty()) {
            null
        } else {
            "启动热水前需要授权：${missing.joinToString("、")}"
        }
    }

    private fun runHotwaterAction(
        loading: ShuiRuntimeState.() -> ShuiRuntimeState,
        success: ShuiRuntimeState.() -> ShuiRuntimeState,
        failure: ShuiRuntimeState.(String) -> ShuiRuntimeState,
        block: () -> Unit
    ) {
        state = state.loading()
        worker.execute {
            try {
                block()
                postState { state = state.success() }
            } catch (e: Exception) {
                val message = e.message ?: "热水操作失败"
                AppLogStore.append(appContext, "[runtime-hotwater-error] ${e.javaClass.simpleName}: $message")
                postState {
                    state = state.failure(message)
                    if (isSessionError(message)) {
                        state = state.copy(hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.LoginRequired, "住理登录已失效，请重新登录"))
                    }
                }
            }
        }
    }

    private fun runUjingAction(
        loading: ShuiRuntimeState.() -> ShuiRuntimeState,
        success: ShuiRuntimeState.() -> ShuiRuntimeState,
        failure: ShuiRuntimeState.(String) -> ShuiRuntimeState,
        autoSuccess: Boolean = true,
        block: () -> Unit
    ) {
        state = state.loading()
        worker.execute {
            try {
                block()
                if (autoSuccess) {
                    postState { state = state.success() }
                }
            } catch (e: Exception) {
                val message = e.message ?: "U净操作失败"
                AppLogStore.append(appContext, "[runtime-ujing-error] ${e.javaClass.simpleName}: $message")
                if (isSessionError(message)) {
                    ujing.clearCachedSession()
                }
                postState {
                    state = state.failure(message)
                    if (isSessionError(message)) {
                        state = state.copy(
                            ujingAccount = null,
                            washerLogin = RuntimeActionStatus(RuntimeTaskState.LoginRequired, "U净登录已失效，请重新登录")
                        )
                    }
                }
            }
        }
    }

    private fun isSessionError(message: String): Boolean {
        val normalized = message.lowercase()
        return normalized.contains("api_sign_error") ||
            normalized.contains("token") ||
            normalized.contains("unauthorized") ||
            normalized.contains("登录已失效") ||
            normalized.contains("请先登录")
    }

    private fun postState(update: () -> Unit) {
        mainHandler.post(update)
    }

    fun close() {
        worker.shutdownNow()
    }

    companion object {
        fun create(context: Context): ShuiRuntimeController {
            return ShuiRuntimeController(context)
        }
    }

    private fun initialState(): ShuiRuntimeState {
        val cached = ujing.loadCachedSession()
        val localDevices = loadLocalDevices()
        val refreshedAt = prefs.getString("local_devices_last_refreshed", "") ?: ""
        val hotwaterPhone = prefs.getString("phone", "") ?: ""
        val hotwaterDeviceCode = prefs.getString("device_id", "") ?: ""
        return if (cached == null) {
            ShuiRuntimeState(
                hotwaterPhone = hotwaterPhone,
                hotwaterDeviceCode = hotwaterDeviceCode,
                hotwaterLogin = if (hotwaterPhone.isBlank()) {
                    RuntimeActionStatus(RuntimeTaskState.LoginRequired, "住理生活未登录")
                } else {
                    RuntimeActionStatus(RuntimeTaskState.Success, "已缓存住理生活：$hotwaterPhone")
                },
                localDevices = localDevices,
                localDevicesLastRefreshed = refreshedAt
            )
        } else {
            ShuiRuntimeState(
                hotwaterPhone = hotwaterPhone,
                hotwaterDeviceCode = hotwaterDeviceCode,
                hotwaterLogin = if (hotwaterPhone.isBlank()) {
                    RuntimeActionStatus(RuntimeTaskState.LoginRequired, "住理生活未登录")
                } else {
                    RuntimeActionStatus(RuntimeTaskState.Success, "已缓存住理生活：$hotwaterPhone")
                },
                ujingAccount = cached.toUi(),
                washerLogin = RuntimeActionStatus(RuntimeTaskState.Success, "已缓存 U净登录：${cached.mobile}"),
                localDevices = localDevices,
                localDevicesLastRefreshed = refreshedAt
            )
        }
    }

    private fun UjingRuntimeAdapter.AccountSession.toUi(): UjingAccountUi {
        return UjingAccountUi(
            mobile = mobile,
            userId = userId,
            serviceSubjectId = serviceSubjectId
        )
    }

    private fun UjingRuntimeAdapter.WasherProgram.toUi(): WasherProgramUi {
        return WasherProgramUi(
            deviceId = deviceId,
            deviceNo = deviceNo,
            deviceTypeName = deviceTypeName,
            storeId = storeId,
            storeName = storeName,
            status = status.toString(),
            reason = reason ?: "",
            createOrderEnabled = createOrderEnabled,
            defaultWashModelId = defaultWashModelId,
            models = models.map { model ->
                WasherModelUi(
                    id = model.id,
                    name = model.name,
                    priceFen = model.price,
                    timeMinutes = model.time
                )
            }
        )
    }

    private fun UjingRuntimeAdapter.WasherOrderDetail.toUi(): WasherOrderUi {
        return WasherOrderUi(
            orderId = orderId,
            deviceNo = deviceNo,
            statusText = statusText,
            payPrice = payPrice,
            status = status,
            remainTimeSeconds = remainTimeSeconds,
            countDownSeconds = countDownSeconds
        )
    }

    private fun UjingRuntimeAdapter.PaymentResult.toUi(): WasherPaymentUi {
        return WasherPaymentUi(
            orderId = orderId,
            resultStatus = resultStatus,
            memo = memo,
            sdkResult = sdkResult,
            paymentSucceeded = paymentSucceeded
        )
    }

    private fun UjingRuntimeAdapter.WaterReady.toUi(): WaterReadyUi {
        return WaterReadyUi(
            cd = cd,
            serviceSubjectId = serviceSubjectId,
            serviceSubjectName = serviceSubjectName,
            storeId = storeId,
            balanceFen = balanceFen,
            giftBalanceFen = giftBalanceFen
        )
    }

    private fun UjingRuntimeAdapter.WaterOrderDetail.toUi(): WaterOrderUi {
        return WaterOrderUi(
            orderId = orderId,
            orderNo = orderNo,
            serviceSubjectName = serviceSubjectName,
            storeName = storeName,
            deviceNo = deviceNo,
            orderStatus = orderStatus,
            orderStatusName = orderStatusName,
            statusRemark = statusRemark,
            warmWaterMl = warmWaterMl,
            waterSeconds = waterSeconds,
            payment = payment,
            payPrice = payPrice,
            payFlag = payFlag
        )
    }
}

object PreviewShuiRuntimeActions : ShuiRuntimeActions {
    override fun loginHotwater(phone: String, password: String) = Unit
    override fun checkHotwaterStatus() = Unit
    override fun bindHotwaterDeviceCode(deviceId: String) = Unit
    override fun startHotwater(phone: String, password: String, deviceId: String) = Unit
    override fun startHotwater() = Unit
    override fun stopHotwater() = Unit
    override fun loadHotwaterHistory() = Unit
    override fun loginUjing(phone: String, captcha: String) = Unit
    override fun requestUjingCaptcha(phone: String) = Unit
    override fun checkUjingStatus() = Unit
    override fun scanWasherWithCamera() = Unit
    override fun scanWasher(qrCode: String) = Unit
    override fun createWasherOrder(washModelId: Int, temperatureId: Int) = Unit
    override fun refreshCurrentWasherOrder() = Unit
    override fun createWasherOrder() = Unit
    override fun payCurrentWasherOrderWithAlipay() = Unit
    override fun startCurrentWasherOrder() = Unit
    override fun cancelCurrentWasherOrder() = Unit
    override fun stopCurrentWasherOrder() = Unit
    override fun prepareDrinkingWater(qrCodeOrCd: String) = Unit
    override fun createDrinkingWaterOrder() = Unit
    override fun refreshCurrentDrinkingWaterOrder() = Unit
    override fun refreshLocalDevices() = Unit
    override fun renameLocalDevice(deviceId: String, name: String) = Unit
    override fun deleteLocalDevice(deviceId: String) = Unit
}

object PreviewShuiRuntimeProvider : ShuiRuntimeProvider {
    override val state = ShuiRuntimeState(
        hotwaterLogin = RuntimeActionStatus(RuntimeTaskState.Success, "预览：住理账号已登录"),
        hotwaterHistory = RuntimeActionStatus(RuntimeTaskState.Success, "预览：热水历史已加载"),
        hotwaterHistoryRecords = listOf(
            HotwaterHistoryUi("06-01 10:30", "A-01", "2.50", "已完成", "preview-hot-1"),
            HotwaterHistoryUi("06-01 09:45", "A-02", "1.80", "使用中", "preview-hot-2")
        ),
        ujingAccount = UjingAccountUi(
            mobile = "13800000000",
            userId = "preview-user",
            serviceSubjectId = "preview-subject"
        ),
        ujingCaptcha = RuntimeActionStatus(RuntimeTaskState.Success, "预览：验证码已发送"),
        washerLogin = RuntimeActionStatus(RuntimeTaskState.Success, "预览：U净账号已登录"),
        washerScan = RuntimeActionStatus(RuntimeTaskState.Success, "预览：洗衣机识别完成"),
        washerProgram = WasherProgramUi(
            deviceId = "preview-device",
            deviceNo = "WASH-003",
            deviceTypeName = "波轮洗衣机",
            storeId = "preview-store",
            storeName = "芙兰公寓 2楼 洗衣房A区",
            status = "0",
            reason = "",
            createOrderEnabled = true,
            defaultWashModelId = 1,
            models = listOf(
                WasherModelUi(1, "超强洗", 600, 45),
                WasherModelUi(2, "普通洗", 450, 35)
            )
        ),
        washerOrder = RuntimeActionStatus(RuntimeTaskState.Success, "预览：洗衣订单已创建"),
        currentWasherOrder = WasherOrderUi(
            orderId = "preview-washer-order",
            deviceNo = "WASH-003",
            statusText = "待支付",
            payPrice = "6.00",
            status = "pending"
        ),
        washerPayment = RuntimeActionStatus(RuntimeTaskState.Idle, "预览：暂时只支持支付宝支付"),
        currentWasherPayment = WasherPaymentUi(
            orderId = "preview-washer-order",
            resultStatus = "9000",
            memo = "预览：支付成功",
            sdkResult = "{resultStatus=9000, memo=预览}"
        ),
        waterScan = RuntimeActionStatus(RuntimeTaskState.Success, "预览：饮水机已确认"),
        currentWaterReady = WaterReadyUi(
            cd = "0011202108055265",
            serviceSubjectId = "37810",
            serviceSubjectName = "武汉理工大学.马房山校区",
            storeId = "63199627046cb84fd7c9f7ba",
            balanceFen = 1000,
            giftBalanceFen = 0
        ),
        waterOrder = RuntimeActionStatus(RuntimeTaskState.Success, "预览：接水订单已创建"),
        currentWaterOrder = WaterOrderUi(
            orderId = "1102876060",
            orderNo = "preview-water-order",
            serviceSubjectName = "武汉理工大学.马房山校区",
            storeName = "学海7舍-5",
            deviceNo = "070501",
            orderStatus = "50",
            orderStatusName = "取水正常完成",
            statusRemark = "取水正常完成",
            warmWaterMl = 133,
            waterSeconds = 2,
            payment = 0.02,
            payPrice = 0.02,
            payFlag = 1
        ),
        localDevices = listOf(
            LocalDeviceShortcut(
                id = "preview-washer-1",
                customName = "洗衣机 A-01",
                deviceType = LocalDeviceType.Washer,
                qrUrl = "preview://washer/a01",
                lastStatus = "空闲",
                sortOrder = 0
            ),
            LocalDeviceShortcut(
                id = "preview-drinking-1",
                customName = "饮水机 A-01",
                deviceType = LocalDeviceType.DrinkingWater,
                cd = "preview-cd",
                lastStatus = "待接入",
                sortOrder = 1
            )
        )
    )
    override val actions: ShuiRuntimeActions = PreviewShuiRuntimeActions
}
