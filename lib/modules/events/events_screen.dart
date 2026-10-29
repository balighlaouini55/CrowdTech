import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../models/crowd_models.dart';
import '../../shared/database_error_view.dart';
import '../../shared/account_admin_pages.dart';
import '../../shared/data_record_details_page.dart';
import '../../shared/data_record_list_page.dart';
import '../../shared/simulation_pages.dart';
import 'event_form_page.dart';
import 'events_management_page.dart';
import 'reservation_form_page.dart';

class EventsScreen extends StatefulWidget {
  final String accountKey;
  const EventsScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final reserved = <int>{};
  final reservationCounts = <int, int>{};
  bool loading = true;
  String? loadError;

  static const sampleEvents = [
    EventItem(
      title: 'Tech Innovation Summit',
      date: '12 Nov 2026',
      city: 'Paris',
      seats: 80,
    ),
    EventItem(
      title: 'Startup & AI Forum',
      date: '18 Nov 2026',
      city: 'Lyon',
      seats: 36,
    ),
  ];
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
      final rows = await CrowdTechDatabase.loadSeededItems(
        'events',
        sampleEvents.map((event) => event.toMap()).toList(),
      );
      final savedReservations = await CrowdTechDatabase.getItems(
        'reservations',
      );
      if (!mounted) return;
      final loadedEvents = rows.map(EventItem.fromMap).toList();
      final eventIds = {
        for (var index = 0; index < loadedEvents.length; index++)
          loadedEvents[index].id!: index,
      };
      final loadedReserved = <int>{};
      final loadedReservationCounts = <int, int>{};
      for (final reservation in savedReservations) {
        final eventIndex = eventIds[reservation['eventId']! as int];
        if (eventIndex == null) continue;
        loadedReserved.add(eventIndex);
        loadedReservationCounts.update(
          eventIndex,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
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
        loading = false;
      });
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
      final id = await CrowdTechDatabase.insertItem('events', {
        ...event.toMap(),
        'ownerKey': widget.accountKey,
      });
      if (!mounted) return;
      setState(() => events.add(event.copyWithId(id)));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Événement enregistré dans la base locale.'),
      ),
    );
  }

  Future<void> reserve(int index) async {
    if (reserved.contains(index)) return;
    final event = events[index];
    final remainingSeats = event.seats - (reservationCounts[index] ?? 0);
    if (remainingSeats <= 0) return;
    final values = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(builder: (_) => const ReservationFormPage()),
    );
    if (!mounted || values == null) return;
    final attendee = ReservationAttendee(
      name: values['attendeeName']! as String,
      email: values['email']! as String,
    );
    final ticket =
        'CT-${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().year}';
    try {
      await CrowdTechDatabase.insertItem('reservations', {
        'eventId': event.id!,
        'eventTitle': event.title,
        'attendeeName': attendee.name,
        'email': attendee.email,
        'ownerKey': widget.accountKey,
        'ticket': ticket,
        'checkedIn': false,
        'status': 'Réservé',
        'createdAt': DateTime.now().toIso8601String(),
      });
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    if (!mounted) return;
    setState(() {
      reserved.add(index);
      reservationCounts.update(index, (count) => count + 1, ifAbsent: () => 1);
    });
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TicketBadgePage(
          eventTitle: event.title,
          attendeeName: attendee.name,
          ticket: ticket,
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
            tooltip: 'Ajouter un événement',
            onPressed: addEvent,
            icon: const Icon(Icons.add_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Autres pages événements',
            onSelected: (value) => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => switch (value) {
                  'mine' => const EventsManagementPage(),
                  'tickets' => DataRecordListPage(
                    title: 'Mes billets',
                    collection: 'reservations',
                    emptyMessage: 'Aucun billet réservé.',
                    ownedOnly: true,
                    accountKey: widget.accountKey,
                  ),
                  _ => const CheckInPage(),
                },
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mine',
                child: Text('Gérer tous les événements'),
              ),
              PopupMenuItem(value: 'tickets', child: Text('Mes billets')),
              PopupMenuItem(
                value: 'checkin',
                child: Text('Contrôle des entrées'),
              ),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadEvents)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Salons & conférences',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const Text(
                  'Réservez votre place. La file d’attente et le pass sont simulés localement.',
                  style: TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                ...events.indexed.map(
                  (entry) => _EventCard(
                    entry.$2,
                    seats: entry.$2.seats - (reservationCounts[entry.$1] ?? 0),
                    isReserved: reserved.contains(entry.$1),
                    onReserve: () => reserve(entry.$1),
                    onDetails: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DataRecordDetailsPage(
                          title: 'Détails de l’événement',
                          record: entry.$2.toMap(),
                        ),
                      ),
                    ),
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

class _EventCard extends StatelessWidget {
  final EventItem event;
  final int seats;
  final bool isReserved;
  final VoidCallback onReserve;
  final VoidCallback onDetails;
  const _EventCard(
    this.event, {
    required this.seats,
    required this.isReserved,
    required this.onReserve,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDetails,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Détails'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(event.date),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(event.city),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$seats places restantes',
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isReserved || seats == 0 ? null : onReserve,
              child: Text(isReserved ? 'Réservé' : 'Réserver'),
            ),
          ),
        ],
      ),
    );
  }
}
