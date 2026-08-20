import 'package:flutter/material.dart';

/// Fade + 8px slide-up entrance for list items, staggered by [index] (40ms
/// steps, clamped) so a freshly-loaded list cascades in instead of
/// appearing all at once. Runs once per widget instance on first build —
/// fine at this app's list sizes (tens of items, not virtualized hundreds),
/// so items don't replay the animation as they're recycled off/onscreen.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final delayMs = (widget.index * 40).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(offset: Offset(0, (1 - _animation.value) * 8), child: child),
        );
      },
    );
  }
}
