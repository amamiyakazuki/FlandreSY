import 'package:flutter/material.dart';

import '../data/device_import.dart';
import '../runtime/shui_runtime.dart';

/// 保留读到的剪贴板内容，保存失败可重试；列表改变则重新展示替换范围。
class DeviceImportDialog extends StatefulWidget {
  const DeviceImportDialog(
      {required this.runtime, required this.raw, super.key});
  final ShuiRuntime runtime;
  final String raw;
  @override
  State<DeviceImportDialog> createState() => _DeviceImportDialogState();
}

class _DeviceImportDialogState extends State<DeviceImportDialog> {
  DeviceImportPreview? _preview;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    try {
      _preview = widget.runtime.previewDeviceImport(widget.raw);
    } on FormatException catch (error) {
      _error = error.message;
    }
  }

  Future<void> _save() async {
    if (_busy || _preview == null) return;
    setState(() => _busy = true);
    final result = await widget.runtime.confirmDeviceImport(_preview!);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.message;
      _prepare();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('导入设备列表'),
          scrollable: true,
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_preview != null)
                  Text(
                      '用 ${_preview!.devices.length} 条设备替换当前 ${_preview!.previousCount} 条（包含隐藏的旧记录）。\n原列表将被替换，导入后状态需手动刷新。'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ]),
          actions: [
            TextButton(
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('取消')),
            if (_preview != null)
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? '保存中…' : '确认替换')),
          ],
        ),
      );
}
