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

  // Module B1 - Devices: empty state box + bottom character decoration.
  static final emptyBox = png('empty_box.png');
  static final orderBottomCharacter = png('order_bottom_character.png');

  // Module P1 - Profile: top character, account logos, status/check icons,
  // more-options icon, bottom decoration.
  static final profileTopCharacter = png('profile_top_character.png');
  static final profileBottom = png('shui_wode_bottom.png');
  static final shuiZhuli = png('shui_zhuli.png');
  static final shuiU = png('shui_u.png');
  static final shuiHuisheng798 = png('shui_huisheng_798_logo.png');
  static final shuiRed1 = png('shui_red_1.png');
  static final shuiRed2 = png('shui_red_2.png');
  static final shuiRed3 = png('shui_red_3.png');
  static final shuiRed4 = png('shui_red_4.png');
  static final shuiRed5 = png('shui_red_5.png');
  static final shuiRedCheck = png('shui_red_check.png');
  static final shuiBlueCheck = png('shui_blue_check.png');

  // Module W1 - Washer order option icons (套餐/温度/洗衣液/除菌液).
  static final washerModelStrong = png('shui_qiang.png');
  static final washerModelShirt = png('shui_mid.png');
  static final washerModelBolt = png('shui_fast.png');
  static final washerModelSpiral = png('shui_tuoshui.png');
  static final tempNormal = png('shui_changwen.png');
  static final temp30 = png('shui_30.png');
  static final temp40 = png('shui_40.png');
  static final temp60 = png('shui_60.png');
  static final detergentNo = png('shui_ye_no.png');
  static final detergentLow = png('shui_ye_low.png');
  static final detergentHigh = png('shui_ye_high.png');
  static final disinfectNo = png('shui_chu_no.png');
  static final disinfectLow = png('shui_chu_low.png');
  static final disinfectHigh = png('shui_chu_high.png');
}
