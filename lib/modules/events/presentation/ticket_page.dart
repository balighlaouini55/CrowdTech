// Billet électronique : QR code du badge d'accès chiffré (AES-256-GCM) et horodaté,
// présenté au contrôle des entrées.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/network_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TicketPage extends StatelessWidget {
  final String eventTitle;
  final String attendeeName;
  final String ticket;

  /// Badge chiffré `CTB2.…` (absent pour les anciens billets).
  final String? badge;
  final String? validUntil;

  const TicketPage({
    required this.eventTitle,
    required this.attendeeName,
    required this.ticket,
    this.badge,
    this.validUntil,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final code = badge ?? ticket;
    final data = badge == null ? null : AccessBadge.decode(badge!);
    return Scaffold(
      appBar: AppBar(title: const Text('Mon billet')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: softShadow,
            ),
            child: Column(
              children: [
                const Text('🎟️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(
                  eventTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Participant : $attendeeName',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                QrCodeImage(code, size: 220),
                const SizedBox(height: 14),
                SelectableText(
                  ticket,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (data != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Émis le ${formatDateTime(data.issuedAt.toIso8601String())}\n'
                    'Valable jusqu’au ${formatDateTime(data.validUntil.toIso8601String())}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) return;
                      context.showMessage('Code du badge copié.');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copier le code du badge'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ModulePalette.events.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              badge == null
                  ? 'Billet de démonstration (sans badge chiffré).'
                  : '🔐 Badge chiffré (AES-256-GCM) et horodaté : toute '
                        'modification du code est détectée au contrôle des '
                        'entrées. Un rappel vous sera envoyé avant '
                        'l’événement.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
