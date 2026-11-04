// Modération participative des commentaires d'actualités :
// - filtrage automatique à la publication (insultes masquées, spam refusé) ;
// - signalements par les lecteurs, masquage automatique au-delà d'un seuil ;
// - tri dynamique des commentaires (pertinence, récents, signalés).

import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/news/data/news_repository.dart';
import 'package:crowdtech/shared/utils/text_normalizer.dart';

/// Résultat de l'analyse automatique d'un commentaire.
enum ModerationVerdict { approved, masked, rejected }

class ModerationResult {
  final ModerationVerdict verdict;

  /// Texte à publier (mots interdits remplacés par des étoiles).
  final String text;

  /// Raison affichée à l'utilisateur quand le commentaire est refusé.
  final String? reason;

  const ModerationResult(this.verdict, this.text, [this.reason]);

  bool get accepted => verdict != ModerationVerdict.rejected;
}

/// Statut d'un commentaire enregistré dans `news_comments`.
class CommentStatus {
  CommentStatus._();
  static const visible = 'Visible';
  static const hidden = 'Masqué';
}

class CommentModeration {
  CommentModeration._();

  /// Nombre de signalements qui masque automatiquement un commentaire.
  static const reportThreshold = 3;

  /// Mots masqués automatiquement (liste volontairement courte).
  static const bannedWords = [
    'idiot',
    'imbécile',
    'crétin',
    'débile',
    'connard',
    'abruti',
    'stupide',
    'nul à chier',
    'stupid',
    'moron',
    'scam',
    'arnaque',
  ];

  /// Mots typiques du spam publicitaire.
  static const spamWords = [
    'gagnez de l\'argent',
    'cliquez ici',
    'promo code',
    'crypto gratuite',
    'free money',
    'click here',
    'whatsapp',
  ];

  static String _normalize(String text) =>
      normalizeText(text).replaceAll('’', '\'');

  /// Lettres et leurs variantes accentuées.
  static const _accents = {
    'a': '[aàâä]',
    'c': '[cç]',
    'e': '[eéèêë]',
    'i': '[iîï]',
    'o': '[oôö]',
    'u': '[uùûü]',
  };

  /// Reconnaît un mot interdit avec ou sans accents, au féminin ou au pluriel,
  /// mais pas à l'intérieur d'un autre mot (« scam » ne masque pas « scampi »).
  static RegExp _bannedPattern(String word) {
    final letters = _normalize(word)
        .split('')
        .map((letter) => _accents[letter] ?? RegExp.escape(letter))
        .join();
    return RegExp(
      '(?<![\\p{L}\\p{N}])$letters(?:e?s?)(?![\\p{L}\\p{N}])',
      caseSensitive: false,
      unicode: true,
    );
  }

  /// Analyse un commentaire avant sa publication.
  static ModerationResult analyze(String raw) {
    final text = raw.trim();
    if (text.length < 3) {
      return const ModerationResult(
        ModerationVerdict.rejected,
        '',
        'Commentaire trop court.',
      );
    }
    final normalized = _normalize(text);

    final links = RegExp(r'https?://|www\.').allMatches(normalized).length;
    if (links > 2) {
      return const ModerationResult(
        ModerationVerdict.rejected,
        '',
        'Trop de liens : ce commentaire ressemble à du spam.',
      );
    }
    for (final word in spamWords) {
      if (normalized.contains(_normalize(word))) {
        return const ModerationResult(
          ModerationVerdict.rejected,
          '',
          'Ce commentaire ressemble à de la publicité.',
        );
      }
    }
    if (RegExp(r'(.)\1{6,}').hasMatch(normalized)) {
      return const ModerationResult(
        ModerationVerdict.rejected,
        '',
        'Caractères répétés : merci d’écrire un vrai message.',
      );
    }
    final letters = text.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.length >= 12 && letters == letters.toUpperCase()) {
      return const ModerationResult(
        ModerationVerdict.rejected,
        '',
        'Évitez d’écrire tout en majuscules.',
      );
    }

    var cleaned = text;
    var masked = false;
    for (final word in bannedWords) {
      final pattern = _bannedPattern(word);
      if (pattern.hasMatch(cleaned)) {
        masked = true;
        cleaned = cleaned.replaceAllMapped(
          pattern,
          (match) => '*' * match[0]!.length,
        );
      }
    }
    return ModerationResult(
      masked ? ModerationVerdict.masked : ModerationVerdict.approved,
      cleaned,
    );
  }

  /// Signalements de tous les commentaires : commentId → comptes.
  static Future<Map<int, Set<String>>> reports() async {
    final result = <int, Set<String>>{};
    for (final row in await NewsRepository.reports.all()) {
      final id = (row['commentId'] as num?)?.toInt();
      if (id == null) continue;
      result.putIfAbsent(id, () => {}).add(row['reporterKey'].toString());
    }
    return result;
  }

  /// Signale un commentaire (une fois par compte). Le commentaire est
  /// masqué automatiquement dès [reportThreshold] signalements.
  /// Retourne le nombre de signalements.
  static Future<int> report(int commentId, {String reason = ''}) async {
    final me = CrowdTechSession.accountKey ?? '';
    final comment = await NewsRepository.comments.byId(commentId);
    if (comment == null) {
      throw const RuleException('Commentaire introuvable.');
    }
    if (comment['ownerKey'] == me) {
      throw const RuleException(
        'Vous ne pouvez pas signaler votre propre commentaire.',
      );
    }
    final existing = (await reports())[commentId] ?? const <String>{};
    if (existing.contains(me)) {
      throw const RuleException('Vous avez déjà signalé ce commentaire.');
    }
    await NewsRepository.reports.add({
      'commentId': commentId,
      'reporterKey': me,
      'reason': reason,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final count = existing.length + 1;
    if (count >= reportThreshold && comment['status'] != CommentStatus.hidden) {
      await setStatus(comment, CommentStatus.hidden);
    }
    return count;
  }

  /// Masque ou rétablit un commentaire (administrateur).
  static Future<void> setStatus(
    Map<String, Object?> comment,
    String status,
  ) async {
    final id = comment['id'];
    if (id is! int) return;
    await NewsRepository.comments.update(
      id,
      {...comment, 'status': status}..remove('id'),
    );
  }

  static Future<void> restore(int commentId) async {
    if (!Permissions.isAdmin) {
      throw const RuleException(Permissions.adminOnlyMessage);
    }
    final comment = await NewsRepository.comments.byId(commentId);
    if (comment != null) await setStatus(comment, CommentStatus.visible);
  }

  /// Score de pertinence d'un commentaire : longueur utile, absence de
  /// signalement et fraîcheur.
  static double relevance(
    Map<String, Object?> comment,
    int reportCount, {
    DateTime? now,
  }) {
    final text = comment['text']?.toString() ?? '';
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final lengthScore = (words.length / 30).clamp(0.0, 1.0);
    final created = DateTime.tryParse(comment['createdAt']?.toString() ?? '');
    final ageDays = created == null
        ? 30
        : (now ?? DateTime.now()).difference(created).inHours / 24;
    final freshness = 1 / (1 + ageDays / 7);
    final penalty = reportCount * 0.25;
    return lengthScore * 0.6 + freshness * 0.4 - penalty;
  }
}
