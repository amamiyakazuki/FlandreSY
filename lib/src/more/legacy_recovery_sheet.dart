import 'package:flutter/material.dart';
import '../runtime/shui_runtime.dart';

Future<void> showLegacyRecoverySheet(
        BuildContext context, ShuiRuntime runtime, VoidCallback onAccounts) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AnimatedBuilder(
        animation: runtime,
        builder: (context, _) {
          final migration = runtime.migration;
          return SafeArea(
              child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('旧数据保全',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(migration.failure ??
                        (runtime.recoveryWarnings.isNotEmpty
                            ? '部分旧数据无法读取，原件已保留。请重启后重试，不要清除应用数据。'
                            : '升级前的资料和历史已保留，来源尚未全部核对。各服务首次使用请重新登录；旧活动记录核对前不会用于控制设备，也不会自动删除。')),
                    const SizedBox(height: 12),
                    for (final service in const {
                      'ujing': 'U净',
                      'zhuli': '住理生活',
                      'shower798': '慧生活798'
                    }.entries)
                      if (migration.needsLogin(service.key))
                        Text('${service.value}：需要重新登录'),
                    const SizedBox(height: 12),
                    for (final entry in migration.records.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${_kind(entry.key)} · ${entry.key.substring(entry.key.indexOf(':') + 1)}'),
                        subtitle: Text(switch (entry.value['state']) {
                          'simulated' => '旧模拟记录已保留，不可操作',
                          'verified' => '身份与记录已核对',
                          _ => '待核对，原记录已保留',
                        }),
                      ),
                    if (migration.preservedHistory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('升级前记录快照（只读，来源未核对）'),
                      for (final record in migration.preservedHistory)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(record.title),
                            subtitle: Text(record.detail)),
                    ],
                    const Text('若无法核对，请在官方 App 检查实际订单及设备。旧版已经覆盖的数据无法保证找回。'),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, children: [
                      FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onAccounts();
                          },
                          child: const Text('前往账号中心')),
                      TextButton(
                          onPressed: runtime.retryLegacyRecovery,
                          child: const Text('重试保全与核对')),
                    ]),
                  ],
                )),
          ));
        },
      ),
    );

String _kind(String key) => switch (key.split(':').first) {
      'water' => '接水记录',
      'washer' => '洗衣记录',
      _ => '热水记录',
    };
