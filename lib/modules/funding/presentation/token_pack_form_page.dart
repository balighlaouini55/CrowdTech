// Formulaire d'ajout / modification d'un pack de jetons.

import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:flutter/material.dart';

class TokenPackFormPage extends StatefulWidget {
  final TokenPack? initialPack;
  const TokenPackFormPage({this.initialPack, super.key});

  @override
  State<TokenPackFormPage> createState() => _TokenPackFormPageState();
}

class _TokenPackFormPageState extends State<TokenPackFormPage> {
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(
    text: widget.initialPack?.name ?? '',
  );
  late final tokensController = TextEditingController(
    text: widget.initialPack?.tokens.toString() ?? '',
  );
  late final bonusController = TextEditingController(
    text: widget.initialPack?.bonusPercent.toString() ?? '0',
  );
  late final discountController = TextEditingController(
    text: widget.initialPack?.discountPercent.toString() ?? '0',
  );
  late bool highlighted = widget.initialPack?.highlighted ?? false;

  @override
  void dispose() {
    nameController.dispose();
    tokensController.dispose();
    bonusController.dispose();
    discountController.dispose();
    super.dispose();
  }

  String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    if (text.length > 30) return '30 caractères maximum.';
    return null;
  }

  String? Function(String?) validateInt({required int min, required int max}) =>
      (value) {
        final number = int.tryParse(value?.trim() ?? '');
        if (number == null) return 'Saisissez un nombre entier.';
        if (number < min || number > max) {
          return 'Valeur entre $min et $max.';
        }
        return null;
      };

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      TokenPack(
        id: widget.initialPack?.id,
        name: nameController.text.trim(),
        tokens: int.parse(tokensController.text.trim()),
        bonusPercent: int.parse(bonusController.text.trim()),
        discountPercent: int.parse(discountController.text.trim()),
        highlighted: highlighted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialPack == null ? 'Nouveau pack' : 'Modifier le pack',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom du pack'),
              validator: validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: tokensController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jetons achetés'),
              validator: validateInt(min: 1, max: 10000),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bonusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jetons offerts (%)',
              ),
              validator: validateInt(min: 0, max: 100),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Réduction sur le prix (%)',
              ),
              validator: validateInt(min: 0, max: 90),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Afficher le badge « Populaire »'),
              value: highlighted,
              onChanged: (value) => setState(() => highlighted = value),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: save, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
