import 'package:flutter/material.dart';
//product form marketplace page
class MarketplaceProductFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const MarketplaceProductFormPage({this.initialValues, super.key});

  @override
  State<MarketplaceProductFormPage> createState() =>
      _MarketplaceProductFormPageState();
}

class _MarketplaceProductFormPageState
    extends State<MarketplaceProductFormPage> {
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(
    text: widget.initialValues?['name']?.toString() ?? '',
  );
  late final categoryController = TextEditingController(
    text: widget.initialValues?['category']?.toString() ?? '',
  );
  late final priceController = TextEditingController(
    text: widget.initialValues?['price']?.toString() ?? '',
  );

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    super.dispose();
  }

  String? requiredText(String? value, {int minimum = 1, bool isName = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return isName ? 'Saisissez votre nom.' : 'Ce champ est requis.';
    }
    if (text.length < minimum) {
      return 'Saisissez au moins $minimum caractères.';
    }
    return null;
  }

  String? validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    final price = double.tryParse(text);
    if (price == null || !price.isFinite) return 'Saisissez un nombre valide.';
    if (price < 0.01) return 'Saisissez un nombre supérieur ou égal à 0.01.';
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object?>{
      'name': nameController.text.trim(),
      'category': categoryController.text.trim(),
      'price': double.parse(priceController.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier le produit' : 'Créer un produit'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom du produit'),
              validator: (value) =>
                  requiredText(value, minimum: 2, isName: true),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              validator: requiredText,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Prix (€)'),
              validator: validatePrice,
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
