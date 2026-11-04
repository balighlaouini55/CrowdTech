// Fonctions de mise en forme des dates et des montants, utilisées partout
// dans l'application pour un affichage cohérent.

/// `5` → `05` (jours, mois, heures, minutes).
String twoDigits(int value) => value.toString().padLeft(2, '0');

/// Numéro affiché d'un élément : `42` → `00042` ; un identifiant partagé
/// entre appareils (très long) est écrit en base 36 : `2B9QX4M7K1`.
String displayNumber(Object? id, {int width = 5}) {
  final value = id is int ? id : 0;
  if (value.toString().length <= width) {
    return value.toString().padLeft(width, '0');
  }
  return value.toRadixString(36).toUpperCase();
}

/// `2026-11-12` (ou date ISO complète) → `12/11/2026`.
/// Un texte qui n'est pas une date ISO (ex. « 12 Nov 2026 ») est rendu tel quel.
String formatDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}

/// Date ISO complète → `12/11/2026 à 09:30`.
String formatDateTime(String? value) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return value ?? '';
  return '${formatDate(value)} à '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

/// Date → `2026-11-12`, le format enregistré dans la base.
String isoDate(DateTime date) =>
    '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';

/// `1499` → `1 499 €` ; `12.5` → `12,50 €`.
String formatMoney(num value) {
  final fixed = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  final parts = fixed.split('.');
  // Ajoute une espace tous les 3 chiffres.
  final digits = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '${parts.length > 1 ? '$digits,${parts[1]}' : digits} €';
}

/// Lit une date saisie `jj/mm/aaaa` ou une date ISO.
/// Retourne null si la date est invalide (ex. 31/02/2026).
DateTime? parseFlexibleDate(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
  if (match != null) {
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    if (date.day == day && date.month == month) return date;
    return null;
  }
  return DateTime.tryParse(text);
}

/// Texte de remplacement quand une chaîne est vide.
extension IfEmpty on String {
  String ifEmpty(String replacement) => isEmpty ? replacement : this;
}
