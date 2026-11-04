// Historique de toutes les opérations de l’utilisateur.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/profile/data/profile_repository.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Toutes les opérations enregistrées dans SQLite pour un utilisateur.
class ActivityLogPage extends StatefulWidget {
  final String accountKey;
  const ActivityLogPage({required this.accountKey, super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  static const modules = [
    'Compte',
    'Actualités',
    'Crowdfunding',
    'Marketplace',
    'Événements',
    'Profil',
  ];
  static const icons = {
    'Compte': Icons.key_rounded,
    'Actualités': Icons.newspaper_rounded,
    'Crowdfunding': Icons.trending_up_rounded,
    'Marketplace': Icons.store_rounded,
    'Événements': Icons.event_rounded,
    'Profil': Icons.person_rounded,
  };

  bool loading = true;
  String? error;
  String? moduleFilter;
  List<Map<String, Object?>> entries = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await ProfileRepository.activityLog.all();
      if (!mounted) return;
      setState(() {
        entries = rows
            .where((row) => row['ownerKey'] == widget.accountKey)
            .toList()
            .reversed
            .toList();
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger l’historique : $exception';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = moduleFilter == null
        ? entries
        : entries.where((entry) => entry['module'] == moduleFilter).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des opérations'),
        actions: [
          IconButton(
            onPressed: load,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? DatabaseErrorView(message: error!, onRetry: load)
          : Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      for (final module in [null, ...modules])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(module ?? 'Tout'),
                            selected: moduleFilter == module,
                            onSelected: (_) =>
                                setState(() => moduleFilter = module),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          message: 'Aucune opération.',
                          palette: ModulePalette.profile,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final entry = visible[index];
                            final module = entry['module']?.toString() ?? '';
                            final details = entry['details']?.toString() ?? '';
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    icons[module] ?? Icons.history_rounded,
                                  ),
                                ),
                                title: Text(entry['action']?.toString() ?? ''),
                                subtitle: Text(
                                  [
                                    module,
                                    if (details.isNotEmpty) details,
                                    formatDateTime(
                                      entry['createdAt']?.toString(),
                                    ),
                                  ].join(' • '),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
