// Page générique : détail d'un enregistrement (champs traduits et formatés).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:flutter/material.dart';

class RecordDetailsPage extends StatelessWidget {
  final String title;
  final Map<String, Object?> record;

  /// Image facultative affichée en haut (ex. photo d'un produit).
  final Widget? banner;

  /// Cartes ajoutées sous l'en-tête (météo d'un événement…).
  final List<Widget> extras;

  const RecordDetailsPage({
    required this.title,
    required this.record,
    this.banner,
    this.extras = const [],
    super.key,
  });

  /// Champs techniques jamais affichés à l’utilisateur.
  static const hiddenKeys = {
    'id',
    'accountKey',
    'ownerKey',
    'sourceCredibility',
    'salt',
    'passwordHash',
    'productId',
    'eventId',
    'projectId',
    'articleId',
    'imageUrl',
    'imageData',
  };

  static const moneyKeys = {
    'goal',
    'amountRaised',
    'tokenPrice',
    'price',
    'total',
    'amount',
    'unitPrice',
    'estimate',
  };

  static const dateKeys = {'publishedAt', 'deadline', 'createdAt'};

  String labelFor(String key) {
    const labels = {
      'title': 'Titre',
      'name': 'Nom',
      'summary': 'Résumé',
      'source': 'Source',
      'tag': 'Catégorie',
      'credibility': 'Score de crédibilité',
      'author': 'Auteur',
      'url': 'Lien',
      'publishedAt': 'Date de publication',
      'company': 'Entreprise',
      'goal': 'Objectif',
      'amountRaised': 'Montant collecté',
      'progress': 'Progression',
      'tokenPrice': 'Prix par jeton',
      'feature': 'Fonctionnalité financée',
      'category': 'Catégorie',
      'description': 'Description',
      'deadline': 'Date limite',
      'price': 'Prix',
      'rating': 'Note',
      'brand': 'Marque',
      'stock': 'Stock',
      'condition': 'État',
      'date': 'Date',
      'time': 'Heure',
      'venue': 'Lieu',
      'city': 'Ville',
      'seats': 'Places',
      'attendeeName': 'Participant',
      'eventTitle': 'Événement',
      'customerName': 'Client',
      'email': 'Email',
      'phone': 'Téléphone',
      'bio': 'Bio',
      'role': 'Rôle',
      'address': 'Adresse',
      'items': 'Articles',
      'total': 'Total',
      'ticket': 'Code du billet',
      'checkedIn': 'Entrée validée',
      'projectTitle': 'Projet',
      'tokens': 'Jetons',
      'pack': 'Pack',
      'bonusTokens': 'Jetons offerts',
      'country': 'Pays',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'amount': 'Montant',
      'stars': 'Note (étoiles)',
      'review': 'Avis',
      'articleTitle': 'Actualité',
      'authorName': 'Auteur',
      'status': 'Statut',
      'text': 'Commentaire',
      'createdAt': 'Créé le',
      'ratePercent': 'Taux annuel (%)',
      'years': 'Durée (années)',
      'estimate': 'Valeur estimée',
      'productName': 'Produit',
      'quantity': 'Quantité',
      'stage': 'Stade',
      'location': 'Ville',
      'website': 'Site web',
      'teamSize': 'Taille de l’équipe',
    };
    return labels[key] ??
        key.replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => ' ${match[0]!.toLowerCase()}',
        );
  }

  String valueOf(String key, Object? value) {
    if (value is List) {
      return value
          .map(
            (item) => item is Map
                ? '${item['quantity'] ?? 1} × ${item['productName'] ?? item['name'] ?? ''}'
                      '${item['unitPrice'] is num ? ' — ${formatMoney(item['unitPrice']! as num)}' : ''}'
                : valueOf(key, item),
          )
          .join('\n');
    }
    if (value is Map) {
      return value.entries
          .map((entry) => '${labelFor('${entry.key}')} : ${entry.value}')
          .join('\n');
    }
    if (value is bool) return value ? 'Oui' : 'Non';
    if (key == 'price' && value == 0) return 'Gratuit';
    if (value is num && moneyKeys.contains(key)) return formatMoney(value);
    if (key == 'credibility' || key == 'progress') return '$value %';
    if (value is String && dateKeys.contains(key)) {
      final date = DateTime.tryParse(value);
      if (date == null) return value;
      return key == 'createdAt' ? formatDateTime(value) : formatDate(value);
    }
    if (key == 'rating' && value is num) return value.toStringAsFixed(1);
    // Sur le Web, tous les nombres sont des doubles : 12.0 s'affiche « 12 ».
    if (value is num && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    if (value is double) return value.toStringAsFixed(2);
    return value?.toString() ?? '—';
  }

  /// Champs de texte long, affichés en paragraphe sous l'en-tête.
  static const longTextKeys = {
    'summary',
    'description',
    'feature',
    'text',
    'bio',
  };

  /// Champs utilisés comme titre de l'en-tête.
  static const titleKeys = [
    'title',
    'name',
    'projectTitle',
    'eventTitle',
    'productName',
    'customerName',
  ];

  /// Couleur et icône de l'en-tête, devinées d'après les champs présents.
  (ModulePalette, IconData) get style {
    if (record.containsKey('tokenPrice') || record.containsKey('tokens')) {
      return (ModulePalette.funding, Icons.rocket_launch_rounded);
    }
    if (record.containsKey('credibility')) {
      return (ModulePalette.news, Icons.newspaper_rounded);
    }
    if (record.containsKey('seats') || record.containsKey('ticket')) {
      return (ModulePalette.events, Icons.event_rounded);
    }
    if (record.containsKey('stock') ||
        record.containsKey('items') ||
        record.containsKey('brand')) {
      return (ModulePalette.store, Icons.shopping_bag_rounded);
    }
    return (ModulePalette.profile, Icons.article_rounded);
  }

  /// Icône de chaque champ dans la liste d'informations.
  IconData iconFor(String key) => switch (key) {
    'source' || 'url' => Icons.public_rounded,
    'author' || 'attendeeName' || 'customerName' => Icons.person_rounded,
    'company' || 'brand' => Icons.business_rounded,
    'category' || 'tag' || 'condition' => Icons.sell_rounded,
    'date' ||
    'publishedAt' ||
    'deadline' ||
    'createdAt' => Icons.calendar_month_rounded,
    'time' => Icons.schedule_rounded,
    'city' ||
    'venue' ||
    'address' ||
    'country' ||
    'location' => Icons.place_rounded,
    'website' => Icons.language_rounded,
    'teamSize' => Icons.groups_rounded,
    'stage' => Icons.timeline_rounded,
    'seats' => Icons.event_seat_rounded,
    'stock' || 'quantity' => Icons.inventory_2_rounded,
    'email' => Icons.email_rounded,
    'phone' => Icons.phone_rounded,
    'credibility' || 'rating' => Icons.verified_rounded,
    'progress' => Icons.trending_up_rounded,
    'tokens' || 'bonusTokens' || 'pack' => Icons.toll_rounded,
    'ticket' => Icons.qr_code_2_rounded,
    'status' || 'checkedIn' => Icons.info_rounded,
    _ when moneyKeys.contains(key) => Icons.payments_rounded,
    _ => Icons.label_rounded,
  };

  /// Photo de l'élément (si le formulaire en a enregistré une).
  Widget? autoBanner(ModulePalette palette, IconData icon) {
    final url = record['imageUrl'] as String?;
    final data = record['imageData'] as String?;
    if (!ItemImage.hasPhoto(url, data)) return null;
    return ItemImage(
      imageUrl: url,
      imageData: data,
      icon: icon,
      colors: [palette.start, palette.end],
    );
  }

  bool isVisible(MapEntry<String, Object?> entry) =>
      !hiddenKeys.contains(entry.key) &&
      entry.value != null &&
      entry.value.toString().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final (palette, icon) = style;
    final headline =
        titleKeys.map((key) => record[key]).whereType<String>().firstOrNull ??
        title;
    final longTexts = record.entries
        .where((entry) => longTextKeys.contains(entry.key) && isVisible(entry))
        .toList();
    final details = record.entries
        .where(
          (entry) =>
              isVisible(entry) &&
              !longTextKeys.contains(entry.key) &&
              entry.value != headline,
        )
        .toList();
    // Informations clés affichées dans l'en-tête : un montant, une
    // catégorie et une date au maximum.
    final money = [
      'price',
      'total',
      'amount',
      'goal',
      'tokenPrice',
    ].map((key) => record[key]).whereType<num>().firstOrNull;
    final category = ['category', 'tag']
        .map((key) => record[key])
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final date = ['date', 'deadline', 'publishedAt']
        .map((key) => record[key])
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final highlights = [
      if (money != null)
        (Icons.payments_rounded, money == 0 ? 'Gratuit' : formatMoney(money)),
      if (category != null) (Icons.sell_rounded, category),
      if (date != null) (Icons.calendar_month_rounded, formatDate(date)),
    ].take(3).toList();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (banner ?? autoBanner(palette, icon) case final image?)
            Container(
              height: 240,
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: softShadow,
              ),
              child: image,
            ),
          _DetailsHeader(
            palette: palette,
            icon: icon,
            headline: headline,
            highlights: highlights,
          ),
          ...extras,
          if (longTexts.isNotEmpty)
            _SectionCard(
              title: 'Description',
              icon: Icons.notes_rounded,
              palette: palette,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in longTexts) ...[
                    if (longTexts.length > 1)
                      Text(
                        labelFor(entry.key),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText(
                        valueOf(entry.key, entry.value),
                        style: const TextStyle(
                          color: AppColors.ink,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          _SectionCard(
            title: 'Informations',
            icon: Icons.info_outline_rounded,
            palette: palette,
            child: Column(
              children: [
                for (final (index, entry) in details.indexed) ...[
                  if (index > 0) const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: palette.soft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          iconFor(entry.key),
                          size: 18,
                          color: palette.start,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelFor(entry.key),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            SelectableText(
                              valueOf(entry.key, entry.value),
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grand en-tête coloré de la page de détail.
class _DetailsHeader extends StatelessWidget {
  final ModulePalette palette;
  final IconData icon;
  final String headline;
  final List<(IconData, String)> highlights;
  const _DetailsHeader({
    required this.palette,
    required this.icon,
    required this.headline,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: palette.gradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: palette.start.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Icon(
              icon,
              size: 190,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: palette.start, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (highlights.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (chipIcon, label) in highlights)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(chipIcon, size: 15, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte blanche avec un titre et une icône colorée.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final ModulePalette palette;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.start, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
