// Questionnaire du profil investisseur : il fixe le plafond par projet.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class InvestorProfilePage extends StatefulWidget {
  final String accountKey;
  const InvestorProfilePage({required this.accountKey, super.key});

  @override
  State<InvestorProfilePage> createState() => _InvestorProfilePageState();
}

class _InvestorProfilePageState extends State<InvestorProfilePage> {
  /// Question → réponses notées 0, 1 et 2.
  static const questions = [
    (
      'Votre expérience des investissements ?',
      ['Aucune', 'Quelques placements', 'Je suis expérimenté(e)'],
    ),
    (
      'Si un projet échoue et que vous perdez votre mise, vous…',
      ['Seriez très inquiet(e)', 'L’accepteriez', 'L’aviez prévu'],
    ),
    (
      'Quelle part de votre épargne voulez-vous investir ?',
      ['Moins de 5 %', 'Entre 5 et 15 %', 'Plus de 15 %'],
    ),
  ];

  final answers = List<int?>.filled(questions.length, null);
  InvestorProfile? current;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    CrowdRules.profileOf(widget.accountKey).then((profile) {
      if (mounted) {
        setState(() {
          current = profile;
          loading = false;
        });
      }
    });
  }

  Future<void> save() async {
    if (answers.contains(null)) {
      context.showMessage('Répondez aux 3 questions.');
      return;
    }
    final profile = await CrowdRules.saveProfile(widget.accountKey, [
      for (final answer in answers) answer!,
    ]);
    if (!mounted) return;
    setState(() => current = profile);
    context.showMessage(
      'Profil ${profile.name} ${profile.emoji} : plafond de '
      '${formatMoney(profile.limitPerProject)} par projet.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = current;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil investisseur')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ScreenHeader(
                  title: profile == null
                      ? 'Quel investisseur êtes-vous ?'
                      : 'Profil ${profile.name} ${profile.emoji}',
                  subtitle:
                      profile?.description ??
                      'Sans questionnaire, le plafond standard est de '
                          '${formatMoney(CrowdRules.standardLimit)} par projet.',
                  icon: Icons.psychology_alt_rounded,
                  stats: [
                    (
                      formatMoney(
                        profile?.limitPerProject ?? CrowdRules.standardLimit,
                      ),
                      'plafond par projet',
                    ),
                  ],
                ),
                for (final (index, (question, options)) in questions.indexed)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. $question',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (score, option) in options.indexed)
                                ChoiceChip(
                                  label: Text(option),
                                  selected: answers[index] == score,
                                  onSelected: (_) =>
                                      setState(() => answers[index] = score),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer mon profil'),
                ),
                const SizedBox(height: 16),
                for (final item in CrowdRules.profiles.values)
                  ListTile(
                    leading: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      '${item.name} : ${formatMoney(item.limitPerProject)} '
                      'max par projet',
                    ),
                    subtitle: Text(item.description),
                  ),
              ],
            ),
    );
  }
}
