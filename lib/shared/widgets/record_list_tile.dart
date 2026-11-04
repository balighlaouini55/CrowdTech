// Ligne d'un enregistrement dans une liste générique.

import 'package:crowdtech/shared/widgets/module_avatar.dart';
import 'package:flutter/material.dart';

class RecordListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const RecordListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const ModuleAvatar(Icons.description_outlined),
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        onTap: onTap,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
