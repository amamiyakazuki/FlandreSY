// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors (primary/cardBorder/deepText/mutedText), AppTypography.textTheme,
// AppCustomTokens radius/space/alpha. Token-ized OutlinedTextField wrapper for forms.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';

/// 统一令牌化文本框（P2）。label/hint/text 走 textTheme，圆角/描边走 token，
/// 避免每个表单各自硬编码 InputDecoration。
class ShuiTextField extends StatelessWidget {
  const ShuiTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
      borderSide: BorderSide(
        color: AppColors.cardBorder
            .withValues(alpha: AppCustomTokens.alphaSoftBorder),
        width: AppCustomTokens.strokeThin,
      ),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceMd,
          vertical: AppCustomTokens.spaceSm + AppCustomTokens.spaceXs,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppCustomTokens.strokeMedium,
          ),
        ),
      ),
    );
  }
}
