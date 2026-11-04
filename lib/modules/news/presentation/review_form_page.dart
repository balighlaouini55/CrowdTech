// Noter une actualité : 1 à 5 étoiles (obligatoire) et un avis (facultatif).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:crowdtech/shared/widgets/star_rating.dart';
import 'package:flutter/material.dart';

/// Résultat du formulaire : la note et l'avis (chaîne vide si aucun avis).
typedef ReviewInput = ({int stars, String review});

class ReviewFormPage extends StatefulWidget {
  final String articleTitle;
  final int initialStars;
  final String initialReview;
  const ReviewFormPage({
    required this.articleTitle,
    this.initialStars = 0,
    this.initialReview = '',
    super.key,
  });

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage> {
  final formKey = GlobalKey<FormState>();
  late final reviewController = TextEditingController(
    text: widget.initialReview,
  );
  late int stars = widget.initialStars;
  bool showStarError = false;

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  /// L'avis est facultatif ; s'il est rempli, il doit être lisible.
  String? validateReview(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length < 5) return 'Avis trop court (5 caractères minimum).';
    if (RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(text)) {
      return 'Les liens sont filtrés dans cette démonstration.';
    }
    return null;
  }

  void save() {
    final formValid = formKey.currentState!.validate();
    setState(() => showStarError = stars == 0);
    if (!formValid || stars == 0) return;
    Navigator.pop<ReviewInput>(context, (
      stars: stars,
      review: reviewController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialStars == 0 ? 'Noter l’actualité' : 'Modifier ma note',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: softShadow,
              ),
              child: Column(
                children: [
                  Text(
                    widget.articleTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cette actualité vous semble-t-elle fiable ?',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  StarPicker(
                    value: stars,
                    onChanged: (value) => setState(() {
                      stars = value;
                      showStarError = false;
                    }),
                  ),
                  if (showStarError) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Choisissez une note de 1 à 5 étoiles.',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: reviewController,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Votre avis (facultatif)',
                hintText: 'Qu’avez-vous pensé de cette actualité ?',
                alignLabelWithHint: true,
              ),
              validator: validateReview,
            ),
            SpellCheckButton(controller: reviewController),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.star_rounded),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
