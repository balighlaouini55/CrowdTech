// Bouton « Corriger l'orthographe » placé sous un champ de texte
// (commentaire, avis, description…). Il envoie le texte à LanguageTool puis
// affiche chaque faute : l'utilisateur choisit une correction proposée ou
// garde son mot.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/core/network/spell_checker.dart';
import 'package:flutter/material.dart';

class SpellCheckButton extends StatefulWidget {
  final TextEditingController controller;

  /// Icône seule, pour une barre de saisie (chat de l'assistant).
  final bool compact;
  const SpellCheckButton({
    required this.controller,
    this.compact = false,
    super.key,
  });

  @override
  State<SpellCheckButton> createState() => _SpellCheckButtonState();
}

class _SpellCheckButtonState extends State<SpellCheckButton> {
  bool checking = false;

  Future<void> check() async {
    final text = widget.controller.text;
    final messenger = ScaffoldMessenger.of(context);
    if (text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Écrivez d’abord votre texte.')),
      );
      return;
    }
    setState(() => checking = true);
    final List<SpellingIssue> issues;
    try {
      issues = await SpellChecker.check(text);
    } on ApiException catch (error) {
      if (mounted) setState(() => checking = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Correcteur indisponible : $error')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => checking = false);
    if (issues.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('✅ Aucune faute trouvée.')),
      );
      return;
    }
    final corrected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SpellCheckSheet(text: text, issues: issues),
    );
    if (corrected == null || corrected == text) return;
    widget.controller.value = TextEditingValue(
      text: corrected,
      selection: TextSelection.collapsed(offset: corrected.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        tooltip: 'Corriger l’orthographe',
        onPressed: checking ? null : check,
        icon: checking
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.spellcheck_rounded),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: checking ? null : check,
        icon: checking
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.spellcheck_rounded, size: 20),
        label: Text(checking ? 'Vérification…' : 'Corriger l’orthographe'),
      ),
    );
  }
}

/// Liste des fautes : pour chacune, les corrections proposées et « Garder ».
/// Retourne le texte corrigé (Navigator.pop).
class SpellCheckSheet extends StatefulWidget {
  final String text;
  final List<SpellingIssue> issues;
  const SpellCheckSheet({required this.text, required this.issues, super.key});

  @override
  State<SpellCheckSheet> createState() => _SpellCheckSheetState();
}

class _SpellCheckSheetState extends State<SpellCheckSheet> {
  /// Choix par faute : la correction, ou null pour garder le mot.
  late final Map<SpellingIssue, String?> choices = {
    for (final issue in widget.issues) issue: issue.suggestions.firstOrNull,
  };

  void chooseAll({required bool correct}) => setState(() {
    for (final issue in widget.issues) {
      choices[issue] = correct ? issue.suggestions.firstOrNull : null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final preview = SpellChecker.apply(widget.text, widget.issues, choices);
    final corrections = choices.values.whereType<String>().length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.spellcheck_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.issues.length} faute(s) possible(s)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Tout corriger ou tout garder',
                    onSelected: (correct) => chooseAll(correct: correct),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: true, child: Text('Tout corriger')),
                      PopupMenuItem(value: false, child: Text('Tout garder')),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final issue in widget.issues) _issueCard(issue),
                  const SizedBox(height: 8),
                  Text('Aperçu', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(preview),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, preview),
                      child: Text(
                        corrections == 0
                            ? 'Garder mon texte'
                            : 'Appliquer ($corrections)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _issueCard(SpellingIssue issue) {
    final choice = choices[issue];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: issue.original,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.wavy,
                      decorationColor: AppColors.danger,
                    ),
                  ),
                  if (choice != null) ...[
                    const TextSpan(text: '  →  '),
                    TextSpan(
                      text: choice,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              issue.message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final suggestion in issue.suggestions)
                  ChoiceChip(
                    label: Text(suggestion),
                    selected: choice == suggestion,
                    onSelected: (_) =>
                        setState(() => choices[issue] = suggestion),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.undo_rounded, size: 16),
                  label: Text('Garder « ${issue.original} »'),
                  selected: choice == null,
                  onSelected: (_) => setState(() => choices[issue] = null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
