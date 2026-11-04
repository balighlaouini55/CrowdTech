// Règles de validation des formulaires (champs requis, email, lien, date…).
// Chaque fonction retourne null si la valeur est correcte, sinon le message
// d'erreur affiché sous le champ.

import 'package:crowdtech/shared/utils/formatters.dart';

/// Champ obligatoire, avec une longueur minimale facultative.
String? requiredText(String? value, {int minimum = 1}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Ce champ est requis.';
  if (text.length < minimum) return 'Saisissez au moins $minimum caractères.';
  return null;
}

/// Lien facultatif : s'il est rempli, il doit commencer par http(s)://.
String? optionalUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return 'Saisissez un lien commençant par http:// ou https://';
  }
  return null;
}

/// Date facultative : si elle est remplie, elle doit être au format jj/mm/aaaa.
String? optionalDate(String? value) {
  if ((value?.trim() ?? '').isEmpty) return null;
  return parseFlexibleDate(value) == null
      ? 'Date invalide (format jj/mm/aaaa).'
      : null;
}

/// Adresse email obligatoire et bien formée.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email requis.';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
      ? null
      : 'Email invalide.';
}

/// Mot de passe : 8 caractères minimum, au moins une lettre et un chiffre.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Mot de passe requis.';
  if (value.length < 8) return 'Minimum 8 caractères.';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
    return 'Ajoutez au moins une lettre et un chiffre.';
  }
  return null;
}

/// Téléphone : 8 à 15 chiffres, « + » au début autorisé (espaces ignorés).
/// Champ facultatif si [required] vaut false.
String? validatePhone(String? value, {bool required = true}) {
  final text = (value ?? '').replaceAll(RegExp(r'[\s.-]'), '');
  if (text.isEmpty) return required ? 'Téléphone requis.' : null;
  return RegExp(r'^\+?\d{8,15}$').hasMatch(text)
      ? null
      : 'Numéro invalide (8 à 15 chiffres, ex. +216 20 123 456).';
}

/// Date de naissance au format jj/mm/aaaa : pas dans le futur, âge entre
/// [minimumAge] et 120 ans. Champ facultatif si [required] vaut false.
String? validateBirthDate(
  String? value, {
  int minimumAge = 16,
  bool required = true,
}) {
  if ((value?.trim() ?? '').isEmpty) {
    return required ? 'Date de naissance requise.' : null;
  }
  final date = parseFlexibleDate(value);
  if (date == null) return 'Date invalide (format jj/mm/aaaa).';
  final now = DateTime.now();
  var age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age--;
  }
  if (date.isAfter(now)) return 'La date ne peut pas être dans le futur.';
  if (age < minimumAge) return 'Vous devez avoir au moins $minimumAge ans.';
  if (age > 120) return 'Date de naissance invalide.';
  return null;
}

/// Code postal : 4 ou 5 chiffres (Tunisie, France…). Champ facultatif si
/// [required] vaut false.
String? validatePostalCode(String? value, {bool required = true}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'Code postal requis.' : null;
  return RegExp(r'^\d{4,5}$').hasMatch(text)
      ? null
      : 'Code postal invalide (4 ou 5 chiffres).';
}
