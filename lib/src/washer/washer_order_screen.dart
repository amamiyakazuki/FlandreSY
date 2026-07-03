// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors service palette, AppTypography.textTheme, AppCustomTokens space.
// Reference: P_PLAN/...Reference.md §4.5 + legacy ShuiScreens.kt WasherOrderScreen (1171).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/washer_order.dart';
import '../theme/shui_assets.dart';
import '../widgets/option_card.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'washer_info_card.dart';
import 'washer_payment_card.dart';

/// 洗衣下单页（W1）。扫码识别 program → 选套餐/温度/洗衣液/除菌液 → 实时算价 → 创建 → 支付卡。
/// 表单本地态用 StatefulWidget（对齐 legacy remember）。
class WasherOrderScreen extends StatefulWidget {
  const WasherOrderScreen({
    required this.state,
    required this.onBack,
    required this.onCreateOrder,
    required this.onPay,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onBack;
  final void Function(
    int washModelId,
    int temperatureId,
    int? detergentGearId,
    int? disinfectantGearId,
  ) onCreateOrder;
  final ValueChanged<bool> onPay;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  State<WasherOrderScreen> createState() => _WasherOrderScreenState();
}

class _WasherOrderScreenState extends State<WasherOrderScreen> {
  int _selectedModelId = 0;
  int _selectedTemperatureId = 1;
  int? _selectedDetergentGearId;
  int? _selectedDisinfectantGearId;
  bool _autoStart = true;

  static final _modelColors = <Color>[
    AppColors.primary,
    AppColors.serviceBlue,
    AppColors.serviceOrange,
    AppColors.serviceViolet,
  ];
  static final _modelIcons = <String>[
    ShuiAssets.washerModelStrong,
    ShuiAssets.washerModelShirt,
    ShuiAssets.washerModelBolt,
    ShuiAssets.washerModelSpiral,
  ];

  WasherProgramUi? get _program => widget.state.washerProgram;

  @override
  void initState() {
    super.initState();
    _selectedModelId = _program?.defaultWashModelId ?? 0;
  }

  @override
  void didUpdateWidget(WasherOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // program 首次到达时初始化默认套餐。
    if (_selectedModelId == 0 && _program != null) {
      _selectedModelId = _program!.defaultWashModelId;
    }
  }

  WasherModelUi? get _selectedModel {
    final models = _program?.models ?? const [];
    for (final m in models) {
      if (m.id == _selectedModelId) return m;
    }
    return models.isNotEmpty ? models.first : null;
  }

  List<WasherAdditionOptionUi> _additionOptions(String key) {
    final groups = _selectedModel?.additionGroups ?? const [];
    for (final g in groups) {
      if (g.key == key) return g.options;
    }
    return const [];
  }

  int get _totalFen {
    final model = _selectedModel;
    if (model == null) return 0;
    final det = _additionOptions('wp_detergentGearId')
        .where((o) => o.id == _selectedDetergentGearId);
    final dis = _additionOptions('wp_disinfectantGearId')
        .where((o) => o.id == _selectedDisinfectantGearId);
    // 水温档价本地全额纳入（kWasherTemperaturePriceFen，用户拍板固定表）——静默加进总价，
    // 水温卡不显价格副标题；让 UI 预估 == 真机实收（有意偏离 legacy 本地不算水温价）。
    final tempFen = kWasherTemperaturePriceFen[_selectedTemperatureId] ?? 0;
    return model.priceFen +
        tempFen +
        (det.isEmpty ? 0 : det.first.priceFen) +
        (dis.isEmpty ? 0 : dis.first.priceFen);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final program = _program;
    final models = program?.models.take(4).toList() ?? const [];
    final orderBusy = s.washerOrder.isBusy;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;

    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '洗衣下单', showBack: true, onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceSm,
                AppCustomTokens.spaceMd,
                bottomPadding,
              ),
              child: Column(
                children: [
                  WasherRuntimeInfoCard(program: program),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  RuntimeStatusBanner(status: s.washer.washerScan),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  _buildModelSection(models),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  _buildTemperatureSection(),
                  ..._buildAdditionSections(),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  AutoStartNoticeCard(
                    enabled: _autoStart,
                    onChanged: (v) => setState(() => _autoStart = v),
                  ),
                  if (s.washerOrder.message != null) ...[
                    const SizedBox(height: AppCustomTokens.spaceSm),
                    RuntimeStatusBanner(status: s.washerOrder),
                  ],
                  if (s.currentWasherOrder != null) ...[
                    const SizedBox(height: AppCustomTokens.spaceSm),
                    CurrentWasherOrderPaymentCard(
                      order: s.currentWasherOrder!,
                      paying: s.washerPayment.isBusy,
                      orderBusy: orderBusy,
                      paymentMessage: s.washerPayment.message,
                      paymentState: s.washerPayment,
                      onPay: () => widget.onPay(_autoStart),
                      onStart: widget.onStart,
                      onStop: widget.onStop,
                      onCancel: widget.onCancel,
                    ),
                  ],
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  PriceBar(
                    amount: formatFenAmount(_totalFen),
                    enabled: program != null &&
                        _selectedModelId != 0 &&
                        !orderBusy,
                    buttonText: orderBusy ? '创建中' : '创建订单',
                    onCreate: () => widget.onCreateOrder(
                      _selectedModelId,
                      _selectedTemperatureId,
                      _selectedDetergentGearId,
                      _selectedDisinfectantGearId,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSection(List<WasherModelUi> models) {
    final items = models.isEmpty
        ? [
            const OptionItem(
              title: '待扫码',
              iconAsset: null,
              iconColor: AppColors.primary,
            ),
          ]
        : [
            for (var i = 0; i < models.length; i++)
              OptionItem(
                title: models[i].name,
                subtitle: formatFenAmount(models[i].priceFen),
                iconAsset: _modelIcons[i % _modelIcons.length],
                iconColor: _modelColors[i % _modelColors.length],
              ),
          ];
    var selected = 0;
    for (var i = 0; i < models.length; i++) {
      if (models[i].id == _selectedModelId) selected = i;
    }
    return OptionSection(
      iconAsset: ShuiAssets.shuiYifu,
      title: '套餐选择',
      tail: '请选择洗衣套餐',
      options: items,
      selectedIndex: selected,
      onSelected: (i) {
        if (i < models.length) {
          setState(() {
            _selectedModelId = models[i].id;
            _selectedDetergentGearId = null;
            _selectedDisinfectantGearId = null;
          });
        }
      },
    );
  }

  Widget _buildTemperatureSection() {
    final temps = <(int, String, String)>[
      (1, '常温', ShuiAssets.tempNormal),
      (2, '30°C', ShuiAssets.temp30),
      (3, '40°C', ShuiAssets.temp40),
      (4, '60°C', ShuiAssets.temp60),
    ];
    final items = [
      for (final t in temps)
        OptionItem(title: t.$2, iconAsset: t.$3, iconColor: AppColors.primary),
    ];
    var selected = 0;
    for (var i = 0; i < temps.length; i++) {
      if (temps[i].$1 == _selectedTemperatureId) selected = i;
    }
    return OptionSection(
      iconAsset: ShuiAssets.shuiFire,
      title: '温度选择',
      tail: '请选择洗涤温度',
      options: items,
      selectedIndex: selected,
      compact: true,
      onSelected: (i) => setState(() => _selectedTemperatureId = temps[i].$1),
    );
  }

  List<Widget> _buildAdditionSections() {
    final widgets = <Widget>[];
    final detergent = _additionOptions('wp_detergentGearId');
    if (detergent.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: AppCustomTokens.spaceSm))
        ..add(
          _buildAdditionSection(
            title: '洗衣液选择',
            tail: '请选择洗衣液用量',
            noneIcon: ShuiAssets.detergentNo,
            addedIcons: [ShuiAssets.detergentLow, ShuiAssets.detergentHigh],
            options: detergent,
            selectedId: _selectedDetergentGearId,
            onSelected: (id) => setState(() => _selectedDetergentGearId = id),
          ),
        );
    }
    final disinfect = _additionOptions('wp_disinfectantGearId');
    if (disinfect.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: AppCustomTokens.spaceSm))
        ..add(
          _buildAdditionSection(
            title: '除菌液选择',
            tail: '请选择除菌液用量',
            noneIcon: ShuiAssets.disinfectNo,
            addedIcons: [ShuiAssets.disinfectLow, ShuiAssets.disinfectHigh],
            options: disinfect,
            selectedId: _selectedDisinfectantGearId,
            onSelected: (id) => setState(() => _selectedDisinfectantGearId = id),
          ),
        );
    }
    return widgets;
  }

  Widget _buildAdditionSection({
    required String title,
    required String tail,
    required String noneIcon,
    required List<String> addedIcons,
    required List<WasherAdditionOptionUi> options,
    required int? selectedId,
    required ValueChanged<int?> onSelected,
  }) {
    final items = <OptionItem>[
      OptionItem(title: '不添加', iconAsset: noneIcon, iconColor: AppColors.primary),
      for (var i = 0; i < options.length; i++)
        OptionItem(
          title: options[i].name,
          subtitle: formatFenAmount(options[i].priceFen),
          iconAsset: addedIcons[i % addedIcons.length],
          iconColor: AppColors.serviceBlue,
        ),
    ];
    var selected = 0;
    for (var i = 0; i < options.length; i++) {
      if (options[i].id == selectedId) selected = i + 1;
    }
    return OptionSection(
      iconAsset: ShuiAssets.shuiYifu,
      title: title,
      tail: tail,
      options: items,
      selectedIndex: selected,
      compact: true,
      onSelected: (i) => onSelected(i == 0 ? null : options[i - 1].id),
    );
  }
}
