// Liste des pages de gestion : recherche, compteur, état vide.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Liste des pages de gestion : recherche, compteur et état vide.
class ManagementListView extends StatefulWidget {
  final List<Map<String, Object?>> records;
  final List<String> searchKeys;
  final Widget Function(BuildContext context, Map<String, Object?> record)
  itemBuilder;
  final String noun;

  const ManagementListView({
    required this.records,
    required this.searchKeys,
    required this.itemBuilder,
    this.noun = 'élément',
    super.key,
  });

  @override
  State<ManagementListView> createState() => _ManagementListViewState();
}

class _ManagementListViewState extends State<ManagementListView> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final visible = query.isEmpty
        ? widget.records
        : widget.records
              .where(
                (record) => widget.searchKeys.any(
                  (key) =>
                      record[key]?.toString().toLowerCase().contains(query) ??
                      false,
                ),
              )
              .toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: visible.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${visible.length} ${widget.noun}(s)'
                  '${query.isEmpty ? '' : ' trouvé(s)'}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (visible.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'Aucun résultat.',
                  ),
              ],
            ),
          );
        }
        return widget.itemBuilder(context, visible[index - 1]);
      },
    );
  }
}
