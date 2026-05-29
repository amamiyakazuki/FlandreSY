package com.kazuki.zhulihotwater.ui

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale

object ShuiMotion {
    const val Quick = 120
    const val Normal = 220
    const val Route = 260
    const val Opening = 620
    const val PressedScale = 0.97f
    const val SoftPressedScale = 0.985f

    val EaseOut = CubicBezierEasing(0.18f, 0.88f, 0.26f, 1f)
    val EaseIn = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)
    val Springy = spring<Float>(
        dampingRatio = Spring.DampingRatioMediumBouncy,
        stiffness = Spring.StiffnessMediumLow
    )
}

fun <T> shuiTween(durationMillis: Int = ShuiMotion.Normal): FiniteAnimationSpec<T> {
    return tween(durationMillis = durationMillis, easing = ShuiMotion.EaseOut)
}

@Composable
fun Modifier.shuiPressable(
    enabled: Boolean = true,
    scale: Float = ShuiMotion.PressedScale,
    onClick: () -> Unit
): Modifier {
    if (!enabled) return this
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val animatedScale by animateFloatAsState(
        targetValue = if (pressed) scale else 1f,
        animationSpec = ShuiMotion.Springy,
        label = "shuiPressScale"
    )
    val animatedAlpha by animateFloatAsState(
        targetValue = if (pressed) 0.88f else 1f,
        animationSpec = tween(ShuiMotion.Quick),
        label = "shuiPressAlpha"
    )
    return this
        .scale(animatedScale)
        .alpha(animatedAlpha)
        .clickable(
            interactionSource = interactionSource,
            indication = null,
            enabled = true,
            onClick = onClick
        )
}

fun shuiDialogEnter(): EnterTransition {
    return fadeIn(tween(ShuiMotion.Normal, easing = ShuiMotion.EaseOut)) +
        scaleIn(tween(ShuiMotion.Normal, easing = ShuiMotion.EaseOut), initialScale = 0.94f)
}

fun shuiDialogExit(): ExitTransition {
    return fadeOut(tween(ShuiMotion.Quick, easing = ShuiMotion.EaseIn)) +
        scaleOut(tween(ShuiMotion.Quick, easing = ShuiMotion.EaseIn), targetScale = 0.96f)
}

fun shuiStatusEnter(): EnterTransition {
    return fadeIn(tween(ShuiMotion.Normal, easing = ShuiMotion.EaseOut)) +
        slideInVertically(tween(ShuiMotion.Normal, easing = ShuiMotion.EaseOut)) { -it / 4 }
}

fun shuiStatusExit(): ExitTransition {
    return fadeOut(tween(ShuiMotion.Quick, easing = ShuiMotion.EaseIn)) +
        slideOutVertically(tween(ShuiMotion.Quick, easing = ShuiMotion.EaseIn)) { -it / 5 }
}

fun <S> shuiPageTransform(scope: AnimatedContentTransitionScope<S>): ContentTransform {
    return with(scope) {
        val forward = targetState.hashCode() >= initialState.hashCode()
        val distance = if (forward) { width: Int -> width / 12 } else { width: Int -> -width / 12 }
        slideIntoContainer(
            AnimatedContentTransitionScope.SlideDirection.Left,
            animationSpec = tween(ShuiMotion.Route, easing = ShuiMotion.EaseOut),
            initialOffset = { distance(it) }
        ) + fadeIn(tween(ShuiMotion.Route, easing = ShuiMotion.EaseOut)) togetherWith
            slideOutOfContainer(
                AnimatedContentTransitionScope.SlideDirection.Left,
                animationSpec = tween(ShuiMotion.Route, easing = ShuiMotion.EaseIn),
                targetOffset = { -distance(it) }
            ) + fadeOut(tween(ShuiMotion.Quick, easing = ShuiMotion.EaseIn))
    }
}
