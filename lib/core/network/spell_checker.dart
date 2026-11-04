// Correcteur d'orthographe et de grammaire : LanguageTool (API publique
// gratuite, sans clé, français par défaut). L'utilisateur choisit mot par
// mot : garder son texte ou prendre une correction proposée.

import 'package:crowdtech/core/network/crowdtech_api.dart';

/// Faute détectée dans un texte.
class SpellingIssue {
  final int offset;
  final int length;
  final String original;
  final String message;
  final List<String> suggestions;
  const SpellingIssue({
    required this.offset,
    required this.length,
    required this.original,
    required this.message,
    required this.suggestions,
  });
}

class SpellChecker {
  SpellChecker._();

  /// Nombre maximal de corrections proposées par faute.
  static const maxSuggestions = 4;

  /// Fautes de [text] (vide si le texte est correct).
  static Future<List<SpellingIssue>> check(
    String text, {
    String language = 'fr',
  }) async {
    if (text.trim().isEmpty) return const [];
    final json = await CrowdTechApi.postForm(
      Uri.https('api.languagetool.org', '/v2/check'),
      {'text': text, 'language': language},
    );
    final matches = json is Map ? json['matches'] : null;
    if (matches is! List) {
      throw const ApiException('Réponse du correcteur invalide.');
    }
    return parse(text, matches);
  }

  /// Fautes à partir de la réponse de LanguageTool (`matches`).
  static List<SpellingIssue> parse(String text, List<Object?> matches) => [
    for (final match in matches)
      if (match is Map &&
          match['offset'] is int &&
          match['length'] is int &&
          (match['offset']! as int) + (match['length']! as int) <= text.length)
        SpellingIssue(
          offset: match['offset']! as int,
          length: match['length']! as int,
          original: text.substring(
            match['offset']! as int,
            (match['offset']! as int) + (match['length']! as int),
          ),
          message:
              match['message']?.toString() ??
              match['shortMessage']?.toString() ??
              'Faute possible.',
          suggestions: [
            for (final replacement in (match['replacements'] as List? ?? []))
              if (replacement is Map && replacement['value'] is String)
                replacement['value']! as String,
          ].take(maxSuggestions).toList(),
        ),
  ];

  /// Texte corrigé : chaque faute de [choices] est remplacée par la
  /// correction choisie ; une faute sans choix (ou choix null) garde le
  /// mot d'origine. Les remplacements partent de la fin pour garder les
  /// positions valides.
  static String apply(
    String text,
    List<SpellingIssue> issues,
    Map<SpellingIssue, String?> choices,
  ) {
    final chosen = [
      for (final issue in issues)
        if (choices[issue] case final String replacement)
          (issue: issue, replacement: replacement),
    ]..sort((a, b) => b.issue.offset.compareTo(a.issue.offset));
    var result = text;
    var limit = text.length;
    for (final (:issue, :replacement) in chosen) {
      // Deux fautes qui se chevauchent : seule la dernière est appliquée.
      if (issue.offset + issue.length > limit) continue;
      result = result.replaceRange(
        issue.offset,
        issue.offset + issue.length,
        replacement,
      );
      limit = issue.offset;
    }
    return result;
  }
}
