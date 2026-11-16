import 'package:flutter/material.dart';

/// 「移除本机记录」确认框。只影响本 App 的记录，不会向服务端或设备发送指令。
Future<bool> confirmRemoveLocalRecord(BuildContext context,
    {required String detail}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('移除本机订单记录？'),
      content: Text(detail),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除')),
      ],
    ),
  );
  return confirmed == true;
}
