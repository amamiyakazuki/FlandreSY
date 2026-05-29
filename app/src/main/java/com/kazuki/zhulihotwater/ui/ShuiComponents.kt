package com.kazuki.zhulihotwater.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kazuki.zhulihotwater.R

enum class MainTab(val label: String, val icon: String) {
    Home("功能", "⌂"),
    Orders("订单", "▤"),
    Devices("设备", "▣"),
    Profile("我的", "●")
}

data class OrderUi(
    val type: String,
    val time: String,
    val device: String,
    val amount: String,
    val status: String,
    val color: Color = ShuiColors.Primary,
    val icon: String = "♨"
)

data class DeviceUi(
    val name: String,
    val id: String,
    val type: String,
    val status: String,
    val statusColor: Color,
    @DrawableRes val imageRes: Int = R.drawable.washer_machine
)

@Composable
fun AdaptivePhoneContainer(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ShuiColors.Background),
        contentAlignment = Alignment.TopCenter
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .widthIn(max = 430.dp)
                .fillMaxWidth()
                .background(ShuiColors.Background)
        ) {
            content()
        }
    }
}

@Composable
fun TopHeader(
    title: String,
    modifier: Modifier = Modifier,
    showBack: Boolean = false,
    showSettings: Boolean = false,
    showAdd: Boolean = false,
    character: @Composable (BoxScope.() -> Unit)? = null,
    onBack: () -> Unit = {},
    onAdd: () -> Unit = {},
    height: Dp = 118.dp
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .background(
                Brush.linearGradient(
                    listOf(ShuiColors.Primary, ShuiColors.PrimaryDark, ShuiColors.PrimaryLight)
                )
            )
    ) {
        character?.invoke(this)
        Text(
            text = title,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = if (title.length <= 3) 29.sp else 27.sp,
            modifier = Modifier
                .align(Alignment.Center)
                .padding(top = 2.dp),
            textAlign = TextAlign.Center
        )
        if (showBack) {
            Text(
                text = "‹",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 42.sp,
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .padding(start = 14.dp)
                    .shuiPressable(onClick = onBack)
            )
        }
        if (showSettings) {
            Text(
                text = "⚙",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 34.sp,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 22.dp)
            )
        }
        if (showAdd) {
            Text(
                text = "+",
                color = Color.White,
                fontWeight = FontWeight.Normal,
                fontSize = 33.sp,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 24.dp)
                    .shuiPressable(onClick = onAdd)
            )
        }
        DecorativeImage(R.drawable.shui_heart, Modifier.align(Alignment.CenterStart).padding(start = 78.dp, bottom = 18.dp).size(24.dp), alpha = .58f)
        DecorativeImage(R.drawable.shui_heart, Modifier.align(Alignment.CenterEnd).padding(end = 80.dp, top = 18.dp).size(30.dp), alpha = .46f)
        Text("✦", color = Color.White.copy(alpha = .9f), fontSize = 18.sp, modifier = Modifier.align(Alignment.CenterEnd).padding(end = 58.dp, bottom = 20.dp))
        HeaderWave(Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun HeaderWave(modifier: Modifier = Modifier) {
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(25.dp)
    ) {
        val path = Path().apply {
            moveTo(0f, size.height * .25f)
            cubicTo(size.width * .25f, size.height * .95f, size.width * .65f, size.height * .85f, size.width, size.height * .2f)
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
        drawPath(path, ShuiColors.Background)
        drawPath(path, Color.White.copy(alpha = .28f))
    }
}

@Composable
fun WavyBottomBar(
    selectedTab: MainTab,
    onTabSelected: (MainTab) -> Unit,
    modifier: Modifier = Modifier
) {
    BottomNavBar(selectedTab = selectedTab, onTabSelected = onTabSelected, modifier = modifier)
}

@Composable
fun BottomNavBar(
    selectedTab: MainTab,
    onTabSelected: (MainTab) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(68.dp)
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val path = Path().apply {
                moveTo(0f, 12f)
                var x = 0f
                val wave = size.width / 18f
                while (x + wave < size.width) {
                    quadraticTo(x + wave / 2f, 0f, x + wave, 12f)
                    x += wave
                }
                lineTo(size.width, 12f)
                lineTo(size.width, size.height)
                lineTo(0f, size.height)
                close()
            }
            drawPath(path, Brush.linearGradient(listOf(ShuiColors.PrimaryLight, ShuiColors.Primary, ShuiColors.PrimaryDark)))
        }
        DecorativeImage(R.drawable.shui_bianfu, Modifier.align(Alignment.CenterEnd).padding(end = 108.dp, top = 8.dp).size(42.dp), alpha = .44f)
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp)
                .padding(top = 8.dp, bottom = 4.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            MainTab.values().forEach { tab ->
                val selected = tab == selectedTab
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .clip(RoundedCornerShape(18.dp))
                        .shuiPressable(scale = ShuiMotion.SoftPressedScale) { onTabSelected(tab) },
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    ShuiLineIcon(
                        name = when (tab) {
                            MainTab.Home -> "home"
                            MainTab.Orders -> "orders"
                            MainTab.Devices -> "washer"
                            MainTab.Profile -> "profile"
                        },
                        color = Color.White.copy(alpha = if (selected) 1f else .46f),
                        modifier = Modifier.size(25.dp)
                    )
                    Text(
                        text = tab.label,
                        color = Color.White.copy(alpha = if (selected) 1f else .58f),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

fun Modifier.dashedBorder(
    color: Color = ShuiColors.PrimaryLight,
    radius: Dp = 12.dp,
    strokeWidth: Dp = 1.dp
): Modifier = drawBehind {
    drawRoundRect(
        color = color,
        style = Stroke(
            width = strokeWidth.toPx(),
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 10f), 0f)
        ),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius.toPx(), radius.toPx())
    )
}

@Composable
fun SectionCard(
    modifier: Modifier = Modifier,
    borderColor: Color = ShuiColors.CardBorder,
    contentPadding: PaddingValues = PaddingValues(12.dp),
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(17.dp))
            .background(
                Brush.linearGradient(
                    listOf(Color.White, ShuiColors.SoftPink.copy(alpha = .85f), Color.White)
                )
            )
            .border(BorderStroke(1.dp, borderColor), RoundedCornerShape(17.dp))
            .padding(contentPadding)
    ) {
        content()
    }
}

@Composable
fun SectionTitle(icon: String, title: String, modifier: Modifier = Modifier, tail: String? = null) {
    Row(modifier = modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        ShuiLineIcon(sectionIconName(icon, title), ShuiColors.Primary, Modifier.size(25.dp))
        Spacer(Modifier.width(7.dp))
        Text(title, color = ShuiColors.DeepText, fontSize = 19.sp, fontWeight = FontWeight.Bold)
        Text("  ✦", color = ShuiColors.CardBorder, fontSize = 16.sp)
        Spacer(Modifier.weight(1f))
        if (tail != null) {
            Text(tail, color = ShuiColors.MutedText, fontSize = 14.sp)
        } else {
            Box(Modifier.width(82.dp).height(1.dp).background(ShuiColors.CardBorder.copy(alpha = .55f)))
        }
    }
}

private fun sectionIconName(icon: String, title: String): String {
    return when {
        title.contains("进行中") || title.contains("热水") || icon == "♨" -> "hot"
        title.contains("扫码") -> "scan"
        title.contains("洗衣设备") || title.contains("套餐") || icon == "▰" -> "shirt"
        title.contains("账号") && icon == "U" -> "u"
        title.contains("账号") -> "home"
        title.contains("更多") -> "bag"
        title.contains("温度") -> "drop"
        title.contains("洗衣液") || title.contains("除菌液") -> "bottle"
        else -> "spark"
    }
}

@Composable
fun ShuiLineIcon(name: String, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val stroke = Stroke(width = (w * .12f).coerceAtLeast(3f), cap = StrokeCap.Round, join = StrokeJoin.Round)
        fun line(x1: Float, y1: Float, x2: Float, y2: Float) {
            drawLine(color, Offset(w * x1, h * y1), Offset(w * x2, h * y2), stroke.width, StrokeCap.Round)
        }
        when (name) {
            "home" -> {
                val roof = Path().apply {
                    moveTo(w * .18f, h * .52f)
                    lineTo(w * .50f, h * .22f)
                    lineTo(w * .82f, h * .52f)
                }
                drawPath(roof, color, style = stroke)
                val body = Path().apply {
                    moveTo(w * .26f, h * .48f)
                    lineTo(w * .26f, h * .82f)
                    lineTo(w * .74f, h * .82f)
                    lineTo(w * .74f, h * .48f)
                }
                drawPath(body, color, style = stroke)
            }
            "orders" -> {
                drawRoundRect(color, topLeft = Offset(w * .25f, h * .18f), size = androidx.compose.ui.geometry.Size(w * .50f, h * .64f), style = stroke, cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * .08f))
                line(.36f, .35f, .64f, .35f)
                line(.36f, .50f, .64f, .50f)
                line(.36f, .65f, .56f, .65f)
            }
            "cup" -> {
                val cup = Path().apply {
                    moveTo(w * .28f, h * .26f)
                    lineTo(w * .34f, h * .78f)
                    lineTo(w * .66f, h * .78f)
                    lineTo(w * .72f, h * .26f)
                    close()
                }
                drawPath(cup, color, style = stroke)
                line(.34f, .42f, .66f, .42f)
                line(.40f, .56f, .60f, .56f)
            }
            "washer" -> {
                drawRoundRect(color, topLeft = Offset(w * .23f, h * .16f), size = androidx.compose.ui.geometry.Size(w * .54f, h * .68f), style = stroke, cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * .08f))
                drawCircle(color, radius = w * .16f, center = Offset(w * .50f, h * .56f), style = stroke)
                line(.34f, .28f, .66f, .28f)
            }
            "profile" -> {
                drawCircle(color, radius = w * .15f, center = Offset(w * .50f, h * .34f), style = stroke)
                val p = Path().apply {
                    moveTo(w * .24f, h * .82f)
                    cubicTo(w * .30f, h * .60f, w * .70f, h * .60f, w * .76f, h * .82f)
                }
                drawPath(p, color, style = stroke)
            }
            "hot" -> {
                line(.22f, .78f, .78f, .78f)
                line(.30f, .30f, .30f, .62f)
                line(.50f, .22f, .50f, .62f)
                line(.70f, .30f, .70f, .62f)
            }
            "scan" -> {
                line(.18f, .38f, .18f, .18f); line(.18f, .18f, .38f, .18f)
                line(.62f, .18f, .82f, .18f); line(.82f, .18f, .82f, .38f)
                line(.82f, .62f, .82f, .82f); line(.82f, .82f, .62f, .82f)
                line(.38f, .82f, .18f, .82f); line(.18f, .82f, .18f, .62f)
            }
            "shirt" -> {
                val p = Path().apply {
                    moveTo(w * .22f, h * .32f)
                    lineTo(w * .36f, h * .22f)
                    lineTo(w * .44f, h * .34f)
                    lineTo(w * .56f, h * .34f)
                    lineTo(w * .64f, h * .22f)
                    lineTo(w * .78f, h * .32f)
                    lineTo(w * .70f, h * .48f)
                    lineTo(w * .64f, h * .44f)
                    lineTo(w * .64f, h * .80f)
                    lineTo(w * .36f, h * .80f)
                    lineTo(w * .36f, h * .44f)
                    lineTo(w * .30f, h * .48f)
                    close()
                }
                drawPath(p, color, style = stroke)
            }
            "bag" -> {
                drawRoundRect(color, topLeft = Offset(w * .22f, h * .32f), size = androidx.compose.ui.geometry.Size(w * .56f, h * .48f), style = stroke, cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * .08f))
                line(.38f, .32f, .38f, .24f); line(.62f, .32f, .62f, .24f); line(.38f, .24f, .62f, .24f)
            }
            "drop" -> {
                val p = Path().apply {
                    moveTo(w * .50f, h * .16f)
                    cubicTo(w * .24f, h * .46f, w * .24f, h * .72f, w * .50f, h * .82f)
                    cubicTo(w * .76f, h * .72f, w * .76f, h * .46f, w * .50f, h * .16f)
                }
                drawPath(p, color, style = stroke)
            }
            "bottle" -> {
                drawRoundRect(color, topLeft = Offset(w * .34f, h * .30f), size = androidx.compose.ui.geometry.Size(w * .32f, h * .50f), style = stroke, cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * .08f))
                line(.40f, .30f, .40f, .18f); line(.60f, .30f, .60f, .18f); line(.40f, .18f, .60f, .18f)
            }
            "u" -> {
                line(.30f, .22f, .30f, .62f)
                val p = Path().apply {
                    moveTo(w * .30f, h * .62f)
                    cubicTo(w * .30f, h * .84f, w * .70f, h * .84f, w * .70f, h * .62f)
                    lineTo(w * .70f, h * .22f)
                }
                drawPath(p, color, style = stroke)
            }
            else -> {
                line(.50f, .16f, .50f, .84f)
                line(.16f, .50f, .84f, .50f)
            }
        }
    }
}

@Composable
fun StatusPill(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    filled: Boolean = false
) {
    Text(
        text = text,
        color = color,
        fontSize = 13.sp,
        fontWeight = FontWeight.Bold,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (filled) color.copy(alpha = .13f) else Color.White.copy(alpha = .9f))
            .border(1.dp, color.copy(alpha = .25f), RoundedCornerShape(8.dp))
            .padding(horizontal = 10.dp, vertical = 5.dp)
    )
}

@Composable
fun PrimaryGradientButton(
    text: String,
    modifier: Modifier = Modifier,
    icon: String? = null,
    enabled: Boolean = true,
    onClick: () -> Unit = {}
) {
    val brush = if (enabled) {
        Brush.linearGradient(listOf(ShuiColors.PrimaryLight, ShuiColors.Primary, ShuiColors.PrimaryDark))
    } else {
        Brush.linearGradient(listOf(Color(0xFFE8E4E8), Color(0xFFD8D4D8)))
    }
    Row(
        modifier = modifier
            .height(48.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(brush)
            .shuiPressable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        if (icon != null) {
            Text(icon, color = if (enabled) Color.White else ShuiColors.Brown, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(5.dp))
        }
        Text(
            text = text,
            color = if (enabled) Color.White else ShuiColors.DeepText,
            fontWeight = FontWeight.Bold,
            fontSize = 14.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
fun OptionCard(
    title: String,
    subtitle: String? = null,
    icon: String? = null,
    selected: Boolean,
    color: Color = ShuiColors.Primary,
    iconColor: Color = color,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .height(if (subtitle == null) 48.dp else 86.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) color.copy(alpha = .06f) else Color.White.copy(alpha = .62f))
            .border(1.3.dp, if (selected) color else ShuiColors.CardBorder.copy(alpha = .55f), RoundedCornerShape(12.dp))
            .padding(6.dp),
        contentAlignment = Alignment.Center
    ) {
        if (subtitle == null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                if (icon != null) {
                    OptionIcon(icon, iconColor, Modifier.size(22.dp))
                    Spacer(Modifier.width(5.dp))
                }
                Text(title, color = if (selected) color else ShuiColors.DeepText, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            }
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (icon != null) {
                    OptionIcon(icon, iconColor, Modifier.size(31.dp))
                    Spacer(Modifier.height(2.dp))
                }
                Text(title, color = if (selected) color else ShuiColors.DeepText, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                Spacer(Modifier.height(3.dp))
                Text(subtitle, color = if (selected) color else ShuiColors.MutedText, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }
        if (selected && subtitle != null) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(20.dp)
                    .clip(RoundedCornerShape(topStart = 14.dp))
                    .background(color),
                contentAlignment = Alignment.Center
            ) {
                Text("✓", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun OptionIcon(name: String, color: Color, modifier: Modifier = Modifier) {
    when (name) {
        "strong" -> DecorativeImage(R.drawable.shui_qiang, modifier)
        "shirt" -> DecorativeImage(R.drawable.shui_mid, modifier)
        "bolt" -> DecorativeImage(R.drawable.shui_fast, modifier)
        "spiral" -> DecorativeImage(R.drawable.shui_tuoshui, modifier)
        "temp_normal" -> DecorativeImage(R.drawable.shui_changwen, modifier)
        "temp_30" -> DecorativeImage(R.drawable.shui_30, modifier)
        "temp_40" -> DecorativeImage(R.drawable.shui_40, modifier)
        "temp_60" -> DecorativeImage(R.drawable.shui_60, modifier)
        "no_bottle" -> DecorativeImage(R.drawable.shui_ye_no, modifier)
        "bottle" -> DecorativeImage(R.drawable.shui_ye_low, modifier)
        "bottles" -> DecorativeImage(R.drawable.shui_ye_high, modifier)
        "no_shield" -> DecorativeImage(R.drawable.shui_chu_no, modifier)
        "shield" -> DecorativeImage(R.drawable.shui_chu_low, modifier)
        "shields" -> DecorativeImage(R.drawable.shui_chu_high, modifier)
        "drop" -> ShuiLineIcon(name, color, modifier)
        "shield_line", "shields_line" -> Canvas(modifier) {
            val w = size.width
            val h = size.height
            val stroke = Stroke(width = (w * .10f).coerceAtLeast(2.4f), cap = StrokeCap.Round, join = StrokeJoin.Round)
            fun shieldPath(xOffset: Float, scale: Float): Path = Path().apply {
                moveTo(w * (xOffset + .18f * scale), h * .22f)
                lineTo(w * (xOffset + .50f * scale), h * .12f)
                lineTo(w * (xOffset + .82f * scale), h * .22f)
                lineTo(w * (xOffset + .76f * scale), h * .58f)
                cubicTo(w * (xOffset + .68f * scale), h * .78f, w * (xOffset + .50f * scale), h * .88f, w * (xOffset + .50f * scale), h * .88f)
                cubicTo(w * (xOffset + .50f * scale), h * .88f, w * (xOffset + .32f * scale), h * .78f, w * (xOffset + .24f * scale), h * .58f)
                close()
            }
            if (name == "shields_line") {
                drawPath(shieldPath(.00f, .52f), color, style = stroke)
                drawPath(shieldPath(.45f, .52f), color, style = stroke)
            } else {
                drawPath(shieldPath(0f, 1f), color, style = stroke)
            }
        }
        "none" -> Canvas(modifier) {
            val strokeWidth = (size.width * .11f).coerceAtLeast(2.4f)
            drawCircle(color, radius = size.width * .28f, center = Offset(size.width / 2f, size.height / 2f), style = Stroke(strokeWidth, cap = StrokeCap.Round))
            drawLine(color, Offset(size.width * .32f, size.height * .68f), Offset(size.width * .68f, size.height * .32f), strokeWidth, StrokeCap.Round)
        }
        else -> Text(name, color = color, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun DecorativeImage(
    @DrawableRes resId: Int,
    modifier: Modifier = Modifier,
    alpha: Float = 1f,
    contentScale: ContentScale = ContentScale.Fit
) {
    Image(
        painter = painterResource(resId),
        contentDescription = null,
        contentScale = contentScale,
        modifier = modifier.alpha(alpha)
    )
}

@Composable
fun OrderListItem(order: OrderUi, onClick: () -> Unit) {
    SectionCard(contentPadding = PaddingValues(14.dp), modifier = Modifier.shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onClick)) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(order.icon, color = order.color, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(8.dp))
                Text(order.type, color = ShuiColors.DeepText, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                val statusColor = when (order.status) {
                    "使用中" -> ShuiColors.Blue
                    "已取消" -> ShuiColors.MutedText
                    else -> ShuiColors.Green
                }
                StatusPill(order.status, statusColor, filled = true)
            }
            Spacer(Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(order.time, color = ShuiColors.DeepText, fontSize = 14.sp)
                Spacer(Modifier.width(24.dp))
                Text(order.device, color = ShuiColors.DeepText, fontSize = 14.sp)
                Spacer(Modifier.weight(1f))
                Text(order.amount, color = ShuiColors.DeepText, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(16.dp))
                Text("›", color = ShuiColors.Primary, fontSize = 24.sp)
            }
        }
    }
}

@Composable
fun DeviceListItem(device: DeviceUi, onMenu: () -> Unit, onOpen: () -> Unit) {
    SectionCard(modifier = Modifier.shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onOpen), contentPadding = PaddingValues(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DecorativeImage(device.imageRes, Modifier.size(58.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(device.name, color = ShuiColors.DeepText, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(5.dp))
                Text(
                    "设备号：${device.id}",
                    color = ShuiColors.DeepText,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(5.dp))
                Text(device.type, color = ShuiColors.DeepText, fontSize = 12.sp)
            }
            Column(horizontalAlignment = Alignment.End) {
                StatusPill(device.status, device.statusColor, filled = true)
                Spacer(Modifier.height(18.dp))
                Box(
                    Modifier
                        .size(18.dp)
                        .clip(CircleShape)
                        .border(1.2.dp, ShuiColors.Primary, CircleShape)
                        .shuiPressable(onClick = onMenu)
                )
            }
        }
    }
}

@Composable
fun AccountCard(
    title: String,
    accent: Color,
    @DrawableRes titleIcon: Int,
    @DrawableRes logoRes: Int,
    @DrawableRes serviceIcon: Int,
    @DrawableRes resetIcon: Int,
    @DrawableRes unsetIcon: Int,
    @DrawableRes statusIcon: Int,
    loginHint: String,
    serviceText: String,
    modifier: Modifier = Modifier,
    statusTitle: String = "未登录",
    statusSubtitle: String = loginHint,
    middleActionText: String = "绑定设备码",
    onOpen: () -> Unit = {}
) {
    SectionCard(
        modifier = modifier.shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onOpen),
        borderColor = accent.copy(alpha = .28f),
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 8.dp)
    ) {
        Column {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                DecorativeImage(titleIcon, Modifier.size(if (title.contains("U净")) 24.dp else 26.dp))
                Spacer(Modifier.width(8.dp))
                Text(title, color = ShuiColors.DeepText, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                Text("  ✦", color = accent.copy(alpha = .35f), fontSize = 16.sp)
                Spacer(Modifier.weight(1f))
                Box(Modifier.width(82.dp).height(1.dp).background(accent.copy(alpha = .16f)))
            }
            Spacer(Modifier.height(6.dp))
            SectionCard(borderColor = accent.copy(alpha = .18f), contentPadding = PaddingValues(8.dp)) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        DecorativeImage(logoRes, Modifier.size(42.dp))
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(statusTitle, color = ShuiColors.DeepText, fontSize = 18.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(statusSubtitle, color = ShuiColors.Brown, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        AccountLoginButton(accent, Modifier.width(82.dp).height(34.dp))
                    }
                    Spacer(Modifier.height(7.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White.copy(alpha = .75f))
                            .border(1.dp, accent.copy(alpha = .18f), RoundedCornerShape(12.dp))
                            .padding(horizontal = 9.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        DecorativeImage(serviceIcon, Modifier.size(24.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(serviceText, color = ShuiColors.DeepText, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.weight(1f))
                        Text("›", color = ShuiColors.MutedText, fontSize = 20.sp)
                    }
                    Spacer(Modifier.height(6.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .dashedBorder(accent.copy(alpha = .42f), 12.dp)
                            .padding(vertical = 5.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        SmallAction(resetIcon, "重新登录")
                        SmallDivider(accent)
                        SmallAction(unsetIcon, middleActionText)
                        SmallDivider(accent)
                        SmallAction(statusIcon, "查看状态")
                    }
                }
            }
        }
    }
}

@Composable
private fun AccountLoginButton(accent: Color, modifier: Modifier) {
    val endColor = if (accent == ShuiColors.Blue) Color(0xFF4388E8) else ShuiColors.PrimaryDark
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Brush.linearGradient(listOf(accent.copy(alpha = .86f), endColor)))
            .border(1.dp, Color.White.copy(alpha = .42f), RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center
    ) {
        Text("点击登录", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1)
    }
}

@Composable
private fun SmallDivider(color: Color) {
    Box(Modifier.width(1.dp).height(28.dp).background(color.copy(alpha = .14f)))
}

@Composable
private fun SmallAction(@DrawableRes icon: Int, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        DecorativeImage(icon, Modifier.size(19.dp), alpha = .82f)
        Spacer(Modifier.height(2.dp))
        Text(label, color = ShuiColors.Brown, fontSize = 10.sp)
    }
}

@Composable
fun MoreOptionsCard(onLegacyHotwater: () -> Unit = {}) {
    val rows = listOf(
        R.drawable.shui_red_1 to "权限检测",
        R.drawable.shui_red_2 to "日志与诊断",
        R.drawable.shui_red_3 to "导入/导出洗衣机设备列表",
        R.drawable.shui_red_4 to "清除缓存   12.6 MB",
        R.drawable.shui_red_5 to "关于"
    )
    SectionCard(contentPadding = PaddingValues(horizontal = 10.dp, vertical = 8.dp)) {
        Column {
            SectionTitle(icon = "▣", title = "更多选项")
            Spacer(Modifier.height(6.dp))
            rows.forEachIndexed { index, item ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = index == rows.lastIndex, onClick = onLegacyHotwater)
                        .padding(vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    DecorativeImage(item.first, Modifier.size(22.dp))
                    Spacer(Modifier.width(12.dp))
                    Text(item.second, color = ShuiColors.DeepText, fontSize = 14.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("›", color = ShuiColors.MutedText, fontSize = 21.sp)
                }
                if (index != rows.lastIndex) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(ShuiColors.CardBorder.copy(alpha = .35f))
                    )
                }
            }
        }
    }
}

@Composable
fun WasherInfoCard() {
    SectionCard(contentPadding = PaddingValues(horizontal = 14.dp, vertical = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DecorativeImage(R.drawable.washer_machine, Modifier.size(74.dp))
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("3号洗衣机", color = ShuiColors.DeepText, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.width(8.dp))
                    StatusPill("空闲中", ShuiColors.Green, filled = true)
                }
                Spacer(Modifier.height(8.dp))
                Text("设备号： WASH-003", color = ShuiColors.Brown, fontSize = 15.sp)
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    LocationPin(ShuiColors.PrimaryLight, Modifier.size(17.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("芙兰公寓 2楼 洗衣房A区", color = ShuiColors.Brown, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Box(Modifier.size(76.dp), contentAlignment = Alignment.Center) {
                Canvas(
                    Modifier
                        .align(Alignment.BottomCenter)
                        .width(58.dp)
                        .height(16.dp)
                ) {
                    drawOval(
                        color = ShuiColors.Primary.copy(alpha = .12f),
                        topLeft = Offset(size.width * .10f, size.height * .20f),
                        size = androidx.compose.ui.geometry.Size(size.width * .80f, size.height * .48f)
                    )
                }
                DecorativeImage(R.drawable.wing_decoration, Modifier.size(72.dp))
            }
        }
    }
}

@Composable
private fun LocationPin(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val path = Path().apply {
            moveTo(w * .50f, h * .94f)
            cubicTo(w * .20f, h * .58f, w * .18f, h * .36f, w * .28f, h * .22f)
            cubicTo(w * .40f, h * .06f, w * .60f, h * .06f, w * .72f, h * .22f)
            cubicTo(w * .82f, h * .36f, w * .80f, h * .58f, w * .50f, h * .94f)
            close()
        }
        drawPath(path, color)
        drawCircle(Color.White.copy(alpha = .86f), radius = w * .13f, center = Offset(w * .50f, h * .38f))
    }
}

@Composable
fun AddWasherDialog(onDismiss: () -> Unit, onScan: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
                .background(Color.Black.copy(alpha = .42f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        SectionCard(
            modifier = Modifier
                .padding(horizontal = 34.dp)
                .clickable(enabled = false) {},
            contentPadding = PaddingValues(18.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Spacer(Modifier.weight(1f))
                    Text("添加洗衣机", color = ShuiColors.DeepText, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.weight(1f))
                    Text("×", color = ShuiColors.PrimaryLight, fontSize = 22.sp, modifier = Modifier.clickable(onClick = onDismiss))
                }
                Spacer(Modifier.height(14.dp))
                Text(
                    text = "扫描设备二维码后，\n可在此列表中直接查看状态并预约",
                    color = ShuiColors.DeepText,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                    lineHeight = 22.sp
                )
                Spacer(Modifier.height(20.dp))
                PrimaryGradientButton("开始扫码", Modifier.fillMaxWidth(), icon = "⌗", onClick = onScan)
                Spacer(Modifier.height(10.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(45.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White.copy(alpha = .75f))
                        .border(1.dp, ShuiColors.CardBorder, RoundedCornerShape(12.dp))
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center
                ) {
                    Text("取消", color = ShuiColors.Primary, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }
            }
        }
    }
}

@Composable
fun DeviceActionPopup(
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    Box(
        Modifier
            .fillMaxSize()
                .background(Color.Black.copy(alpha = .50f))
            .clickable(onClick = onDismiss)
    ) {
        Column(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 42.dp)
                .width(150.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(ShuiColors.SoftPink)
                .border(1.dp, ShuiColors.CardBorder, RoundedCornerShape(10.dp))
        ) {
            PopupAction("✎", "编辑名称", onEdit)
            Box(Modifier.fillMaxWidth().height(1.dp).background(ShuiColors.CardBorder.copy(alpha = .45f)))
            PopupAction("⌫", "删除设备", onDelete)
        }
    }
}

@Composable
private fun PopupAction(icon: String, text: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(icon, color = ShuiColors.Primary, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.width(14.dp))
        Text(text, color = ShuiColors.DeepText, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun CenteredPreviewBox(content: @Composable () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        AdaptivePhoneContainer { content() }
    }
}
