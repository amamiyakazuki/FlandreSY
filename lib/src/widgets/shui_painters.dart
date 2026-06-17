// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors line/icon palette, AppCustomTokens stroke/spacing/header wave sizing.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';

class DashedRule extends StatelessWidget {
  const DashedRule({this.color = AppColors.cardBorder, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRulePainter(color),
      child: const SizedBox(
        height: AppCustomTokens.spaceXs,
        width: double.infinity,
      ),
    );
  }
}

class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    required this.child,
    this.color = AppColors.primaryLight,
    this.radius = AppCustomTokens.radiusMedium,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppCustomTokens.spaceMd,
      vertical: AppCustomTokens.spaceSm,
    ),
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(color, radius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
            rect.deflate(AppCustomTokens.strokeThin), Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppCustomTokens.strokeMedium
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final extract = metric.extractPath(
          distance,
          (distance + AppCustomTokens.spaceSm).clamp(0, metric.length),
        );
        canvas.drawPath(extract, paint);
        distance += AppCustomTokens.spaceMd;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: AppCustomTokens.alphaMuted)
      ..strokeWidth = AppCustomTokens.strokeThin;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + AppCustomTokens.spaceSm, size.height / 2),
        paint,
      );
      x += AppCustomTokens.spaceMd;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRulePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class ShuiLineIcon extends StatelessWidget {
  const ShuiLineIcon({
    required this.name,
    required this.color,
    this.size = AppCustomTokens.navIconSize,
    super.key,
  });

  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShuiLineIconPainter(name, color),
      size: Size.square(size),
    );
  }
}

class _ShuiLineIconPainter extends CustomPainter {
  const _ShuiLineIconPainter(this.name, this.color);

  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..strokeWidth = (w * AppCustomTokens.alphaLow).clamp(3.0, 6.0).toDouble()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void line(double x1, double y1, double x2, double y2) {
      canvas.drawLine(Offset(w * x1, h * y1), Offset(w * x2, h * y2), paint);
    }

    switch (name) {
      case 'home':
        final roof = Path()
          ..moveTo(w * 0.18, h * 0.52)
          ..lineTo(w * 0.50, h * 0.22)
          ..lineTo(w * 0.82, h * 0.52);
        canvas.drawPath(roof, paint);
        final body = Path()
          ..moveTo(w * 0.26, h * 0.48)
          ..lineTo(w * 0.26, h * 0.82)
          ..lineTo(w * 0.74, h * 0.82)
          ..lineTo(w * 0.74, h * 0.48);
        canvas.drawPath(body, paint);
        break;
      case 'orders':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.25, h * 0.18, w * 0.50, h * 0.64),
            Radius.circular(w * 0.08),
          ),
          paint,
        );
        line(0.36, 0.35, 0.64, 0.35);
        line(0.36, 0.50, 0.64, 0.50);
        line(0.36, 0.65, 0.56, 0.65);
        break;
      case 'washer':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.23, h * 0.16, w * 0.54, h * 0.68),
            Radius.circular(w * 0.08),
          ),
          paint,
        );
        canvas.drawCircle(Offset(w * 0.50, h * 0.56), w * 0.16, paint);
        line(0.34, 0.28, 0.66, 0.28);
        break;
      case 'profile':
        canvas.drawCircle(Offset(w * 0.50, h * 0.34), w * 0.15, paint);
        final path = Path()
          ..moveTo(w * 0.24, h * 0.82)
          ..cubicTo(w * 0.30, h * 0.60, w * 0.70, h * 0.60, w * 0.76, h * 0.82);
        canvas.drawPath(path, paint);
        break;
      case 'hot':
        line(0.22, 0.78, 0.78, 0.78);
        line(0.30, 0.30, 0.30, 0.62);
        line(0.50, 0.22, 0.50, 0.62);
        line(0.70, 0.30, 0.70, 0.62);
        break;
      case 'scan':
        line(0.18, 0.38, 0.18, 0.18);
        line(0.18, 0.18, 0.38, 0.18);
        line(0.62, 0.18, 0.82, 0.18);
        line(0.82, 0.18, 0.82, 0.38);
        line(0.82, 0.62, 0.82, 0.82);
        line(0.82, 0.82, 0.62, 0.82);
        line(0.38, 0.82, 0.18, 0.82);
        line(0.18, 0.82, 0.18, 0.62);
        break;
      default:
        line(0.50, 0.16, 0.50, 0.84);
        line(0.16, 0.50, 0.84, 0.50);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ShuiLineIconPainter oldDelegate) {
    return oldDelegate.name != name || oldDelegate.color != color;
  }
}

class HeaderWave extends StatelessWidget {
  const HeaderWave({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _HeaderWavePainter(),
      child: SizedBox(
        height: AppCustomTokens.headerWaveHeight,
        width: double.infinity,
      ),
    );
  }
}

class _HeaderWavePainter extends CustomPainter {
  const _HeaderWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.25)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.95,
        size.width * 0.65,
        size.height * 0.85,
        size.width,
        size.height * 0.2,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.background);
    canvas.drawPath(
      path,
      Paint()
        ..color =
            AppColors.onPrimary.withValues(alpha: AppCustomTokens.alphaAccent),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
