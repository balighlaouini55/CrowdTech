// Carte d'un événement et petite page de calendrier.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/events/domain/event_item.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/gradient_progress_bar.dart';
import 'package:crowdtech/shared/widgets/info_line.dart';
import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  final EventItem event;
  final int seats;
  final bool isReserved;
  final VoidCallback onReserve;
  final VoidCallback onDetails;

  /// Événement complet : inscription sur la liste d'attente.
  final VoidCallback? onWaitlist;

  /// Position de l'utilisateur dans la file d'attente, ou null.
  final int? waitlistPosition;
  const EventCard(
    this.event, {
    super.key,
    required this.seats,
    required this.isReserved,
    required this.onReserve,
    required this.onDetails,
    this.onWaitlist,
    this.waitlistPosition,
  });

  bool get canJoinWaitlist =>
      seats <= 0 && !isReserved && !event.isPast && onWaitlist != null;

  @override
  Widget build(BuildContext context) {
    final filled = event.seats == 0 ? 1.0 : 1 - seats / event.seats;
    final when = [formatDate(event.date), ?event.time].join(' à ');
    final where = [?event.venue, event.city].join(', ');
    return FadeSlideIn(child: _card(when, where, filled));
  }

  Widget _card(String when, String where, double filled) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ItemImage.hasPhoto(event.imageUrl, event.imageData)) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 160,
                  child: ItemImage(
                    imageUrl: event.imageUrl,
                    imageData: event.imageData,
                    icon: Icons.event_rounded,
                    colors: [
                      ModulePalette.events.start,
                      ModulePalette.events.end,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                if (event.category case final category?)
                  StatusBadge(category, icon: Icons.category_outlined),
                const Spacer(),
                StatusBadge(
                  event.isFree ? 'Gratuit' : formatMoney(event.price!),
                  tone: event.isFree ? BadgeTone.success : BadgeTone.info,
                  icon: Icons.confirmation_number_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                EventDateTile(parseFlexibleDate(event.date)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            if (event.description case final description?) ...[
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            InfoLine(Icons.calendar_today_rounded, when),
            InfoLine(Icons.location_on_outlined, where),
            const SizedBox(height: 8),
            GradientProgressBar(
              value: filled,
              palette: seats == 0 ? ModulePalette.store : ModulePalette.events,
            ),
            const SizedBox(height: 8),
            Text(
              event.isPast
                  ? 'Événement terminé'
                  : seats == 0
                  ? 'Complet'
                  : '$seats places restantes',
              style: TextStyle(
                color: event.isPast
                    ? AppColors.muted
                    : seats == 0
                    ? AppColors.danger
                    : AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDetails,
                    child: const Text('Détails'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: canJoinWaitlist
                      ? ElevatedButton.icon(
                          onPressed: onWaitlist,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                          ),
                          icon: const Icon(Icons.hourglass_top_rounded),
                          label: Text(
                            waitlistPosition == null
                                ? 'Liste d’attente'
                                : 'En attente (n°$waitlistPosition)',
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: isReserved || seats <= 0 || event.isPast
                              ? null
                              : onReserve,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ModulePalette.events.start,
                          ),
                          icon: Icon(
                            isReserved
                                ? Icons.check_circle_rounded
                                : Icons.local_activity_outlined,
                          ),
                          label: Text(isReserved ? 'Réservé' : 'Réserver'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Petite page de calendrier : jour et mois de l’événement.
class EventDateTile extends StatelessWidget {
  final DateTime? date;
  const EventDateTile(this.date, {super.key});

  static const months = [
    'JANV',
    'FÉVR',
    'MARS',
    'AVR',
    'MAI',
    'JUIN',
    'JUIL',
    'AOÛT',
    'SEPT',
    'OCT',
    'NOV',
    'DÉC',
  ];

  @override
  Widget build(BuildContext context) {
    final value = date;
    return Container(
      width: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(gradient: ModulePalette.events.gradient),
            child: Text(
              value == null ? 'DATE' : months[value.month - 1],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: value == null
                ? Icon(Icons.event_rounded, color: ModulePalette.events.start)
                : Text(
                    '${value.day}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
