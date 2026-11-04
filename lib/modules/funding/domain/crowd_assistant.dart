// Assistant « Crowdy » du module Crowdfunding.
//
// IA : Google Gemini (offre gratuite, clé créée sur Google AI Studio).
// Deux protections pour ne répondre QUE sur le crowdfunding :
//  1. un filtre local refuse tout de suite les questions hors sujet,
//     sans même appeler Gemini ;
//  2. les consignes données à Gemini lui imposent la même règle.
// Sans clé ou sans connexion, des réponses de secours sont calculées
// à partir des données de l'application.

import 'dart:async';
import 'dart:convert';

import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Un message de la conversation.
class ChatMessage {
  final bool fromUser;
  final String text;

  /// Réponse produite sans l'IA (refus ou mode hors ligne).
  final bool offline;

  /// Achat demandé : le chat affiche une carte de confirmation.
  final PurchaseRequest? purchase;

  /// Suivi demandé : le chat ajoute ou retire le projet des favoris.
  final FollowRequest? follow;

  /// Pourquoi Gemini n'a pas répondu (quota, clé, réseau…).
  final String? offlineReason;
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.offline = false,
    this.purchase,
    this.follow,
    this.offlineReason,
  });
}

/// Échec d'un appel à Gemini ([statusCode] 429 : quota épuisé).
class GeminiException implements Exception {
  final String message;
  final int? statusCode;
  const GeminiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// « Suis le projet Green Pulse » (follow) ou « Ne plus suivre » (unfollow).
class FollowRequest {
  final FundingProject project;
  final bool follow;
  const FollowRequest({required this.project, required this.follow});
}

/// Achat demandé dans le chat (« Achète le pack Découverte de Green
/// Pulse »). Le projet, le pack ou le budget peuvent manquer : la carte de
/// confirmation les fait alors choisir.
class PurchaseRequest {
  final FundingProject? project;
  final TokenPack? pack;
  final double? budget;
  const PurchaseRequest({this.project, this.pack, this.budget});
}

/// Données du module transmises à l'assistant.
class CrowdContext {
  final List<FundingProject> projects;
  final List<TokenPack> packs;
  final List<Map<String, Object?>> myInvestments;

  /// Projets suivis (❤️) par l'utilisateur.
  final Set<int> favoriteIds;

  /// Profil investisseur (« Prudent »…), `null` sans questionnaire.
  final String? investorProfile;
  final double limitPerProject;
  final String? referralCode;
  final int referralBonuses;
  const CrowdContext({
    required this.projects,
    required this.packs,
    this.myInvestments = const [],
    this.favoriteIds = const {},
    this.investorProfile,
    this.limitPerProject = 5000,
    this.referralCode,
    this.referralBonuses = 0,
  });

  CrowdContext copyWith({
    List<FundingProject>? projects,
    List<Map<String, Object?>>? myInvestments,
    Set<int>? favoriteIds,
  }) => CrowdContext(
    projects: projects ?? this.projects,
    packs: packs,
    myInvestments: myInvestments ?? this.myInvestments,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    investorProfile: investorProfile,
    limitPerProject: limitPerProject,
    referralCode: referralCode,
    referralBonuses: referralBonuses,
  );

  /// Montant que l'utilisateur a investi dans [project].
  double investedIn(FundingProject project) => myInvestments
      .where((row) => row['projectId'] == project.id)
      .fold(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));

  /// Jetons que l'utilisateur détient dans [project].
  int tokensIn(FundingProject project) => myInvestments
      .where((row) => row['projectId'] == project.id)
      .fold(0, (sum, row) => sum + ((row['tokens'] as num?)?.toInt() ?? 0));

  List<FundingProject> get favorites => [
    for (final project in projects)
      if (favoriteIds.contains(project.id)) project,
  ];

  List<FundingProject> get openProjects => [
    for (final project in projects)
      if (project.acceptsInvestments) project,
  ];

  int percentOf(FundingProject project) => project.goal <= 0
      ? 0
      : (project.amountRaised / project.goal * 100).round().clamp(0, 100);

  String statusOf(FundingProject project) => project.isClosed
      ? 'clôturé'
      : project.isFunded
      ? 'financé'
      : 'en cours';

  /// Résumé chiffré, déjà calculé, pour que l'IA n'ait pas à compter.
  String describe() {
    final buffer = StringBuffer('PROJETS :\n');
    for (final project in projects) {
      final days = project.daysLeft;
      buffer.writeln(
        '- ${project.title} (${project.company}, '
        '${project.category ?? 'sans catégorie'}) : '
        '${formatMoney(project.amountRaised)} collectés sur '
        '${formatMoney(project.goal)} (${percentOf(project)} %), '
        'reste ${formatMoney((project.goal - project.amountRaised).clamp(0, project.goal))}, '
        'jeton à ${formatMoney(project.tokenPrice)}, '
        'statut ${statusOf(project)}'
        '${days != null && days >= 0 ? ', $days jours restants' : ''}'
        '${project.stage == null ? '' : ', stade ${project.stage}'}. '
        'Objectif : ${project.feature}.',
      );
    }
    final ranked = [...projects]
      ..sort((a, b) => percentOf(b).compareTo(percentOf(a)));
    if (ranked.isNotEmpty) {
      buffer.writeln(
        'Le plus avancé : ${ranked.first.title} (${percentOf(ranked.first)} %).',
      );
    }
    buffer.writeln('PACKS DE JETONS (prix déjà calculés pour chaque projet) :');
    for (final pack in packs) {
      buffer.writeln(
        '- ${pack.name} : ${pack.tokens} jetons'
        '${pack.bonusPercent > 0 ? ', +${pack.bonusPercent} % de jetons bonus' : ''}'
        '${pack.discountPercent > 0 ? ', ${pack.discountPercent} % de réduction' : ''}'
        ' → ${pack.totalTokens} jetons reçus. Prix : ${[for (final project in projects) '${formatMoney(pack.priceFor(project.tokenPrice))} pour ${project.title}'].join(', ')}.',
      );
    }
    if (myInvestments.isNotEmpty) {
      final total = myInvestments.fold<double>(
        0,
        (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
      );
      final titles = {
        for (final row in myInvestments) row['projectTitle']?.toString() ?? '',
      }..remove('');
      buffer.writeln(
        'INVESTISSEMENTS DE L’UTILISATEUR : ${myInvestments.length} achat(s), '
        '${formatMoney(total)} au total, dans : ${titles.join(', ')}.',
      );
      for (final project in projects) {
        final invested = investedIn(project);
        if (invested <= 0) continue;
        buffer.writeln(
          '- ${project.title} : ${formatMoney(invested)} investis, '
          '${tokensIn(project)} jetons détenus, plafond restant '
          '${formatMoney((limitPerProject - invested).clamp(0, limitPerProject))}.',
        );
      }
    } else {
      buffer.writeln('L’utilisateur n’a encore rien investi.');
    }
    buffer
      ..writeln(
        'PROFIL INVESTISSEUR : ${investorProfile ?? 'questionnaire non rempli'}'
        ', plafond de ${formatMoney(limitPerProject)} par projet.',
      )
      ..writeln(
        'PROJETS SUIVIS (❤️) : '
        '${favorites.isEmpty ? 'aucun' : favorites.map((project) => project.title).join(', ')}.',
      );
    if (referralCode != null) {
      buffer.writeln(
        'PARRAINAGE : code $referralCode, $referralBonuses bonus de +10 % '
        'de jetons disponible(s).',
      );
    }
    return buffer.toString();
  }
}

class CrowdAssistant {
  CrowdAssistant._();

  static const name = 'Crowdy';

  /// Phrase de refus, identique pour le filtre local et pour l'IA.
  static const refusal =
      'Je suis l’assistant Crowdfunding de CrowdTech : je réponds seulement '
      'aux questions sur le financement participatif et l’investissement '
      'dans nos projets. 🙂';

  static const baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Clé gratuite créée sur https://aistudio.google.com/apikey, fournie au
  /// lancement : `flutter run --dart-define-from-file=config.json`.
  static const apiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Modèle imposé (facultatif), par exemple `gemini-3.6-flash`.
  static const forcedModel = String.fromEnvironment('GEMINI_MODEL');

  /// Modèles rapides et stables, essayés en premier et dans cet ordre.
  /// Mesuré avec l'offre gratuite (novembre 2026) : gemini-3.6-flash répond
  /// en 1 à 4 s, alors que le plus récent (3.8) mettait 25 à 50 s.
  /// Les « Lite » ont leur propre quota gratuit et répondent en 1 à 2 s :
  /// ils prennent le relais quand le quota de 3.6-flash est épuisé (429).
  static const preferredModels = [
    'gemini-3.6-flash',
    'gemini-flash-lite-latest',
    'gemini-3.1-flash-lite',
    'gemini-flash-latest',
  ];

  /// Modèle au quota épuisé ou trop lent : mis de côté quelques minutes
  /// pour ne pas attendre sa réponse à chaque message.
  static const pause = Duration(minutes: 10);
  static final _pausedUntil = <String, DateTime>{};

  @visibleForTesting
  static String? apiKeyOverride;
  static String get _key => apiKeyOverride ?? apiKey;
  static bool get isConfigured => _key.isNotEmpty;

  static http.Client client = http.Client();

  /// Délai par modèle : au-delà, on passe au modèle suivant.
  static const timeout = Duration(seconds: 12);
  static List<String>? _models;

  /// Oublie les modèles choisis (par exemple pour les tests).
  @visibleForTesting
  static void resetModel() {
    _models = null;
    _pausedUntil.clear();
  }

  // -------------------------------------------------------------------------
  // 1. Filtre de sujet

  /// Mots propres au sujet. Les mots trop vagues (« meilleur », « prix »,
  /// « conseil »…) sont volontairement absents : « le meilleur film » ou
  /// « le prix d'une pizza » ne doivent pas passer.
  static const _topicWords = [
    'crowd',
    'financ',
    'invest',
    'jeton',
    'token',
    'pack',
    'projet',
    'collecte',
    'objectif de',
    'bonus',
    'rendement',
    ' roi ',
    'risqu',
    'portefeuille',
    'diversif',
    'startup',
    'start-up',
    'levée de fonds',
    'levee de fonds',
    ' capital ',
    'capital-',
    'dividende',
    'rentab',
    '€',
    'contribu',
    'soutenir un',
    'participatif',
    'participative',
    'clôtur',
    'clotur',
    'date limite',
    'prototype',
    'simulat',
    'épargne',
    'epargne',
    'crowdtech',
    'crowdy',
    'donat',
    'rembours',
    'arnaque',
    'parrain',
    'filleul',
    'jalon',
    'plafond',
    'contrepartie',
    'attestation',
    'revendre',
    'revente',
    'porteur',
    'tout ou rien',
    'favori',
    'projets suivis',
    'questionnaire',
    'profil investisseur',
    'déblocage',
    'débloqu',
    'debloqu',
    'des fonds',
    'commission',
    'mode démo',
    'mode demo',
    'jours restants',
    'se termine',
    'fin de la collecte',
    'mon code',
    'code de parrain',
    'mes achats',
    'historique d',
    'marché des',
    'marche des',
  ];

  static const _smallTalk = [
    'bonjour',
    'salut',
    'hello',
    'coucou',
    'bonsoir',
    'merci',
    'aide',
    'help',
    'qui es-tu',
    'qui es tu',
    'tu fais quoi',
    'que sais-tu',
    'comment ça marche',
    'comment ca marche',
  ];

  /// Questions d'argent (« comment gagner de l'argent ? », « où placer
  /// 500 € ? ») : Crowdy y répond en les ramenant à CrowdTech. « gagner »
  /// seul est absent pour refuser « qui a gagné la coupe du monde ? ».
  static const _moneyWords = [
    'argent',
    'gagner de',
    'gagner des',
    'gagner plus',
    'gagner beaucoup',
    'gagner ma vie',
    'gagne de',
    'gagne combien',
    'combien je gagne',
    'combien je peux gagner',
    'combien vais-je gagner',
    ' gain',
    'bénéfic',
    'benefic',
    'profit',
    'placer mon',
    'placer mes',
    'placer de',
    'placement',
    'fructifier',
    'économies',
    'economies',
    'économiser',
    'revenu',
    'riche',
    'enrichir',
    'budget',
    ' euros',
    ' euro ',
    'plus-value',
    'plus value',
  ];

  static String _normalize(String text) =>
      ' ${text.toLowerCase().trim().replaceAll('’', "'")} ';

  /// Vrai si la question parle d'argent, de gains ou d'un budget.
  static bool isAboutMoney(String question) =>
      _moneyWords.any(_normalize(question).contains);

  /// Vrai si la question parle du crowdfunding, des projets ou des packs
  /// de l'application, d'argent à faire fructifier, ou si c'est une simple
  /// formule de politesse.
  static bool isOnTopic(String question, CrowdContext context) {
    final text = _normalize(question);
    if (_topicWords.any(text.contains)) return true;
    if (isAboutMoney(question)) return true;
    // Politesse (« Bonjour », « Merci ! ») : seulement pour un message court.
    final isShort = question.trim().split(RegExp(r'\s+')).length <= 5;
    if (isShort && _smallTalk.any(text.contains)) return true;
    final names = [
      for (final project in context.projects) ...[
        project.title,
        project.company,
        ?project.category,
      ],
      for (final pack in context.packs) pack.name,
    ];
    return names.any(
      (name) => name.trim().length > 2 && text.contains(name.toLowerCase()),
    );
  }

  // -------------------------------------------------------------------------
  // 2. Demande d'achat (traitée par l'application, jamais par l'IA)

  static const _buyWords = [
    'achète',
    'achete',
    'achetez',
    'acheter',
    'je prends',
    'prends-moi',
    'prends moi',
    'prends le',
    'investis ',
    'je veux investir',
    'je voudrais investir',
    'je souhaite investir',
    'commande',
  ];

  /// Une question (« Comment acheter ? », « Quel pack acheter ? ») reste une
  /// question : Crowdy y répond au lieu d'ouvrir un achat.
  static const _questionWords = [
    'comment',
    'pourquoi',
    'quel',
    'quelle',
    'est-ce',
    'combien',
    'faut-il',
    'dois-je',
    'peut-on',
    'puis-je',
    'conseil',
  ];

  static bool _mentions(String text, String name) =>
      name.trim().length > 2 && text.contains(name.trim().toLowerCase());

  /// Projet cité dans [text] (titre, entreprise ou deux premiers mots).
  static FundingProject? _mentionedProject(String text, CrowdContext context) =>
      context.projects.where((project) {
        final words = project.title.split(RegExp(r'\s+'));
        return _mentions(text, project.title) ||
            _mentions(text, project.company) ||
            (words.length > 2 && _mentions(text, words.take(2).join(' ')));
      }).firstOrNull;

  static const _followWords = [
    'favori',
    'suis le projet',
    'suis ce projet',
    'suivre le projet',
    'suivre ce projet',
    'ne plus suivre',
    'arrête de suivre',
    'arrete de suivre',
  ];

  static const _unfollowWords = [
    'retire',
    'enlève',
    'enleve',
    'supprime',
    'ne plus suivre',
    'arrête de suivre',
    'arrete de suivre',
  ];

  /// « Ajoute Green Pulse à mes favoris », « Ne plus suivre AI Ops » : le
  /// projet à suivre (ou à ne plus suivre), sinon `null`.
  static FollowRequest? followRequest(String message, CrowdContext context) {
    final text = _normalize(message);
    if (!_followWords.any(text.contains) || _questionWords.any(text.contains)) {
      return null;
    }
    final project = _mentionedProject(text, context);
    if (project == null || project.id == null) return null;
    return FollowRequest(
      project: project,
      follow: !_unfollowWords.any(text.contains),
    );
  }

  /// La demande d'achat contenue dans [message], ou `null` s'il n'y en a pas.
  static PurchaseRequest? purchaseRequest(
    String message,
    CrowdContext context,
  ) {
    final text = _normalize(message);
    if (!_buyWords.any(text.contains) || _questionWords.any(text.contains)) {
      return null;
    }
    final project = _mentionedProject(text, context);
    final pack = context.packs
        .where((pack) => _mentions(text, pack.name))
        .firstOrNull;
    final amount = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:€|euros?\b)')
        .firstMatch(text)
        ?.group(1);
    return PurchaseRequest(
      project: project,
      pack: pack,
      budget: amount == null
          ? null
          : double.tryParse(amount.replaceAll(',', '.')),
    );
  }

  /// Le plus grand pack de [project] qui tient dans [budget].
  static TokenPack? packForBudget(
    FundingProject project,
    List<TokenPack> packs,
    double budget,
  ) {
    final fitting = [
      for (final pack in packs)
        if (pack.priceFor(project.tokenPrice) <= budget) pack,
    ]..sort((a, b) => a.tokens.compareTo(b.tokens));
    return fitting.lastOrNull;
  }

  // -------------------------------------------------------------------------
  // 3. Réponse

  /// Répond à [question]. [history] contient les échanges précédents.
  static Future<ChatMessage> answer(
    String question,
    CrowdContext context, {
    List<ChatMessage> history = const [],
  }) async {
    final follow = followRequest(question, context);
    if (follow != null) {
      return ChatMessage(fromUser: false, text: '', follow: follow);
    }
    final purchase = purchaseRequest(question, context);
    if (purchase != null) {
      return ChatMessage(
        fromUser: false,
        text: 'Avec plaisir ! 🛒 Vérifiez les détails puis confirmez :',
        purchase: purchase,
      );
    }
    // Une courte relance (« et le deuxième ? », 4 mots maximum) dans une conversation déjà
    // lancée est confiée à l'IA, qui applique elle aussi la règle du sujet.
    final isFollowUp =
        history.any((message) => message.fromUser) &&
        question.trim().split(RegExp(r'\s+')).length <= 4;
    if (!isOnTopic(question, context) && !isFollowUp) {
      return const ChatMessage(fromUser: false, text: refusal, offline: true);
    }
    try {
      final reply = await _askGemini(question, context, history);
      return ChatMessage(fromUser: false, text: reply);
    } on Exception catch (error) {
      debugPrint('Gemini indisponible : $error');
      if (!isOnTopic(question, context)) {
        return const ChatMessage(fromUser: false, text: refusal, offline: true);
      }
      return ChatMessage(
        fromUser: false,
        text: offlineAnswer(question, context),
        offline: true,
        offlineReason: offlineReasonFor(error),
      );
    }
  }

  /// Explication courte, en français, d'un échec de Gemini.
  static String offlineReasonFor(Exception error) => switch (error) {
    GeminiException(statusCode: 429) =>
      'Quota gratuit Gemini épuisé pour le moment : réessayez dans quelques '
          'minutes.',
    GeminiException(statusCode: 400 || 401 || 403) =>
      'Clé Gemini refusée : vérifiez-la dans config.json.',
    GeminiException(statusCode: null, :final message) => message,
    GeminiException() => 'Gemini est momentanément indisponible.',
    TimeoutException() => 'Gemini a mis trop de temps à répondre.',
    _ => 'Pas de connexion Internet.',
  };

  static String systemPrompt(CrowdContext context) =>
      '''
Tu es « $name », l’assistant du module Crowdfunding de l’application CrowdTech.
Règles :
- Réponds en français, de façon courte et claire (6 phrases maximum), sur un ton chaleureux.
- Vouvoie toujours l’utilisateur. Ne dis pas bonjour et ne te présente pas, sauf s’il te salue ; va droit à la réponse.
- Tu parles UNIQUEMENT de : crowdfunding, projets de CrowdTech, packs de jetons, investissement, risques, diversification, fonctionnement du module.
- Pour toute autre question (cuisine, sport, code, devoirs, actualité générale, etc.), réponds EXACTEMENT : « $refusal »
- Les questions sur l’argent sont DANS le sujet : « comment gagner de l’argent ? », « où placer mes économies ? », « j’ai 300 €, je fais quoi ? », « combien je peux gagner ? ». Réponds-y TOUJOURS en restant dans CrowdTech : explique comment on peut espérer un gain ici (valeur des jetons si le projet réussit, revente sur le Marché des jetons, jetons offerts des gros packs et du parrainage, contreparties, Simulateur de rendement dans le menu ⋮), propose 1 ou 2 projets ouverts et les packs qui entrent dans le budget, et rappelle en une phrase qu’un gain n’est jamais garanti. Ne parle pas des autres placements.
- Seules les questions qui demandent explicitement un AUTRE placement (bourse, cryptomonnaies, immobilier, livret, impôts, crédit, paris, jeux d’argent) sont hors sujet : réponds alors en une phrase que tu ne conseilles que sur CrowdTech, puis propose une piste dans CrowdTech.
- Utilise seulement les chiffres ci-dessous, ne les invente jamais et ne recalcule pas les pourcentages.
- Ne promets jamais de gain. Rappelle le risque de perte seulement quand l’utilisateur parle d’une somme à investir ou demande un conseil, pas à chaque message.
- Pour un budget donné, compare-le aux prix des packs ci-dessous et indique concrètement quels packs entrent dans ce budget, pour quel projet.
- L’utilisateur peut acheter un pack directement dans ce chat en écrivant par exemple « Achète le pack Découverte de Green Pulse Sensor » ou « Investis 200 € dans AI Ops Dashboard » : une carte de confirmation s’affiche. Toi, tu n’achètes jamais rien et tu ne dis jamais qu’un achat est fait. Quand l’utilisateur hésite ou demande comment investir, propose-lui la phrase exacte à écrire (ou le bouton « Investir » de la carte du projet), sans le répéter à chaque message.

FONCTIONNEMENT DU MODULE :
- Tout ou rien : si l’objectif n’est pas atteint à la date limite, les investisseurs sont remboursés automatiquement.
- Chaque nouveau projet est vérifié et validé par l’administrateur avant d’être visible.
- Plafond par projet selon le profil investisseur (menu ⋮ → Mon profil investisseur) : Prudent 1 000 €, Équilibré 5 000 €, Dynamique 20 000 €, sans questionnaire 5 000 €.
- Contreparties : Supporter dès 100 €, Ambassadeur dès 500 €, Mécène dès 2 000 € investis dans un projet.
- Les fonds sont débloqués au porteur par jalons, après un vote des investisseurs du projet.
- On peut suivre un projet (❤️), poser des questions au porteur, lire ses actualités, revendre ses jetons sur le Marché des jetons et télécharger une attestation PDF depuis Mon portefeuille.
- Parrainage : le filleul et le parrain reçoivent +10 % de jetons offerts sur leur prochain pack.
- Mode démo : aucun paiement réel, aucune commission.

QUESTIONS PERSONNELLES : réponds avec les données ci-dessous (mes investissements, mes jetons par projet, mon plafond restant, mon profil, mes projets suivis, mon code de parrainage). Si une donnée manque, dis où la trouver dans le menu ⋮.

CE QUE L’UTILISATEUR PEUT FAIRE DANS CE CHAT (propose-le quand c’est utile, en donnant la phrase exacte) :
- Acheter un pack : « Achète le pack Découverte de <projet> » ou « Investis 200 € dans <projet> ».
- Suivre un projet : « Ajoute <projet> à mes favoris » ; arrêter : « Retire <projet> de mes favoris ».
- Comparer des projets, choisir selon un budget, comprendre les risques, les jalons, la revente, le parrainage.

DONNÉES ACTUELLES DE L’APPLICATION :
${context.describe()}''';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-goog-api-key': _key,
  };

  /// Version d'un modèle (« gemini-3.8-flash » → 3.8), pour garder le plus
  /// récent.
  static double _versionOf(String model) =>
      double.tryParse(
        RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(model)?.group(1) ?? '',
      ) ??
      0;

  /// Modèles à essayer, dans l'ordre : [forcedModel] s'il est donné, sinon
  /// les [preferredModels] disponibles pour la clé, puis les autres Flash
  /// « texte » du plus récent au plus ancien (les noms changent souvent).
  static Future<List<String>> _candidateModels() async {
    if (forcedModel.isNotEmpty) return [forcedModel];
    final cached = _models;
    if (cached != null) return cached;
    try {
      final response = await client
          .get(Uri.parse('$baseUrl/models?pageSize=200'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return preferredModels;
      final models = [
        for (final model
            in (jsonDecode(utf8.decode(response.bodyBytes))
                        as Map<String, Object?>)['models']
                    as List? ??
                [])
          if (model is Map &&
              model['name'] is String &&
              ((model['supportedGenerationMethods'] as List?) ?? []).contains(
                'generateContent',
              ))
            (model['name']! as String).replaceFirst('models/', ''),
      ];
      // Flash « texte » uniquement (pas image, audio, lite ni preview).
      const excluded = [
        'image',
        'tts',
        'audio',
        'live',
        'lite',
        'preview',
        'omni',
      ];
      final flash =
          models
              .where(
                (model) =>
                    model.startsWith('gemini-') &&
                    model.contains('flash') &&
                    !excluded.any(model.contains),
              )
              .toList()
            ..sort((a, b) => _versionOf(b).compareTo(_versionOf(a)));
      final ordered = [
        for (final model in preferredModels)
          if (models.contains(model)) model,
        for (final model in flash)
          if (!preferredModels.contains(model)) model,
      ];
      return _models = ordered.isEmpty
          ? preferredModels
          : ordered.take(4).toList();
    } on Exception {
      return preferredModels;
    }
  }

  /// Essaie les modèles l'un après l'autre : si l'un est surchargé, trop lent
  /// ou indisponible, le suivant prend le relais. Un modèle en échec passe en
  /// dernier pour les questions suivantes.
  static Future<String> _askGemini(
    String question,
    CrowdContext context,
    List<ChatMessage> history,
  ) async {
    if (!isConfigured) {
      throw const GeminiException(
        'Clé Gemini absente : lancez l’app avec F5 dans VS Code '
        '(elle lit config.json).',
      );
    }
    final models = await _candidateModels();
    final now = DateTime.now();
    final ready = [
      for (final model in models)
        if (!(_pausedUntil[model]?.isAfter(now) ?? false)) model,
    ];
    Exception? lastError;
    // Tous en pause : on les réessaie quand même, le quota a pu revenir.
    for (final model in ready.isEmpty ? [...models] : ready) {
      try {
        final reply = await _generate(model, question, context, history);
        _pausedUntil.remove(model);
        return reply;
      } on Exception catch (error) {
        debugPrint('Gemini ($model) : $error');
        lastError = error;
        if (error is TimeoutException ||
            (error is GeminiException && error.statusCode == 429)) {
          _pausedUntil[model] = DateTime.now().add(pause);
        }
        if (identical(models, _models) && models.length > 1) {
          models
            ..remove(model)
            ..add(model);
        }
      }
    }
    throw lastError ?? Exception('Aucun modèle Gemini disponible.');
  }

  static Future<String> _generate(
    String model,
    String question,
    CrowdContext context,
    List<ChatMessage> history, {
    bool lightThinking = true,
  }) async {
    // Les 6 derniers messages suffisent pour suivre la conversation ;
    // Gemini exige que la conversation commence par l'utilisateur.
    final recent = history.reversed
        .take(6)
        .toList()
        .reversed
        .skipWhile((message) => !message.fromUser);
    final response = await client
        .post(
          Uri.parse('$baseUrl/models/$model:generateContent'),
          headers: _headers,
          body: jsonEncode({
            // Réflexion légère : réponses plus rapides.
            if (lightThinking)
              'generationConfig': {
                'thinkingConfig': {'thinkingLevel': 'low'},
              },
            'system_instruction': {
              'parts': [
                {'text': systemPrompt(context)},
              ],
            },
            'contents': [
              for (final message in recent)
                {
                  'role': message.fromUser ? 'user' : 'model',
                  'parts': [
                    {'text': message.text},
                  ],
                },
              {
                'role': 'user',
                'parts': [
                  {'text': question},
                ],
              },
            ],
          }),
        )
        .timeout(timeout);
    // Ancien modèle qui ne connaît pas « thinkingLevel » : on réessaie sans.
    if (response.statusCode == 400 &&
        lightThinking &&
        response.body.toLowerCase().contains('think')) {
      return _generate(model, question, context, history, lightThinking: false);
    }
    if (response.statusCode != 200) {
      throw GeminiException(
        'Gemini a répondu ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    final candidates = body['candidates'] as List?;
    final parts =
        ((candidates?.firstOrNull as Map?)?['content'] as Map?)?['parts']
            as List?;
    final content = [
      for (final part in parts ?? const [])
        if (part is Map && part['text'] is String && part['thought'] != true)
          part['text']! as String,
    ].join().trim();
    if (content.isEmpty) {
      throw Exception('Réponse vide de Gemini.');
    }
    return content;
  }

  // -------------------------------------------------------------------------
  // 4. Réponses de secours (sans IA)

  static String offlineAnswer(String question, CrowdContext context) {
    final text = _normalize(question);
    bool has(List<String> words) => words.any(text.contains);
    final open = context.projects.where(
      (project) => !project.isClosed && !project.isFunded,
    );
    String list(Iterable<FundingProject> projects) => projects.isEmpty
        ? 'aucun'
        : projects.map((project) => project.title).join(', ');

    if (has(['que sais-tu', 'tu fais quoi', 'qui es', 'aide', 'help'])) {
      return 'Je suis **Crowdy** 🤖, je peux :\n'
          '• répondre sur les projets, les packs, les risques, les jalons, '
          'la revente et le parrainage ;\n'
          '• vous dire ce que vous avez investi et votre plafond restant ;\n'
          '• acheter un pack : « Achète le pack Découverte de … » ;\n'
          '• suivre un projet : « Ajoute … à mes favoris ».';
    }
    if (has(['favori', 'suivi', 'suivre'])) {
      return '❤️ Projets suivis : ${list(context.favorites)}.\n'
          'Pour en suivre un, écrivez « Ajoute <projet> à mes favoris ».';
    }
    if (has([
      'mes invest',
      'mes achats',
      'mes jetons',
      'portefeuille',
      'historique',
    ])) {
      final mine = [
        for (final project in context.projects)
          if (context.investedIn(project) > 0)
            '• ${project.title} : ${formatMoney(context.investedIn(project))}, '
                '${context.tokensIn(project)} jetons',
      ];
      return mine.isEmpty
          ? 'Vous n’avez encore rien investi. Essayez « Achète le pack '
                'Découverte de … » 🙂'
          : '💼 Vos investissements :\n${mine.join('\n')}\n'
                'Détails et attestations : menu ⋮ → Mon portefeuille.';
    }
    if (has(['plafond', 'profil', 'questionnaire', 'limite'])) {
      return '🧭 Profil : ${context.investorProfile ?? 'questionnaire non rempli'}'
          ' → plafond de ${formatMoney(context.limitPerProject)} par projet '
          '(Prudent 1 000 €, Équilibré 5 000 €, Dynamique 20 000 €). '
          'Pour le changer : menu ⋮ → Mon profil investisseur.';
    }
    if (has(['parrain', 'filleul', 'mon code'])) {
      return '🎁 Parrainage : partagez votre code'
          '${context.referralCode == null ? '' : ' **${context.referralCode}**'}. '
          'Votre filleul et vous recevez +10 % de jetons offerts sur le '
          'prochain pack. Bonus disponibles : ${context.referralBonuses}. '
          '(menu ⋮ → Parrainage)';
    }
    if (has(['revend', 'revente', 'vendre', 'marché', 'marche des'])) {
      return '🏷️ Sur le **Marché des jetons** (menu ⋮), vous mettez en vente '
          'vos jetons au prix choisi, et un autre investisseur peut les '
          'racheter. Depuis Mon portefeuille, le bouton « Revendre » le fait '
          'pour un projet.';
    }
    if (has(['jalon', 'vote', 'fonds', 'débloc', 'debloc'])) {
      return '🗳️ Les fonds ne sont pas versés d’un coup : le porteur les '
          'demande par jalons, et les investisseurs du projet votent. Le '
          'jalon est débloqué si la majorité vote pour.';
    }
    if (has(['rembours', 'tout ou rien', 'échou', 'echou'])) {
      return '↩️ Tout ou rien : si l’objectif n’est pas atteint à la date '
          'limite, tous les investisseurs sont remboursés automatiquement.';
    }
    if (has(['valid', 'admin', 'en attente'])) {
      return '✅ Chaque nouveau projet est vérifié par l’administrateur avant '
          'd’être visible. Refusé, il revient au porteur avec un motif.';
    }
    if (has(['attestation', 'pdf', 'certificat'])) {
      return '📜 Menu ⋮ → Mon portefeuille → touchez un achat → « Télécharger '
          'le PDF ».';
    }
    if (has(['date limite', 'jours', 'termine', 'fin de', 'bientôt'])) {
      final ending = [
        for (final project in open)
          if (project.daysLeft != null) project,
      ]..sort((a, b) => a.daysLeft!.compareTo(b.daysLeft!));
      return ending.isEmpty
          ? 'Aucune collecte ouverte n’a de date limite.'
          : '⏳ Collectes qui se terminent bientôt :\n${[for (final project in ending) '• ${project.title} : ${project.daysLeft} jour(s)'].join('\n')}';
    }

    if (isAboutMoney(question) &&
        !has(['risqu', 'perte', 'perdre', 'arnaque'])) {
      final best = [...open]
        ..sort((a, b) => context.percentOf(b).compareTo(context.percentOf(a)));
      final cheapest = [...context.packs]
        ..sort((a, b) => a.tokens.compareTo(b.tokens));
      return '💰 **Faire fructifier son argent avec CrowdTech :**\n'
          '• Achetez des jetons d’un projet : s’il réussit, vos jetons '
          'prennent de la valeur et vous recevez des contreparties '
          '(Supporter dès 100 €, Ambassadeur dès 500 €, Mécène dès 2 000 €).\n'
          '• Les grands packs offrent des jetons bonus, et le parrainage '
          'ajoute +10 % de jetons offerts.\n'
          '• Vous pouvez revendre vos jetons sur le **Marché des jetons**.\n'
          '• Estimez un gain avec le **Simulateur de rendement** (menu ⋮).\n'
          '${best.isEmpty ? '' : '👉 À regarder : ${best.take(2).map((project) => '${project.title} (${context.percentOf(project)} %)').join(', ')}.\n'}'
          '${cheapest.isEmpty ? '' : 'Pour commencer petit : le pack ${cheapest.first.name}.\n'}'
          '⚠️ Aucun gain n’est garanti : n’investissez que ce que vous pouvez '
          'vous permettre de perdre, et répartissez sur plusieurs projets.';
    }
    if (has(['pack', 'jeton', 'token', 'bonus', 'réduction'])) {
      return 'Les packs disponibles :\n${[for (final pack in context.packs) '• ${pack.name} : ${pack.tokens} jetons'
            '${pack.bonusPercent > 0 ? ' (+${pack.bonusPercent} % bonus)' : ''}'
            '${pack.discountPercent > 0 ? ' (−${pack.discountPercent} %)' : ''}'].join('\n')}\nPlus le pack est grand, plus vous recevez de jetons offerts.';
    }
    if (has(['risqu', 'risk', 'perte', 'perdre', 'sécuris', 'arnaque'])) {
      return 'Investir dans une startup comporte un risque de perte totale. '
          'Conseils : n’investissez que ce que vous pouvez vous permettre de '
          'perdre, répartissez sur plusieurs projets et regardez le stade '
          '(prototype, lancé…) et la date limite de chaque collecte.';
    }
    if (has(['diversif', 'répartir', 'repartir', 'portefeuille'])) {
      return 'Diversifier, c’est répartir votre budget sur plusieurs projets '
          'de catégories différentes pour limiter le risque. Vous pouvez '
          'suivre vos achats dans « Mon portefeuille ».';
    }
    if (has(['avancé', 'proche', 'meilleur', 'populaire', 'objectif'])) {
      final ranked = [...context.projects]
        ..sort((a, b) => context.percentOf(b).compareTo(context.percentOf(a)));
      if (ranked.isEmpty) return 'Aucun projet n’est publié pour le moment.';
      return 'Avancement des collectes :\n${[for (final project in ranked) '• ${project.title} : ${context.percentOf(project)} % '
            '(${formatMoney(project.amountRaised)} / ${formatMoney(project.goal)})'].join('\n')}';
    }
    if (has(['invest', 'comment', 'acheter', 'participer', 'soutenir'])) {
      return 'Pour investir : ouvrez un projet, appuyez sur « Investir », '
          'choisissez un pack de jetons puis validez. Les jetons apparaissent '
          'ensuite dans votre portefeuille. Vous pouvez aussi m’écrire « Achète le pack Découverte de … » : je prépare l’achat. ${open.length} projet(s) sont '
          'ouverts actuellement.';
    }
    return 'Je peux vous aider sur les projets, les packs de jetons, les risques '
        'et la diversification. Projets ouverts : '
        '${open.isEmpty ? 'aucun' : open.map((project) => project.title).join(', ')}.';
  }
}
