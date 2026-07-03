// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Pure routing model (no visual constants).

import 'shui_shell.dart';
import '../runtime/models/account_session.dart';

/// 轻量路由模型（Module B1）。对齐 legacy `ShuiRoute` sealed class，
/// 但本模块只落地当前需要的几种：Tab、空设备页、饮水页（B2 才填充内容）。
///
/// 设计目的：让 Shell 在「主 Tab」之外能 push 子页面并正确处理返回，
/// 而不引入重型路由库（保持 Module A 的 ChangeNotifier + AnimatedSwitcher 风格）。
sealed class ShuiRoute {
  const ShuiRoute();
}

/// 主 Tab 路由（Home / Orders / Devices / Profile）。
class TabRoute extends ShuiRoute {
  const TabRoute(this.tab);

  final MainTab tab;
}

/// 空设备引导页（从 Devices 列表为空或显式进入）。
class EmptyDevicesRoute extends ShuiRoute {
  const EmptyDevicesRoute();
}

/// 饮水接水页（B1 仅打通导航与返回；真实 ready/create/poll 在 B2 实现）。
class DrinkingWaterRoute extends ShuiRoute {
  const DrinkingWaterRoute(this.cd);

  final String cd;
}

/// 账号详情登录子页（P2）。归属 Profile tab。
class AccountDetailRoute extends ShuiRoute {
  const AccountDetailRoute(this.kind);

  final AccountKind kind;
}

/// 洗衣下单子页（W1）。归属 Devices tab。qr 用于 fake 扫码识别 program。
class WasherOrderRoute extends ShuiRoute {
  const WasherOrderRoute(this.qr);

  final String qr;
}

/// 热水详情子页（H1）。归属 Home tab。
class HotwaterDetailRoute extends ShuiRoute {
  const HotwaterDetailRoute();
}

/// 更多选项子页（M1）。归属 Profile tab。
class MoreOptionsRoute extends ShuiRoute {
  const MoreOptionsRoute();
}

/// 每个非 Tab 路由在底栏上「归属」哪个 Tab（用于高亮 + 返回落点）。
extension ShuiRouteParent on ShuiRoute {
  MainTab get parentTab {
    return switch (this) {
      TabRoute(:final tab) => tab,
      EmptyDevicesRoute() => MainTab.devices,
      DrinkingWaterRoute() => MainTab.devices,
      AccountDetailRoute() => MainTab.profile,
      WasherOrderRoute() => MainTab.devices,
      HotwaterDetailRoute() => MainTab.home,
      MoreOptionsRoute() => MainTab.profile,
    };
  }

  bool get isTab => this is TabRoute;
}
