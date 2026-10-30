String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email requis.';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
      ? null
      : 'Email invalide.';
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Mot de passe requis.';
  if (value.length < 8) return 'Minimum 8 caractères.';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
    return 'Ajoutez au moins une lettre et un chiffre.';
  }
  return null;
}
