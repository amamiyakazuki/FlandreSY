// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppCustomTokens pressScale/softPressScale/alphaPressed.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';

class ShuiMotion {
  static const quick = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const route = Duration(milliseconds: 260);
  static const opening = Duration(milliseconds: 620);
  static const easeOut = Cubic(0.18, 0.88, 0.26, 1);
  static const easeIn = Cubic(0.42, 0, 0.58, 1);
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

  void setPressed(bool value) {
    if (pressed == value || !widget.enabled) {
      return;
    }
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: (_) => setPressed(true),
      onTapCancel: () => setPressed(false),
      onTapUp: (_) => setPressed(false),
      child: AnimatedOpacity(
        opacity: pressed ? AppCustomTokens.alphaPressed : 1,
        curve: ShuiMotion.easeOut,
        duration: ShuiMotion.quick,
        child: widget.child,
      ),
    );
  }
}
