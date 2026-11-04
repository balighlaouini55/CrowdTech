// Gestion des événements : modifier, supprimer, vérifier les villes (HTTP).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/events/data/events_repository.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/modules/events/presentation/event_form_page.dart';
import 'package:crowdtech/shared/pages/record_details_page.dart';
import 'package:crowdtech/shared/utils/api_import.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/management_list_view.dart';
import 'package:crowdtech/shared/widgets/module_avatar.dart';
import 'package:flutter/material.dart';

class EventManagementPage extends StatefulWidget {
  const EventManagementPage({super.key});

  @override
  State<EventManagementPage> createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
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
      final rows = await EventsRepository.events.all();
      if (!mounted) return;
      setState(() {
        // Chacun gère ses propres éléments ; l'administrateur gère tout.
        events = rows.where(Permissions.canManage).toList().reversed.toList();
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

  /// Vérifie par HTTP la ville de chaque événement pas encore vérifié et
  /// enregistre le pays et les coordonnées dans SQLite.
  Future<int> verifyCities() async {
    var verified = 0;
    for (final event in await EventsRepository.events.all()) {
      final id = event['id'];
      final city = event['city']?.toString().trim() ?? '';
      if (id is! int || city.isEmpty || event['country'] != null) continue;
      final place = await CrowdTechApi.geocodeCity(city);
      final values = {...event, ...?place}..remove('id');
      values['country'] ??= 'Ville introuvable';
      await EventsRepository.events.update(id, values);
      verified++;
    }
    return verified;
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
      // On ne peut pas descendre sous le nombre de billets déjà réservés.
      final booked = (await EventsRepository.reservations.all())
          .where(
            (reservation) =>
                reservation['eventId'] == id &&
                ReservationStatus.isActive(reservation),
          )
          .length;
      final seats = (changes['seats'] as num?)?.toInt();
      if (seats != null && seats < booked) {
        if (!mounted) return;
        context.showMessage(
          '$booked billet(s) déjà réservé(s) : le nombre de places ne '
          'peut pas être inférieur à $booked.',
        );
        return;
      }
      final values = {...event, ...changes}..remove('id');
      if (changes['city'] != event['city']) {
        // La ville a changé : l’ancienne vérification n’est plus valable.
        values
          ..remove('country')
          ..remove('latitude')
          ..remove('longitude');
      }
      final rows = await EventsRepository.events.update(id, values);
      if (rows != 1) throw Exception('Cet événement est introuvable.');
      await loadEvents();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de modifier l’événement : $exception');
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
      final rows = await EventsRepository.events.remove(id);
      if (rows != 1) throw Exception('Cet événement est introuvable.');
      await loadEvents();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de supprimer l’événement : $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des événements'),
        actions: [
          if (Permissions.isAdmin)
            IconButton(
              onPressed: () => runApiImport(
                context,
                run: verifyCities,
                reload: loadEvents,
                successLabel: 'ville(s) vérifiée(s) avec Open-Meteo',
              ),
              tooltip: 'Vérifier les villes sur Internet',
              icon: const Icon(Icons.travel_explore_rounded),
            ),
          IconButton(
            onPressed: loadEvents,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const LoadingSkeleton()
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
          ? const EmptyState(
              palette: ModulePalette.events,
              icon: Icons.event_busy_outlined,
              message: 'Aucun événement enregistré.',
            )
          : ManagementListView(
              records: events,
              noun: 'événement',
              searchKeys: const ['title', 'city', 'category', 'venue'],
              itemBuilder: (context, event) {
                final title = event['title']?.toString() ?? 'Événement';
                final date = formatDate(event['date']?.toString());
                final city = event['city']?.toString() ?? '';
                final seats = event['seats']?.toString() ?? '';
                final country = event['country']?.toString();
                final price = (event['price'] as num?) ?? 0;
                return Card(
                  child: ListTile(
                    leading: const ModuleAvatar(
                      Icons.event_rounded,
                      palette: ModulePalette.events,
                    ),
                    title: Text(title),
                    subtitle: Text(
                      [
                        ?event['category']?.toString(),
                        date,
                        '$city${country == null ? '' : ' ($country)'}',
                        '$seats places',
                        price <= 0 ? 'gratuit' : formatMoney(price),
                      ].join(' • '),
                    ),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecordDetailsPage(title: title, record: event),
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
