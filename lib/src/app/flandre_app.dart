// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppTheme, AppColors.background, AppTypography.textTheme.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../shell/shui_shell.dart';

class FlandreApp extends StatelessWidget {
  const FlandreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '芙兰水衣',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: AppTypography.textTheme.apply(
          bodyColor: AppColors.deepText,
          displayColor: AppColors.deepText,
        ),
      ),
      home: const ShuiRuntimeScope(child: ShuiShell()),
    );
  }
}
