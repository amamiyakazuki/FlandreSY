// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Home tab actions (Module A). Mixin on ShuiRuntimeBase; behavior unchanged by the runtime split.

import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin HomeActions on ShuiRuntimeBase {
  void openWasherSummary() {
    emit(
      state.copyWith(
        washerScan: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '已进入洗衣设备入口，请在设备页点选洗衣机下单',
        ),
      ),
    );
    _clearHomeBannerLater();
  }

  void switchBathSystem() {
    final next = state.bathSystemPreference == BathSystemPreference.zhuli
        ? BathSystemPreference.shower798
        : BathSystemPreference.zhuli;
    emit(state.copyWith(bathSystemPreference: next));
    // 持久化偏好（P1）：通过注入的 repository 落盘，runtime 不直接碰 IO。
    settings.saveBathSystem(next);
  }

  /// 切换「使用模拟后端」（Phase 0）。emit 新值让开关即时反映 + 持久化。
  /// adapter 在启动时一次性构造，故实际生效需重启（UI 侧提示「重启后生效」）。
  void setUseSimulatedBackend(bool useSimulated) {
    emit(state.copyWith(useSimulatedBackend: useSimulated));
    settings.saveUseSimulatedBackend(useSimulated);
  }

  void _clearHomeBannerLater() {
    scheduleHomeBannerClear(() {
      emit(
        state.copyWith(
          waterScan: const RuntimeActionStatus(
            state: RuntimeTaskState.idle,
            message: '扫描饮水机或洗衣机二维码',
          ),
          washerScan: const RuntimeActionStatus(),
        ),
      );
    });
  }
}
