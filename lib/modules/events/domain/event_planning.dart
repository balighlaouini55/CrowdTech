// Préparation d'un événement : météo prévue (codes WMO d'Open-Meteo) et
// jours fériés (Nager.Date).

/// Météo prévue pour un jour.
class DayForecast {
  final int code;
  final double? maxTemp;
  final double? minTemp;
  final int? rainChance;
  const DayForecast({
    required this.code,
    this.maxTemp,
    this.minTemp,
    this.rainChance,
  });

  String get emoji => EventPlanning.weatherOf(code).emoji;
  String get label => EventPlanning.weatherOf(code).label;

  /// « ☀️ Ensoleillé · 12–21 °C · pluie 10 % ».
  String get summary => [
    '$emoji $label',
    if (minTemp != null && maxTemp != null)
      '${minTemp!.round()}–${maxTemp!.round()} °C',
    if (rainChance != null) 'pluie $rainChance %',
  ].join(' · ');

  /// Conseil pour les participants (pluie probable, forte chaleur…).
  String? get advice {
    if ((rainChance ?? 0) >= 60 || code >= 61) {
      return 'Pluie probable : prévoyez un parapluie.';
    }
    if ((maxTemp ?? 0) >= 33) return 'Forte chaleur : pensez à vous hydrater.';
    if ((minTemp ?? 20) <= 2) return 'Grand froid : couvrez-vous bien.';
    return null;
  }
}

/// Jour férié.
class Holiday {
  final DateTime day;
  final String name;
  final String localName;
  const Holiday({required this.day, required this.name, this.localName = ''});
}

class EventPlanning {
  EventPlanning._();

  /// Les prévisions Open-Meteo couvrent les 16 prochains jours.
  static const forecastDays = 16;

  static bool hasForecast(DateTime day, {DateTime? now}) {
    final today = _dayOf(now ?? DateTime.now());
    final target = _dayOf(day);
    return !target.isBefore(today) &&
        target.difference(today).inDays < forecastDays;
  }

  /// Nombre de jours avant que la météo de [day] soit disponible (0 si
  /// elle l'est déjà ou si le jour est passé).
  static int daysUntilForecast(DateTime day, {DateTime? now}) {
    final today = _dayOf(now ?? DateTime.now());
    final wait = _dayOf(day).difference(today).inDays - (forecastDays - 1);
    return wait > 0 ? wait : 0;
  }

  /// Codes météo WMO → emoji et libellé.
  static ({String emoji, String label}) weatherOf(int code) => switch (code) {
    0 => (emoji: '☀️', label: 'Ensoleillé'),
    1 || 2 => (emoji: '🌤️', label: 'Éclaircies'),
    3 => (emoji: '☁️', label: 'Couvert'),
    45 || 48 => (emoji: '🌫️', label: 'Brouillard'),
    >= 51 && <= 57 => (emoji: '🌦️', label: 'Bruine'),
    >= 61 && <= 67 => (emoji: '🌧️', label: 'Pluie'),
    >= 71 && <= 77 => (emoji: '❄️', label: 'Neige'),
    >= 80 && <= 82 => (emoji: '🌦️', label: 'Averses'),
    85 || 86 => (emoji: '🌨️', label: 'Averses de neige'),
    >= 95 => (emoji: '⛈️', label: 'Orage'),
    _ => (emoji: '🌡️', label: 'Variable'),
  };

  /// Jour férié qui tombe le jour [day], ou null.
  static Holiday? holidayOn(DateTime day, List<Holiday> holidays) {
    final target = _dayOf(day);
    for (final holiday in holidays) {
      if (_dayOf(holiday.day) == target) return holiday;
    }
    return null;
  }

  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
