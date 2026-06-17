// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used indirectly by UI consumers; this file centralizes legacy asset reuse.

class ShuiAssets {
  static const String _drawable = 'assets/legacy/images';

  static String png(String name) => '$_drawable/$name';

  static final homeTopCharacter = png('home_top_character.png');
  static final hotWaterCharacter = png('hot_water_character.png');
  static final scan = png('scan.png');
  static final scanCharacter = png('scan_character_v2.png');
  static final washerCharacter = png('washer_character.png');
  static final washerMachine = png('washer_machine.png');
  static final sleep = png('sleep.png');
  static final shuiFire = png('shui_fire.png');
  static final shuiReshui = png('shui_reshui.png');
  static final shuiJieshui = png('shui_jieshui.png');
  static final shuiYifu = png('shui_yifu.png');
  static final shuiScancode = png('shui_scancode.png');
  static final shuiBianfu = png('shui_bianfu.png');
  static final shuiHeart = png('shui_heart.png');
  static final shuiCloud = png('shui_cloud.png');
  static final shuiThreeStar = png('shui_3star.png');
}
