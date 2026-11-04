// Effet « bouton enfoncé » : le contenu rétrécit légèrement quand on appuie.

import 'package:flutter/material.dart';

class PressableScale extends StatefulWidget {
  final Widget child;
  const PressableScale({required this.child, super.key});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool pressed = false;

  void setPressed(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // Listener observe le doigt sans bloquer les boutons de la carte.
    return Listener(
      onPointerDown: (_) => setPressed(true),
      onPointerUp: (_) => setPressed(false),
      onPointerCancel: (_) => setPressed(false),
      child: AnimatedScale(
        scale: pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
