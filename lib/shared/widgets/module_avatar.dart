// Pastille colorée d'un élément de liste, aux couleurs de son module.

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

class ModuleAvatar extends StatelessWidget {
  final IconData icon;
  final ModulePalette palette;
  const ModuleAvatar(
    this.icon, {
    this.palette = ModulePalette.funding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: palette.start, size: 22),
    );
  }
}
