import 'package:flutter/material.dart';

/// Fades and slides its child up once when first built.
/// [index] staggers items in a list so they don't all appear at once.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 24});

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final delayFactor = (index.clamp(0, 8)) * 60;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delayFactor),
      curve: Interval(delayFactor / (380 + delayFactor), 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, offset * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }
}
