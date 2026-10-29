import 'package:flutter/material.dart';

class DataRecordDetailsPage extends StatelessWidget {
  final String title;
  final Map<String, Object?> record;

  const DataRecordDetailsPage({
    required this.title,
    required this.record,
    super.key,
  });

  String labelFor(String key) {
    const labels = {
      'summary': 'Résumé',
      'source': 'Source',
      'tag': 'Catégorie',
      'credibility': 'Score de crédibilité',
      'company': 'Entreprise',
      'goal': 'Objectif',
      'amountRaised': 'Montant collecté',
      'tokenPrice': 'Prix par jeton',
      'feature': 'Fonctionnalité financée',
      'price': 'Prix',
      'rating': 'Note',
      'date': 'Date',
      'city': 'Ville',
      'seats': 'Places',
      'attendeeName': 'Participant',
      'customerName': 'Client',
      'email': 'Email',
      'address': 'Adresse',
      'total': 'Total',
      'ticket': 'Pass de démonstration',
      'tokens': 'Jetons',
      'amount': 'Montant',
      'status': 'Statut',
    };
    return labels[key] ??
        key.replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => ' ${match[0]!.toLowerCase()}',
        );
  }

  String valueOf(Object? value) {
    if (value is List) return value.map(valueOf).join('\n');
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${valueOf(entry.value)}')
          .join('\n');
    }
    if (value is double) return value.toStringAsFixed(2);
    return value?.toString() ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final visible = record.entries.where(
      (entry) => entry.key != 'id' && entry.key != 'accountKey',
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.article_outlined,
            size: 72,
            color: Color(0xFF4F46E5),
          ),
          const SizedBox(height: 16),
          for (final entry in visible)
            Card(
              child: ListTile(
                title: Text(labelFor(entry.key)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText(valueOf(entry.value)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
