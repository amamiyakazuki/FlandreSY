import 'package:flutter/material.dart';

import '../theme/shui_motion.dart';

/// Keeps removed rows alive while surviving rows close the gap.
class ShuiAnimatedList<T> extends StatefulWidget {
  const ShuiAnimatedList(
      {required this.items,
      required this.identity,
      required this.itemBuilder,
      required this.empty,
      super.key});

  final List<T> items;
  final Object Function(T) identity;
  final Widget Function(T, int) itemBuilder;
  final Widget empty;

  @override
  State<ShuiAnimatedList<T>> createState() => _ShuiAnimatedListState<T>();
}

class _ShuiAnimatedListState<T> extends State<ShuiAnimatedList<T>> {
  final _key = GlobalKey<AnimatedListState>();
  late final List<T> _items = List.of(widget.items);

  Widget _transition(Widget child, Animation<double> animation) =>
      SizeTransition(
        sizeFactor: animation.drive(CurveTween(curve: ShuiMotion.easeOut)),
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      );

  @override
  void didUpdateWidget(ShuiAnimatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final duration = ShuiMotion.duration(context, ShuiMotion.local);
    final wanted = widget.items.map(widget.identity).toSet();
    for (var i = _items.length - 1; i >= 0; i--) {
      if (!wanted.contains(widget.identity(_items[i]))) {
        final removed = _items.removeAt(i);
        final child = oldWidget.itemBuilder(removed, i);
        _key.currentState!.removeItem(
            i,
            (_, animation) => IgnorePointer(
                child: ExcludeSemantics(
                    child: ExcludeFocus(child: _transition(child, animation)))),
            duration: duration);
      }
    }
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final existing = _items.indexWhere(
          (value) => widget.identity(value) == widget.identity(item));
      if (existing == i) {
        _items[i] = item;
      } else {
        if (existing >= 0) {
          _items.removeAt(existing);
          _key.currentState!.removeItem(
              existing, (_, animation) => const SizedBox.shrink(),
              duration: Duration.zero);
        }
        _items.insert(i, item);
        _key.currentState!.insertItem(i, duration: duration);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AnimatedList(
            key: _key,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            initialItemCount: _items.length,
            itemBuilder: (context, index, animation) {
              final item = _items[index];
              return KeyedSubtree(
                  key: ValueKey(widget.identity(item)),
                  child:
                      _transition(widget.itemBuilder(item, index), animation));
            },
          ),
          AnimatedSize(
            duration: ShuiMotion.duration(context, ShuiMotion.local),
            child: _items.isEmpty
                ? widget.empty
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
}
