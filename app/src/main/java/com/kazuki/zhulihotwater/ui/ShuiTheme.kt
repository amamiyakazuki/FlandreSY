package com.kazuki.zhulihotwater.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.kazuki.zhulihotwater.R

val ShuiFontFamily = FontFamily(Font(R.font.future_round_sc_regular))

object ShuiColors {
    val Background = Color(0xFFFFF8F8)
    val Primary = Color(0xFFEF4056)
    val PrimaryDark = Color(0xFFD92F4A)
    val PrimaryLight = Color(0xFFFF7B8A)
    val DeepText = Color(0xFF4A1D25)
    val MutedText = Color(0xFF8D6F75)
    val CardBorder = Color(0xFFFFC6CE)
    val WeakPink = Color(0xFFFFE8EC)
    val SoftPink = Color(0xFFFFF1F3)
    val Blue = Color(0xFF4D8DEB)
    val Orange = Color(0xFFFFA93A)
    val Green = Color(0xFF7DBF4C)
    val Brown = Color(0xFF7C4A50)
}

private val ShuiColorScheme = lightColorScheme(
    primary = ShuiColors.Primary,
    onPrimary = Color.White,
    secondary = ShuiColors.Blue,
    background = ShuiColors.Background,
    surface = ShuiColors.Background,
    onSurface = ShuiColors.DeepText,
    outline = ShuiColors.CardBorder,
    error = ShuiColors.PrimaryDark
)

@Composable
fun ShuiTheme(
    content: @Composable () -> Unit
) {
    val base = MaterialTheme.typography
    MaterialTheme(
        colorScheme = ShuiColorScheme,
        typography = base.copy(
            displayLarge = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Bold, fontSize = 34.sp),
            headlineLarge = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Bold, fontSize = 28.sp),
            headlineMedium = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Bold, fontSize = 23.sp),
            titleLarge = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Bold, fontSize = 20.sp),
            titleMedium = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Bold, fontSize = 17.sp),
            bodyLarge = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Normal, fontSize = 16.sp),
            bodyMedium = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Normal, fontSize = 14.sp),
            labelLarge = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Bold, fontSize = 15.sp),
            labelMedium = TextStyle(fontFamily = ShuiFontFamily, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        ),
        content = content
    )
}
