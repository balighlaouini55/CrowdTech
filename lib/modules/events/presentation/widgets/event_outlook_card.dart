// Carte « Météo et calendrier » d'un événement : prévisions Open-Meteo pour
// le jour et la ville, et jour férié éventuel (Nager.Date).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/events/data/events_web_api.dart';
import 'package:crowdtech/modules/events/domain/event_planning.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:flutter/material.dart';

class EventOutlookCard extends StatefulWidget {
  final Map<String, Object?> event;
  const EventOutlookCard({required this.event, super.key});

  @override
  State<EventOutlookCard> createState() => _EventOutlookCardState();
}

class _EventOutlookCardState extends State<EventOutlookCard> {
  bool loading = true;
  String? weather;
  String? advice;
  String? holiday;
  String? note;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final day = parseFlexibleDate(widget.event['date']?.toString());
    final city = widget.event['city']?.toString() ?? '';
    if (day == null || city.isEmpty) {
      setState(() => loading = false);
      return;
    }
    try {
      var lat = (widget.event['latitude'] as num?)?.toDouble();
      var lon = (widget.event['longitude'] as num?)?.toDouble();
      final place = await CrowdTechApi.geocodeCity(city);
      lat ??= place?['latitude'] as double?;
      lon ??= place?['longitude'] as double?;
      final countryCode = place?['countryCode']?.toString() ?? '';

      if (lat != null && lon != null) {
        final forecast = await EventsWebApi.forecast(lat, lon, day);
        if (forecast != null) {
          weather = forecast.summary;
          advice = forecast.advice;
        } else {
          final wait = EventPlanning.daysUntilForecast(day);
          note = wait > 0
              ? 'Météo disponible dans $wait jour(s) (prévisions à 16 jours).'
              : null;
        }
      }
      if (countryCode.isNotEmpty) {
        final holidays = await EventsWebApi.holidays(day.year, countryCode);
        final found = EventPlanning.holidayOn(day, holidays);
        if (found != null) holiday = 'Jour férié : ${found.name}';
      }
    } on ApiException {
      note = 'Météo indisponible hors ligne.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final lines = [
      if (weather != null) (Icons.wb_sunny_outlined, weather!),
      if (advice != null) (Icons.tips_and_updates_outlined, advice!),
      if (holiday != null) (Icons.celebration_outlined, holiday!),
      if (note != null) (Icons.schedule_rounded, note!),
    ];
    if (!loading && lines.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: ModulePalette.events.start),
                const SizedBox(width: 8),
                Text(
                  'Météo et calendrier',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              const LinearProgressIndicator()
            else
              for (final (icon, text) in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
