package com.kazuki.zhulihotwater.runtime

import android.net.Uri
import java.util.Locale

enum class HomeTaskTarget {
    HotwaterDetail,
    WasherOrderDetail,
    DrinkingWaterDetail
}

data class HomeTaskUi(
    val id: String,
    val title: String,
    val subtitle: String,
    val extra: String,
    val iconName: String,
    val target: HomeTaskTarget
)

sealed class ScanRouting {
    data object Washer : ScanRouting()
    data class DrinkingWater(val cd: String) : ScanRouting()
    data class Unknown(val reason: String) : ScanRouting()
}

val ShuiRuntimeState.homeTasks: List<HomeTaskUi>
    get() = buildList {
        val hotwaterActive = hotwaterStart.state == RuntimeTaskState.Success && hotwaterStop.state != RuntimeTaskState.Success
        if (hotwaterActive) {
            add(
                HomeTaskUi(
                    id = "hotwater",
                    title = "热水使用中",
                    subtitle = hotwaterStart.message ?: "热水已开启",
                    extra = hotwaterStop.message ?: "点击查看详情",
                    iconName = "reshui",
                    target = HomeTaskTarget.HotwaterDetail
                )
            )
        }
        currentWasherOrder?.takeUnless { it.isTerminalWasherOrder }?.let { order ->
            add(
                HomeTaskUi(
                    id = "washer",
                    title = washerTaskTitle(order),
                    subtitle = order.deviceNo.ifBlank { order.orderId },
                    extra = washerTaskExtra(order),
                    iconName = "yifu",
                    target = HomeTaskTarget.WasherOrderDetail
                )
            )
        }
        currentWaterOrder?.let { order ->
            add(
                HomeTaskUi(
                    id = "drinking",
                    title = waterTaskTitle(order),
                    subtitle = order.deviceNo.ifBlank { order.orderId },
                    extra = waterTaskExtra(order),
                    iconName = "jieshui",
                    target = HomeTaskTarget.DrinkingWaterDetail
                )
            )
        }
    }.let { tasks ->
        if (tasks.size <= 3) tasks
        else tasks.take(2) + HomeTaskUi(
            id = "overflow",
            title = "更多任务",
            subtitle = "还有 ${tasks.size - 2} 个任务",
            extra = "点击查看",
            iconName = "yifu",
            target = HomeTaskTarget.WasherOrderDetail
        )
    }

private fun waterTaskTitle(order: WaterOrderUi): String {
    return when (order.orderStatus) {
        "50" -> "接水已完成"
        "0" -> "等待接水"
        else -> "接水中"
    }
}

private fun waterTaskExtra(order: WaterOrderUi): String {
    return when {
        order.orderStatus == "50" -> String.format(Locale.CHINA, "¥%.2f", order.payment)
        order.warmWaterMl > 0 -> "${order.warmWaterMl}ml"
        else -> order.statusRemark.ifBlank { "请按机器按钮" }
    }
}

private fun washerTaskTitle(order: WasherOrderUi): String {
    return when (order.status) {
        "10" -> "洗衣待支付"
        "20" -> "洗衣已预约"
        "21", "40" -> "洗衣进行中"
        "50" -> "洗衣已完成"
        else -> "洗衣订单"
    }
}

private fun washerTaskExtra(order: WasherOrderUi): String {
    return when {
        order.remainTimeSeconds > 0 -> "剩余 ${formatRemainTime(order.remainTimeSeconds)}"
        order.countDownSeconds > 0 -> "预约 ${formatRemainTime(order.countDownSeconds)}"
        order.status == "10" -> "待支付"
        order.status == "20" -> "待启动"
        else -> order.statusText
    }
}

private val WasherOrderUi.isTerminalWasherOrder: Boolean
    get() = status == "50" || statusText.contains("完成") || statusText.contains("取消")

fun classifyScanRouting(qrCode: String): ScanRouting {
    val raw = qrCode.trim()
    if (raw.isBlank()) return ScanRouting.Unknown("二维码为空")
    val lower = raw.lowercase(Locale.getDefault())
    val uri = runCatching { Uri.parse(raw) }.getOrNull()

    val cd = uri?.getQueryParameter("cd")?.trim()?.takeIf { it.isNotEmpty() }
        ?: extractQueryParameter(raw, "cd")
    if (!cd.isNullOrEmpty() && (
            lower.contains("q.ujing.com.cn/ed") ||
                lower.contains("/ed/") ||
                lower.contains("type=drink") ||
                lower.contains("type=water")
            )
    ) {
        return ScanRouting.DrinkingWater(cd)
    }

    if (
        lower.contains("u_download.html") ||
        lower.contains("type=ujing") ||
        lower.contains("scanwashercode") ||
        lower.contains("uuid=")
    ) {
        return ScanRouting.Washer
    }

    if (lower.contains("q.ujing.com.cn/ed")) {
        return ScanRouting.DrinkingWater(cd.orEmpty())
    }

    return ScanRouting.Unknown("暂时无法识别该二维码类型")
}

private fun extractQueryParameter(raw: String, key: String): String? {
    val pattern = Regex("([?&])$key=([^&]+)", RegexOption.IGNORE_CASE)
    return pattern.find(raw)?.groupValues?.getOrNull(2)?.takeIf { it.isNotBlank() }
}

private fun formatRemainTime(seconds: Int): String {
    val safe = seconds.coerceAtLeast(0)
    val minutes = safe / 60
    val remainSeconds = safe % 60
    return String.format(Locale.CHINA, "%02d:%02d", minutes, remainSeconds)
}
