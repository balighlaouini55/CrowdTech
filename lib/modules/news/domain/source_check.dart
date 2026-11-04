// Règles de vérification des sources : fiabilité de départ d'un article
// importé (DEV Community) et sujet à chercher sur Wikipédia.

class SourceCheck {
  SourceCheck._();

  /// Fiabilité de départ d'un article DEV : 55 % de base, plus 1 point
  /// pour 10 réactions et 1 point pour 4 commentaires, entre 55 et 92 %.
  /// La note des lecteurs la corrige ensuite (score de fiabilité).
  static int devToCredibility({
    required num reactions,
    required num comments,
  }) => (55 + reactions ~/ 10 + comments ~/ 4).clamp(55, 92).toInt();

  /// Tags DEV (anglais) → catégories CrowdTech.
  static const _tags = {
    'ai': 'IA',
    'machinelearning': 'IA',
    'llm': 'IA',
    'security': 'Sécurité',
    'cybersecurity': 'Sécurité',
    'cloud': 'Cloud',
    'aws': 'Cloud',
    'devops': 'Cloud',
    'flutter': 'Mobile',
    'mobile': 'Mobile',
    'android': 'Mobile',
    'ios': 'Mobile',
    'blockchain': 'Fintech',
    'fintech': 'Fintech',
    'startup': 'Startups',
    'hardware': 'Matériel',
  };

  /// Catégorie CrowdTech d'une liste de tags DEV (« Web » par défaut).
  static String tagOf(Object? tags) {
    if (tags is List) {
      for (final tag in tags) {
        final known = _tags[tag.toString().toLowerCase()];
        if (known != null) return known;
      }
    }
    return 'Web';
  }

  /// Mots vides retirés du titre avant la recherche Wikipédia.
  static const _stopWords = {
    'le',
    'la',
    'les',
    'un',
    'une',
    'des',
    'du',
    'de',
    'd',
    'l',
    'et',
    'ou',
    'en',
    'dans',
    'par',
    'pour',
    'sur',
    'avec',
    'au',
    'aux',
    'son',
    'sa',
    'ses',
    'leur',
    'leurs',
    'qui',
    'que',
    'se',
    'ce',
    'cette',
    'est',
    'sont',
    'a',
    'à',
    'plus',
    'nouveau',
    'nouvelle',
    'nouvelles',
    'lance',
    'gagne',
  };

  /// Sujet à chercher sur Wikipédia pour un titre : les mots porteurs de
  /// sens (sans les mots vides), au plus 4.
  /// « Les centres de données passent au refroidissement liquide »
  /// → « centres données passent refroidissement ».
  static String topicOf(String title) {
    final words = title
        .replaceAll(RegExp("[’'«»:;,.!?()]"), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1)
        .where((word) => !_stopWords.contains(word.toLowerCase()))
        .take(4);
    return words.join(' ');
  }

  /// Notions tech reconnues dans un titre → page Wikipédia.
  static const _knownTopics = {
    'deep tech': 'Entreprise de technologie profonde',
    'startup': 'Start-up',
    'start-up': 'Start-up',
    'amorçage': 'Capital-risque',
    'passkey': 'Passkey',
    'risc-v': 'RISC-V',
    'flutter': 'Flutter (logiciel)',
    'centres de données': 'Centre de données',
    'centre de données': 'Centre de données',
    'cloud': 'Cloud computing',
    'bitcoin': 'Bitcoin',
    'crypto': 'Cryptomonnaie',
    'fuite de données': 'Fuite de données',
    'smartphone': 'Smartphone',
    'crowdfunding': 'Financement participatif',
    'financement participatif': 'Financement participatif',
    'jetons': 'Jeton (cryptographie)',
    'ia générative': 'Intelligence artificielle générative',
    'intelligence artificielle': 'Intelligence artificielle',
    'développeurs': 'Développeur',
  };

  /// Catégories CrowdTech → page Wikipédia générale.
  static const _tagTopics = {
    'IA': 'Intelligence artificielle',
    'Sécurité': 'Sécurité de l\'information',
    'Cloud': 'Cloud computing',
    'Mobile': 'Smartphone',
    'Startups': 'Start-up',
    'Fintech': 'Technologie financière',
    'Green tech': 'Informatique durable',
    'Matériel': 'Matériel informatique',
  };

  /// Pages Wikipédia à essayer dans l'ordre pour vérifier un article :
  /// notions reconnues dans le titre, mots techniques (RISC-V, 5G…), puis
  /// la catégorie de l'article.
  static List<String> wikiCandidates(String title, {String? tag}) {
    final lower = title.toLowerCase();
    final found = <(int, String)>[
      for (final MapEntry(:key, :value) in _knownTopics.entries)
        if (RegExp('(^|[^a-zà-ÿ])${RegExp.escape(key)}s?(\$|[^a-zà-ÿ])')
                .firstMatch(lower)
            case final match?)
          (match.start, value),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final technical = [
      for (final word in title.split(RegExp(r'[\s,;:!?()«»]+')))
        if (RegExp(r'^[A-Z0-9][A-Z0-9-]*[A-Z0-9]$').hasMatch(word) &&
            RegExp(r'[A-Z]').hasMatch(word))
          word,
    ];
    final tagTopic = _tagTopics[tag];
    return {
      for (final (_, topic) in found) topic,
      ...technical,
      ?tagTopic,
    }.toList();
  }

  /// Vrai si le titre d'une page trouvée partage un mot (de 4 lettres ou
  /// plus) avec la recherche : évite les résultats hors sujet.
  static bool isRelevant(String pageTitle, String query) {
    Set<String> words(String text) => {
      for (final word
          in text
              .toLowerCase()
              .replaceAll('-', '')
              .split(RegExp(r'[^a-zà-ÿ0-9]+')))
        if (word.length >= 4) word.replaceAll(RegExp(r's$'), ''),
    };
    return words(pageTitle).intersection(words(query)).isNotEmpty;
  }
}
