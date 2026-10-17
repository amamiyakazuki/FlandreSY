import 'package:flutter/material.dart';

import '../../design_tokens.dart';

/// 仅压缩展示，不修改服务端状态或据此推导设备是否可操作。
String compactDeviceStatus(String? status) {
  final text = status?.trim() ?? '';
  return switch (text) {
    '' => '状态未知',
    '此设备正在运行中，请使用其他设备' || '此设备正在运行中，请使用其他设备。' => '运行中',
    _ => text.runes.length <= 6 && !text.contains('\n') ? text : '查看状态',
  };
}

/// 状态独占一行，原文放入可滚动详情，避免长句挤占名称或撑高卡片。
class DeviceStatusLabel extends StatelessWidget {
  const DeviceStatusLabel({
    required this.label,
    required this.details,
    required this.color,
    super.key,
  });

  final String label;
  final String details;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '查看设备状态详情',
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('设备状态详情'),
              scrollable: true,
              content: SelectableText(details),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: AppCustomTokens.spaceXs),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: color),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: color),
              ],
            ),
          ),
        ),
      );
}
