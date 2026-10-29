import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../shared/data_record_details_page.dart';
import 'event_form_page.dart';

class EventsManagementPage extends StatefulWidget {
  const EventsManagementPage({super.key});

  @override
  State<EventsManagementPage> createState() => _EventsManagementPageState();
}

class _EventsManagementPageState extends State<EventsManagementPage> {
  bool loading = true;
  String? error;
  List<Map<String, Object?>> events = [];

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await CrowdTechDatabase.getItems('events');
      if (!mounted) return;
      setState(() {
        events = rows.reversed.toList();
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les événements : $exception';
        loading = false;
      });
    }
  }

  Future<void> editEvent(Map<String, Object?> event) async {
    final id = event['id'];
    if (id is! int) return;
    final changes = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(builder: (_) => EventFormPage(initialValues: event)),
    );
    if (!mounted || changes == null) return;
    try {
      final rows = await CrowdTechDatabase.updateItem(
        'events',
        id,
        {...event, ...changes}..remove('id'),
      );
      if (rows != 1) throw Exception('Cet événement est introuvable.');
      await loadEvents();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de modifier l’événement : $exception'),
        ),
      );
    }
  }

  Future<void> deleteEvent(Map<String, Object?> event) async {
    final id = event['id'];
    if (id is! int) return;
    final title = event['title']?.toString() ?? 'cet événement';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’événement ?'),
        content: Text('Voulez-vous supprimer « $title » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      final rows = await CrowdTechDatabase.deleteItem('events', id);
      if (rows != 1) throw Exception('Cet événement est introuvable.');
      await loadEvents();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de supprimer l’événement : $exception'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des événements'),
        actions: [
          IconButton(
            onPressed: loadEvents,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loadEvents,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : events.isEmpty
          ? const Center(child: Text('Aucun événement enregistré.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final title = event['title']?.toString() ?? 'Événement';
                final date = event['date']?.toString() ?? '';
                final city = event['city']?.toString() ?? '';
                final seats = event['seats']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.event_rounded),
                    ),
                    title: Text(title),
                    subtitle: Text('$date • $city • $seats places'),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DataRecordDetailsPage(title: title, record: event),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') editEvent(event);
                        if (action == 'delete') deleteEvent(event);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
