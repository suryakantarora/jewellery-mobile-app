import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

extension WidgetX on Widget {
  Widget paddedAll(double value) =>
      Padding(padding: EdgeInsets.all(value), child: this);

  Widget paddedSymmetric({double horizontal = 0, double vertical = 0}) =>
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
        child: this,
      );

  Widget paddedOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => Padding(
    padding: EdgeInsets.only(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    ),
    child: this,
  );

  Widget get expanded => Expanded(child: this);

  Widget flexible({int flex = 1}) => Flexible(flex: flex, child: this);

  Widget get sliverBox => SliverToBoxAdapter(child: this);

  /// Hides the widget without removing it from the tree — used where a stable
  /// layout matters more than a rebuild.
  Widget visible(bool value) =>
      Visibility(visible: value, maintainState: true, child: this);

  /// Fades and rises into place, staggered by list position.
  ///
  /// Applied to list content so a screen assembles rather than snapping into
  /// existence. The stagger is capped so long lists do not crawl.
  Widget entrance({int index = 0, Duration? duration}) => _Entrance(
    index: index,
    duration: duration ?? AppMotion.normal,
    child: this,
  );
}

class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.child,
    required this.index,
    required this.duration,
  });

  final Widget child;
  final int index;
  final Duration duration;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    final delay = AppMotion.stagger(widget.index);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the platform's reduce-motion setting: animation here is decorative.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
