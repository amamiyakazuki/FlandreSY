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
    setBathSystem(next);
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
