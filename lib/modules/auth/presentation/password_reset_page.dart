// Page « Mot de passe oublié » : lien par email avec Firebase ; sinon, nouveau
// mot de passe après vérification de l'identité (voir AccountService).

import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:flutter/material.dart';

class PasswordResetPage extends StatefulWidget {
  final String initialEmail;

  /// Changement obligatoire : impossible de revenir en arrière sans l'avoir
  /// fait (mot de passe par défaut de l'administrateur).
  final bool mandatory;

  const PasswordResetPage({
    this.initialEmail = '',
    this.mandatory = false,
    super.key,
  });

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final formKey = GlobalKey<FormState>();
  late final emailController = TextEditingController(text: widget.initialEmail);
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final birthDateController = TextEditingController();
  final phoneController = TextEditingController();

  /// Connecté : le titulaire a déjà prouvé son identité.
  bool get connected => CrowdTechSession.accountKey != null;

  bool passwordChanged = false;

  /// Le nouveau mot de passe se choisit ici, sauf avec Firebase hors connexion
  /// (le lien reçu par email sert alors de preuve).
  bool get showPasswordForm => connected || !FirebaseRest.authEnabled;

  @override
  void dispose() {
    birthDateController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AccountService.resetPassword(
        email: emailController.text,
        newPassword: passwordController.text,
        birthDate: birthDateController.text,
        phone: phoneController.text,
      );
      if (!mounted) return;
      setState(() => passwordChanged = true);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mot de passe modifié. Vous pouvez vous connecter.'),
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  /// Firebase Auth : envoie le lien de réinitialisation par email.
  Future<void> sendEmail() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = validateEmail(emailController.text);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    try {
      await AccountService.sendResetEmail(emailController.text);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Email envoyé 📬 Suivez le lien reçu, puis connectez-vous.',
          ),
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory || passwordChanged,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réinitialiser le mot de passe'),
          automaticallyImplyLeading: !widget.mandatory,
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.mandatory
                    ? 'Ce compte utilise le mot de passe par défaut, connu de '
                          'tous : choisissez-en un nouveau pour continuer.'
                    : connected
                    ? 'Choisissez le nouveau mot de passe de votre compte.'
                    : FirebaseRest.authEnabled
                    ? 'Recevez un lien de réinitialisation par email.'
                    : 'Mode local : aucun email n’est envoyé. Confirmez votre '
                          'identité avec les informations données à l’inscription.',
              ),
              if (FirebaseRest.authEnabled) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: sendEmail,
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Recevoir un email de réinitialisation'),
                ),
              ],
              const SizedBox(height: 18),
              TextFormField(
                controller: emailController,
                readOnly: widget.mandatory,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email du compte',
                  border: OutlineInputBorder(),
                ),
                validator: validateEmail,
              ),
              if (showPasswordForm && !connected) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: birthDateController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Date de naissance (JJ/MM/AAAA)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Saisissez votre date de naissance.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Saisissez votre téléphone.'
                      : null,
                ),
              ],
              if (showPasswordForm) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  validator: validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != passwordController.text
                      ? 'Les mots de passe ne correspondent pas.'
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Changer le mot de passe'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
