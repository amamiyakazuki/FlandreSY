import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../data/permission_service.dart';
import '../widgets/shui_header.dart';

/// 进入和返回前台只读检查；申请与打开设置必须由用户点选。
class PermissionCheckScreen extends StatefulWidget {
  const PermissionCheckScreen({this.permissions, super.key});
  final ShuiPermissionService? permissions;
  @override
  State<PermissionCheckScreen> createState() => _PermissionCheckScreenState();
}

class _PermissionCheckScreenState extends State<PermissionCheckScreen>
    with WidgetsBindingObserver {
  ShuiPermissionService get service =>
      widget.permissions ?? ShuiPermissionService.instance;
  ShuiPermissionState? _state;
  bool _busy = false;
  String? _message;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final revision = ++_revision;
    final state = await service.check();
    if (mounted && revision == _revision) setState(() => _state = state);
  }

  Future<void> _request(ShuiPermissionKind kind) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await service.request(kind);
    if (!mounted) return;
    setState(() {
      _message = result.message;
      _busy = false;
    });
    await _check();
  }

  Future<void> _settings() async {
    if (_busy) return;
    setState(() => _busy = true);
    final message = await service.openSettings();
    if (!mounted) return;
    setState(() {
      _message = message;
      _busy = false;
    });
    await _check();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(children: [
        TopHeader(
            title: '权限与功能',
            showBack: true,
            onBack: () => Navigator.of(context).pop()),
        Expanded(
            child: ListView(
                padding: const EdgeInsets.all(AppCustomTokens.spaceMd),
                children: [
              const Text('使用功能时才申请权限。授权状态与蓝牙开关、设备支持情况分别检查。'),
              if (_message != null)
                Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppCustomTokens.spaceSm),
                    child: Text(_message!)),
              for (final kind in ShuiPermissionKind.values)
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(AppCustomTokens.spaceMd),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            kind == ShuiPermissionKind.camera ? '扫码相机' : '住理蓝牙',
                            style: AppTypography.textTheme.titleMedium),
                        Text(_state?.status[kind]?.message ?? '正在检查权限'),
                        if (_state?.status[kind]?.canRequest == true)
                          TextButton(
                            onPressed: _busy ? null : () => _request(kind),
                            child: Text(kind == ShuiPermissionKind.camera
                                ? '申请相机权限'
                                : '申请蓝牙权限'),
                          ),
                        if (_state?.status[kind]?.status ==
                                ShuiPermissionStatus.permanentlyDenied ||
                            _state?.status[kind]?.status ==
                                ShuiPermissionStatus.restricted)
                          TextButton(
                              onPressed: _busy ? null : _settings,
                              child: const Text('打开系统设置')),
                      ]),
                )),
              TextButton(
                  onPressed: _busy ? null : _check,
                  child: const Text('重新检查权限')),
            ])),
      ]));
}
