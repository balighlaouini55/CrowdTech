import 'package:flutter/material.dart';

class NewsArticleFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const NewsArticleFormPage({this.initialValues, super.key});

  @override
  State<NewsArticleFormPage> createState() => _NewsArticleFormPageState();
}

class _NewsArticleFormPageState extends State<NewsArticleFormPage> {
  final formKey = GlobalKey<FormState>();
  late final titleController = TextEditingController(
    text: widget.initialValues?['title']?.toString() ?? '',
  );
  late final sourceController = TextEditingController(
    text: widget.initialValues?['source']?.toString() ?? '',
  );
  late final categoryController = TextEditingController(
    text: widget.initialValues?['tag']?.toString() ?? '',
  );
  late final summaryController = TextEditingController(
    text: widget.initialValues?['summary']?.toString() ?? '',
  );

  @override
  void dispose() {
    titleController.dispose();
    sourceController.dispose();
    categoryController.dispose();
    summaryController.dispose();
    super.dispose();
  }

  String? requiredText(String? value, {int minimum = 1}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    if (text.length < minimum) {
      return 'Saisissez au moins $minimum caractères.';
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object?>{
      'title': titleController.text.trim(),
      'source': sourceController.text.trim(),
      'tag': categoryController.text.trim(),
      'summary': summaryController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier l’actualité' : 'Créer une actualité'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Titre'),
              validator: (value) => requiredText(value, minimum: 3),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: sourceController,
              decoration: const InputDecoration(labelText: 'Source'),
              validator: requiredText,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              validator: requiredText,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: summaryController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Résumé'),
              validator: (value) => requiredText(value, minimum: 10),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
