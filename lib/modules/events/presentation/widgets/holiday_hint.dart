// Avertissement dans le formulaire d'événement : la date choisie tombe un
// jour férié dans le pays de la ville (Nager.Date + Nominatim).

import 'dart:async';

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/events/data/events_web_api.dart';
import 'package:crowdtech/modules/events/domain/event_planning.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:flutter/material.dart';

class HolidayHint extends StatefulWidget {
  final TextEditingController dateController;
  final TextEditingController cityController;
  const HolidayHint({
    required this.dateController,
    required this.cityController,
    super.key,
  });

  @override
  State<HolidayHint> createState() => _HolidayHintState();
}

class _HolidayHintState extends State<HolidayHint> {
  String? warning;
  Timer? _debounce;

  /// Pays déjà trouvés (ville → code) et jours fériés (pays/année).
  final _countries = <String, String>{};
  final _holidays = <String, List<Holiday>>{};

  @override
  void initState() {
    super.initState();
    widget.dateController.addListener(_schedule);
    widget.cityController.addListener(_schedule);
    _schedule();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.dateController.removeListener(_schedule);
    widget.cityController.removeListener(_schedule);
    super.dispose();
  }

  /// Attend que la saisie soit finie avant d'interroger les API.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _check);
  }

  Future<void> _check() async {
    final day = parseFlexibleDate(widget.dateController.text);
    final city = widget.cityController.text.trim();
    String? found;
    if (day != null && city.length >= 2) {
      try {
        final code =
            _countries[city.toLowerCase()] ??
            (await CrowdTechApi.geocodeCity(
              city,
            ))?['countryCode']?.toString() ??
            '';
        if (code.isNotEmpty) {
          _countries[city.toLowerCase()] = code;
          final key = '$code/${day.year}';
          final holidays = _holidays[key] ??= await EventsWebApi.holidays(
            day.year,
            code,
          );
          final holiday = EventPlanning.holidayOn(day, holidays);
          if (holiday != null) {
            found =
                'Le ${formatDate(day.toIso8601String())} est un jour férié '
                '(${holiday.name}) : moins de participants possibles.';
          }
        }
      } on ApiException {
        found = null;
      }
    }
    if (mounted && found != warning) setState(() => warning = found);
  }

  @override
  Widget build(BuildContext context) {
    final text = warning;
    if (text == null) return const SizedBox.shrink();
    return TipBanner(emoji: '🎉', text: text, palette: ModulePalette.events);
  }
}
