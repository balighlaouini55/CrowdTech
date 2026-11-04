// Page d’inscription : identité, coordonnées, sécurité du compte et
// acceptation des conditions. Tous les champs sont obligatoires ; les
// coordonnées servent ensuite à préremplir les commandes.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/password_breach.dart';
import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:crowdtech/modules/auth/presentation/widgets/auth_header.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final birthDateController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final postalCodeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final referralController = TextEditingController();
  String? country = 'Tunisie';
  String role = UserRoles.reader;
  bool acceptedTerms = false;
  bool showPassword = false;
  bool submitting = false;
  String? errorMessage;

  @override
  void dispose() {
    for (final controller in [
      nameController,
      birthDateController,
      emailController,
      phoneController,
      addressController,
      cityController,
      postalCodeController,
      passwordController,
      confirmController,
      referralController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final valid = formKey.currentState!.validate();
    if (!acceptedTerms) {
      setState(
        () => errorMessage = 'Veuillez accepter les conditions d’utilisation.',
      );
      return;
    }
    if (!valid) return;
    setState(() {
      submitting = true;
      errorMessage = null;
    });
    try {
      // Mot de passe déjà divulgué dans une fuite (Have I Been Pwned) ?
      final breach = await PasswordBreach.check(passwordController.text);
      if (breach != null) {
        if (!mounted) return;
        setState(() {
          errorMessage = breach;
          submitting = false;
        });
        return;
      }
      final birthDate = parseFlexibleDate(birthDateController.text);
      // Parrainage : le code doit correspondre à un compte existant.
      final code = referralController.text.trim();
      final referrer = code.isEmpty ? null : await CrowdRules.referrerFor(code);
      if (code.isNotEmpty && referrer == null) {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Code de parrainage inconnu.';
          submitting = false;
        });
        return;
      }
      final user = await AccountService.register(
        name: nameController.text,
        email: emailController.text,
        password: passwordController.text,
        role: role,
        // Les champs laissés vides ne sont pas enregistrés.
        details: {
          'birthDate': birthDate == null ? '' : isoDate(birthDate),
          'phone': phoneController.text,
          'address': addressController.text,
          'city': cityController.text,
          'postalCode': postalCodeController.text,
          'country': country ?? '',
        },
      );
      if (!mounted) return;
      if (referrer != null) {
        await CrowdRules.recordReferral(
          referrerKey: referrer,
          refereeKey: user.email,
        );
      }
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                icon: Icons.auto_awesome_rounded,
                title: 'Rejoignez CrowdTech',
                subtitle: 'Créez votre compte en quelques secondes.',
                emoji: '🎉',
              ),
              const TipBanner(
                emoji: '📝',
                text:
                    'Tous les champs sont obligatoires. Votre adresse sera '
                    'reprise automatiquement lors de vos commandes '
                    '(toujours modifiable).',
              ),
              FormSection(
                title: 'L’essentiel',
                icon: Icons.badge_outlined,
                badge: 'Obligatoire',
                children: [
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nom requis.'
                        : null,
                  ),
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
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      helperText: '8 caractères minimum, lettres et chiffres',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: showPassword ? 'Masquer' : 'Afficher',
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: validatePassword,
                  ),
                  PasswordStrengthMeter(password: passwordController.text),
                  TextFormField(
                    controller: confirmController,
                    obscureText: !showPassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez confirmer le mot de passe.';
                      }
                      return value != passwordController.text
                          ? 'Les mots de passe ne correspondent pas.'
                          : null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Je suis',
                      prefixIcon: Icon(Icons.workspace_premium_outlined),
                    ),
                    items: [
                      for (final value in UserRoles.selfService)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) =>
                        setState(() => role = value ?? UserRoles.reader),
                  ),
                ],
              ),
              FormSection(
                title: 'Mes coordonnées',
                icon: Icons.contact_mail_outlined,
                badge: 'Obligatoire',
                children: [
                  DateFormField(
                    controller: birthDateController,
                    label: 'Date de naissance',
                    firstDate: DateTime(1900),
                    validator: (value) => validateBirthDate(value),
                  ),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      hintText: '+216 20 123 456',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: validatePhone,
                  ),
                  TextFormField(
                    controller: addressController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      hintText: 'N° et rue',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    validator: (value) => requiredText(value, minimum: 5),
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
                          validator: (value) => validatePostalCode(value),
                        ),
                      ),
                    ],
                  ),
                  CountryField(
                    value: country,
                    optional: false,
                    onChanged: (value) => setState(() => country = value),
                  ),
                ],
              ),
              FormSection(
                title: 'Pour finir',
                icon: Icons.favorite_outline_rounded,
                children: [
                  TextFormField(
                    controller: referralController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Code de parrainage (facultatif)',
                      hintText: 'CT-XXXXXX',
                      prefixIcon: Icon(Icons.card_giftcard_rounded),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: acceptedTerms,
                    onChanged: (value) => setState(() {
                      acceptedTerms = value ?? false;
                      if (acceptedTerms) errorMessage = null;
                    }),
                    title: const Text(
                      'J’accepte les conditions d’utilisation et la '
                      'politique de confidentialité.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  '🔒 Les données sont enregistrées '
                  '${FirebaseRest.authEnabled ? 'sur l’appareil et dans Firebase' : 'dans la base SQLite de l’appareil'} '
                  '(mot de passe chiffré). Le rôle administrateur '
                  'ne peut pas être choisi à l’inscription.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              if (errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 10),
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
              ElevatedButton(
                onPressed: submitting ? null : submit,
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('S’inscrire'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jauge colorée indiquant la solidité du mot de passe saisi.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({required this.password, super.key});

  int get score {
    if (password.isEmpty) return 0;
    var points = 0;
    if (password.length >= 8) points++;
    if (password.length >= 12) points++;
    if (RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'\d').hasMatch(password)) {
      points++;
    }
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      points++;
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final (label, color) = switch (score) {
      <= 1 => ('Faible 😕', AppColors.danger),
      2 => ('Moyen 🙂', AppColors.warning),
      3 => ('Bon 😊', AppColors.success),
      _ => ('Excellent 💪', AppColors.success),
    };
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: score / 4),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                color: color,
                backgroundColor: AppColors.border,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
