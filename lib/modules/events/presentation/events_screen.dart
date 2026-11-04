// Écran Événements : liste, réservation de places (jauge), liste d’attente,
// badges chiffrés et rappels.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/events/data/events_repository.dart';
import 'package:crowdtech/modules/events/data/sample_events.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/modules/events/domain/event_item.dart';
import 'package:crowdtech/modules/events/presentation/check_in_page.dart';
import 'package:crowdtech/modules/events/presentation/event_form_page.dart';
import 'package:crowdtech/modules/events/presentation/event_management_page.dart';
import 'package:crowdtech/modules/events/presentation/my_passes_page.dart';
import 'package:crowdtech/modules/events/presentation/notifications_page.dart';
import 'package:crowdtech/modules/events/presentation/reservation_form_page.dart';
import 'package:crowdtech/modules/events/presentation/ticket_page.dart';
import 'package:crowdtech/modules/events/presentation/widgets/event_card.dart';
import 'package:crowdtech/modules/events/presentation/widgets/event_map_banner.dart';
import 'package:crowdtech/modules/events/presentation/widgets/event_outlook_card.dart';
import 'package:crowdtech/shared/pages/record_details_page.dart';
import 'package:crowdtech/shared/pages/record_list_page.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/reload_on_sync.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class EventsScreen extends StatefulWidget {
  final String accountKey;
  const EventsScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with ReloadOnSync<EventsScreen> {
  @override
  void reloadAfterSync() => loadEvents();

  final reserved = <int>{};
  final reservationCounts = <int, int>{};

  /// Position de l'utilisateur dans la file d'attente (index → n°).
  final waitPositions = <int, int>{};
  int unreadNotifications = 0;
  bool loading = true;
  String? loadError;

  final events = <EventItem>[];

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final rows = await EventsRepository.events.seeded(
        sampleEvents.map((event) => event.toMap()).toList(),
      );
      final savedReservations = await EventsRepository.reservations.all();
      if (!mounted) return;
      final loadedEvents = rows.map(EventItem.fromMap).toList();
      final eventIds = {
        for (var index = 0; index < loadedEvents.length; index++)
          loadedEvents[index].id!: index,
      };
      final loadedReserved = <int>{};
      final loadedReservationCounts = <int, int>{};
      final queue = await EventsRepository.waitlist.all();
      final loadedPositions = <int, int>{};
      for (final (index, event) in loadedEvents.indexed) {
        final waiting = queue
            .where(
              (row) =>
                  row['eventId'] == event.id &&
                  row['status'] == ReservationStatus.waiting,
            )
            .toList();
        final position = waiting.indexWhere(
          (row) => row['ownerKey'] == widget.accountKey,
        );
        if (position >= 0) loadedPositions[index] = position + 1;
      }
      for (final reservation in savedReservations) {
        final eventIndex = eventIds[reservation['eventId']! as int];
        if (eventIndex == null) continue;
        // Une réservation annulée libère sa place.
        if (!ReservationStatus.isActive(reservation)) continue;
        // « Réservé » ne concerne que les réservations de l'utilisateur ;
        // toutes les réservations comptent pour les places restantes.
        if (reservation['ownerKey'] == widget.accountKey) {
          loadedReserved.add(eventIndex);
        }
        loadedReservationCounts.update(
          eventIndex,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (!mounted) return;
      setState(() {
        events
          ..clear()
          ..addAll(loadedEvents);
        reserved
          ..clear()
          ..addAll(loadedReserved);
        reservationCounts
          ..clear()
          ..addAll(loadedReservationCounts);
        waitPositions
          ..clear()
          ..addAll(loadedPositions);
        loading = false;
      });
      await refreshNotifications();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Impossible de charger les événements : $error';
      });
    }
  }

  Future<void> addEvent() async {
    final values = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(builder: (_) => const EventFormPage()),
    );
    if (!mounted || values == null) return;
    final event = EventItem.fromMap(values);
    try {
      final id = await EventsRepository.events.add({
        ...event.toMap(),
        'ownerKey': widget.accountKey,
      });
      if (!mounted) return;
      setState(() => events.add(event.copyWithId(id)));
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    context.showMessage('Événement enregistré dans la base locale.');
  }

  Future<void> reserve(int index) async {
    if (reserved.contains(index)) return;
    final event = events[index];
    final remainingSeats = event.seats - (reservationCounts[index] ?? 0);
    if (remainingSeats <= 0 || event.isPast) return;
    final values = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationFormPage(
          accountKey: widget.accountKey,
          eventTitle: event.title,
        ),
      ),
    );
    if (!mounted || values == null) return;
    final attendee = ReservationAttendee(
      name: values['attendeeName']! as String,
      email: values['email']! as String,
    );
    final Map<String, Object?> booking;
    try {
      // Jauge vérifiée dans la base, billet et badge chiffré créés ensemble.
      booking = await EventCapacity.book(
        event: {...event.toMap(), 'id': event.id},
        accountKey: widget.accountKey,
        name: attendee.name,
        email: attendee.email,
      );
    } on RuleException catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
      await loadEvents();
      return;
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    await Reminders.generate(widget.accountKey);
    if (!mounted) return;
    setState(() {
      reserved.add(index);
      reservationCounts.update(index, (count) => count + 1, ifAbsent: () => 1);
    });
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TicketPage(
          eventTitle: event.title,
          attendeeName: attendee.name,
          ticket: booking['ticket']! as String,
          badge: booking['badge'] as String?,
          validUntil: booking['validUntil'] as String?,
        ),
      ),
    );
    await refreshNotifications();
  }

  /// Événement complet : inscription sur la liste d'attente.
  Future<void> joinWaitlist(int index) async {
    final event = events[index];
    final position = waitPositions[index];
    if (position != null) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Text('⏳', style: TextStyle(fontSize: 32)),
          title: Text('Vous êtes n°$position'),
          content: const Text(
            'Dès qu’une place se libère, elle vous est attribuée '
            'automatiquement et vous recevez une notification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitter la file'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Rester'),
            ),
          ],
        ),
      );
      if (leave != true) return;
      await EventCapacity.leaveWaitlist(event.id!, widget.accountKey);
      await loadEvents();
      return;
    }
    final values = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationFormPage(
          accountKey: widget.accountKey,
          eventTitle: '${event.title} (liste d’attente)',
        ),
      ),
    );
    if (!mounted || values == null) return;
    try {
      final rank = await EventCapacity.joinWaitlist(
        event: {...event.toMap(), 'id': event.id},
        accountKey: widget.accountKey,
        name: values['attendeeName']! as String,
        email: values['email']! as String,
      );
      await loadEvents();
      if (!mounted) return;
      context.showMessage('Inscrit sur la liste d’attente : n°$rank ⏳');
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  /// Rappels automatiques et nombre de notifications non lues.
  Future<void> refreshNotifications() async {
    await Reminders.generate(widget.accountKey);
    final count = await Reminders.unreadCount(widget.accountKey);
    if (mounted) setState(() => unreadNotifications = count);
  }

  void openNotifications() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(accountKey: widget.accountKey),
      ),
    ).then((_) => refreshNotifications());
  }

  void openDetails(EventItem event) {
    final record = event.toMap();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RecordDetailsPage(
          title: 'Détails de l’événement',
          record: record,
          banner: EventMapBanner(event: {...record, 'id': event.id}),
          extras: [EventOutlookCard(event: record)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Événements'),
        actions: [
          IconButton(
            tooltip: 'Notifications et rappels',
            onPressed: openNotifications,
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text('$unreadNotifications'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          if (Permissions.canOrganizeEvents)
            IconButton(
              tooltip: 'Ajouter un événement',
              onPressed: addEvent,
              icon: const Icon(Icons.add_rounded),
            ),
          PopupMenuButton<String>(
            tooltip: 'Autres pages événements',
            onSelected: (value) =>
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => switch (value) {
                      'mine' => const EventManagementPage(),
                      'passes' => MyPassesPage(accountKey: widget.accountKey),
                      'tickets' => RecordListPage(
                        title: 'Mes billets',
                        collection: 'reservations',
                        emptyMessage: 'Aucun billet réservé.',
                        ownedOnly: true,
                        accountKey: widget.accountKey,
                      ),
                      _ => const CheckInPage(),
                    },
                  ),
                ).then((_) {
                  if (mounted) loadEvents();
                }),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mine',
                child: Text(
                  Permissions.isAdmin
                      ? 'Gérer tous les événements'
                      : 'Gérer mes événements',
                ),
              ),
              PopupMenuItem(value: 'tickets', child: Text('Mes billets')),
              PopupMenuItem(
                value: 'passes',
                child: Text('Mes pass, badges et file d’attente'),
              ),
              if (Permissions.isAdmin)
                PopupMenuItem(
                  value: 'checkin',
                  child: Text('Contrôle des entrées'),
                ),
            ],
          ),
        ],
      ),
      body: loading
          ? const LoadingSkeleton()
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadEvents)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ScreenHeader(
                  title: 'Salons & conférences',
                  subtitle:
                      'Réservez votre place et recevez votre billet '
                      'électronique.',
                  icon: Icons.event_rounded,
                  palette: ModulePalette.events,
                  stats: [
                    ('${events.length}', 'événements'),
                    (
                      '${events.indexed.fold<int>(0, (sum, entry) => sum + (entry.$2.seats - (reservationCounts[entry.$1] ?? 0)).clamp(0, 1 << 30))}',
                      'places libres',
                    ),
                    ('${reserved.length}', 'réservées'),
                  ],
                ),
                if (events.isEmpty)
                  const EmptyState(
                    palette: ModulePalette.events,
                    icon: Icons.event_busy_outlined,
                    message: 'Aucun événement programmé.',
                  ),
                ...events.indexed.map(
                  (entry) => EventCard(
                    entry.$2,
                    seats: entry.$2.seats - (reservationCounts[entry.$1] ?? 0),
                    isReserved: reserved.contains(entry.$1),
                    waitlistPosition: waitPositions[entry.$1],
                    onReserve: () => reserve(entry.$1),
                    onWaitlist: () => joinWaitlist(entry.$1),
                    onDetails: () => openDetails(entry.$2),
                  ),
                ),
              ],
            ),
    );
  }
}

class ReservationAttendee {
  final String name;
  final String email;
  const ReservationAttendee({required this.name, required this.email});
}
