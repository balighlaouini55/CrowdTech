// Validation de la commande. Les coordonnées et l’adresse de livraison sont
// préremplies depuis le compte (profil, puis informations d’inscription) et
// restent modifiables avant de confirmer. Les frais de livraison sont
// calculés selon la distance (OSRM) et le code postal est vérifié.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/marketplace/data/marketplace_repository.dart';
import 'package:crowdtech/modules/marketplace/domain/delivery_quote.dart';
import 'package:crowdtech/modules/marketplace/domain/order_escrow.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/delivery_estimate_card.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class CheckoutPage extends StatefulWidget {
  final String accountKey;
  const CheckoutPage({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final postalCodeController = TextEditingController();
  String? country;
  bool loading = true;
  bool submitting = false;
  double total = 0;

  /// Livraison estimée (OSRM) : ajoutée au total si elle a été calculée.
  DeliveryQuote? delivery;
  double get shipping => delivery?.cost ?? 0;
  List<Map<String, Object?>> orderItems = [];

  /// Coordonnées enregistrées dans le compte, pour « Reprendre mes infos ».
  Map<String, String> saved = const {};

  /// Enregistre l’adresse saisie dans le profil après la commande.
  bool saveToProfile = false;

  bool get hasSavedAddress => (saved['address'] ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  @override
  void dispose() {
    for (final controller in [
      nameController,
      emailController,
      phoneController,
      addressController,
      cityController,
      postalCodeController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadSummary() async {
    try {
      final values = await Future.wait([
        MarketplaceRepository.cart.all(),
        MarketplaceRepository.products.all(),
      ]);
      final contact = await AccountService.contactOf(widget.accountKey);
      final cart = values[0]
          .where((item) => item['ownerKey'] == widget.accountKey)
          .toList();
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
          if (row['ownerKey'] case final String seller) 'sellerKey': seller,
          'quantity': quantity,
          'unitPrice': price,
        });
      }

      if (!mounted) return;
      setState(() {
        saved = contact;
        applySaved();
        // Sans adresse enregistrée, on propose de mémoriser celle saisie.
        saveToProfile = !hasSavedAddress;
        orderItems = lines;
        total = lines.fold<double>(
          0,
          (sum, line) =>
              sum + (line['unitPrice']! as double) * (line['quantity']! as int),
        );
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() => loading = false);
      context.showMessage(
        'Impossible de charger la commande et le profil : $exception',
      );
    }
  }

  /// Remplit les champs avec les coordonnées du compte.
  void applySaved() {
    nameController.text = saved['name'] ?? '';
    emailController.text = saved['email'] ?? '';
    phoneController.text = saved['phone'] ?? '';
    addressController.text = saved['address'] ?? '';
    cityController.text = saved['city'] ?? '';
    postalCodeController.text = saved['postalCode'] ?? '';
    final savedCountry = saved['country'] ?? '';
    country = savedCountry.isEmpty ? null : savedCountry;
  }

  /// Adresse complète sur une ligne : « rue, code ville, pays ».
  String get fullAddress => [
    addressController.text.trim(),
    [
      postalCodeController.text.trim(),
      cityController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' '),
    country ?? '',
  ].where((part) => part.isNotEmpty).join(', ');

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (orderItems.isEmpty) {
      context.showMessage('Le panier est vide ou indisponible.');
      return;
    }
    setState(() => submitting = true);
    try {
      await MarketplaceRepository.placeOrder({
        'customerName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'ownerKey': widget.accountKey,
        'address': fullAddress,
        'street': addressController.text.trim(),
        'city': cityController.text.trim(),
        'postalCode': postalCodeController.text.trim(),
        'country': country ?? '',
        'items': orderItems,
        'total': total + shipping,
        if (delivery case final quote?) ...{
          'itemsTotal': total,
          'delivery': quote.toMap(),
        },
        // Escrow : l'argent reste bloqué jusqu'à la réception.
        'status': OrderState.held,
        'sellerKeys': {
          for (final line in orderItems)
            if (line['sellerKey'] case final String seller) seller,
        }.toList(),
        'history': [
          {
            'status': OrderState.held,
            'action': 'Commande payée (démo)',
            'by': widget.accountKey,
            'at': DateTime.now().toIso8601String(),
          },
        ],
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (saveToProfile) {
        await AccountService.saveContact(widget.accountKey, {
          'phone': phoneController.text,
          'address': addressController.text,
          'city': cityController.text,
          'postalCode': postalCodeController.text,
          'country': country ?? '',
        });
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() => submitting = false);
      context.showMessage(
        exception is RuleException
            ? '$exception Modifiez votre panier.'
            : 'Erreur SQLite : $exception',
      );
    }
  }

  Widget _orderSummary() {
    return FormSection(
      title: 'Récapitulatif',
      icon: Icons.receipt_long_rounded,
      children: [
        for (final item in orderItems)
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ModulePalette.store.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '×${item['quantity']}',
                  style: TextStyle(
                    color: ModulePalette.store.start,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${item['productName']}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatMoney(
                  (item['unitPrice']! as double) * (item['quantity']! as int),
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        if (delivery case final quote?)
          Row(
            children: [
              const Expanded(child: Text('Livraison')),
              Text(
                quote.isFree ? 'Offerte' : formatMoney(quote.cost),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        const Divider(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total de la commande',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              formatMoney(total + shipping),
              style: TextStyle(
                color: ModulePalette.store.start,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finaliser la commande')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  ScreenHeader(
                    title: 'Presque terminé !',
                    subtitle: 'Vérifiez vos coordonnées avant de confirmer.',
                    icon: Icons.shopping_bag_rounded,
                    palette: ModulePalette.store,
                    stats: [
                      ('${orderItems.length}', 'article(s)'),
                      (formatMoney(total), 'total'),
                    ],
                  ),
                  _orderSummary(),
                  TipBanner(
                    palette: ModulePalette.store,
                    emoji: hasSavedAddress ? '📍' : '✍️',
                    text: hasSavedAddress
                        ? 'Vos coordonnées ont été reprises de votre compte. '
                              'Vous pouvez les modifier pour cette commande.'
                        : 'Aucune adresse enregistrée pour l’instant : '
                              'saisissez-la ci-dessous, elle sera proposée '
                              'la prochaine fois.',
                  ),
                  FormSection(
                    title: 'Vos coordonnées',
                    icon: Icons.person_outline_rounded,
                    children: [
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'Saisissez votre nom.'
                            : null,
                      ),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: validateEmail,
                      ),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone (facultatif)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) =>
                            validatePhone(value, required: false),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Livraison',
                    icon: Icons.local_shipping_outlined,
                    children: [
                      TextFormField(
                        controller: addressController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Adresse de livraison',
                          hintText: 'N° et rue',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 5
                            ? 'Adresse requise (5 caractères minimum).'
                            : null,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cityController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Ville',
                                prefixIcon: Icon(Icons.location_city_outlined),
                              ),
                              validator: requiredText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: postalCodeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Code postal',
                              ),
                              validator: (value) =>
                                  validatePostalCode(value, required: false),
                            ),
                          ),
                        ],
                      ),
                      CountryField(
                        value: country,
                        onChanged: (value) => setState(() => country = value),
                      ),
                      DeliveryEstimateCard(
                        cityController: cityController,
                        postalCodeController: postalCodeController,
                        country: country,
                        orderTotal: total,
                        onQuote: (quote) => setState(() => delivery = quote),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: saveToProfile,
                        onChanged: (value) =>
                            setState(() => saveToProfile = value ?? false),
                        title: const Text(
                          'Enregistrer cette adresse dans mon profil',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      if (hasSavedAddress)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(applySaved),
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reprendre mes infos'),
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ModulePalette.store.soft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.ink),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Paiement désactivé : cette validation enregistre une commande de démonstration.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: loading
          ? null
          : FormSaveBar(
              onPressed: submitting ? null : submit,
              label: submitting ? 'Enregistrement...' : 'Valider',
              icon: Icons.check_circle_outline_rounded,
            ),
    );
  }
}
