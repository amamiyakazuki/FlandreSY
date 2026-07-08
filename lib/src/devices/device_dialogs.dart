// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/stroke/dialog sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.6；legacy ShuiComponents.kt AddWasherDialog/DeviceActionPopup, ShuiScreens.kt PresetWasherDeviceDialog/EditDeviceNameDialog.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/preset_washers.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';

/// 半透明遮罩 + 居中卡片的通用对话框骨架。点击遮罩关闭，点击卡片不冒泡。
class _DialogScaffold extends StatelessWidget {
  const _DialogScaffold({
    required this.onDismiss,
    required this.child,
    this.horizontalMargin = AppCustomTokens.dialogMarginWide,
    this.overlayAlpha = AppCustomTokens.alphaPopup,
  });

  final VoidCallback onDismiss;
  final Widget child;
  final double horizontalMargin;
  final double overlayAlpha;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ColoredBox(
        color: AppColors.scrim.withValues(alpha: overlayAlpha),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: SectionCard(
                padding: const EdgeInsets.all(AppCustomTokens.spaceContent),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogTitleRow extends StatelessWidget {
  const _DialogTitleRow({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Text(
          title,
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: AppColors.deepText,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: ShuiPressable(
              onTap: onClose,
              child: Text(
                '×',
                style: AppTypography.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 添加设备对话框。对齐 legacy `AddWasherDialog`：开始扫码 / 选择海七已有设备 / 取消。
class AddDeviceDialog extends StatelessWidget {
  const AddDeviceDialog({
    required this.onDismiss,
    required this.onScan,
    required this.onPreset,
    super.key,
  });

  final VoidCallback onDismiss;
  final VoidCallback onScan;
  final VoidCallback onPreset;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return _DialogScaffold(
      onDismiss: onDismiss,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogTitleRow(title: '添加洗衣机', onClose: onDismiss),
          const SizedBox(height: AppCustomTokens.spaceMd),
          Text(
            '扫描设备二维码后，\n可在此列表中直接查看状态并预约',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceLg),
          PrimaryGradientButton(
            label: '开始扫码',
            icon: Icons.qr_code_scanner,
            onTap: onScan,
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          _OutlineDialogButton(
            key: const ValueKey('add-dialog-preset'),
            label: '选择海七已有设备',
            color: AppColors.primary,
            onTap: onPreset,
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          _OutlineDialogButton(
            label: '取消',
            color: AppColors.primary,
            borderColor: AppColors.cardBorder,
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _OutlineDialogButton extends StatelessWidget {
  const _OutlineDialogButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.borderColor,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ShuiPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: AppCustomTokens.primaryActionHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: AppCustomTokens.alphaHigh),
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          border: Border.all(
            color: borderColor ??
                color.withValues(alpha: AppCustomTokens.alphaAccent),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}

/// 海七预设设备选择对话框。对齐 legacy `PresetWasherDeviceDialog`：3 列 grid 卡片。
class PresetDeviceDialog extends StatelessWidget {
  const PresetDeviceDialog({
    required this.onDismiss,
    required this.onSelect,
    super.key,
  });

  final VoidCallback onDismiss;
  final ValueChanged<PresetWasherDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return _DialogScaffold(
      onDismiss: onDismiss,
      horizontalMargin: AppCustomTokens.spaceMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogTitleRow(title: '选择海七已有设备', onClose: onDismiss),
          const SizedBox(height: AppCustomTokens.spaceMd),
          SizedBox(
            height: AppCustomTokens.presetGridHeight,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppCustomTokens.spaceSm,
                crossAxisSpacing: AppCustomTokens.spaceSm,
                mainAxisExtent: AppCustomTokens.presetCellHeight,
              ),
              itemCount: haiqiPresetWashers.length,
              itemBuilder: (context, index) {
                final device = haiqiPresetWashers[index];
                return ShuiPressable(
                  soft: true,
                  onTap: () => onSelect(device),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AppCustomTokens.spaceXs),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(
                        alpha: AppCustomTokens.alphaStrong,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppCustomTokens.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: AppCustomTokens.strokeThin,
                      ),
                    ),
                    child: Text(
                      device.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.deepText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Text(
            '只保存到本地列表，不会绑定到官方账号',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

/// 设备操作弹层。对齐 legacy `DeviceActionPopup`：右对齐 SoftPink 卡，编辑名称 / 删除设备。
class DeviceActionPopup extends StatelessWidget {
  const DeviceActionPopup({
    required this.onDismiss,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final VoidCallback onDismiss;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ColoredBox(
        color: AppColors.scrim.withValues(alpha: AppCustomTokens.alphaPopup),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(
              right: AppCustomTokens.devicePopupEndPadding,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                width: AppCustomTokens.devicePopupWidth,
                decoration: BoxDecoration(
                  color: AppColors.softPink,
                  borderRadius: BorderRadius.circular(
                    AppCustomTokens.radiusCompact,
                  ),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: AppCustomTokens.strokeThin,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PopupAction(icon: '✎', label: '编辑名称', onTap: onEdit),
                    Container(
                      height: AppCustomTokens.strokeThin,
                      color: AppColors.cardBorder.withValues(
                        alpha: AppCustomTokens.alphaOverlay,
                      ),
                    ),
                    _PopupAction(icon: '⌫', label: '删除设备', onTap: onDelete),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupAction extends StatelessWidget {
  const _PopupAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return ShuiPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceContent,
          vertical: AppCustomTokens.spaceMd - AppCustomTokens.strokeThin,
        ),
        child: Row(
          children: [
            Text(
              icon,
              style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: AppCustomTokens.spaceMd),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
            ),
          ],
        ),
      ),
    );
  }
}

/// 编辑设备名称对话框。对齐 legacy `EditDeviceNameDialog`：输入框 + 取消/保存。
class EditDeviceNameDialog extends StatefulWidget {
  const EditDeviceNameDialog({
    required this.initialName,
    required this.onDismiss,
    required this.onSave,
    super.key,
  });

  final String initialName;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSave;

  @override
  State<EditDeviceNameDialog> createState() => _EditDeviceNameDialogState();
}

class _EditDeviceNameDialogState extends State<EditDeviceNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return _DialogScaffold(
      onDismiss: widget.onDismiss,
      overlayAlpha: AppCustomTokens.alphaOverlay + AppCustomTokens.alphaVeryLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '编辑名称',
            style: textTheme.titleLarge?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceMd),
          TextField(
            controller: _controller,
            maxLines: 1,
            style: textTheme.bodyLarge?.copyWith(color: AppColors.deepText),
            decoration: const InputDecoration(labelText: '洗衣机名称'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppCustomTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: _OutlineDialogButton(
                  label: '取消',
                  color: AppColors.primary,
                  borderColor: AppColors.cardBorder,
                  onTap: widget.onDismiss,
                ),
              ),
              const SizedBox(width: AppCustomTokens.spaceSm),
              Expanded(
                child: PrimaryGradientButton(
                  label: '保存',
                  enabled: _controller.text.trim().isNotEmpty,
                  onTap: () => widget.onSave(_controller.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
