import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_motion.dart';

/// Retains the barrier until dismissal finishes and shares it across steps.
class ShuiOverlayHost extends StatefulWidget {
  const ShuiOverlayHost({required this.child, super.key});

  final Widget? child;

  @override
  State<ShuiOverlayHost> createState() => _ShuiOverlayHostState();
}

class _ShuiOverlayHostState extends State<ShuiOverlayHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _visibility = AnimationController(vsync: this);
  final FocusScopeNode _scope = FocusScopeNode(
      debugLabel: 'modal',
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);
  FocusNode? _origin;
  Widget? _retained;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visibility.duration = ShuiMotion.duration(context, ShuiMotion.overlay);
    _sync();
  }

  @override
  void didUpdateWidget(ShuiOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.child != null) {
      if (_retained == null) {
        _origin = FocusManager.instance.primaryFocus;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.child != null) _scope.requestFocus();
        });
      }
      _retained = widget.child;
      _visibility.forward();
    } else if (_retained != null) {
      _visibility.reverse().then((_) {
        if (!mounted || widget.child != null) return;
        setState(() => _retained = null);
        if (_origin?.context != null && _origin!.canRequestFocus) {
          _origin!.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _visibility.dispose();
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_retained == null) return const SizedBox.shrink();
    return Material(
      type: MaterialType.transparency,
      child: Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: _visibility,
          child: ModalBarrier(
              color:
                  AppColors.scrim.withValues(alpha: AppCustomTokens.alphaPopup),
              dismissible: false),
        ),
        BlockSemantics(
          child: FocusScope(
            node: _scope,
            child: IgnorePointer(
              ignoring: widget.child == null,
              child: ExcludeFocus(
                excluding: widget.child == null,
                child: FadeTransition(
                  opacity: _visibility,
                  child: ScaleTransition(
                    scale: Tween(
                            begin: ShuiMotion.reduced(context) ? 1.0 : 0.97,
                            end: 1.0)
                        .animate(CurvedAnimation(
                            parent: _visibility, curve: ShuiMotion.easeOut)),
                    child: AnimatedSwitcher(
                      duration: ShuiMotion.duration(context, ShuiMotion.local),
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final child in previous)
                            IgnorePointer(
                                child: ExcludeSemantics(
                                    child: ExcludeFocus(child: child))),
                          if (current != null) current,
                        ],
                      ),
                      child: _retained,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
