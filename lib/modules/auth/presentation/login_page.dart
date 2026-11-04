// Page de connexion : vérifie email et mot de passe dans SQLite.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:crowdtech/modules/auth/presentation/password_reset_page.dart';
import 'package:crowdtech/modules/auth/presentation/widgets/auth_header.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool submitting = false;
  bool showPassword = false;
  String? errorMessage;

  Future<void> submit() async {
    if (submitting || !formKey.currentState!.validate()) return;
    setState(() {
      submitting = true;
      errorMessage = null;
    });
    try {
      final user = await AccountService.login(
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) return;
      if (AccountService.isDefaultAdminPassword(
        emailController.text,
        passwordController.text,
      )) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PasswordResetPage(
              initialEmail: emailController.text.trim(),
              mandatory: true,
            ),
          ),
        );
        if (!mounted) return;
      }
      // L'historique est vidé : « retour » ne ramène pas à l'accueil.
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
        arguments: user,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.toString();
        submitting = false;
      });
    }
  }

  Future<void> resetPassword() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            PasswordResetPage(initialEmail: emailController.text.trim()),
      ),
    );
  }

  /// Remplit le formulaire avec le compte administrateur de démonstration.
  void useDemoAdmin() {
    setState(() {
      emailController.text = AccountService.defaultAdminEmail;
      passwordController.text = AccountService.defaultAdminPassword;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    const AuthHeader(
                      icon: Icons.waving_hand_rounded,
                      title: 'Bon retour !',
                      subtitle: 'Renseignez vos identifiants.',
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: softShadow,
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: passwordController,
                            obscureText: !showPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => submit(),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: showPassword ? 'Masquer' : 'Afficher',
                                onPressed: () => setState(
                                  () => showPassword = !showPassword,
                                ),
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Mot de passe requis.'
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: resetPassword,
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ),
                          if (errorMessage != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Text('😕'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: submitting ? null : submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 56),
                              ),
                              child: const Text('Connexion'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Pas encore de compte ?',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: const Text('Créer un compte'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Raccourci de développement : absent de la version finale.
                    if (kDebugMode)
                      ActionChip(
                        avatar: const Text('🔑'),
                        label: const Text('Essayer avec le compte démo admin'),
                        onPressed: useDemoAdmin,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      FirebaseRest.authEnabled
                          ? 'Les comptes sont enregistrés sur l’appareil et '
                                'dans Firebase.'
                          : 'Les comptes sont enregistrés dans la base SQLite '
                                'de l’appareil.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
