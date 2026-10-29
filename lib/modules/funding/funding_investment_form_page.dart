import 'package:flutter/material.dart';

class FundingInvestmentFormPage extends StatefulWidget {
  final String projectTitle;
  final int maxTokens;

  const FundingInvestmentFormPage({
    required this.projectTitle,
    required this.maxTokens,
    super.key,
  });

  @override
  State<FundingInvestmentFormPage> createState() =>
      _FundingInvestmentFormPageState();
}

class _FundingInvestmentFormPageState extends State<FundingInvestmentFormPage> {
  final formKey = GlobalKey<FormState>();
  final tokensController = TextEditingController();

  @override
  void dispose() {
    tokensController.dispose();
    super.dispose();
  }

  String? validateTokens(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    final tokens = int.tryParse(text);
    if (tokens == null) return 'Saisissez un nombre valide.';
    if (tokens < 1) return 'Saisissez un nombre supérieur ou égal à 1.';
    if (tokens > widget.maxTokens) {
      return 'Maximum autorisé : ${widget.maxTokens}.';
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, int.parse(tokensController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Investir dans ${widget.projectTitle}')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Jetons disponibles : ${widget.maxTokens}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: tokensController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de jetons'),
              validator: validateTokens,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: save, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
