import 'package:flutter/material.dart';

class DataRecordListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const DataRecordListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        onTap: onTap,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
