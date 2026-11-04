// Centre de notifications : rappels automatiques des événements (J-7, J-1,
// jour J) et places obtenues depuis la liste d'attente.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  final String accountKey;
  const NotificationsPage({required this.accountKey, super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool loading = true;
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await Reminders.generate(widget.accountKey);
    final rows = await Reminders.of(widget.accountKey);
    if (!mounted) return;
    setState(() {
      items = rows;
      loading = false;
    });
    // Ouvrir la page marque les notifications comme lues.
    await Reminders.markAllRead(widget.accountKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: loading
          ? const LoadingSkeleton()
          : items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              message:
                  'Pas de notification. Vos rappels d’événements '
                  'apparaîtront ici.',
              palette: ModulePalette.events,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items)
                  Card(
                    color: item['read'] == true
                        ? null
                        : ModulePalette.events.soft,
                    child: ListTile(
                      leading: Icon(
                        item['read'] == true
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_active_rounded,
                        color: ModulePalette.events.start,
                      ),
                      title: Text('${item['title']}'),
                      subtitle: Text(
                        '${item['body']}\n'
                        '${formatDateTime(item['createdAt']?.toString())}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
