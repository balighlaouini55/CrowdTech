// Ligne d'information avec icône (date, lieu…).

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

class InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoLine(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
