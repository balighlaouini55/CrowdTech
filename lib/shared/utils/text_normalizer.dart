// Normalisation du texte pour les recherches et la modération : minuscules
// et sans accents (« Crédit » et « credit » sont le même mot).

String normalizeText(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('œ', 'oe');
