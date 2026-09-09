// Design tokens used: AppCustomTokens pressScale/softPressScale/alphaPressed.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';

class ShuiMotion {
  static const quick = Duration(milliseconds: 120);
  static const press = Duration(milliseconds: 100);
  static const local = Duration(milliseconds: 190);
  static const normal = Duration(milliseconds: 220);
  static const route = Duration(milliseconds: 260);
  static const overlay = Duration(milliseconds: 220);
  static const opening = Duration(milliseconds: 620);
  static const easeOut = Cubic(0.18, 0.88, 0.26, 1);
  static const easeIn = Cubic(0.42, 0, 0.58, 1);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;
}

class ShuiPressable extends StatefulWidget {
  const ShuiPressable({
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.soft = false,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;
  final bool soft;

  @override
  State<ShuiPressable> createState() => _ShuiPressableState();
}

class _ShuiPressableState extends State<ShuiPressable> {
  bool pressed = false;
  bool focused = false;

  @override
  void didUpdateWidget(ShuiPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) pressed = false;
  }

  void setPressed(bool value) {
    if (pressed == value || (value && !widget.enabled)) {
      return;
    }
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = ShuiMotion.duration(
      context,
      widget.enabled ? ShuiMotion.press : Duration.zero,
    );
    final scale = pressed && !ShuiMotion.reduced(context)
        ? (widget.soft
            ? AppCustomTokens.softPressScale
            : AppCustomTokens.pressScale)
        : 1.0;
    return FocusableActionDetector(
      enabled: widget.enabled,
      mouseCursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => focused = value),
      onFocusChange: (value) {
        if (!value) setPressed(false);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          if (widget.enabled) widget.onTap();
          return null;
        }),
      },
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        child: DecoratedBox(
          decoration: BoxDecoration(
              border: focused
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2)
                  : null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.onTap : null,
            onTapDown: (_) => setPressed(true),
            onTapCancel: () => setPressed(false),
            onTapUp: (_) => setPressed(false),
            child: AnimatedScale(
              scale: scale,
              duration: duration,
              curve: ShuiMotion.easeOut,
              child: AnimatedOpacity(
                opacity: pressed ? AppCustomTokens.alphaPressed : 1,
                curve: ShuiMotion.easeOut,
                duration: duration,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
