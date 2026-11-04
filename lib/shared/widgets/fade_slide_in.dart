// Animation des cartes : apparition douce (fondu + glissement) et léger
// enfoncement quand on appuie dessus.

import 'package:crowdtech/shared/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';

class FadeSlideIn extends StatelessWidget {
  final Widget child;

  /// Position dans la liste : les cartes suivantes apparaissent un peu après.
  final int index;
  const FadeSlideIn({required this.child, this.index = 0, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + 70 * index.clamp(0, 6)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
      child: PressableScale(child: child),
    );
  }
}
