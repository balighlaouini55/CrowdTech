// Discussion avec « Crowdy », l'assistant du crowdfunding. Crowdy peut
// aussi préparer l'achat d'un pack : l'utilisateur le confirme dans une
// carte, et l'achat suit les mêmes règles que l'écran Crowd.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/crowd_assistant.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:flutter/material.dart';

class CrowdAssistantPage extends StatefulWidget {
  final CrowdContext crowdContext;
  final String accountKey;
  const CrowdAssistantPage({
    required this.crowdContext,
    required this.accountKey,
    super.key,
  });

  @override
  State<CrowdAssistantPage> createState() => _CrowdAssistantPageState();
}

class _CrowdAssistantPageState extends State<CrowdAssistantPage> {
  final inputController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <ChatMessage>[
    const ChatMessage(
      fromUser: false,
      text:
          'Coucou, je suis ${CrowdAssistant.name} 🤖 ! Je réponds à vos '
          'questions sur les projets, les packs de jetons et l’investissement '
          'participatif. Je peux aussi préparer un achat : écrivez par '
          'exemple « Achète le pack Découverte de Green Pulse Sensor ». 🛒',
    ),
  ];
  bool waiting = false;

  /// Données à jour (après un achat fait dans le chat).
  late CrowdContext crowd = widget.crowdContext;

  /// Achète [pack] dans [project] et l'annonce dans la conversation.
  /// Retourne `true` si l'achat est fait.
  Future<bool> buy(FundingProject project, TokenPack pack) async {
    String reply;
    var done = false;
    try {
      final purchase = await CrowdRules.buyPack(
        projectId: project.id!,
        pack: pack,
        accountKey: widget.accountKey,
      );
      done = true;
      reply =
          '✅ ${purchase.summary}\nRetrouvez-le dans **Mon portefeuille** 💼 '
          '(menu ⋮), avec son attestation PDF.';
      final investments = (await FundingRepository.investments.all())
          .where(
            (row) =>
                row['ownerKey'] == widget.accountKey &&
                CrowdRules.isActive(row),
          )
          .toList();
      crowd = crowd.copyWith(
        projects: [
          for (final item in crowd.projects)
            item.id == project.id ? purchase.project : item,
        ],
        myInvestments: investments,
      );
    } on RuleException catch (error) {
      reply = '😕 Achat impossible : ${error.message}';
    } on Exception catch (error) {
      reply = '😕 Achat impossible : $error';
    }
    if (!mounted) return done;
    setState(() => messages.add(ChatMessage(fromUser: false, text: reply)));
    scrollToEnd();
    return done;
  }

  /// Projet cité dans les exemples (le premier ouvert).
  String get sample =>
      crowd.openProjects.firstOrNull?.title ??
      crowd.projects.firstOrNull?.title ??
      'Green Pulse Sensor';

  /// Toutes les idées de questions, par thème (bouton 💡).
  List<(String, List<(String, String)>)> get ideas => [
    (
      'Agir',
      [
        ('🛒', 'Achète le pack Découverte de $sample'),
        ('🎯', 'Investis 200 € dans $sample'),
        ('❤️', 'Ajoute $sample à mes favoris'),
      ],
    ),
    (
      'Mon compte',
      [
        ('💼', 'Mes investissements'),
        ('🧭', 'Quel est mon plafond ?'),
        ('🎁', 'Mon code de parrainage'),
        ('❤️', 'Quels projets je suis ?'),
      ],
    ),
    (
      'Choisir un projet',
      [
        ('🏆', 'Quel projet est le plus avancé ?'),
        ('⏳', 'Quelles collectes se terminent bientôt ?'),
        ('⚖️', 'Compare les projets ouverts'),
        ('🔎', 'Parle-moi de $sample'),
      ],
    ),
    (
      'Argent & risques',
      [
        ('💰', 'Comment gagner de l’argent avec CrowdTech ?'),
        ('🪙', 'Quel pack de jetons choisir ?'),
        ('⚠️', 'Quels sont les risques ?'),
        ('🧺', 'Comment diversifier mes investissements ?'),
      ],
    ),
    (
      'Fonctionnement',
      [
        ('↩️', 'Que se passe-t-il si l’objectif n’est pas atteint ?'),
        ('🗳️', 'Comment sont débloqués les fonds ?'),
        ('🏷️', 'Comment revendre mes jetons ?'),
        ('✅', 'Comment un projet est-il validé ?'),
        ('📜', 'Comment obtenir mon attestation ?'),
      ],
    ),
  ];

  /// Ouvre la liste des idées ; une idée touchée est envoyée.
  Future<void> showIdeas() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text(
                '💡 Que demander à Crowdy ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              for (final (title, items) in ideas) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (emoji, idea) in items)
                      ActionChip(
                        avatar: Text(emoji),
                        label: Text(idea),
                        onPressed: () => Navigator.pop(context, idea),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked != null) await send(picked);
  }

  /// Ajoute ou retire un projet des favoris, à la demande de l'utilisateur.
  Future<String> follow(FollowRequest request) async {
    final id = request.project.id!;
    final title = request.project.title;
    if (crowd.favoriteIds.contains(id) == request.follow) {
      return request.follow
          ? '❤️ Vous suivez déjà **$title**.'
          : 'Vous ne suivez pas **$title**.';
    }
    try {
      final followed = await CrowdRules.toggleFavorite(id, widget.accountKey);
      crowd = crowd.copyWith(
        favoriteIds: {
          ...crowd.favoriteIds.where((item) => item != id),
          if (followed) id,
        },
      );
      return followed
          ? '❤️ **$title** est dans vos favoris. Filtrez-les avec le cœur sur '
                'l’écran Crowd.'
          : '🤍 Vous ne suivez plus **$title**.';
    } on Exception catch (error) {
      return '😕 Impossible de modifier vos favoris : $error';
    }
  }

  static const suggestions = [
    ('💰', 'Comment gagner de l’argent avec CrowdTech ?'),
    ('🎯', 'J’ai 200 €, je fais quoi ?'),
    ('🏆', 'Quel projet est le plus avancé ?'),
    ('🪙', 'Quel pack de jetons choisir ?'),
    ('⚠️', 'Quels sont les risques ?'),
    ('🧺', 'Comment diversifier mes investissements ?'),
  ];

  @override
  void dispose() {
    inputController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> send([String? preset]) async {
    final question = (preset ?? inputController.text).trim();
    if (question.isEmpty || waiting) return;
    final history = messages.skip(1).toList();
    inputController.clear();
    setState(() {
      messages.add(ChatMessage(fromUser: true, text: question));
      waiting = true;
    });
    scrollToEnd();
    final reply = await CrowdAssistant.answer(
      question,
      crowd,
      history: history,
    );
    final request = reply.follow;
    final shown = request == null
        ? reply
        : ChatMessage(fromUser: false, text: await follow(request));
    if (!mounted) return;
    setState(() {
      messages.add(shown);
      waiting = false;
    });
    scrollToEnd();
  }

  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ModulePalette.funding;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: palette.gradient,
                shape: BoxShape.circle,
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant ${CrowdAssistant.name}'),
                Text(
                  'Crowdfunding & investissement',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                for (final message in messages) ...[
                  _bubble(message),
                  if (message.purchase case final request?)
                    _PurchaseCard(
                      key: ObjectKey(message),
                      request: request,
                      crowd: crowd,
                      onConfirm: buy,
                    ),
                ],
                if (waiting) _typing(),
                if (messages.length == 1) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Suggestions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (emoji, suggestion) in suggestions)
                        ActionChip(
                          avatar: Text(emoji),
                          label: Text(suggestion),
                          onPressed: () => send(suggestion),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _inputBar(palette),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage message) {
    final mine = message.fromUser;
    final palette = ModulePalette.funding;
    final isRefusal = message.text == CrowdAssistant.refusal;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          gradient: mine ? palette.gradient : null,
          color: mine
              ? null
              : isRefusal
              ? AppColors.warningSoft
              : AppColors.surfaceRaised,
          border: mine ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(mine ? 22 : 6),
            bottomRight: Radius.circular(mine ? 6 : 22),
          ),
          boxShadow: mine ? null : softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText.rich(
              TextSpan(
                style: TextStyle(
                  color: mine ? Colors.white : AppColors.ink,
                  height: 1.4,
                ),
                children: _withBold(message.text),
              ),
            ),
            if (!mine && message.offline && !isRefusal) ...[
              const SizedBox(height: 6),
              Text(
                '⚡ Réponse de secours, sans IA. '
                '${message.offlineReason ?? 'Gemini est indisponible.'}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
    if (mine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    // Messages de Crowdy : sa petite bouille à gauche.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8, bottom: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: palette.gradient,
            shape: BoxShape.circle,
          ),
          child: const Text('🤖', style: TextStyle(fontSize: 16)),
        ),
        Flexible(child: bubble),
      ],
    );
  }

  /// `**texte**` (format renvoyé par Gemini) → texte en gras.
  static List<TextSpan> _withBold(String text) => [
    for (final (index, part) in text.split('**').indexed)
      if (part.isNotEmpty)
        TextSpan(
          text: part,
          style: index.isOdd
              ? const TextStyle(fontWeight: FontWeight.w700)
              : null,
        ),
  ];

  Widget _typing() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: softShadow,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            '${CrowdAssistant.name} réfléchit…',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _inputBar(ModulePalette palette) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: softShadow,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Idées de questions',
            onPressed: waiting ? null : showIdeas,
            icon: const Text('💡', style: TextStyle(fontSize: 22)),
          ),
          Expanded(
            child: TextField(
              controller: inputController,
              minLines: 1,
              maxLines: 4,
              maxLength: 400,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => send(),
              decoration: const InputDecoration(
                hintText: 'Posez votre question sur le crowdfunding…',
                counterText: '',
              ),
            ),
          ),
          SpellCheckButton(controller: inputController, compact: true),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Envoyer',
            onPressed: waiting ? null : send,
            style: IconButton.styleFrom(
              backgroundColor: palette.start,
              foregroundColor: Colors.white,
              minimumSize: const Size(50, 50),
            ),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    ),
  );
}

/// Carte d'achat proposée par Crowdy : choix du projet et du pack s'ils
/// manquent, récapitulatif, puis confirmation.
class _PurchaseCard extends StatefulWidget {
  final PurchaseRequest request;
  final CrowdContext crowd;
  final Future<bool> Function(FundingProject project, TokenPack pack) onConfirm;
  const _PurchaseCard({
    required this.request,
    required this.crowd,
    required this.onConfirm,
    super.key,
  });

  @override
  State<_PurchaseCard> createState() => _PurchaseCardState();
}

enum _CardState { choosing, buying, bought, cancelled }

class _PurchaseCardState extends State<_PurchaseCard> {
  late FundingProject? project = widget.request.project;
  late TokenPack? pack = widget.request.pack;
  var state = _CardState.choosing;

  /// Pack trop cher pour le budget annoncé (aucun ne rentre dedans).
  bool budgetTooSmall = false;

  @override
  void initState() {
    super.initState();
    _pickForBudget();
  }

  void _pickForBudget() {
    final budget = widget.request.budget;
    final chosen = project;
    if (pack != null || budget == null || chosen == null) return;
    pack = CrowdAssistant.packForBudget(chosen, widget.crowd.packs, budget);
    budgetTooSmall = pack == null;
  }

  Future<void> confirm() async {
    final chosenProject = project;
    final chosenPack = pack;
    if (chosenProject == null || chosenPack == null) return;
    setState(() => state = _CardState.buying);
    final done = await widget.onConfirm(chosenProject, chosenPack);
    if (!mounted) return;
    setState(() {
      state = done ? _CardState.bought : _CardState.choosing;
      // Refusé (plafond, montant restant…) : on laisse choisir un autre pack.
      if (!done) pack = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chosenProject = project;
    final chosenPack = pack;
    final palette = ModulePalette.funding;
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.soft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.start.withValues(alpha: 0.3)),
        ),
        child: switch (state) {
          _CardState.bought => const Text(
            '✅ Achat confirmé',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          _CardState.cancelled => const Text(
            'Achat annulé.',
            style: TextStyle(color: AppColors.muted),
          ),
          _ when chosenProject == null => _choices(
            'Dans quel projet voulez-vous investir ?',
            [
              for (final item in widget.crowd.projects)
                if (item.acceptsInvestments && item.id != null)
                  (
                    '🚀 ${item.title}',
                    () => setState(() {
                      project = item;
                      _pickForBudget();
                    }),
                  ),
            ],
            empty: 'Aucun projet n’accepte d’investissement en ce moment.',
          ),
          _ when chosenPack == null => _choices(
            budgetTooSmall
                ? 'Aucun pack de ${chosenProject.title} ne tient dans '
                      '${formatMoney(widget.request.budget ?? 0)}. '
                      'Choisissez un pack :'
                : 'Quel pack pour ${chosenProject.title} ?',
            [
              for (final item in widget.crowd.packs)
                (
                  '🪙 ${item.name} • '
                      '${formatMoney(item.priceFor(chosenProject.tokenPrice))}',
                  () => setState(() => pack = item),
                ),
            ],
          ),
          _ => _summary(chosenProject, chosenPack),
        },
      ),
    );
  }

  Widget _choices(
    String title,
    List<(String, VoidCallback)> options, {
    String empty = '',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (options.isEmpty) Text(empty),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, onTap) in options)
            ActionChip(label: Text(label), onPressed: onTap),
        ],
      ),
      TextButton(
        onPressed: () => setState(() => state = _CardState.cancelled),
        child: const Text('Annuler'),
      ),
    ],
  );

  Widget _summary(FundingProject project, TokenPack pack) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    final buying = state == _CardState.buying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🛒 Récapitulatif',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 6),
        line('Projet', project.title),
        line('Pack', pack.name),
        line(
          'Jetons',
          '${pack.totalTokens}'
              '${pack.bonusTokens > 0 ? ' (dont ${pack.bonusTokens} offerts)' : ''}',
        ),
        line('Prix', formatMoney(pack.priceFor(project.tokenPrice))),
        const SizedBox(height: 6),
        const Text(
          '⚠️ Mode démo : aucun paiement réel. Un investissement comporte '
          'un risque de perte.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: buying
                    ? null
                    : () => setState(() => state = _CardState.cancelled),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: buying ? null : confirm,
                child: buying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
