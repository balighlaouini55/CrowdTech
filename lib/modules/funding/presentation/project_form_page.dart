// Formulaire d'ajout / modification d'un projet.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/currency_service.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/photo_picker_field.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:flutter/material.dart';

class ProjectFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const ProjectFormPage({this.initialValues, super.key});

  @override
  State<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends State<ProjectFormPage> {
  static const categories = [
    'IA',
    'Green tech',
    'Santé',
    'Fintech',
    'Éducation',
    'Logiciel',
  ];

  final formKey = GlobalKey<FormState>();
  late final titleController = controllerFor('title');
  late final companyController = controllerFor('company');
  late final goalController = controllerFor('goal');
  late final tokenPriceController = controllerFor('tokenPrice');
  late final featureController = controllerFor('feature');
  late final categoryController = controllerFor('category');
  late final descriptionController = controllerFor('description');
  late final deadlineController = TextEditingController(
    text: formatDate(widget.initialValues?['deadline']?.toString()),
  );

  late final imageUrlController = controllerFor('imageUrl');
  late final locationController = controllerFor('location');
  late final websiteController = controllerFor('website');
  late final teamSizeController = controllerFor('teamSize');
  static const stages = ['Idée', 'Prototype', 'Lancé'];
  late String stage = stages.contains(widget.initialValues?['stage'])
      ? widget.initialValues!['stage']! as String
      : 'Prototype';

  /// Photo choisie sur l'appareil, en base64 (null = aucune).
  late String? imageData = widget.initialValues?['imageData'] as String?;

  TextEditingController controllerFor(String key) =>
      TextEditingController(text: widget.initialValues?[key]?.toString() ?? '');

  @override
  void dispose() {
    for (final controller in [
      imageUrlController,
      locationController,
      websiteController,
      teamSizeController,
      titleController,
      companyController,
      goalController,
      tokenPriceController,
      featureController,
      categoryController,
      descriptionController,
      deadlineController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? positiveAmount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    final amount = double.tryParse(text);
    if (amount == null || !amount.isFinite) {
      return 'Saisissez un nombre valide.';
    }
    if (amount < 0.01) {
      return 'Saisissez un nombre supérieur ou égal à 0.01.';
    }
    return null;
  }

  String? validateTokenPrice(String? value) {
    final error = positiveAmount(value);
    if (error != null) return error;
    final goal = double.tryParse(goalController.text.trim());
    final price = double.parse(value!.trim());
    if (goal != null && price > goal) {
      return 'Le prix du jeton ne peut pas dépasser l’objectif.';
    }
    return null;
  }

  String? validateDeadline(String? value) {
    final error = optionalDate(value);
    if (error != null) return error;
    final date = parseFlexibleDate(value);
    if (date == null || widget.initialValues != null) return null;
    final now = DateTime.now();
    if (date.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'La date limite doit être aujourd’hui ou plus tard.';
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final deadline = parseFlexibleDate(deadlineController.text);
    String? optional(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    Navigator.pop(context, <String, Object?>{
      'title': titleController.text.trim(),
      'company': companyController.text.trim(),
      'goal': double.parse(goalController.text.trim()),
      'tokenPrice': double.parse(tokenPriceController.text.trim()),
      'feature': featureController.text.trim(),
      'category': optional(categoryController),
      'description': optional(descriptionController),
      'deadline': deadline == null ? null : isoDate(deadline),
      'imageUrl': optional(imageUrlController),
      'imageData': imageData,
      'stage': stage,
      'location': optional(locationController),
      'website': optional(websiteController),
      'teamSize': int.tryParse(teamSizeController.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier le projet' : 'Créer un projet'),
      ),
      bottomNavigationBar: FormSaveBar(onPressed: save),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              FormSection(
                title: 'Projet',
                icon: Icons.rocket_launch_outlined,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du projet',
                      prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                    ),
                    validator: (value) => requiredText(value, minimum: 3),
                  ),
                  TextFormField(
                    controller: companyController,
                    decoration: const InputDecoration(
                      labelText: 'Entreprise',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: requiredText,
                  ),
                ],
              ),
              FormSection(
                title: 'Financement',
                icon: Icons.savings_outlined,
                children: [
                  TextFormField(
                    controller: goalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Objectif (€)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    validator: positiveAmount,
                  ),
                  TextFormField(
                    controller: tokenPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Prix par jeton (€)',
                      prefixIcon: Icon(Icons.toll_outlined),
                    ),
                    validator: validateTokenPrice,
                  ),
                  // Moteur de prix : propose un prix « rond » visant
                  // environ 1 000 jetons pour l'objectif saisi.
                  ListenableBuilder(
                    listenable: goalController,
                    builder: (context, _) {
                      final goal = double.tryParse(
                        goalController.text.trim().replaceAll(',', '.'),
                      );
                      if (goal == null || goal <= 0) {
                        return const SizedBox.shrink();
                      }
                      final suggested = TokenPricing.suggestedPrice(goal);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            'Prix suggéré : ${formatMoney(suggested)} '
                            '(${TokenPricing.supply(goal, suggested)} jetons)',
                          ),
                          onPressed: () => tokenPriceController.text = suggested
                              .toStringAsFixed(
                                suggested == suggested.roundToDouble() ? 0 : 2,
                              ),
                        ),
                      );
                    },
                  ),
                  TextFormField(
                    controller: featureController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Fonctionnalité financée',
                      alignLabelWithHint: true,
                    ),
                    validator: requiredText,
                  ),
                  SpellCheckButton(controller: featureController),
                ],
              ),
              FormSection(
                title: 'Présentation',
                icon: Icons.description_outlined,
                children: [
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie (facultatif)',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  SuggestionChips(
                    controller: categoryController,
                    options: categories,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 600,
                    decoration: const InputDecoration(
                      labelText: 'Description (facultatif)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SpellCheckButton(controller: descriptionController),
                  DateFormField(
                    controller: deadlineController,
                    label: 'Date limite de la collecte (facultatif)',
                    validator: validateDeadline,
                  ),
                ],
              ),
              FormSection(
                title: 'Équipe et avancement',
                icon: Icons.groups_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: stage,
                    decoration: const InputDecoration(
                      labelText: 'Stade du projet',
                      prefixIcon: Icon(Icons.timeline_rounded),
                    ),
                    items: [
                      for (final value in stages)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) =>
                        setState(() => stage = value ?? 'Prototype'),
                  ),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Ville (facultatif)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: websiteController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Site web (facultatif)',
                      hintText: 'https://…',
                      prefixIcon: Icon(Icons.language_rounded),
                    ),
                    validator: optionalUrl,
                  ),
                  TextFormField(
                    controller: teamSizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Taille de l'équipe (facultatif)",
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final size = int.tryParse(text);
                      return size == null || size < 1 || size > 10000
                          ? 'Saisissez un nombre entre 1 et 10000.'
                          : null;
                    },
                  ),
                ],
              ),
              FormSection(
                title: 'Photo de couverture',
                icon: Icons.image_outlined,
                children: [
                  PhotoPickerField(
                    imageData: imageData,
                    onImageDataChanged: (value) =>
                        setState(() => imageData = value),
                    urlController: imageUrlController,
                    fallbackIcon: Icons.image_outlined,
                    fallbackColors: [
                      ModulePalette.funding.start,
                      ModulePalette.funding.end,
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
