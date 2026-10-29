import 'package:flutter/material.dart';

class NewsCommentFormPage extends StatefulWidget {
  const NewsCommentFormPage({super.key});

  @override
  State<NewsCommentFormPage> createState() => _NewsCommentFormPageState();
}

class _NewsCommentFormPageState extends State<NewsCommentFormPage> {
  final formKey = GlobalKey<FormState>();
  final commentController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  String? validateComment(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 10) return 'Saisissez au moins 10 caractères.';
    if (text.length > 500) return 'Maximum 500 caractères.';
    if (RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(text)) {
      return 'Les liens sont filtrés dans cette démonstration.';
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, commentController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau commentaire')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: commentController,
              minLines: 4,
              maxLines: 8,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Votre commentaire',
                alignLabelWithHint: true,
              ),
              validator: validateComment,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: save, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
