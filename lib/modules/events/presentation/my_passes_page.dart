// Mes pass : billets actifs avec badge chiffré, annulation (la place passe
// automatiquement au premier de la liste d'attente) et inscriptions en
// file d'attente.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/events/data/events_repository.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/modules/events/domain/event_ticket.dart';
import 'package:crowdtech/modules/events/presentation/ticket_page.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

class MyPassesPage extends StatefulWidget {
  final String accountKey;
  const MyPassesPage({required this.accountKey, super.key});

  @override
  State<MyPassesPage> createState() => _MyPassesPageState();
}

class _MyPassesPageState extends State<MyPassesPage> {
  bool loading = true;
  List<Map<String, Object?>> passes = [];
  List<(Map<String, Object?>, int)> waiting = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final reservations = await EventsRepository.reservations.all();
    final queue = await EventsRepository.waitlist.all();
    final mine = [
      for (final row in queue)
        if (row['ownerKey'] == widget.accountKey &&
            row['status'] == ReservationStatus.waiting)
          row,
    ];
    final positions = <(Map<String, Object?>, int)>[];
    for (final row in mine) {
      final eventId = (row['eventId'] as num?)?.toInt() ?? -1;
      final position = await EventCapacity.positionOf(
        eventId,
        widget.accountKey,
      );
      if (position != null) positions.add((row, position));
    }
    if (!mounted) return;
    setState(() {
      passes = reservations
          .where((row) => row['ownerKey'] == widget.accountKey)
          .toList()
          .reversed
          .toList();
      waiting = positions;
      loading = false;
    });
  }

  Future<void> cancel(Map<String, Object?> pass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce billet ?'),
        content: const Text(
          'Votre place sera donnée automatiquement à la première personne de '
          'la liste d’attente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler le billet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final promoted = await EventCapacity.cancelReservation(
        pass['id']! as int,
      );
      await load();
      if (!mounted) return;
      context.showMessage(
        promoted == null
            ? 'Billet annulé, la place est de nouveau disponible.'
            : 'Billet annulé : la place a été attribuée à $promoted.',
      );
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = passes.where(ReservationStatus.isActive).toList();
    final cancelled = passes.where((row) => !ReservationStatus.isActive(row));
    return Scaffold(
      appBar: AppBar(title: const Text('Mes pass')),
      body: loading
          ? const LoadingSkeleton()
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (active.isEmpty && waiting.isEmpty)
                    const EmptyState(
                      icon: Icons.confirmation_number_outlined,
                      message: 'Aucun pass pour l’instant.',
                      palette: ModulePalette.events,
                    ),
                  for (final pass in active) _passCard(pass),
                  if (waiting.isNotEmpty) ...[
                    const _Title('⏳ Liste d’attente'),
                    for (final (row, position) in waiting)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.warningSoft,
                            child: Text(
                              '$position',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text('${row['eventTitle']}'),
                          subtitle: Text(
                            'Position n°$position · place attribuée '
                            'automatiquement dès qu’elle se libère',
                          ),
                        ),
                      ),
                  ],
                  if (cancelled.isNotEmpty) ...[
                    const _Title('Billets annulés'),
                    for (final pass in cancelled)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.cancel_outlined),
                          title: Text('${pass['eventTitle']}'),
                          subtitle: Text('${pass['ticket']}'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _passCard(Map<String, Object?> row) {
    final pass = EventTicket.fromMap(row);
    final checkedIn = pass.checkedIn;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ModulePalette.events.soft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            checkedIn ? Icons.verified_rounded : Icons.qr_code_2_rounded,
            color: ModulePalette.events.start,
          ),
        ),
        title: Text(pass.eventTitle),
        subtitle: Text(
          '${formatDate(pass.date)} · '
          '${checkedIn
              ? 'Entrée validée'
              : pass.badge == null
              ? 'Billet'
              : 'Badge chiffré'}',
        ),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TicketPage(
              eventTitle: pass.eventTitle,
              attendeeName: pass.attendeeName,
              ticket: pass.ticket,
              badge: pass.badge,
              validUntil: pass.validUntil,
            ),
          ),
        ),
        trailing: checkedIn
            ? null
            : IconButton(
                tooltip: 'Annuler le billet',
                onPressed: () => cancel(row),
                icon: const Icon(Icons.event_busy_outlined),
              ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: AppColors.ink,
      ),
    ),
  );
}
