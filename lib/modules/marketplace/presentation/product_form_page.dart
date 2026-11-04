// Formulaire d'ajout / modification d'un produit.

import 'dart:convert';

import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/product_image.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/photo_picker_field.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:flutter/material.dart';

class ProductFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const ProductFormPage({this.initialValues, super.key});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  static const categories = [
    'Portable',
    'Smartphone',
    'Tablette',
    'Audio',
    'Montre',
    'Écran',
    'Accessoire',
  ];
  static const conditions = ['Neuf', 'Reconditionné', 'Occasion'];

  final formKey = GlobalKey<FormState>();
  late final nameController = controllerFor('name');
  late final categoryController = controllerFor('category');
  late final priceController = controllerFor('price');
  late final brandController = controllerFor('brand');
  late final stockController = TextEditingController(
    text: widget.initialValues?['stock']?.toString() ?? '10',
  );
  late final descriptionController = controllerFor('description');
  late final imageUrlController = controllerFor('imageUrl');

  /// Photo choisie sur l'appareil, en base64 (null = pas de photo).
  late String? imageData = widget.initialValues?['imageData'] as String?;
  late String condition =
      conditions.contains(widget.initialValues?['condition'])
      ? widget.initialValues!['condition']! as String
      : 'Neuf';

  TextEditingController controllerFor(String key) =>
      TextEditingController(text: widget.initialValues?[key]?.toString() ?? '');

  @override
  void dispose() {
    for (final controller in [
      nameController,
      categoryController,
      priceController,
      brandController,
      stockController,
      descriptionController,
      imageUrlController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Saisissez votre nom.';
    if (text.length < 2) return 'Saisissez au moins 2 caractères.';
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

  String? validateStock(String? value) {
    final stock = int.tryParse(value?.trim() ?? '');
    if (stock == null || stock < 0 || stock > 100000) {
      return 'Saisissez un stock entre 0 et 100000.';
    }
    return null;
  }

  bool uploading = false;

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    String? optional(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    var photoData = imageData;
    var photoUrl = optional(imageUrlController);
    // Firebase Storage (si configuré) : la photo est envoyée en ligne et
    // seul son lien est gardé. Sinon elle reste dans SQLite (base64).
    if (FirebaseRest.storageEnabled && (photoData?.isNotEmpty ?? false)) {
      setState(() => uploading = true);
      try {
        photoUrl = await FirebaseRest.upload(
          'products/${DateTime.now().millisecondsSinceEpoch}.jpg',
          base64Decode(photoData!),
        );
        photoData = null;
      } on Exception catch (error) {
        if (mounted) {
          context.showMessage('Photo gardée sur l’appareil ($error).');
        }
      }
      if (!mounted) return;
      setState(() => uploading = false);
    }
    if (!mounted) return;
    Navigator.pop(context, <String, Object?>{
      'name': nameController.text.trim(),
      'category': categoryController.text.trim(),
      'price': double.parse(priceController.text.trim()),
      'brand': optional(brandController),
      'stock': int.parse(stockController.text.trim()),
      'condition': condition,
      'description': optional(descriptionController),
      'imageUrl': photoUrl,
      'imageData': photoData,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier le produit' : 'Créer un produit'),
      ),
      bottomNavigationBar: FormSaveBar(
        onPressed: uploading ? null : save,
        label: uploading ? 'Envoi de la photo...' : 'Enregistrer',
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              FormSection(
                title: 'Produit',
                icon: Icons.inventory_2_outlined,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du produit',
                      prefixIcon: Icon(Icons.devices_other_rounded),
                    ),
                    validator: validateName,
                  ),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator: requiredText,
                  ),
                  SuggestionChips(
                    controller: categoryController,
                    options: categories,
                  ),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Prix (€)',
                      prefixIcon: Icon(Icons.euro_rounded),
                    ),
                    validator: validatePrice,
                  ),
                ],
              ),
              FormSection(
                title: 'Inventaire et détails',
                icon: Icons.warehouse_outlined,
                children: [
                  TextFormField(
                    controller: brandController,
                    decoration: const InputDecoration(
                      labelText: 'Marque (facultatif)',
                      prefixIcon: Icon(Icons.verified_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantité en stock',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                    validator: validateStock,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: condition,
                    decoration: const InputDecoration(
                      labelText: 'État',
                      prefixIcon: Icon(Icons.new_releases_outlined),
                    ),
                    items: [
                      for (final value in conditions)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) =>
                        setState(() => condition = value ?? 'Neuf'),
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
                ],
              ),
              FormSection(
                title: 'Photo du produit',
                icon: Icons.photo_camera_outlined,
                children: [
                  PhotoPickerField(
                    imageData: imageData,
                    onImageDataChanged: (value) =>
                        setState(() => imageData = value),
                    urlController: imageUrlController,
                    fallbackIcon: ProductImage.iconFor(categoryController.text),
                    fallbackColors: ProductImage.colorsFor(
                      categoryController.text,
                    ),
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
