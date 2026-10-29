import 'package:flutter/material.dart';

class FundingProjectFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const FundingProjectFormPage({this.initialValues, super.key});

  @override
  State<FundingProjectFormPage> createState() => _FundingProjectFormPageState();
}

class _FundingProjectFormPageState extends State<FundingProjectFormPage> {
  final formKey = GlobalKey<FormState>();
  late final titleController = TextEditingController(
    text: widget.initialValues?['title']?.toString() ?? '',
  );
  late final companyController = TextEditingController(
    text: widget.initialValues?['company']?.toString() ?? '',
  );
  late final goalController = TextEditingController(
    text: widget.initialValues?['goal']?.toString() ?? '',
  );
  late final tokenPriceController = TextEditingController(
    text: widget.initialValues?['tokenPrice']?.toString() ?? '',
  );
  late final featureController = TextEditingController(
    text: widget.initialValues?['feature']?.toString() ?? '',
  );

  @override
  void dispose() {
    titleController.dispose();
    companyController.dispose();
    goalController.dispose();
    tokenPriceController.dispose();
    featureController.dispose();
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

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object?>{
      'title': titleController.text.trim(),
      'company': companyController.text.trim(),
      'goal': double.parse(goalController.text.trim()),
      'tokenPrice': double.parse(tokenPriceController.text.trim()),
      'feature': featureController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier le projet' : 'Créer un projet'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Nom du projet'),
              validator: (value) => requiredText(value, minimum: 3),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: companyController,
              decoration: const InputDecoration(labelText: 'Entreprise'),
              validator: requiredText,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: goalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Objectif (€)'),
              validator: positiveAmount,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: tokenPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Prix par jeton (€)',
              ),
              validator: positiveAmount,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: featureController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Fonctionnalité financée',
              ),
              validator: requiredText,
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
