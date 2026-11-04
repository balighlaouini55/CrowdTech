// Formulaire d'ajout / modification d'une actualité.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/photo_picker_field.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:flutter/material.dart';

class ArticleFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const ArticleFormPage({this.initialValues, super.key});

  @override
  State<ArticleFormPage> createState() => _ArticleFormPageState();
}

class _ArticleFormPageState extends State<ArticleFormPage> {
  static const categories = ['IA', 'Cloud', 'Sécurité', 'Web', 'Startups'];

  final formKey = GlobalKey<FormState>();
  late final titleController = controllerFor('title');
  late final sourceController = controllerFor('source');
  late final categoryController = controllerFor('tag');
  late final summaryController = controllerFor('summary');
  late final authorController = controllerFor('author');
  late final urlController = controllerFor('url');
  late final dateController = TextEditingController(
    text: formatDate(
      widget.initialValues?['publishedAt']?.toString() ??
          isoDate(DateTime.now()),
    ),
  );

  late final imageUrlController = controllerFor('imageUrl');

  /// Photo choisie sur l'appareil, en base64 (null = aucune).
  late String? imageData = widget.initialValues?['imageData'] as String?;

  TextEditingController controllerFor(String key) =>
      TextEditingController(text: widget.initialValues?[key]?.toString() ?? '');

  @override
  void dispose() {
    for (final controller in [
      imageUrlController,
      titleController,
      sourceController,
      categoryController,
      summaryController,
      authorController,
      urlController,
      dateController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final date = parseFlexibleDate(dateController.text);
    String? optional(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    Navigator.pop(context, <String, Object?>{
      'title': titleController.text.trim(),
      'source': sourceController.text.trim(),
      'tag': categoryController.text.trim(),
      'summary': summaryController.text.trim(),
      'author': optional(authorController),
      'url': optional(urlController),
      'publishedAt': date == null ? null : isoDate(date),
      'imageUrl': optional(imageUrlController),
      'imageData': imageData,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier l’actualité' : 'Créer une actualité'),
      ),
      bottomNavigationBar: FormSaveBar(onPressed: save),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              FormSection(
                title: 'Article',
                icon: Icons.article_outlined,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) => requiredText(value, minimum: 3),
                  ),
                  TextFormField(
                    controller: sourceController,
                    decoration: const InputDecoration(
                      labelText: 'Source',
                      prefixIcon: Icon(Icons.public_rounded),
                    ),
                    validator: requiredText,
                  ),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    validator: requiredText,
                  ),
                  SuggestionChips(
                    controller: categoryController,
                    options: categories,
                  ),
                  TextFormField(
                    controller: summaryController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Résumé',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => requiredText(value, minimum: 10),
                  ),
                  SpellCheckButton(controller: summaryController),
                ],
              ),
              FormSection(
                title: 'Informations complémentaires',
                icon: Icons.info_outline_rounded,
                children: [
                  TextFormField(
                    controller: authorController,
                    decoration: const InputDecoration(
                      labelText: 'Auteur (facultatif)',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  TextFormField(
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Lien de l’article (facultatif)',
                      hintText: 'https://…',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                    validator: optionalUrl,
                  ),
                  DateFormField(
                    controller: dateController,
                    label: 'Date de publication',
                    validator: optionalDate,
                  ),
                ],
              ),
              FormSection(
                title: 'Photo de l’article',
                icon: Icons.image_outlined,
                children: [
                  PhotoPickerField(
                    imageData: imageData,
                    onImageDataChanged: (value) =>
                        setState(() => imageData = value),
                    urlController: imageUrlController,
                    fallbackIcon: Icons.image_outlined,
                    fallbackColors: [
                      ModulePalette.news.start,
                      ModulePalette.news.end,
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
