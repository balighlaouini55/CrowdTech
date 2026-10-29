import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../validation/validators.dart';

class ProductCheckoutPage extends StatefulWidget {
  final String accountKey;
  const ProductCheckoutPage({
    this.accountKey = 'demo@crowdtech.app',
    super.key,
  });

  @override
  State<ProductCheckoutPage> createState() => _ProductCheckoutPageState();
}

class _ProductCheckoutPageState extends State<ProductCheckoutPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  bool submitting = false;
  double total = 0;
  List<Map<String, Object?>> orderItems = [];

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> loadSummary() async {
    try {
      final values = await Future.wait([
        CrowdTechDatabase.getItems('cart'),
        CrowdTechDatabase.getItems('products'),
      ]);
      final cart = values[0];
      final products = values[1];
      final lines = <Map<String, Object?>>[];
      for (final item in cart) {
        final product = products.where((row) => row['id'] == item['productId']);
        if (product.isEmpty) continue;
        final row = product.first;
        final price = (row['price']! as num).toDouble();
        final quantity = item['quantity']! as int;
        lines.add({
          'productId': item['productId'],
          'productName': row['name'],
          'quantity': quantity,
          'unitPrice': price,
        });
      }
      if (!mounted) return;
      setState(() {
        orderItems = lines;
        total = lines.fold<double>(
          0,
          (sum, line) =>
              sum + (line['unitPrice']! as double) * (line['quantity']! as int),
        );
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de calculer la commande : $exception'),
        ),
      );
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le panier est vide ou indisponible.')),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      await CrowdTechDatabase.createOrderAndClearCart({
        'customerName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'ownerKey': widget.accountKey,
        'address': addressController.text.trim(),
        'items': orderItems,
        'total': total,
        'status': 'Enregistrée en mode démonstration',
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $exception')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finaliser la commande')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Total de la commande : ${total.toStringAsFixed(2)} €'),
          const SizedBox(height: 14),
          const Text(
            'Paiement désactivé : la validation enregistre seulement une commande de démonstration.',
          ),
          const SizedBox(height: 14),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Saisissez votre nom.'
                      : null,
                ),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: validateEmail,
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse de livraison',
                  ),
                  validator: (value) => value == null || value.trim().length < 5
                      ? 'Adresse requise (5 caractères minimum).'
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const CircularProgressIndicator()
                      : const Text('Valider'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
