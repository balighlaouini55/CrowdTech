// Formulaire de réservation (nom et email du participant), prérempli avec
// les coordonnées du compte et modifiable.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:flutter/material.dart';

class ReservationFormPage extends StatefulWidget {
  /// Compte connecté, utilisé pour préremplir le formulaire.
  final String? accountKey;
  final String? eventTitle;
  const ReservationFormPage({this.accountKey, this.eventTitle, super.key});

  @override
  State<ReservationFormPage> createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  bool prefilled = false;

  @override
  void initState() {
    super.initState();
    prefill();
  }

  Future<void> prefill() async {
    final key = widget.accountKey;
    if (key == null) return;
    try {
      final contact = await AccountService.contactOf(key);
      if (!mounted) return;
      // Ne remplace pas ce que l’utilisateur a déjà commencé à saisir.
      if (nameController.text.isEmpty) {
        nameController.text = contact['name'] ?? '';
      }
      if (emailController.text.isEmpty) {
        emailController.text = contact['email'] ?? '';
      }
      setState(() => prefilled = nameController.text.isNotEmpty);
    } on Exception {
      // Formulaire laissé vide : l’utilisateur saisit ses informations.
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void reserve() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object?>{
      'attendeeName': nameController.text.trim(),
      'email': emailController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réserver une place')),
      bottomNavigationBar: FormSaveBar(
        onPressed: reserve,
        icon: Icons.confirmation_number_outlined,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.eventTitle case final title?)
              TipBanner(
                emoji: '🎟️',
                palette: ModulePalette.events,
                text: prefilled
                    ? 'Votre place pour « $title ». Vos informations sont '
                          'reprises de votre compte, modifiables si besoin.'
                    : 'Votre place pour « $title ».',
              ),
            FormSection(
              title: 'Participant',
              icon: Icons.person_outline_rounded,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().length < 2
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
